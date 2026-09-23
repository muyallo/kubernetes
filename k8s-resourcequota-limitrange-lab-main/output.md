<!-- lang: es-CO -->
# Salidas reales del laboratorio LimitRange y ResourceQuota

Aquí están, paso a paso, los comandos que ejecuté, la salida que devolvió el
clúster y qué significa cada una. La pregunta de fondo: ¿qué pasa cuando un
Deployment pide más de lo que permite la ResourceQuota del namespace?

## Cómo se ejecutó

- Desde un portátil con `kubectl`, contra un clúster k3s de dos nodos
  (`hp62a` como control-plane y `dell-latitude3400` como worker).
- Desde la raíz de este repositorio, donde están los manifiestos.
- Todas las salidas son de una misma corrida del 2026-09-23, que empezó
  borrando el laboratorio para partir de cero. Guardé cada comando con su
  salida (estándar y de error) y la pegué aquí sin editar.
- Entre algunos pasos esperé de 8 a 20 s (`sleep`) para que los controladores
  de Kubernetes alcanzaran a crear o borrar Pods.

Si repites el laboratorio cambian los nombres de los Pods (`...-7k84t`) y las
edades (`AGE`); el comportamiento y los mensajes son los mismos.

## Paso 0. Entorno

```text
$ kubectl version | head -2
Client Version: v1.37.0
Kustomize Version: v5.8.1
Warning: version difference between client (1.37) and server (1.34) exceeds the supported minor version skew of +/-1
```

La advertencia indica que el cliente `kubectl` (1.37) es más nuevo que el
servidor (1.34). No afecta a este laboratorio: solo se usan funciones estables.

```text
$ kubectl get nodes
NAME                STATUS   ROLES                     AGE    VERSION
dell-latitude3400   Ready    <none>                    250d   v1.34.3+k3s1
hp62a               Ready    control-plane,db,master   264d   v1.34.3+k3s1
```

## Paso 1. Partir de cero

```text
$ ./delete-lab.sh
Contenido actual de lab-resource-quota:
NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web-over-limitrange   0/1     0            0           31m
deployment.apps/web-over-quota        3/3     3            3           30m

NAME                                 READY   STATUS    RESTARTS   AGE
pod/web-over-quota-6dfbf8985-8hvlq   1/1     Running   0          25m
pod/web-over-quota-6dfbf8985-9rnws   1/1     Running   0          25m
pod/web-over-quota-6dfbf8985-l9nvv   1/1     Running   0          28m

NAME                          CREATED AT
limitrange/container-limits   2026-09-23T08:20:22Z

NAME                            REQUEST                                                             LIMIT                                               AGE
resourcequota/namespace-quota   pods: 3/10, requests.cpu: 300m/300m, requests.memory: 192Mi/256Mi   limits.cpu: 600m/600m, limits.memory: 384Mi/512Mi   34m

Borrando el namespace lab-resource-quota (espera a que termine)...
namespace "lab-resource-quota" deleted
Borrado. Para volver a crearlo: ./start-lab.sh
```

`delete-lab.sh` muestra lo que había y borra el namespace. Al borrar un
namespace, Kubernetes borra todo lo que contiene.

## Paso 2. Crear el namespace, el LimitRange y la ResourceQuota

```text
$ kubectl apply -f 00-namespace.yaml -f 01-limitrange.yaml -f 02-resourcequota.yaml
namespace/lab-resource-quota created
limitrange/container-limits created
resourcequota/namespace-quota created
```

```text
$ kubectl -n lab-resource-quota describe limitrange container-limits
Name:       container-limits
Namespace:  lab-resource-quota
Type        Resource  Min   Max    Default Request  Default Limit  Max Limit/Request Ratio
----        --------  ---   ---    ---------------  -------------  -----------------------
Container   cpu       50m   500m   100m             200m           -
Container   memory    32Mi  256Mi  64Mi             128Mi          -
```

El LimitRange actúa sobre cada contenedor:
`Default Request` es lo que se le reserva si no declara nada (100m de CPU, 64Mi
de RAM), `Default Limit` es su techo por defecto, y `Min`/`Max` es el rango
permitido.

```text
$ kubectl -n lab-resource-quota describe resourcequota namespace-quota
Name:            namespace-quota
Namespace:       lab-resource-quota
Resource         Used  Hard
--------         ----  ----
limits.cpu       0     600m
limits.memory    0     512Mi
pods             0     10
requests.cpu     0     300m
requests.memory  0     256Mi
```

La ResourceQuota es el presupuesto total del namespace. `Used` está en
0 porque aún no hay Pods. `Hard` es el tope.

