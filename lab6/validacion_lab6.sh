echo "=== Verificacion final de la Practica 6 ==="

BACKEND_READY=$(kubectl get deployment backend \
  -n lab6 \
  -o jsonpath='{.status.readyReplicas}')

FRONTEND_READY=$(kubectl get deployment frontend \
  -n lab6 \
  -o jsonpath='{.status.readyReplicas}')

[ "$BACKEND_READY" = "2" ] \
  && echo "✅ backend disponible: 2/2" \
  || echo "❌ backend incompleto: ${BACKEND_READY:-0}/2"

[ "$FRONTEND_READY" = "2" ] \
  && echo "✅ frontend disponible: 2/2" \
  || echo "❌ frontend incompleto: ${FRONTEND_READY:-0}/2"

BACKEND_TYPE=$(kubectl get service backend-svc \
  -n lab6 \
  -o jsonpath='{.spec.type}')

FRONTEND_TYPE=$(kubectl get service frontend-svc \
  -n lab6 \
  -o jsonpath='{.spec.type}')

NODEPORT_TYPE=$(kubectl get service frontend-nodeport \
  -n lab6 \
  -o jsonpath='{.spec.type}')

[ "$BACKEND_TYPE" = "ClusterIP" ] \
  && echo "✅ backend-svc es ClusterIP" \
  || echo "❌ backend-svc tiene tipo inesperado: $BACKEND_TYPE"

[ "$FRONTEND_TYPE" = "ClusterIP" ] \
  && echo "✅ frontend-svc es ClusterIP" \
  || echo "❌ frontend-svc tiene tipo inesperado: $FRONTEND_TYPE"

[ "$NODEPORT_TYPE" = "NodePort" ] \
  && echo "✅ frontend-nodeport es NodePort" \
  || echo "❌ frontend-nodeport tiene tipo inesperado: $NODEPORT_TYPE"

NODEPORT=$(kubectl get service frontend-nodeport \
  -n lab6 \
  -o jsonpath='{.spec.ports[0].nodePort}')

[ "$NODEPORT" = "30080" ] \
  && echo "✅ NodePort configurado en 30080" \
  || echo "❌ NodePort inesperado: $NODEPORT"

BACKEND_ENDPOINTS=$(kubectl get endpoints backend-svc \
  -n lab6 \
  -o jsonpath='{.subsets[0].addresses[*].ip}')

FRONTEND_ENDPOINTS=$(kubectl get endpoints frontend-svc \
  -n lab6 \
  -o jsonpath='{.subsets[0].addresses[*].ip}')

[ -n "$BACKEND_ENDPOINTS" ] \
  && echo "✅ backend-svc tiene endpoints" \
  || echo "❌ backend-svc no tiene endpoints"

[ -n "$FRONTEND_ENDPOINTS" ] \
  && echo "✅ frontend-svc tiene endpoints" \
  || echo "❌ frontend-svc no tiene endpoints"

INGRESS_CLASS=$(kubectl get ingress app-ingress \
  -n lab6 \
  -o jsonpath='{.spec.ingressClassName}')

[ "$INGRESS_CLASS" = "nginx" ] \
  && echo "✅ Ingress utiliza la clase nginx" \
  || echo "❌ IngressClass inesperada: $INGRESS_CLASS"

ROOT_BACKEND=$(kubectl get ingress app-ingress \
  -n lab6 \
  -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/")].backend.service.name}')

API_BACKEND=$(kubectl get ingress app-ingress \
  -n lab6 \
  -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/api")].backend.service.name}')

[ "$ROOT_BACKEND" = "frontend-svc" ] \
  && echo "✅ / apunta a frontend-svc" \
  || echo "❌ / apunta a: $ROOT_BACKEND"

[ "$API_BACKEND" = "backend-svc" ] \
  && echo "✅ /api apunta a backend-svc" \
  || echo "❌ /api apunta a: $API_BACKEND"

echo ""
echo "=== Fin de verificacion ==="