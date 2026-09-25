 #!/usr/bin/env bash
# ============================================================
# USO DE PVC - tabla con PVC, PV, StorageClass, ubicación y uso
#
# Uso:
# ./pvc-uso.sh # todos los namespaces
# ./pvc-uso.sh produccion # un namespace
# watch -n 1 ./pvc-uso.sh # refresco cada segundo
#
# Variables:
# UMBRAL=85 porcentaje a partir del cual se marca ALERTA
#
# Requisitos: kubectl, jq, column
# ============================================================

set -uo pipefail

UMBRAL="${UMBRAL:-85}"
NS="${1:-}"

if [[ -n "$NS" ]]; then NSARG=(-n "$NS"); else NSARG=(-A); fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

kubectl get pvc "${NSARG[@]}" -o json > "$TMP/pvc.json" || exit 1
kubectl get pv -o json > "$TMP/pv.json" || exit 1

# Uso real reportado por el kubelet de cada nodo
for n in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
kubectl get --raw "/api/v1/nodes/$n/proxy/stats/summary" 2>/dev/null |
jq -c --arg node "$n" '[.pods[].volume[]? | select(.pvcRef)
| {k: "\(.pvcRef.namespace)/\(.pvcRef.name)", node: $node,
used: .usedBytes, cap: .capacityBytes}]'
done | jq -s 'add // [] | map({(.k): .}) | add // {}' > "$TMP/stats.json"

jq -rn \
--slurpfile pvc "$TMP/pvc.json" \
--slurpfile pv "$TMP/pv.json" \
--slurpfile st "$TMP/stats.json" \
--argjson umbral "$UMBRAL" '
def gib: if . == null then "-" else (. / 1073741824 * 100 | floor / 100 | tostring) end;
def ubicacion:
if .spec.hostPath then .spec.hostPath.path
elif .spec.local then .spec.local.path
elif .spec.nfs then "\(.spec.nfs.server):\(.spec.nfs.path)"
elif .spec.csi then "\(.spec.csi.driver):\(.spec.csi.volumeHandle)"
else "-" end;
def nodo:
[.spec.nodeAffinity.required.nodeSelectorTerms[]?.matchExpressions[]?
| select(.key == "kubernetes.io/hostname") | .values[]] | first;

($pv[0].items | map({(.metadata.name): .}) | add // {}) as $pvs
| $st[0] as $stats
| ["NAMESPACE","PVC","ESTADO","PV","STORAGECLASS","SOLICITADO",
"USADO_GiB","MAX_GiB","USO_%","ALERTA","NODO","UBICACION"],
($pvc[0].items[]
| .metadata.namespace as $ns
| .metadata.name as $n
| $pvs[.spec.volumeName // ""] as $v
| $stats["\($ns)/\($n)"] as $s
| (if $s != null and ($s.cap // 0) > 0
then (100 * $s.used / $s.cap | floor) else null end) as $pct
| [ $ns,
$n,
.status.phase,
(.spec.volumeName // "-"),
(.spec.storageClassName // "-"),
(.spec.resources.requests.storage // "-"),
($s.used | gib),
($s.cap | gib),
($pct // "-" | tostring),
(if $pct == null then "SIN-DATOS"
elif $pct >= $umbral then "ALERTA" else "OK" end),
((if $v then ($v | nodo) else null end) // $s.node // "-"),
(if $v then ($v | ubicacion) else "-" end) ])
| @tsv' | column -t -s $'\t'

echo
echo "Actualizado: $(date '+%H:%M:%S') | Umbral de alerta: ${UMBRAL}%"
