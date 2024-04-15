---
sidebar_position: 4
title: k8s Cert Manager
description: Complete guide to k8s Cert Manager
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

Kubernetes Cert Manager adds certificate and certificate issuers as a custom resource definition (CRD) to Kubernetes. It simplifies the process of obtaining, renewing, and using TLS certificates. Cert Manager can issue certificates from various sources, including Let's Encrypt, HashiCorp Vault, Venafi, private PKI.

The typical workflow will look like this:
```yaml
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-http01-prod
  namespace: monitoring
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ziadh@sreboy.com
    privateKeySecretRef:
      name: letsencrypt-prod-http01-key-pair
    solvers:
    - http01:
        ingress:
          class: external-nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-http01-prod
spec:
  ingressClassName: external-nginx
  tls:
  - hosts:
    - grafana.goviolin.k8s.sreboy.com
    secretName: grafana-tls-secret-dashboard
  rules:
  ...
```

Create a certificate issuer e.g. `letsencrypt`. When you create an ingress for your service you will specify in the annotation that you want to use that issuer `letsencrypt-http01-prod` to secure your ingress.

When you apply the cert manager. Will detect that annotation and issue a certificate from letsencrypt and store it in the kubernetes secret that ingress will use to secure the service.

Cert Manager provides custom resource `issuer` that is ***namespace specific***. And must be used to obtain certificates in the same namespace where it was created. And `ClusterIssuer` which can be used in any namespace.

Also we will discuss how to monitor certificates and cert-manager with prometheus and grafana. We will discuss how to define grafana datasource and a dashboard in the code rather than using the UI. Also how to use alert manager to send alerts when certificates are about to expire.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: datasources
  namespace: monitoring
data:
  datasources.yaml: |-
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-operated:9090
      isDefault: true
```

## Agenda
We will see five examples:
1. Self-signed certificate. The primary use case for self-signed certificates is to use as certificate authority (CA) to sign other certificates. In other words, used to bootstrap your PKI.
```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: goviolin-k8s-sreboy-com-ca
  namespace: cert-manager
spec:
  isCA: true
  duration: 43800h # 5 years
  commonName: goviolin.k8s.sreboy.com
  secretName: goviolin-k8s-sreboy-com-key-pair
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
---
```
2. Generate TLS Certificate using our CA. We will use the self-signed ca to create another type cert-manager issuer which is CA.
```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: goviolin-k8s-sreboy-com-ca
spec:
  ca:
    secretName: goviolin-k8s-sreboy-com-key-pair
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: blog-goviolin-k8s-sreboy-com
  namespace: staging
spec:
  isCA: false
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
  commonName: blog.goviolin.k8s.sreboy.com
  dnsNames:
  - blog.goviolin.k8s.sreboy.com
  - www.blog.goviolin.k8s.sreboy.com
  secretName: blog-goviolin-k8s-sreboy-com-key-pair
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 4096
  issuerRef:
    name: goviolin-k8s-sreboy-com-ca
    kind: ClusterIssuer
    group: cert-manager.io
---
```
3. CA + Ingress + Grafana. We will need to deploy nginx ingress controller and grafana. Sometimes you want to have private hostnames and the only way to to get certificates for them is to use your own CA to issue certificates.

:::warning
It is not secure to expose them even in private subnets without TLS. Only with password protection.

But in this case we will discuss how man-in-the-middle attacks can be done. We will use wire shark to capture raw tcp packets between the grafana and us. We will create a capture filter to only watch for post requests to grafana and **update the credentials**.

```bash
# P: 50
# O: 4f
# S: 53
# T: 54
sudo tshark -i en1 -x -f "host grafana.goviolin.k8s.sreboy.com and port 80 and tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x504f5354" > post.pcap
```

After that we will secure grafana ingress with a certificate that will be issued from the same CA that we created previously. 
:::

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: goviolin-k8s-sreboy-com-ca
spec:
  ca:
    secretName: goviolin-k8s-sreboy-com-key-pair
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: goviolin-k8s-sreboy-com-ca
    cert-manager.io/duration: 2160h # 90 days
    cert-manager.io/renew-before: 360h # 15 days
spec:
  ingressClassName: external-nginx
  tls:
  - hosts:
    - grafana.goviolin.k8s.sreboy.com
    secretName: grafana-goviolin-k8s-sreboy-com-key-pair
  rules:
  - host: grafana.goviolin.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
---
```
4. Let's Encrypt + Ingress + http-01. We will create a letsencrypt issuer and obtain the certificate using the staging environment first. We will use the http 01 challenge. The most important lesson here is that we will see how to debug if we faced any issues with the certificate issuance.
```yaml
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-http01-staging
  namespace: monitoring
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ziadh@sreboy.com
    privateKeySecretRef:
      name: letsencrypt-staging-http01-key-pair
    solvers:
    - http01:
        ingress:
          class: external-nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-http01-staging
spec:
  ingressClassName: external-nginx
  tls:
  - hosts:
    - prometheus.goviolin.k8s.sreboy.com
    secretName: prometheus-goviolin-k8s-sreboy-com-key-pair
  rules:
  - host: prometheus.goviolin.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-operated
            port:
              number: 9090
---
```
5. Let's Encrypt + Ingress + dns-01. We will use the letsencrypt issuer with dns-01 challenge. We will see how to transfer the subdomain to Route53 `*.monitoring...io`.

