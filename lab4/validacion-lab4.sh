echo "=== Verificacion final de la Practica 4 ==="

for ns in development production; do
  STATUS=$(kubectl get namespace "$ns" \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$STATUS" = "Active" ]; then
    echo "✅ Namespace $ns disponible"
  else
    echo "❌ Namespace $ns no disponible"
  fi
done

if kubectl get namespace staging >/dev/null 2>&1; then
  echo "❌ staging todavia existe"
else
  echo "✅ staging fue eliminado"
fi

if kubectl get resourcequota development-quota \
  -n development >/dev/null 2>&1; then
  echo "✅ ResourceQuota disponible"
else
  echo "❌ ResourceQuota no encontrada"
fi

if kubectl get limitrange development-limits \
  -n development >/dev/null 2>&1; then
  echo "✅ LimitRange disponible"
else
  echo "❌ LimitRange no encontrado"
fi

echo ""
echo "Deployments restantes:"
kubectl get deployments --all-namespaces | grep webapp

echo "=== Fin de verificacion ==="