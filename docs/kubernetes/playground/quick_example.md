---
sidebar_position: 1
title: Minikube - Quick Example
description: Deploying a Hello World App on Minikube
---

## Quick Example
```bash
minikube start
minikube enable ingress
kubectl apply -f deployment.yaml
minikube tunnel
curl --resolve "hello-world.info:80:127.0.0.1" -i http://hello-world.info
```

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: temp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: temp
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: hello-app
        image: gcr.io/google-samples/hello-app:1.0
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: web
  name: web
  namespace: temp
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: web
  type: NodePort
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  namespace: temp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  rules:
    - host: hello-world.info
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 8080
---
```
