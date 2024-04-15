---
sidebar_position: 2
title: GoViolin - k8s
description: Deploying GoViolin on k8s
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

```bash
go run $(ls -1 *.go | grep -v _test.go)
# Or
go run main.go home.go scale.go duet.go

# Build 
go build -o main
./main
```

```bash
go test ./...
```

```bash
ziadh@Ziads-MacBook-Air GoViolin % docker info -f '{{ .DriverStatus }}'
[[Backing Filesystem extfs] [Supports d_type true] [Using metacopy false] [Native Overlay Diff true] [userxattr false]]

# First Enable Containerd store
# See: https://docs.docker.com/desktop/containerd/

# Then
ziadh@Ziads-MacBook-Air GoViolin % docker info -f '{{ .DriverStatus }}'
[[driver-type io.containerd.snapshotter.v1]]

# Build and Push
docker build --platform linux/arm64,linux/amd64 --progress plain -t ziadmmh/goviolin:v0.0.2 --push .
```

The next is the old way, when we had not enabled the containerd store.

```bash
docker build --platform linux/arm64 --progress plain -t ziadmmh/goviolin:v0.0.1 .

docker run -p 127.0.0.1:8080:8080 ziadmmh/goviolin:v0.0.1

docker buildx build --platform linux/arm64,linux/amd64 --progress plain -t ziadmmh/goviolin:v0.0.2 --push .
```

```Dockerfile
FROM --platform=$BUILDPLATFORM golang:1.20 AS builder

WORKDIR /app

COPY go.mod go.sum /app/
RUN go mod download

COPY . .

ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o main ./main.go

FROM --platform=$TARGETPLATFORM scratch

COPY --from=builder /app/main /app/main

EXPOSE 80

CMD ["/app/main"]
```


```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: goviolin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: goviolin
  namespace: goviolin
spec:
  replicas: 3
  selector:
    matchLabels:
      app: goviolin
  template:
    metadata:
      labels:
        app: goviolin
    spec:
      containers:
      - name: goviolin
        image: ziadmmh/goviolin:v0.0.1
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: goviolin
  namespace: goviolin
spec:
  selector:
    app: goviolin
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: goviolin
  namespace: goviolin
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: goviolin.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: goviolin
            port:
              number: 80
---
```

## Deployment
1. Run: `minikube start`.
2. Run: `minikube enable ingress`.
3. Run: `minikube tunnel`. In real world we would create a `CNAME` or an `A/AAAA` dns record. To point our domain to our ingress load balancer.
4. Run: `curl --resolve "goviolin.k8s.sreboy.com:80:127.0.0.1" -i http://goviolin.k8s.sreboy.com`.

```bash {2,4,22,24}
# To test ingress locally use this domain: goviolin.k8s.sreboy.com
kubectl apply -f kubernetes/deployment.yaml

k -n goviolin get all,ingress
NAME                            READY   STATUS              RESTARTS   AGE
pod/goviolin-859f468b47-fzdmw   0/1     ContainerCreating   0          62s
pod/goviolin-859f468b47-gx8dx   0/1     ContainerCreating   0          62s
pod/goviolin-859f468b47-gxh52   0/1     ContainerCreating   0          62s

NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/goviolin   ClusterIP   10.108.69.103   <none>        80/TCP    62s

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/goviolin   0/3     3            0           62s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/goviolin-859f468b47   3         3         0       62s

NAME                                 CLASS   HOSTS                     ADDRESS        PORTS   AGE
ingress.networking.k8s.io/goviolin   nginx   goviolin.k8s.sreboy.com   192.168.49.2   80      62s

minikube tunnel

curl --resolve "goviolin.k8s.sreboy.com:80:127.0.0.1" -i http://goviolin.k8s.sreboy.com

kubectl -n ingress-nginx get po
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-x6fbf        0/1     Completed   0          69m
ingress-nginx-admission-patch-q8scr         0/1     Completed   1          69m
ingress-nginx-controller-7799c6795f-6kv2v   1/1     Running     0          69m

kubectl -n ingress-nginx exec ingress-nginx-controller-7799c6795f-6kv2v -- cat /etc/nginx/nginx.conf
```

```bash
minikube service -n goviolin goviolin
```