## Paso 3. Deployment que pide más de lo que cabe

`03-deployment-over-quota.yaml` pide 5 réplicas. Cada una reserva 100m de CPU,
así que en total pide 500m; la cuota solo permite 300m.

```text
$ kubectl apply -f 03-deployment-over-quota.yaml
deployment.apps/web-over-quota created
```

Kubernetes acepta el Deployment. La cuota no se revisa aquí, sino cuando
el ReplicaSet intenta crear cada Pod.

```text
$ kubectl -n lab-resource-quota get deployment web-over-quota
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
web-over-quota   3/5     3            3           15s
```

`READY 3/5`: se pidieron 5 y solo hay 3.

```text
$ kubectl -n lab-resource-quota get replicaset
NAME                        DESIRED   CURRENT   READY   AGE
web-over-quota-5d99769886   5         3         3       15s
```

El ReplicaSet es el que crea los Pods: quiere 5 (`DESIRED`) y tiene 3
(`CURRENT`).

```text
$ kubectl -n lab-resource-quota get pods -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP            NODE                NOMINATED NODE   READINESS GATES
web-over-quota-5d99769886-7k84t   1/1     Running   0          15s   10.42.2.120   dell-latitude3400   <none>           <none>
web-over-quota-5d99769886-j8489   1/1     Running   0          15s   10.42.2.121   dell-latitude3400   <none>           <none>
web-over-quota-5d99769886-tcmjm   1/1     Running   0          15s   10.42.0.179   hp62a               <none>           <none>
```

Solo existen 3 Pods. Los 2 que faltan no aparecen como `Pending`:
nunca llegaron a crearse, porque la API los rechazó antes de guardarlos.
Tampoco es un problema de los nodos: revisando con `kubectl describe nodes`, `dell-latitude3400` tenía reservado el 34 % de su CPU
y `hp62a` el 69 %. Hay CPU libre en el clúster; lo que se agotó es el presupuesto
del namespace.

## Paso 4. El LimitRange completó los recursos del Pod

El manifiesto del Deployment no tiene bloque `resources`. Aun así, cada Pod quedó con:

```text
$ kubectl -n lab-resource-quota get pods -l app.kubernetes.io/name=web-over-quota -o jsonpath='{.items[0].spec.containers[0].resources}{"\n"}'
{"limits":{"cpu":"200m","memory":"128Mi"},"requests":{"cpu":"100m","memory":"64Mi"}}
```

Son exactamente los valores por defecto del LimitRange. Esto pasa antes de
revisar la cuota, y con estos números la cuota cobra cada Pod.

## Paso 5. La cuota quedó llena

```text
$ kubectl -n lab-resource-quota describe resourcequota namespace-quota
Name:            namespace-quota
Namespace:       lab-resource-quota
Resource         Used   Hard
--------         ----   ----
limits.cpu       600m   600m
limits.memory    384Mi  512Mi
pods             3      10
requests.cpu     300m   300m
requests.memory  192Mi  256Mi
```

`requests.cpu 300m/300m` y `limits.cpu 600m/600m`: CPU al tope. La memoria
(192Mi de 256Mi) y el número de Pods (3 de 10) aún tienen espacio, pero basta
con que un recurso esté lleno para bloquear un Pod nuevo.

## Paso 6. Por qué no se crearon las otras 2 réplicas

```text
$ kubectl -n lab-resource-quota get events --field-selector reason=FailedCreate -o custom-columns=OBJETO:.involvedObject.name,MENSAJE:.message | head -3
OBJETO                      MENSAJE
web-over-quota-5d99769886   Error creating: pods "web-over-quota-5d99769886-rhx75" is forbidden: exceeded quota: namespace-quota, requested: limits.cpu=200m,requests.cpu=100m, used: limits.cpu=600m,requests.cpu=300m, limited: limits.cpu=600m,requests.cpu=300m
web-over-quota-5d99769886   Error creating: pods "web-over-quota-5d99769886-6fznv" is forbidden: exceeded quota: namespace-quota, requested: limits.cpu=200m,requests.cpu=100m, used: limits.cpu=600m,requests.cpu=300m, limited: limits.cpu=600m,requests.cpu=300m
```

Así se lee el mensaje:

| Parte | Significado |
|---|---|
| `exceeded quota: namespace-quota` | Qué cuota lo bloqueó |
| `requested: requests.cpu=100m` | Lo que pedía el Pod nuevo |
| `used: requests.cpu=300m` | Lo que ya estaba usado en el namespace |
| `limited: requests.cpu=300m` | El tope; 300m + 100m lo superaría |

## Paso 7. Estado del Deployment