<hr/>

To follow along we need a kubernetes cluster. Create one using `eksctl` tool:
```yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: cert-manager-demo
  region: us-east-1
  version: "1.21"
availabilityZones:
  - us-east-1a
  - us-east-1b
managedNodeGroups:
- name: general
  labels:
    role: general
  instanceType: t3.small
  desiredCapacity: 2
  minSize: 1
  maxSize: 10
  volumeSize: 20
---
```

```bash
eksctl create cluster -f eks.yaml
```

First, check that we have access to the cluster, `kubectl get svc` a standard check that will returns the kubernetes api service in the default namespace. 

Second Deploy prometheus and grafana:
1. CRD.
2. Operator.
3. Prometheus. SA, ClusterRole "RBAC", ClusterRoleBinding, Prometheus.

The above code is mentioned [here](https://github.com/antonputra/tutorials/tree/main/lessons/083/prometheus).

```bash
kubectl get pods -n monitoring
```

## Deploy Cert Manager
```bash
helm repo add jetstack https://charts.jetstack.io
helm search repo cert-manager
vi cert-manager-values.yaml
```

```yaml title="cert-manager-values.yaml"
---
installCRDs: true
# Helm chart will create the following CRDs:
# - Issuer
# - ClusterIssuer
# - Certificate
# - CertificateRequest
# - Order
# - Challenge


# Enable prometheus metrics, and create a service
# monitor object
prometheus:
  enabled: true
  servicemonitor:
    enabled: true
    prometheusInstance: lesson-083 # Has to match the label on Prometheus Object
```

```bash
helm template cert-083 jetstack/cert-manager -n cert-manager \
--version v1.5.3 \
--values cert-manager-values.yaml \
--output-dir helm-generated-yaml
```

```yaml title="cert-manager-ns.yaml"
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    monitoring: prometheus
```

```bash
kubectl apply -f cert-manager-ns.yaml

helm install cert-083 jetstack/cert-manager -n cert-manager \
--version v1.5.3 \
--values cert-manager-values.yaml

helm list -n cert-manager

kubectl get pods -n cert-manager

kubectl port-forward svc/prometheus-operated 9090 -n monitoring
```

## Self-signed Certificate
This is just a resource that we will use to generate a certificate.

```yaml title="self-signed-issuer.yaml"
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
```

You need to specify the namespace where the certificate and the key-pair will be stored.
```yaml title="ca-certificate.yaml"
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: devopsbyexample-io-ca
  namespace: cert-manager
spec:
  isCA: true # Used to sign other child certificates
  duration: 43800h # 5 years
  commonName: devopsbyexample.io # Does not matter now
  # Gen a private key and a cert and store them in a 
  # secret in the cert-manager ns.
  secretName: devopsbyexample-io-key-pair 
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
---
```

```bash
kubectl apply -f example-one

kubectl -n cert-manager get certificate
kubectl -n cert-manager get secrets
kubectl -n cert-manager get secret devopsbyexample-io-key-pair -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

kubectl -n cert-manager get secret devopsbyexample-io-key-pair -o yaml # Base64 encoded
# Private key stored in `tls.key`
# Certificate stored in `tls.crt`
# Since it is a self-signed certificate, `tls.crt` is eq to `ca.crt`

echo "..." | base64 -d -o ca.crt
openssl x509 -in ca.crt -text -noout
```

## Generate TLS Certificate using our CA
In example two we will use the CA that we created in the previous example to sign a certificate for issue a new one. 

```yaml title="ca-issuer.yaml"
---
# To indicate that we want to create a certificate authority
# type issuer. You just need to specify the key and provide
# the path to the kubernetes secret that contains the key.
# NOTE: Since it is a cluster issuer that secret must be
# located in the same namespace where we deployed the 
# cert-manager. This can be modified with the 
# `--cluster-resource-namespace` flag. The `devopsbyexample-io-ca`
# key pair was generated in the first example.
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: devopsbyexample-io-ca
spec:
  ca:
    secretName: devopsbyexample-io-key-pair
```

Here we want to create a certificate in our namespace.
```yaml title="staging-ns.yaml"
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
---
```

Then a certificate itself, for the `blog.devopsbyexample.io`:
```yaml title="blog-certificate.yaml"
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: blog-devopsbyexample-io
  namespace: staging
spec:
  isCA: false
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
  commonName: blog.devopsbyexample.io
  dnsNames: # SAN
  - blog.devopsbyexample.io
  - www.blog.devopsbyexample.io
  secretName: blog-devopsbyexample-io-key-pair
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 4096
  issuerRef:
    name: devopsbyexample-io-ca
    kind: ClusterIssuer
    group: cert-manager.io
```

The above will place a certificate and a secret in the `staging` namespace. 

```bash
kubectl apply -f example-two

kubectl -n staging get certificate
kubectl -n staging get secrets
kubectl -n staging get secret blog-devopsbyexample-io-key-pair -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

Notice that `tls.crt` is different from `ca.crt`.

## CA + Ingress + Grafana
First we will need to deploy nginx ingress controller.
```bash
helm repo add ingress-nginx \
https://kubernetes.github.io/ingress-nginx

helm repo update

helm search repo ingress-nginx
```

```yaml title="ingress-nginx-values.yaml"
---
controller:
  ingressClassResource:
    name: external-nginx
  admissionWebhooks:
    enabled: false
  service:
    annotations:
      # To avoid aws provisioning a classic load balancer
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
  # Required for ACME challenge
  watchIngressWithoutClass: true
  extraArgs:
    ingress-class: external-nginx
---
```

```bash
helm install ing-083 ingress-nginx/ingress-nginx \
-n ingress-nginx \
--version 4.0.1 \
--values ingress-nginx-values.yaml \
--create-namespace

kubectl -n ingress get pods

# The primary mechanism of specifying ingress classes
# is a new type called `IngressClass`. 
kubectl get ingressclass
```

### Grafana
Now we will deploy grafana, it will be used both to illustrate how to create ingresses with cert-manager as well as to monitor certificates and expiration dates.
```yaml title="grafana-secret.yaml"
---
apiVersion: v1
kind: Secret
metadata:
  name: grafana
  namespace: monitoring
type: Opaque
data:
  admin-user: YWRtaW4K # admin
  admin-password: ZGV2b3BzMTIzCg== # devops123
---
```


Create a configmap with a datasource.yaml key that will be used as a filename when we mount it to the grafana pod. You can create a datasource from the UI or predefine it in the yaml. Since Prometheus is deployed in the same monitoring namespace we can just use the kubernetes service name `prometheus-operated` and the port `9090`.

```yaml title="grafana-datasources.yaml"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: datasources
  namespace: monitoring
data:
  datasources.yaml: |-
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-operated:9090
      isDefault: true
---
```

Also we are going to put our cert-manager grafana dashboard in a configmap. And mount it as a file as well.

```yaml title="grafana-dashboard-providers.yaml"
---
# The path if for grafana to discover the dashboard
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboards
  namespace: monitoring
data:
  dashboardproviders.yaml: |-
    apiVersion: 1
    providers:
    - disableDeletion: false
      editable: false
      folder: Kubernetes
      name: kubernetes
      options:
        path: /var/lib/grafana/dashboards/kubernetes
      orgId: 1
      type: file
---
```


The following is our cert-manager dashboard.

<details>
<summary>grafana-dashboard-cert-manager.yaml</summary>

```yaml title="cert-manager.yaml"
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: monitoring
  name: kubernetes-dashboards
data:
  cert-manager.json: |-
    {
    "annotations": {
        "list": [
        {
            "builtIn": 1,
            "datasource": "-- Grafana --",
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "target": {
            "limit": 100,
            "matchAny": false,
            "tags": [],
            "type": "dashboard"
            },
            "type": "dashboard"
        }
        ]
    },
    "description": "",
    "editable": true,
    "gnetId": null,
    "graphTooltip": 1,
    "links": [],
    "panels": [
        {
        "datasource": null,
        "description": "The number of certificates in the ready state.",
        "fieldConfig": {
            "defaults": {
            "mappings": [],
            "thresholds": {
                "mode": "absolute",
                "steps": [
                {
                    "color": "green",
                    "value": null
                },
                {
                    "color": "red",
                    "value": 1
                }
                ]
            }
            },
            "overrides": [
            {
                "matcher": {
                "id": "byName",
                "options": "True"
                },
                "properties": [
                {
                    "id": "thresholds",
                    "value": {
                    "mode": "absolute",
                    "steps": [
                        {
                        "color": "green",
                        "value": null
                        }
                    ]
                    }
                }
                ]
            }
            ]
        },
        "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 0
        },
        "id": 2,
        "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
            "calcs": [
                "lastNotNull"
            ],
            "fields": "",
            "values": false
            },
            "text": {},
            "textMode": "auto"
        },
        "pluginVersion": "8.1.2",
        "targets": [
            {
            "exemplar": true,
            "expr": "sum by (condition) (certmanager_certificate_ready_status)",
            "interval": "",
            "legendFormat": "{{condition}}",
            "refId": "A"
            }
        ],
        "timeFrom": null,
        "timeShift": null,
        "title": "Certificates Ready",
        "transparent": true,
        "type": "stat"
        },
        {
        "datasource": null,
        "fieldConfig": {
            "defaults": {
            "decimals": 1,
            "mappings": [],
            "thresholds": {
                "mode": "absolute",
                "steps": [
                {
                    "color": "red",
                    "value": null
                },
                {
                    "color": "#EAB839",
                    "value": 604800
                },
                {
                    "color": "green",
                    "value": 1209600
                }
                ]
            },
            "unit": "dtdurations"
            },
            "overrides": []
        },
        "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 0
        },
        "id": 4,
        "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
            "calcs": [
                "lastNotNull"
            ],
            "fields": "",
            "values": false
            },
            "text": {},
            "textMode": "auto"
        },
        "pluginVersion": "8.1.2",
        "targets": [
            {
            "expr": "min(certmanager_certificate_expiration_timestamp_seconds > 0) - time()",
            "hide": false,
            "instant": true,
            "interval": "",
            "legendFormat": "",
            "refId": "A"
            },
            {
            "expr": "vector(1250000)",
            "hide": true,
            "instant": true,
            "interval": "",
            "legendFormat": "",
            "refId": "B"
            }
        ],
        "timeFrom": null,
        "timeShift": null,
        "title": "Soonest Cert Expiry",
        "transparent": true,
        "type": "stat"
        },
        {
        "datasource": null,
        "description": "Status of the certificates. Values are True, False or Unknown.",
        "fieldConfig": {
            "defaults": {
            "custom": {
                "align": null,
                "displayMode": "auto",
                "filterable": false
            },
            "mappings": [
                {
                "options": {
                    "": {
                    "text": "Yes"
                    }
                },
                "type": "value"
                }
            ],
            "thresholds": {
                "mode": "absolute",
                "steps": [
                {
                    "color": "green",
                    "value": null
                },
                {
                    "color": "red",
                    "value": 80
                }
                ]
            },
            "unit": "none"
            },
            "overrides": [
            {
                "matcher": {
                "id": "byName",
                "options": "Ready Status"
                },
                "properties": [
                {
                    "id": "custom.width",
                    "value": 100
                }
                ]
            },
            {
                "matcher": {
                "id": "byName",
                "options": "Valid Until"
                },
                "properties": [
                {
                    "id": "unit",
                    "value": "dateTimeAsIso"
                }
                ]
            },
            {
                "matcher": {
                "id": "byName",
                "options": "Valid Until"
                },
                "properties": [
                {
                    "id": "unit",
                    "value": "dateTimeAsIso"
                }
                ]
            }
            ]
        },
        "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 8
        },
        "id": 9,
        "options": {
            "showHeader": true,
            "sortBy": [
            {
                "desc": false,
                "displayName": "Valid Until"
            }
            ]
        },
        "pluginVersion": "8.1.2",
        "targets": [
            {
            "expr": "label_join(avg by (name, namespace, condition, exported_namespace) (certmanager_certificate_ready_status == 1), \"namespaced_name\", \"-\", \"namespace\", \"exported_namespace\", \"name\")",
            "format": "table",
            "instant": true,
            "interval": "",
            "legendFormat": "",
            "refId": "A"
            },
            {
            "expr": "label_join(avg by (name, namespace, exported_namespace) (certmanager_certificate_expiration_timestamp_seconds) * 1000, \"namespaced_name\", \"-\", \"namespace\", \"exported_namespace\", \"name\")",
            "format": "table",
            "instant": true,
            "interval": "",
            "legendFormat": "",
            "refId": "B"
            }
        ],
        "timeFrom": null,
        "timeShift": null,
        "title": "Certificates",
        "transformations": [
            {
            "id": "seriesToColumns",
            "options": {
                "byField": "namespaced_name"
            }
            },
            {
            "id": "organize",
            "options": {
                "excludeByName": {
                "Time": true,
                "Time 1": true,
                "Time 2": true,
                "Value #A": true,
                "exported_namespace": false,
                "exported_namespace 1": false,
                "exported_namespace 2": true,
                "name 1": true,
                "namespace 2": true,
                "namespaced_name": true
                },
                "indexByName": {
                "Time 1": 8,
                "Time 2": 10,
                "Value #A": 6,
                "Value #B": 5,
                "condition": 4,
                "exported_namespace 1": 1,
                "exported_namespace 2": 11,
                "name 1": 9,
                "name 2": 3,
                "namespace": 0,
                "namespace 1": 2,
                "namespaced_name": 7
                },
                "renameByName": {
                "Time 1": "",
                "Value #B": "Valid Until",
                "condition": "Ready Status",
                "exported_namespace": "Certificate Namespace",
                "exported_namespace 1": "Certificate Namespace",
                "exported_namespace 2": "",
                "name": "Certificate",
                "name 2": "Certificate",
                "namespace": "Namespace",
                "namespace 1": "Namespace",
                "namespaced_name": ""
                }
            }
            }
        ],
        "transparent": true,
        "type": "table"
        },
        {
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "datasource": null,
        "description": "The rate of controller sync requests.",
        "fieldConfig": {
            "defaults": {
            "links": []
            },
            "overrides": []
        },
        "fill": 1,
        "fillGradient": 0,
        "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 8
        },
        "hiddenSeries": false,
        "id": 7,
        "interval": "20s",
        "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
        },
        "lines": true,
        "linewidth": 1,
        "maxDataPoints": 250,
        "nullPointMode": "null",
        "options": {
            "alertThreshold": true
        },
        "percentage": false,
        "pluginVersion": "8.1.2",
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "targets": [
            {
            "expr": "sum by (controller) (\n  rate(certmanager_controller_sync_call_count[$__rate_interval])\n)",
            "interval": "",
            "legendFormat": "{{controller}}",
            "refId": "A"
            }
        ],
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "title": "Controller Sync Requests/sec",
        "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
        },
        "transparent": true,
        "type": "graph",
        "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
        },
        "yaxes": [
            {
            "format": "reqps",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": "0",
            "show": true
            },
            {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": true
            }
        ],
        "yaxis": {
            "align": false,
            "alignLevel": null
        }
        },
        {
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "datasource": null,
        "description": "Rate of requests to ACME provider.",
        "fieldConfig": {
            "defaults": {
            "links": []
            },
            "overrides": []
        },
        "fill": 1,
        "fillGradient": 0,
        "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 16
        },
        "hiddenSeries": false,
        "id": 6,
        "interval": "20s",
        "legend": {
            "avg": false,
            "current": false,
            "hideEmpty": true,
            "hideZero": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
        },
        "lines": true,
        "linewidth": 1,
        "maxDataPoints": 250,
        "nullPointMode": "null",
        "options": {
            "alertThreshold": true
        },
        "percentage": false,
        "pluginVersion": "8.1.2",
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "targets": [
            {
            "expr": "sum by (method, path, status) (\n  rate(certmanager_http_acme_client_request_count[$__rate_interval])\n)",
            "interval": "",
            "legendFormat": "{{method}} {{path}} {{status}}",
            "refId": "A"
            }
        ],
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "title": "ACME HTTP Requests/sec",
        "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
        },
        "transparent": true,
        "type": "graph",
        "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
        },
        "yaxes": [
            {
            "format": "reqps",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": "0",
            "show": true
            },
            {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": true
            }
        ],
        "yaxis": {
            "align": false,
            "alignLevel": null
        }
        },
        {
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "datasource": null,
        "description": "Average duration of requests to ACME provider. ",
        "fieldConfig": {
            "defaults": {
            "links": []
            },
            "overrides": []
        },
        "fill": 1,
        "fillGradient": 0,
        "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 16
        },
        "hiddenSeries": false,
        "id": 10,
        "interval": "30s",
        "legend": {
            "avg": false,
            "current": false,
            "hideEmpty": true,
            "hideZero": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
        },
        "lines": true,
        "linewidth": 1,
        "maxDataPoints": 250,
        "nullPointMode": "null",
        "options": {
            "alertThreshold": true
        },
        "percentage": false,
        "pluginVersion": "8.1.2",
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "targets": [
            {
            "expr": "sum by (method, path, status) (rate(certmanager_http_acme_client_request_duration_seconds_sum[$__rate_interval]))\n/\nsum by (method, path, status) (rate(certmanager_http_acme_client_request_duration_seconds_count[$__rate_interval]))",
            "interval": "",
            "legendFormat": "{{method}} {{path}} {{status}}",
            "refId": "A"
            }
        ],
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "title": "ACME HTTP Request avg duration",
        "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
        },
        "transparent": true,
        "type": "graph",
        "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
        },
        "yaxes": [
            {
            "format": "s",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": "0",
            "show": true
            },
            {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": true
            }
        ],
        "yaxis": {
            "align": false,
            "alignLevel": null
        }
        }
    ],
    "refresh": "10s",
    "schemaVersion": 30,
    "style": "dark",
    "tags": [
        "cert-manager",
        "infra"
    ],
    "templating": {
        "list": []
    },
    "time": {
        "from": "now-3h",
        "to": "now"
    },
    "timepicker": {
        "refresh_intervals": [
        "10s",
        "30s",
        "1m",
        "5m",
        "15m",
        "30m",
        "1h",
        "2h",
        "1d"
        ]
    },
    "timezone": "",
    "title": "Cert Manager",
    "uid": "TvuRo2iMk",
    "version": 1
    }
