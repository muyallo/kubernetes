echo "=== Validacion final de la Practica 7 ==="

STATIC_PVC=$(kubectl get pvc pvc-lab7-static \
  -n lab7 \
  -o jsonpath='{.status.phase}')

[ "$STATIC_PVC" = "Bound" ] \
  && echo "✅ PVC estatico Bound" \
  || echo "❌ PVC estatico: $STATIC_PVC"

STATIC_PV=$(kubectl get pv pv-lab7-static \
  -o jsonpath='{.status.phase}')

[ "$STATIC_PV" = "Bound" ] \
  && echo "✅ PV estatico Bound" \
  || echo "❌ PV estatico: $STATIC_PV"

MYSQL_NODE=$(kubectl get pod mysql-persistente \
  -n lab7 \
  -o jsonpath='{.spec.nodeName}')

[ "$MYSQL_NODE" = "minikube" ] \
  && echo "✅ MySQL programado en minikube" \
  || echo "❌ MySQL programado en: $MYSQL_NODE"

MYSQL_COUNT=$(kubectl exec mysql-persistente \
  -n lab7 -- \
  mysql \
  -uroot \
  -p'K8s-lab7-2026!' \
  testdb \
  -sNe 'SELECT COUNT(*) FROM registros;' \
  2>/dev/null)

[ "$MYSQL_COUNT" = "3" ] \
  && echo "✅ Datos MySQL persistentes: 3 registros" \
  || echo "❌ Registros encontrados: $MYSQL_COUNT"

DYNAMIC_PVC=$(kubectl get pvc pvc-lab7-dynamic \
  -n lab7 \
  -o jsonpath='{.status.phase}')

[ "$DYNAMIC_PVC" = "Bound" ] \
  && echo "✅ PVC dinamico Bound" \
  || echo "❌ PVC dinamico: $DYNAMIC_PVC"

DYNAMIC_FILE=$(kubectl exec nginx-dynamic \
  -n lab7 -- \
  sh -c 'cat /usr/share/nginx/html/index.html' \
  2>/dev/null)

echo "$DYNAMIC_FILE" | grep -q "PVC dinamico operativo" \
  && echo "✅ PVC dinamico montado y con datos" \
  || echo "❌ No se pudo validar el contenido del PVC dinamico"

EMPTY_FILE=$(kubectl exec emptydir-demo \
  -n lab7 -- \
  sh -c 'test -f /datos/temporal.txt && echo existe || echo ausente')

[ "$EMPTY_FILE" = "ausente" ] \
  && echo "✅ emptyDir perdio el dato al recrear el Pod" \
  || echo "❌ El archivo temporal sigue presente"

echo "=== Fin de validacion ==="