```text
$ kubectl -n lab-resource-quota get deployment web-over-quota -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
Available=False (MinimumReplicasUnavailable)
ReplicaFailure=True (FailedCreate)
Progressing=True (ReplicaSetUpdated)
```

- `Available=False`: no tiene el mínimo de réplicas disponibles que pide su estrategia.
- `ReplicaFailure=True (FailedCreate)`: su ReplicaSet no puede crear Pods.
- El Deployment no se borra ni falla del todo: sigue sirviendo con 3 Pods.

## Paso 8. Liberar cuota y volver a llenarla

```text
$ kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=2 && sleep 8 && kubectl -n lab-resource-quota get deployment web-over-quota && kubectl -n lab-resource-quota get resourcequota namespace-quota -o jsonpath='requests.cpu usado={.status.used.requests\.cpu} tope={.status.hard.requests\.cpu}{"\n"}'
deployment.apps/web-over-quota scaled
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
web-over-quota   2/2     2            2           25s
requests.cpu usado=200m tope=300m
```

Con 2 réplicas se usan 200m de 300m: el Deployment queda completo (`2/2`).

```text
$ kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=5 && sleep 8 && kubectl -n lab-resource-quota get deployment web-over-quota && kubectl -n lab-resource-quota get resourcequota namespace-quota -o jsonpath='requests.cpu usado={.status.used.requests\.cpu} tope={.status.hard.requests\.cpu}{"\n"}'
deployment.apps/web-over-quota scaled
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
web-over-quota   3/5     3            3           33s
requests.cpu usado=300m tope=300m
```

Al volver a 5, el ReplicaSet crea solo el Pod que cabe (hasta 300m) y vuelve a `3/5`.
No hace falta intervenir: en cuanto hay cuota libre, el ReplicaSet crea los
Pods que faltan por sí solo.

## Paso 9. Trampa: actualizar (rollout) con la cuota llena

Un `rollout restart` crea Pods nuevos para reemplazar los viejos.

```text
$ kubectl -n lab-resource-quota rollout restart deployment web-over-quota && sleep 20 && kubectl -n lab-resource-quota get replicaset
deployment.apps/web-over-quota restarted
NAME                        DESIRED   CURRENT   READY   AGE
web-over-quota-5d99769886   4         3         3       53s
web-over-quota-8458cbddb4   3         0         0       20s
```

El ReplicaSet nuevo (`AGE 20s`) quiere 3 Pods y tiene 0: no hay cuota para
ninguno. El viejo no puede reducirse porque ya le faltan réplicas.

```text
$ kubectl -n lab-resource-quota rollout status deployment web-over-quota --timeout=20s
Waiting for deployment "web-over-quota" rollout to finish: 0 out of 5 new replicas have been updated...
error: timed out waiting for the condition
```

```text
$ kubectl -n lab-resource-quota get events --field-selector reason=FailedCreate --sort-by=.lastTimestamp -o custom-columns=OBJETO:.involvedObject.name,MENSAJE:.message | tail -1
web-over-quota-8458cbddb4   (combined from similar events): Error creating: pods "web-over-quota-8458cbddb4-ngfjp" is forbidden: exceeded quota: namespace-quota, requested: limits.cpu=200m,requests.cpu=100m, used: limits.cpu=600m,requests.cpu=300m, limited: limits.cpu=600m,requests.cpu=300m
```

El rollout queda atascado: los Pods nuevos no caben y los viejos no se
pueden borrar sin dejar al Deployment por debajo de su mínimo.

## Paso 10. Salir del atasco

Se ajustan las réplicas a las que caben (3) y se prohíbe crear Pods extra
durante el rollout (`maxSurge: 0`), para que primero borre uno viejo y luego
cree uno nuevo:

```text
$ kubectl -n lab-resource-quota scale deployment web-over-quota --replicas=3 && kubectl -n lab-resource-quota patch deployment web-over-quota -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}}}'
deployment.apps/web-over-quota scaled
deployment.apps/web-over-quota patched
```

```text
$ date +%T && kubectl -n lab-resource-quota rollout status deployment web-over-quota --timeout=900s && date +%T && kubectl -n lab-resource-quota get replicaset
03:56:20
Waiting for deployment "web-over-quota" rollout to finish: 0 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "web-over-quota" rollout to finish: 2 of 3 updated replicas are available...
deployment "web-over-quota" successfully rolled out
04:04:39
NAME                        DESIRED   CURRENT   READY   AGE
web-over-quota-5d99769886   0         0         0       9m33s
web-over-quota-8458cbddb4   3         3         3       9m
```