```

</details>

Finally in the deployment you can see that we create volumes from all of the previous configmaps. Kubernetes-dashboards, datasources, and dashboards. 
```yaml title="deployment.yaml"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: grafana
    spec:
      volumes:
      - name: dashboards
        configMap:
          name: dashboards
      - name: datasources
        configMap:
          name: datasources
      - name: kubernetes-dashboards
        configMap:
          name: kubernetes-dashboards
      containers:
      - name: grafana
        image: grafana/grafana:8.1.2
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: dashboards
          mountPath: "/etc/grafana/provisioning/dashboards/dashboardproviders.yaml"
          subPath: dashboardproviders.yaml
        - name: datasources
          mountPath: "/etc/grafana/provisioning/datasources/datasources.yaml"
          subPath: datasources.yaml
        - name: kubernetes-dashboards
          mountPath: "/var/lib/grafana/dashboards/kubernetes"
        ports:
        - name: grafana
          containerPort: 3000
          protocol: TCP
        env:
        - name: GF_SECURITY_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: grafana
              key: admin-user
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana
              key: admin-password
        livelinessProbe:
          failureThreshold: 10
          httpGet:
            path: /api/health
            port: grafana
          initialDelaySeconds: 30
          timeoutSeconds: 15
        readinessProbe:
          httpGet:
            path: /api/health
            port: grafana
