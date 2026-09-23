echo "=== Verificacion final de la Practica 5 ==="

kubectl get configmap app-config >/dev/null 2>&1 \
  && echo "✅ ConfigMap app-config disponible" \
  || echo "❌ ConfigMap app-config no encontrado"

kubectl get secret db-credentials >/dev/null 2>&1 \
  && echo "✅ Secret db-credentials disponible" \
  || echo "❌ Secret db-credentials no encontrado"

kubectl get serviceaccount app-reader >/dev/null 2>&1 \
  && echo "✅ ServiceAccount app-reader disponible" \
  || echo "❌ ServiceAccount no encontrada"

kubectl get role pod-configmap-reader >/dev/null 2>&1 \
  && echo "✅ Role disponible" \
  || echo "❌ Role no encontrado"

kubectl get rolebinding app-reader-binding >/dev/null 2>&1 \
  && echo "✅ RoleBinding disponible" \
  || echo "❌ RoleBinding no encontrado"

CAN_GET_PODS=$(kubectl auth can-i get pods \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5)

CAN_GET_SECRETS=$(kubectl auth can-i get secrets \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5)

[ "$CAN_GET_PODS" = "yes" ] \
  && echo "✅ app-reader puede leer Pods" \
  || echo "❌ app-reader no puede leer Pods"

[ "$CAN_GET_SECRETS" = "no" ] \
  && echo "✅ app-reader no puede leer Secrets" \
  || echo "❌ app-reader tiene acceso inesperado a Secrets"

SA=$(kubectl get pod rbac-demo-pod \
  -o jsonpath='{.spec.serviceAccountName}')

[ "$SA" = "app-reader" ] \
  && echo "✅ rbac-demo-pod usa app-reader" \
  || echo "❌ ServiceAccount inesperada: $SA"

echo "=== Fin de verificacion ==="