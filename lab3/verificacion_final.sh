echo "=== Verificacion final de la Practica 3 ==="

NOT_READY=$(kubectl get nodes --no-headers \
  | awk '$2 !~ /^Ready/ {count++} END {print count+0}')

if [ "$NOT_READY" = "0" ]; then
  echo "✅ Todos los nodos estan disponibles"
else
  echo "❌ Existe al menos un nodo no disponible"
fi

if kubectl get nodes --no-headers | grep -q "SchedulingDisabled"; then
  echo "❌ Existe un nodo con SchedulingDisabled"
else
  echo "✅ Todos los nodos aceptan scheduling"
fi

WEB_READY=$(kubectl get deployment app-web -n lab3 \
  -o jsonpath='{.status.readyReplicas}')

WEB_DESIRED=$(kubectl get deployment app-web -n lab3 \
  -o jsonpath='{.spec.replicas}')

if [ "$WEB_READY" = "$WEB_DESIRED" ]; then
  echo "✅ app-web disponible: $WEB_READY/$WEB_DESIRED"
else
  echo "❌ app-web incompleto: $WEB_READY/$WEB_DESIRED"
fi

BACK_READY=$(kubectl get deployment app-backend -n lab3 \
  -o jsonpath='{.status.readyReplicas}')

BACK_DESIRED=$(kubectl get deployment app-backend -n lab3 \
  -o jsonpath='{.spec.replicas}')

if [ "$BACK_READY" = "$BACK_DESIRED" ]; then
  echo "✅ app-backend disponible: $BACK_READY/$BACK_DESIRED"
else
  echo "❌ app-backend incompleto: $BACK_READY/$BACK_DESIRED"
fi

echo ""
echo "Distribucion final de Pods:"
kubectl get pods -n lab3 -o wide

echo ""
echo "PodDisruptionBudgets:"
kubectl get pdb -n lab3

echo "=== Fin de verificacion ==="