---
```


We need a service to create an ingress later.
```yaml title="service.yaml"
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: ClusterIP
  ports:
  - name: grafana
    port: 3000
  selector:
    app: grafana
---
```

```bash
kubectl apply -f grafana

kubectl -n monitoring get svc
```

We are going to use the grafana svc in the ingress definition with the port 3000.

### Third Example
Ingress objects must be created in the same namespace where you have the service.

```yaml title="grafana.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
spec:
  ingressClassName: external-nginx
  rules:
  - host: grafana.devopsbyexample.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
---
```

First we will create ingress without a tls section and cert-manager. Later we will come back to it and secure it with https.

```bash
kubectl apply -f example-three
# Now we have ingress for grafana
```

Now we need to create a ***CNAME*** record that will point to AWS public load balancer hostname.
```bash
kubectl -n monitoring get ing
```

E.g. if the domain `devopsbyexample.io` is registered with google domains. It actually does not matter. We just need to create a DNS record and Point to that Load Balancer.

Hostname | Type | TTL | Data
:--: | :--: | :--: | :--:
grafana | CNAME | 300 | a1b2c3d4e5f6g7h8i9j0.elb.us-east-1.amazonaws.com

Check if you can access the grafana dashboard using [grafana.devopsbyexample.io](http://grafana.devopsbyexample.io). Enter `admin` and `devops123` as credentials.

Check datasources will be able to see the prometheus datasource. Also a dashboard under `Kubernetes` folder then `Cert Manager`.

Sign out and let us see if we can sniff the traffic when someone login. We will use wireshark and simulate a man in the middle attack. 

```bash
brew install wireshark

