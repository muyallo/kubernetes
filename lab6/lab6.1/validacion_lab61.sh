echo "=== Validacion complementaria 6.1 ==="

SELECTOR=$(kubectl get service backend-svc \
  -n lab6 \
  -o jsonpath='{.spec.selector.app}')

ENDPOINTS=$(kubectl get endpoints backend-svc \
  -n lab6 \
  -o jsonpath='{.subsets[0].addresses[*].ip}')

CURRENT_IP=$(kubectl get service backend-svc \
  -n lab6 \
  -o jsonpath='{.spec.clusterIP}')

echo "Selector: $SELECTOR"
echo "Endpoints: $ENDPOINTS"
echo "ClusterIP conservada: $CURRENT_IP"

FRONTEND_POD=$(kubectl get pod \
  -n lab6 \
  -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

RESPONSE=$(kubectl exec \
  -n lab6 \
  "$FRONTEND_POD" -- \
  sh -c 'wget -qO- http://backend-svc')

echo "$RESPONSE" | grep -q "BACKEND API" \
  && echo "Conectividad: OK" \
  || echo "Conectividad: ERROR"