echo "=== Validacion final de la Practica 8 ==="

for POD in \
  pod-a1-imagepull \
  pod-a2-crashloop \
  pod-a3-pending \
  pod-b1-backend \
  pod-b2-webserver \
  pod-c1-dns-policy \
  pod-c2-dns-debug
do
  STATUS=$(kubectl get pod "$POD" \
    -n troubleshooting-lab \
    -o jsonpath='{.status.phase}')

  echo "$POD: $STATUS"
done

READY=$(kubectl get deployment deploy-b3-liveness \
  -n troubleshooting-lab \
  -o jsonpath='{.status.readyReplicas}')

echo "deploy-b3-liveness ready: ${READY:-0}/2"

B1_SELECTOR=$(kubectl get service svc-b1-wrong-selector \
  -n troubleshooting-lab \
  -o jsonpath='{.spec.selector.app}')

B2_TARGET=$(kubectl get service svc-b2-wrong-port \
  -n troubleshooting-lab \
  -o jsonpath='{.spec.ports[0].targetPort}')

B3_PATH=$(kubectl get deployment deploy-b3-liveness \
  -n troubleshooting-lab \
  -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}')

echo "B1 selector: $B1_SELECTOR"
echo "B2 targetPort: $B2_TARGET"
echo "B3 liveness path: $B3_PATH"

echo ""
echo "Endpoints:"

kubectl get endpoints \
  -n troubleshooting-lab \
  svc-b1-wrong-selector \
  svc-b2-wrong-port \
  svc-b3-liveness

echo ""
echo "DNS:"

kubectl exec pod-c1-dns-policy \
  -n troubleshooting-lab -- \
  nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 \
  && echo "C1 DNS: OK" \
  || echo "C1 DNS: FAIL"

kubectl exec pod-c2-dns-debug \
  -n troubleshooting-lab -- \
  nslookup svc-b1-wrong-selector.troubleshooting-lab.svc.cluster.local >/dev/null 2>&1 \
  && echo "C2 DNS: OK" \
  || echo "C2 DNS: FAIL"

echo "=== Fin de validacion ==="