# instead of display filter we will use capture filter.
# [1]: We need to specify the network interface that we want
# to attach with wireshark. `ifconfig` or `ip other` on linux
# We will use our primary network interface `en1`.


# P: 50
# O: 4f
# S: 53
# T: 54
sudo tshark -i en1 -x -f "host grafana.goviolin.k8s.sreboy.com and port 80 and tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x504f5354" > post.pcap


cat post.pcap # We can see the username and password in PLAIN TEXT.
```

### Secure Grafana with TLS

<Tabs>

<TabItem value="Before">

```yaml title="grafana.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
spec:
  ingressClassName: external-nginx
  rules:
  - host: grafana.devopsbyexample.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
---
```

</TabItem>

<TabItem value="After">

```yaml title="grafana.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    # We will use the ClusterIssuer we created in example-two.
    cert-manager.io/cluster-issuer: devopsbyexample-io-ca
    cert-manager.io/duration: 2160h # 90d
    cert-manager.io/renew-before: 360h # 15d
spec:
  ingressClassName: external-nginx
  rules:
  tls:
  - hosts:
    - grafana.devopsbyexample.io
    secretName: blog-devopsbyexample-io-key-pair
  - host: grafana.devopsbyexample.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
---
```

</TabItem>

</Tabs>


```bash
kubectl apply -f example-three

