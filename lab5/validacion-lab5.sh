echo "=== Validacion complementaria 5.1 ==="

echo ""
echo "--- Lectura de Services ---"
for verb in get list watch; do
  RESULT=$(kubectl auth can-i "$verb" services \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5)

  echo "$verb services: $RESULT"
done

echo ""
echo "--- Escritura de Services ---"
for verb in create update delete; do
  RESULT=$(kubectl auth can-i "$verb" services \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5)

  echo "$verb services: $RESULT"
done

echo ""
echo "--- Permisos sensibles ---"
echo "get secrets: $(kubectl auth can-i get secrets \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5)"

echo "create pods: $(kubectl auth can-i create pods \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5)"

echo "get pods kube-system: $(kubectl auth can-i get pods \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=kube-system)"

echo ""
echo "=== Fin de validacion ==="