El rollout terminó, pero tardó 8 min 19 s (03:56:20 a 04:04:39) en
cambiar solo 3 Pods. En otra prueba tardó unos 4 min y medio.

```text
$ kubectl -n lab-resource-quota get events --field-selector reason=FailedCreate -o custom-columns=REPLICASET:.involvedObject.name,VECES:.count | sort | uniq | tail -3
web-over-quota-5d99769886   16
web-over-quota-8458cbddb4   1
web-over-quota-8458cbddb4   17
```

La columna `VECES` explica la demora: el ReplicaSet nuevo
(`web-over-quota-8458cbddb4`) fue rechazado por la cuota 17 veces, y después
de cada rechazo espera más antes de reintentar. Cuando por fin se libera
espacio, puede estar aún esperando.

En la práctica: deja holgura en la cuota para los Pods extra de un rollout, o usa
`maxSurge: 0` con un número de réplicas que quepa, y cuenta con que tarde.

## Paso 11. Comparación: violar el LimitRange

`04-deployment-over-limitrange.yaml` pide 1 sola réplica, pero su
contenedor pide un techo de 1 CPU, por encima del máximo de 500m.

```text
$ kubectl apply -f 04-deployment-over-limitrange.yaml
deployment.apps/web-over-limitrange created
```

```text
$ kubectl -n lab-resource-quota get deployment web-over-limitrange
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
web-over-limitrange   0/1     0            0           10s
```

```text
$ kubectl -n lab-resource-quota get events --field-selector reason=FailedCreate -o custom-columns=OBJETO:.involvedObject.name,MENSAJE:.message | grep limitrange | head -1
web-over-limitrange-86479d6fb8   Error creating: pods "web-over-limitrange-86479d6fb8-lv4kl" is forbidden: maximum cpu usage per Container is 500m, but limit is 1
```

Aquí no importa cuánta cuota quede libre: el Pod es demasiado grande y nunca
entrará. Con la cuota, en cambio, entran los Pods que caben.

## Paso 12. ¿Y sin LimitRange?

Se crea un namespace temporal solo con la ResourceQuota y se prueba un Pod sin `resources`:

```text
$ kubectl create namespace lab-quota-without-limitrange && sed 's/namespace: lab-resource-quota/namespace: lab-quota-without-limitrange/' 02-resourcequota.yaml | kubectl apply -f - && sleep 3 && kubectl -n lab-quota-without-limitrange run probe --image=registry.k8s.io/pause:3.10 --dry-run=server
namespace/lab-quota-without-limitrange created
resourcequota/namespace-quota created
Error from server (Forbidden): pods "probe" is forbidden: failed quota: namespace-quota: must specify limits.cpu for: probe; limits.memory for: probe; requests.cpu for: probe; requests.memory for: probe
```

```text
$ kubectl delete namespace lab-quota-without-limitrange
namespace "lab-quota-without-limitrange" deleted
```

Si la cuota controla CPU y memoria, todo Pod debe declararlas. Sin un
LimitRange que ponga valores por defecto, un Pod sin `resources` se rechaza.

## Paso 13. Dejar el laboratorio en su estado inicial

```text
$ kubectl -n lab-resource-quota delete deployment web-over-quota && kubectl apply -f 03-deployment-over-quota.yaml && sleep 15 && kubectl -n lab-resource-quota get deployments
deployment.apps "web-over-quota" deleted from lab-resource-quota namespace
deployment.apps/web-over-quota created
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
web-over-limitrange   0/1     0            0           35s
web-over-quota        3/5     3            3           15s
```

## Qué pasa cuando no se respeta la ResourceQuota

1. El Deployment se acepta siempre: la cuota no mira el Deployment, mira cada Pod.
2. Se crean los Pods que caben en el presupuesto; el resto se rechaza al crearse.
3. Los Pods rechazados no existen: no quedan en `Pending`, no aparecen en `get pods`.
4. El error solo se ve en los eventos (`FailedCreate`, `exceeded quota`) y en
   `READY 3/5`, `Available=False`, `ReplicaFailure=True`.
5. La aplicación sigue funcionando con menos réplicas de las pedidas.
6. El ReplicaSet reintenta solo: si se libera cuota, completa las réplicas sin intervención.
7. Con la cuota llena, los rollouts se atascan o tardan minutos.
8. La cuota cobra lo declarado (requests y limits), no el consumo real: estos
   Pods (`pause`) casi no usan CPU y aun así llenan la cuota.

## Control de cambios

| Versión | Fecha | Autor | Cambio |
|---|---|---|---|
| 1.0 | 2026-09-23 | Andrés García | Versión inicial |