# Let us see if the certificate was successfully issued by cert-manager
# CA issuer and verify it is in a ready state.
kubectl -n monitoring get certificates

# You will see additional port 443
kubectl -n monitoring get ing 
```

Now you can access the grafana dashboard using [grafana.devopsbyexample.io](https://grafana.devopsbyexample.io).

> It works but since it was issued by the self-signed CA it will not be trusted by the browser.

You can add the CA to the Keychain Access on MacOS:
1. Open Keychain Access.
2. File -> Import Items -> Select the `ca.crt` file.
3. Click on `devopsbyexample.io` -> Get Info -> Trust -> Always Trust.
4. Refresh the page.

```bash
# We can not use host and post request as these packets are encrypted.
sudo tshark -i en1 -x -f "port 443" 
```

## Let's Encrypt + Ingress + http-01
Finally we will start issuing certificates from let's encrypt. In this example we will use let's encrypt staging environment. And in the fifth example we will use let's encrypt production environment.

Now instead of ClusterIssuer we will use Issuer. Not a big difference it just you can only use it in the namespace where it was created.

```yaml title="letsencrypt-staging-http01-issuer.yaml"
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-http01-staging
  namespace: monitoring
spec:
  # ACME: Automated Certificate Management Environment
  # Protocol.
  acme:
    # Always use staging environment first when testing
    # let's encrypt automation.
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ziadh@sreboy.com
    privateKeySecretRef:
      name: letsencrypt-staging-http01-key-pair
    solvers:
    - http01:
         ingress:
           # We specify which what ingress class we will use
           # to resolve the ACME challenge. Cert-manager will
           # create additional temporary ingress using that class
           # to prove to let's encrypt that we own the domain and
           # the server.
           class: external-nginx        
---    
```

Then almost identical but the issuer if for production let's encrypt environment.

```yaml title="letsencrypt-production-http01-issuer.yaml"
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-http01-production
  namespace: monitoring
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ziadh@sreboy.com
    privateKeySecretRef:
      name: letsencrypt-production-http01-key-pair
    solvers:
    - http01:
         ingress:
           class: external-nginx
```

```bash
kubectl apply -f example-four
# Two issuers will be created
# 1. `issuer.cert-manager.io/letsencrypt-http01-staging`
# 2. `issuer.cert-manager.io/letsencrypt-http01-production`

# Before using them check the are in the READY state.
kubectl -n monitoring get issuers

# If you describe the issuer you should see the following message:
# `The ACME account was registered with the ACME server`
kubectl -n monitoring describe issuer letsencrypt-http01-production
```

### Prometheus
Now let us craete ingress for prometheus. We mentioned that it is a bad idea to expose internal services to the internet. But here we have only one single Public ingress so let us do it. 

```yaml title="prometheus-ingress.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-http01-staging
spec:
  ingressClassName: external-nginx
  tls:
  - hosts:
    - prometheus.devopsbyexample.io
    secretName: prometheus-devopsbyexample-io-key-pair
  rules:
  - host: prometheus.devopsbyexample.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-operated
            port:
              number: 9090
---
```

```bash
kubectl apply -f example-four
```

The flow when you use acme with cert-manager:
1. It will create a certificate.
2. Check if there is a valid one already.
3. if not then it will create a certificate request.
4. Then the certificate signing request will create an order and finally a challenge.


Let us see if the certificate is ready now:
```bash
kubectl -n monitoring get certificates

