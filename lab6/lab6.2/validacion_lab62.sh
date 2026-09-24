echo "=== Validacion complementaria 6.2 ==="

echo "dnsPolicy:"
kubectl get pod dns-client \
  -n lab6 \
  -o jsonpath='{.spec.dnsPolicy}{"\n"}'

echo ""
echo "Resolucion FQDN:"
kubectl exec \
  -n lab6 \
  dns-client -- \
  nslookup backend-svc.lab6.svc.cluster.local

echo ""
echo "HTTP:"
kubectl exec \
  -n lab6 \
  dns-client -- \
  sh -c 'wget -qO- http://backend-svc | grep "BACKEND API"'

echo "=== Fin de validacion ==="