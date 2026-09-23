#!/usr/bin/env bash
# Muestra el laboratorio en vivo, refrescando cada segundo. Salir con Ctrl+C.
NS=lab-resource-quota                               # Namespace del laboratorio
EVENTS="kubectl -n $NS get events --field-selector reason=FailedCreate --sort-by=.lastTimestamp -o custom-columns=MENSAJE:.message --no-headers"  # Rechazos al crear Pods

exec watch -n 1 -t "
echo '=== Deployments (READY = Pods listos / Pods pedidos) ===';
kubectl -n $NS get deployments 2>&1;
echo; echo '=== Pods (solo existen los que entraron) ===';
kubectl -n $NS get pods -o custom-columns=POD:.metadata.name,ESTADO:.status.phase,NODO:.spec.nodeName 2>&1;
echo; echo '=== Cuota del namespace (Used = usado, Hard = tope) ===';
kubectl -n $NS describe resourcequota namespace-quota 2>&1 | tail -n +3;
echo; echo '=== Último rechazo por CUOTA (web-over-quota) ===';
$EVENTS 2>&1 | grep web-over-quota | tail -1 | sed 's/.*forbidden: //';
echo; echo '=== Último rechazo por LIMITRANGE (web-over-limitrange) ===';
$EVENTS 2>&1 | grep web-over-limitrange | tail -1 | sed 's/.*forbidden: //'
"                                                   # watch repite este bloque cada 1 s