kubectl -n monitoring describe certificate prometheus-devopsbyexample-io-key-pair 


kubectl -n monitoring get CertificateRequests # APPROVE BUT NOT READY

kubectl -n monitoring describe certificaterequest prometheus-devopsbyexample-io-key-pair-xxxxx
# Order is created and the certificate object waits till it is done.

kubectl -n monitoring get orders
kubectl -n monitoring describe order prometheus-devopsbyexample-io-key-pair-xxxxx
# Order created the challange, let us list and describe the challange


kubectl -n monitoring get challenges # Pending
kubectl -n monitoring describe challenge prometheus-devopsbyexample-io-key-pair-xxxxx
# prometheus.devopsbyexample.io on 10.100.0.10:53 no such host
# That is expected since we never created cname for our prometheus ingress.

# Also when the cert-mangaer creates ingress for the http01 challenge it will also
# spin up the port/Pod you need to make sure that this port/Pod is in READY state
# After you pass this challange certbot will delete that Pod.

kubectl -n monitoring get ing
# Also we have acme ingress now here if you are not going to specify the
# nginx ingress watch ingress without class. That ingress will be ignored.
# And we will not get the Load balance hostname.
# Let's print out the ingress
kubectl -n monitoring get ing cm-acme-http-solver-xxxxx -o yaml
# You are NOT going to find the ingress class field here. Only the annotation `kubernetes.io/ingress.class: external-nginx` by default nginx-ingress will NOT watch those annotations anymore. 
```

Before we create CNAME we will split the terminal to run the following commands:
```bash
# First Terminal
watch -n 1 kubectl -n monitoring get certificates


# Second Terminal
watch -n 1 -t kubectl -n monitoring get challenges
```

That actually the reason to use `http01` challenge in production environments. It allows you to create ingress and obtain the valid certificate without creating a CNAME and redirecting traffic to the service that is NOT ready yet. And does not have the valid certificate yet. 


Now it is time to create a CNAME for prometheus ingress. 

Hostname | Type | TTL | Data
:--: | :--: | :--: | :--:
prometheus | CNAME | 300 | a1b2c3d4e5f6g7h8i9j0.elb.us-east-1.amazonaws.com

It is going to be the same load balancer as the grafana. 

Now we ***wait***. Watch it [here](https://youtu.be/7m4_kZOObzw?si=J5yv8voWBzdPT774&t=1838)

Challange will be accepted first and disappeared and the state for the certificate changed to ready. 


Check if you can access the prometheus dashboard using [prometheus.devopsbyexample.io](https://prometheus.devopsbyexample.io). You will get a certificate but it would be from the staging environment.

## Let's Encrypt + Ingress + dns-01
Time for last example. First we are going to delegate a sub-domain to Route53 and create a dns-01 let's encrypt issuer. You can delegate the whole domain to Route53 but just for this example. We will delegate only the `monitoring.devopsbyexample.io` sub-domain.

That means that all sub-domains such as `grafana.monitoring.devopsbyexample.io` and `prometheus.monitoring.devopsbyexample.io` will be resolved by Route53 and not Google domains. 

### Route53
First we need to create a public hosted zone in Route53. 
1. Open console, navigate to Route53 service.
2. Click on `Create Hosted Zone`.
3. Domain Name: `monitoring.devopsbyexample.io`.
4. Leave type as `Public Hosted Zone`.

In a coming section we will create private hosted zones and use OpenVPN to push dns name servers to our development host that we can resolve the private hostnames.

Delegating a sub-domain is super easy, get back to google domains and and create an `NS` record for the sub domain.

Hostname | Type | TTL | Data
:--: | :--: | :--: | :--:
monitoring | NS | 300 | ns-1.awsdns-1.co.uk., ns-2.awsdns-2.org., ns-3.awsdns-3.com., ns-4.awsdns-4.net.

Now let us test the sub-domain. Create an A record and try to resolve it locally with a dig. 

Record name | Type | TTL | Data
test`.monitoring.devopsbyexample.io` | A | 300 | ip-address can be anything just to test dns resolution.

Make the ROutingPolicy just simple routing.

```bash
dig +short test.monitoring.devopsbyexample.io
```

Since we will use IAM roles for k8s service accounts we need to create OpenID Connect first. Watch it [here](https://youtu.be/7m4_kZOObzw?si=qiZCxFXp3YjvM9X7&t=2017).

1. Navigate to console then `eks` service then clusters.
2. Click on `cert-manager-demo` then `Configuration`.

We need to get an OIDC url from the eks cluster. 

3. Navigate to `IAM` service then `Identity Providers`.
4. Click on `Add provider`.
5. Select `OpenID Connect`. Paste the url and click on `Get thumbprint`.
6. Audience: `sts.amazonaws.com`.
7. Click on `Add provider`.

Now we need to create IAM policy and grant access to create dns records in Route53. 


The way that dns-01 challenge works:
1. You need to prove to letsencrypt that you control domain by creating a specific dns TXT record with a token that letsencrypt provides.
2. When letsencrypt verifies that you have a txt record. They will issue a certificate. 
3. You need to do it every time when ever you want to renew the certificate. Approximately every 60 days.

You can see why without automation it is a pain and not a viable solution to renew certs by yourself. 

The first Statement is to be able to get the current state of the request, to find out if dns record changes have been propagated to all route53 dns servers. 

The second statement one to update dns records such as txt for acme challange. We need to replace `<id>` with the hosted zone id. 

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "route53:GetChange",
            "Resource": "arn:aws:route53:::change/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/<id>"
        }
    ]
}
```


