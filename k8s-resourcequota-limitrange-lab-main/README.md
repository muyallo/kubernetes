<!-- lang: es-CO -->
# Laboratorio: LimitRange y ResourceQuota

Escenario mínimo para ver qué pasa cuando un Deployment pide, en total,
más recursos de los que el namespace permite.

| Archivo | Objeto | Qué hace |
|---|---|---|
| `00-namespace.yaml` | Namespace `lab-resource-quota` | Aísla el laboratorio |
| `01-limitrange.yaml` | LimitRange `container-limits` | Reglas por contenedor: valores por defecto, mínimo y máximo |
| `02-resourcequota.yaml` | ResourceQuota `namespace-quota` | Tope agregado del namespace (suma de todos los Pods) |
| `03-deployment-over-quota.yaml` | Deployment `web-over-quota` | 5 réplicas válidas una a una, pero la suma supera la cuota |
| `04-deployment-over-limitrange.yaml` | Deployment `web-over-limitrange` | 1 réplica cuyo contenedor supera el máximo del LimitRange |

La imagen es `pause`: no consume casi nada. A propósito: la cuota cuenta lo
declarado (requests/limits), no el consumo real.

## Requisitos

- Un clúster Kubernetes (probado en k3s v1.34.3 con dos nodos; sirve minikube o kind).
- `kubectl` apuntando a ese clúster, con permiso para crear namespaces.
- `watch` para la vista en vivo (viene en `procps` en la mayoría de distribuciones Linux).

## Ejecutar

Usa dos terminales:

```bash
./start-lab.sh    # Terminal 1: crea todo paso a paso (Enter entre pasos) y explica cada resultado
./watch-lab.sh    # Terminal 2: vista en vivo (watch -n 1) de Deployments, Pods, cuota y rechazos
./delete-lab.sh   # Al terminar: borra el namespace y todo lo que contiene
```

Cada línea de los manifiestos tiene un comentario que explica para qué sirve.
En [`output.md`](output.md) están los comandos y las salidas de una corrida
completa, con la explicación de cada paso.

Para experimentar con el watch abierto, cambia la cuota o las réplicas y
observa cómo reacciona el ReplicaSet:

```bash
kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=2   # Libera cuota
kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=5   # Vuelve a 3/5
```

## Orden de admisión de un Pod

1. LimitRange (mutación): si el contenedor no declara `resources`, inyecta
   `defaultRequest` (100m / 64Mi) y `default` (200m / 128Mi).
2. LimitRange (validación): si algún valor queda fuera de `min`/`max`, rechaza el Pod.
3. ResourceQuota: suma el Pod a lo ya usado; si pasa de `hard`, rechaza el Pod.

El rechazo ocurre al crear el Pod, no al crear el Deployment. Por eso
`kubectl apply` del Deployment siempre dice `created`.

## Resultados observados (k3s v1.34.3, 2026-09-23)

### Caso 1: `web-over-quota` (5 réplicas x 100m = 500m > 300m de cuota)

```
deployment.apps/web-over-quota   3/5   READY
requests.cpu 300m/300m   limits.cpu 600m/600m   requests.memory 192Mi/256Mi
Error creating: pods "web-over-quota-..." is forbidden: exceeded quota: namespace-quota,
  requested: limits.cpu=200m,requests.cpu=100m, used: limits.cpu=600m,requests.cpu=300m,
  limited: limits.cpu=600m,requests.cpu=300m
```

- Entran los Pods que caben (3) y los otros 2 nunca se crean: no quedan en
  `Pending`, simplemente no existen. El ReplicaSet reintenta con backoff.
- El Deployment queda `Available=False` y `ReplicaFailure=True (FailedCreate)`.
- Los Pods del Deployment no declaran `resources`: el LimitRange les puso
  `requests 100m/64Mi` y `limits 200m/128Mi`, y con eso los cobra la cuota.
- En cuanto se libera cuota, el ReplicaSet crea los Pods pendientes solo.

### Caso 2: `web-over-limitrange` (1 réplica, limit cpu 1 > max 500m)

```
deployment.apps/web-over-limitrange   0/1   READY
Error creating: pods "web-over-limitrange-..." is forbidden:
  maximum cpu usage per Container is 500m, but limit is 1
```

Ningún Pod se crea nunca, sin importar cuánta cuota quede libre.

### Caso 3: rollout con la cuota llena

| Réplicas | Estrategia | Resultado |
|---|---|---|
| 5 (no caben) | por defecto (25 % / 25 %) | Atascado: el RS nuevo queda en 0 Pods |
| 5 (no caben) | `maxSurge: 0`, `maxUnavailable: 1` | Atascado: con 3/5 disponibles ya se viola `maxUnavailable` y no puede borrar viejos |
| 3 (caben justo) | por defecto | Atascado: el Pod extra del surge no cabe en la cuota |
| 3 (caben justo) | `maxSurge: 0` | Completa, pero lento (entre 4 y 8 min en las pruebas): borra uno viejo y crea uno nuevo, de a uno; el ReplicaSet espera cada vez más entre reintentos rechazados |

Conclusión: un rollout necesita holgura de cuota para el `maxSurge`, o
usar `maxSurge: 0` con un número de réplicas que sí quepa.

## Resumen

- LimitRange = tamaño permitido de cada contenedor (y valores por defecto).
- ResourceQuota = suma permitida de todo el namespace.
- Si un Deployment pide más que la cuota, no falla el Deployment: corre
  degradado con las réplicas que caben y registra `FailedCreate`.
- Con cuota de `requests`/`limits` y sin LimitRange, un Pod sin `resources`
  es rechazado con `must specify limits.cpu...`; el LimitRange lo evita
  poniendo valores por defecto.

## Control de cambios

| Versión | Fecha | Autor | Cambio |
|---|---|---|---|
| 1.0 | 2026-09-23 | Andrés García | Versión inicial |
