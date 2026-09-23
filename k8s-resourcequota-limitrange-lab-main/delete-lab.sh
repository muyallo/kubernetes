#!/usr/bin/env bash
# Borra el laboratorio completo. Al borrar el namespace, Kubernetes borra todo
# lo que hay dentro: LimitRange, ResourceQuota, Deployments y Pods.
set -euo pipefail                                   # Detiene el script ante cualquier error

NS=lab-resource-quota                               # Namespace del laboratorio

if ! kubectl get namespace "$NS" >/dev/null 2>&1; then  # ¿Existe el namespace?
  echo "El namespace $NS no existe; no hay nada que borrar."
  exit 0
fi

echo "Contenido actual de $NS:"
kubectl -n "$NS" get deployments,pods,limitrange,resourcequota  # Muestra lo que se va a borrar

echo; echo "Borrando el namespace $NS (espera a que termine)..."
kubectl delete namespace "$NS" --wait=true          # Borra el namespace y todo su contenido
echo "Borrado. Para volver a crearlo: ./start-lab.sh"