Name policy `CertManagerRoute53Access` and click on `Create policy`.


Now it is time to create IAM role. And associate it with the kubernetes service account.
1. Click create Role.
2. Select `Web Identity` the `OpenID Connect` and select `oidc.eks.us-east-1.amazonaws.com/id/<id>` under `Identity provider`.
3. Select under Audience `sts.amazonaws.com`.
4. Filter permissions by `CustomerManaged` and select `CertManagerRoute53Access`.
5. Call it `cert-manager-acme`.

Later we will use this arn in kubernetes service account. 

To allow only our cert-manager kubernetes account to assume this role. We need to create a trust relationship. Click `EditTrustRelationship`:

```bash
kubectl -n cert-manager get sa
# Called cert-083-cert-manager
```

```json
...
"Condition": {
    "StringEquals": {
        "oidc.eks.us-east-1.amazonaws.com/id/<id>:sub": "system:serviceaccount:cert-manager:cert-083-cert-manager"
    }
}
...
```

`cert-manager` is the namespace for that sa and the last argument is the name of the service account.

We completed the IAM configuration part. Now we need to update a couple of kubernetes objects. 

To specify the IAM role to be used by the sa, we need to add an annotation to the service account by default it will use the one that is attached to the k8s workers. 

```bash
kubectl -n cert-manager edit sa cert-083-cert-manager
```

```yaml
annotations:
  ...
  eks.amazonaws.com/role-arn: arn:aws:iam::<id>:role/cert-manager-acme
```

We need to update deployment as well to include a flag to the cert-manager:
```bash
kubectl -n cert-manager get deploy

kubectl -n cert-manager edit deploy cert-083-cert-manager
```

```yaml
containers:
- args:
  - --v=2
  - --cluster-resource-namespace=$(POD_NAMESPACE)
  - --leader-election-namespace=kube-system
  # To be able to use that IAM role.
  - --issuer-ambient-credentials
  # If you are using cluster Issuer you need
  # to replace this one with `cluster-issuer-ambient-credentials`
```

When you make this change:
```bash
kubectl -n cert-manager get po cert-manager
```


By the way the cert-manager helm chart allows you to specify those configuration options before you install it. 


```yaml
---
installCRDs: true
# Helm chart will create the following CRDs:
# - Issuer
# - ClusterIssuer
# - Certificate
# - CertificateRequest
# - Order
# - Challenge


# Enable prometheus metrics, and create a service
# monitor object
prometheus:
  enabled: true
  servicemonitor:
    enabled: true
    prometheusInstance: lesson-083 # Has to match the label on Prometheus Object


# DNS-01 Route53
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/cert-manager-acme
extraArgs:
- --issuer-ambient-credentials
```


Let us Create our final example with a dns resolver.

### Fifth Example
It is going to similar to the first one for the staging environment:

```yaml title="letsencrypt-staging-dns01-issuer.yaml"
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-dns01-staging
  namespace: monitoring
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ziadh@sreboy.com
    privateKeySecretRef:
      name: letsencrypt-staging-dns01-key-pair
    solvers:
    - dns01:
        route53:
          region: us-east-1
          hostedZoneID: Z1234567890
```

The second one is for production environment:


```yaml title="letsencrypt-production-dns01-issuer.yaml"
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-dns01-production
  namespace: monitoring
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ziadh@sreboy.com
    privateKeySecretRef:
      name: letsencrypt-production-dns01-key-pair
    solvers:
    - dns01:
        route53:
          region: us-east-1
          hostedZoneID: Z1234567890
```

Let us create the last grafana ingress and use that with dns issuer:

```yaml title="grafana-ingress.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-dns01-production
spec:
  ingressClassName: external-nginx
  tls:
  - hosts:
    - grafana.monitoring.devopsbyexample.io
  secretName: grafana-monitoring-devopsbyexample-io-key-pair
  rules:
  - host: grafana.monitoring.devopsbyexample.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
```

Let us split terminal and watch those certificates and challenges:

```bash
# First Terminal
watch -n 1 -t kubectl -n monitoring get certificates

# Second Terminal
watch -n 1 -t kubectl -n monitoring get challenges
```

Then `kubectl apply -f example-five` which has the Issuers and Grafana ingress. You can check if the cert manager was able to create a txt record.

Challenge state changed to valid. And in the first window. The certificate state changed to ready.

If you have any issues the best way to find them is through the logs of certmanager:
> kubectl -n cert-manager get po
> kubectl -n cert-manager logs -f cert-083-cert-manager-xxxxx

```bash
kubectl -n monitoring get ing
```

Now we need to create a CNAME record for grafana in Route53 since we delegated the sub-domain to Route53.

Hostname | Type | TTL | Data
:--: | :--: | :--: | :--:
grafana | CNAME | 300 | a1b2c3d4e5f6g7h8i9j0.elb.us-east-1.amazonaws.com
