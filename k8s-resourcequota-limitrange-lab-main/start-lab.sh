#!/usr/bin/env bash
# Arranca el laboratorio paso a paso y muestra en consola lo que va pasando.
# Uso: ./start-lab.sh   (en otra terminal, ./watch-lab.sh para verlo en vivo)
set -euo pipefail                                   # Detiene el script ante cualquier error

NS=lab-resource-quota                               # Namespace del laboratorio
cd "$(dirname "$0")"                                # Trabaja desde la carpeta de los manifiestos

step() {                                            # Imprime el título de un paso y espera Enter
  printf '\n\033[1;36m==> %s\033[0m\n' "$1"         # Título en color para distinguirlo
  if [ -t 0 ]; then read -rp "    (Enter para continuar) "; fi  # Pausa solo si hay alguien en la terminal
}

step "1. Crear el namespace (la 'carpeta' aislada del laboratorio)"
kubectl apply -f 00-namespace.yaml                  # Crea el namespace
kubectl get namespace "$NS"                         # Muestra que existe

step "2. Crear el LimitRange (reglas de tamaño para CADA contenedor)"
kubectl apply -f 01-limitrange.yaml                 # Crea las reglas por contenedor
kubectl -n "$NS" describe limitrange container-limits  # Muestra min, max y valores por defecto

step "3. Crear el ResourceQuota (presupuesto TOTAL del namespace)"
kubectl apply -f 02-resourcequota.yaml              # Crea la cuota del namespace
kubectl -n "$NS" describe resourcequota namespace-quota  # Todo en 0: aún no hay Pods

step "4. Deployment de 5 réplicas cuando la cuota solo alcanza para 3"
kubectl apply -f 03-deployment-over-quota.yaml      # Kubernetes lo ACEPTA: el control es al crear cada Pod
sleep 10                                            # Da tiempo a que se creen los Pods
kubectl -n "$NS" get deployment web-over-quota      # Verás READY 3/5
kubectl -n "$NS" get pods -o wide                   # Solo existen 3 Pods; los otros 2 nunca se crean

step "5. Recursos que el LimitRange le puso al Pod (el manifiesto no declaraba ninguno)"
POD=$(kubectl -n "$NS" get pods -l app.kubernetes.io/name=web-over-quota -o name | head -1)  # Toma un Pod
kubectl -n "$NS" get "$POD" -o jsonpath='{.spec.containers[0].resources}{"\n"}'  # requests y limits inyectados

step "6. La cuota quedó llena"
kubectl -n "$NS" describe resourcequota namespace-quota  # requests.cpu 300m/300m y limits.cpu 600m/600m

step "7. Por qué no se crearon las otras 2 réplicas"
kubectl -n "$NS" get events --field-selector reason=FailedCreate \
  -o custom-columns=OBJETO:.involvedObject.name,MENSAJE:.message | head -3  # Error "exceeded quota"

step "8. Deployment con un contenedor MÁS GRANDE que el máximo del LimitRange"
kubectl apply -f 04-deployment-over-limitrange.yaml  # También se ACEPTA el Deployment
sleep 5                                             # Da tiempo a que intente crear el Pod
kubectl -n "$NS" get deployment web-over-limitrange  # Verás READY 0/1: ningún Pod entra
kubectl -n "$NS" get events --field-selector reason=FailedCreate \
  -o custom-columns=OBJETO:.involvedObject.name,MENSAJE:.message | grep limitrange | head -1  # "maximum cpu usage"

step "Listo. Míralo en vivo con ./watch-lab.sh y bórralo con ./delete-lab.sh"
