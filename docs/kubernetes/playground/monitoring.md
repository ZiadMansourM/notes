---
sidebar_position: 5
title: EKS Monitoring
description: Provision Prometheus and Grafana on EKS
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

In this section we will install prometheus stack on kubernetes, it includes:
- Prometheus Operator.
- Prometheus.
- Alertmanager.
- Grafana.
- Default ServiceMonitors.
- Dashboards.
- Alerts.

Then we will deploy the postgres database in its namespace `db` and we will see how to manually describe the metrics. `kubectl describe endpoints -n db postgres-postgres-metrics`. And configure the `ServiceMonitor` to scrape the metrics.

## Create Cluster

```yaml title="eks.yaml"
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: my-cluster-072-v6
  region: us-east-1
  version: "1.20"
availabilityZones:
- us-east-1a
- us-east-1b
managedNodeGroups:
- name: general
  labels:
    role: general
  instanceType: t3.medium
  minsSize: 2
  maxSize: 10
  desiredCapacity: 2
  volumeSize: 20
---
```

```bash
eksctl create cluster -f eks.yaml
```

## Customize the Prometheus Helm Chart
You can find the chart here: [github.com/prometheus-community/charts/kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).


```yaml title="prometheus-values.yaml" {19-23}
---
# Since we are using eks. The control plane is abstracted away from us.
# We do NOT need to manage ETCD, scheduler, controller-manager, and API server.
# The following will disable alerts for etcd and kube-scheduler.
defaultRules:
  rules:
    etcd: false
    kubeScheduler: false

# Then disable servicemonitors for them
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeEtcd:
  enabled: false

# Add a custom label prometheus eq to devops
prometheus:
  prometheusSpec:
    serviceMonitorSelector:
      matchLabels:
        prometheus: devops

# Last thing update common labels.
# If you did NOT add it. Prometheus Operator
# will IGNORE default service monitors created
# by this helm chart. Consequently, the prometheus 
# targets section will be empty.
commonLabels:
  prometheus: devops

# Optionally, you can update the grafana admin password
grafana:
  adminPassword: testing123
```

The `prometheus: devops` label will be used by prometheus operator to select ServiceMonitors objects

```yaml {6,7}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-postgresql
  namespace: db
  labels:
    prometheus: devops
spec:
...
```

## Install Prometheus Stack

```bash
helm repo add prometheus-community \
https://prometheus-community.github.io/helm-charts

# Grab latest from chart repositories
helm repo update

# Choose: 16.10.0
helm search repo kube-prometheus-stack --max-col-width 23

# Release name: monitoring
# Helm chart name: kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack \
--values prometheus-values.yaml \
--version 16.10.0 \
--namespace monitoring \
--create-namespace
```

```bash
kubectl -n monitoring get pods
```

### Port forward Prometheus

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090
```

Under targets section of [127.0.0.1:9090](http://127.0.0.1:9090) you should see all the default targets provided by this helm chart.

::::note
Unfortunately, eks configures kube-proxy metrics to only be accessible on the `127.0.0.1` interface for those pods.

#### Fix
Review and update this parameter in the `kube-proxy` configmap.

```bash
kubectl -n kube-system get configmap kube-proxy-config -o yaml

kubectl -n kube-system edit configmap kube-proxy-config -o yaml | sed 's/metricsBindAddress: 127.0.0.1:10249/metricsBindAddress: 0.0.0.0:10249/' | kubectl apply -f -
```

:::warning
when we update the configmap it will ***NOT*** restart the pods, we need to manually do it:
```bash
# Option One:
kubectl rollout restart daemonset kube-proxy -n kube-system

# Option Two: directly patch the daemonset
kubectl -n kube-system patch daemonset kube-proxy -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"updateTime\":\"`date +'%s'`\"}}}}}"
```
:::
::::

Now go back and refresh the Prometheus targets page.

<hr/>

This helm chart also provides default prometheus alerts and Grafana dashboards.

### Port forward Grafana

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Then navigate to [127.0.0.1:3000](http://127.0.0.1:3000) and login with the username `admin` and password `testing123`.

Under `Dashboards/Manage` you should see all the default dashboards provided by the `prometheus-stack` helm chart.

## Deploy Postgres Database
You can find the official chart here: [github.com/bitnami/charts/postgresql](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

# For this demo we will use bitnami/postgresql 10.5.0
helm search repo postgresql --max-col-width 23
```

```yaml title="postgres-values.yaml"
---
postgresqlDatabase: test

# Enable metrics to deploy prometheus exporter
# as a sidecar container.
# We can create a servicemonitor by setting enable 
# to true. But we will do it manually.
metrics:
  enabled: true
  serviceMonitor:
    enabled: false
    additionalLabels:
      prometheus: devops
```

```bash
helm install postgres bitnami/postgresql \
--values postgres-values.yaml \
--version 10.5.0 \
--namespace db \
--create-namespace
```

```bash
kubectl -n db get pods
```

```bash
# Look at serviceMonitorSelector
kubectl -n monitoring get prometheus monitoring-kube-prometheus-prometheus -o yaml

kubectl -n db get endpoints

kubectl -n db describe endpoints postgres-postgresql-metrics
```

```yaml title="postgres-service-monitor.yaml"
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-postgresql
  namespace: db
  labels:
    prometheus: devops
spec:
  endpoints:
  - port: http-metrics
    interval: 60s
    scrapeTimeout: 30s
  namespaceSelector:
    matchNames:
    - db
  selector:
    matchLabels:
      # Select endpoint using labels
      app.kubernetes.io/instance: postgres
```

```bash
kubectl apply -f postgres-service-monitor.yaml
```

Then prometheus operator will take the content of this `ServiceMonitor` and update the configmap of the prometheus then trigger hot-reload.

To know what parameters will be available we we configure the service monitor, we can visit prometheus operator github: [https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md)

Under `Documentation/api.md` search for [ServiceMonitorSpecs](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#monitoring.coreos.com/v1.ServiceMonitorSpec) and select `endpoints` to see the available parameters e.g. [here](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#monitoring.coreos.com/v1.Endpoint).

Here you will find the options you can use in the servicemonitor config.

### Import Grafana Dashboard
Open grafana dashboard and import the dashboard `9628` from [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards/?search=9628).

Navigate to the grafana and import the dashboard. Enter postgres dashboard id `13115` and click load. Also select the datasource `Prometheus`. Finally, click import.

This is open source postgres dashboard for prometheus exporter that is used in the helm chart. 


## Deploy cert-manager
Most of the cloud native services such as cert-manager, nginx-ingress, and others. Expose metrics in the prometheus format. 

```yaml title="prometheus.yaml"
---
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  serviceAccountName: prometheus
  serviceMonitorSelector:
    matchLabels:
      # Prometheus will watch servicemonitors objects
      # with the following label:
      # e.g. app.kubernetes.io/monitored-by: prometheus
      prometheus: monitor
  serviceMonitorNamespaceSelector:
    matchLabels:
      # By default, prometheus will ONLY detect servicemonitors
      # in its own namespace `monitoring`. Instruct prometheus
      # to select service monitors in all namespaces with the
      # following label:
      # e.g. app.kubernetes.io/part-of: prometheus
      monitoring: prometheus
---
```

The `cert-manager` helm chart will create a `ServiceMonitor` object in the `cert-manager` namespace. 

Prometheus Operator will convert Prometheus CRD into a configmap and a StateFullSet. 

```bash
kubectl -n monitoring get pods
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
  # https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/README.template.md#prometheusenabled--bool
  enabled: true
  servicemonitor:
    enabled: true
    prometheusInstance: monitor
```


### How to add Grafana Dashboards
Use this [documentation](https://docs.syseleven.de/metakube-accelerator/building-blocks/observability-monitoring/kube-prometheus-stack#adding-grafana-dashboards) and the values file [here]

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    grafana_dashboard: "1"
  name: new-dashboard-configmap
data:
  new-dashboard.json: |-
```

```bash
kubectl create configmap my-custom-dashboard --from-file=path-to-file.json
kubectl label configmaps my-custom-dashboard grafana\_dashboard=1
```

```bash
# Download the dashboard, then:
kubectl create configmap cert-manager-dashboard-11001 --from-file=/Users/ziadh/Downloads/cert-manager-dashboard-11001.json --dry-run=client -o yaml > cert-manager-dashboard-11001.yaml

kubectl apply -f cert-manager-dashboard-11001.yaml

kubectl label configmaps cert-manager-dashboard-11001 grafana_dashboard=1

```

## Deploy Ingress
Official Helm Chart: [github.com/kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx).

```yaml title="ingress-values.yaml"
---
controller:
  config:
    # https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/configmap.md#compute-full-forwarded-for
    compute-full-forwarded-for: "true"
    # https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/configmap.md#use-forwarded-headers
    use-forwarded-headers: "true"
    # https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/configmap.md#proxy-body-size
    proxy-body-size: "0"
  
  # This name we will reference this particular ingress controller
  # incase you have multiple ingress controllers, you can use
  # `ingressClassName` to specify which ingress controller to use.
  # ALSO: For backwards compatibility with ingress.class annotation, use ingressClass. Algorithm is as follows, first ingressClassName is considered, if not present, controller looks for ingress.class annotation. 
  # Ref: https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx
  # E.g. very often we have `internal` and `external` ingresses in the same cluster.
  ingressClass: external-nginx

  # New kubernetes APIs starting from 1.18 let us create an ingress class resource
  ingressClassResource:
    # ENABLED: Create the IngressClass or not
    enabled: true
    # DEFAULT: If true, Ingresses without ingressClassName get assigned to this IngressClass on creation. Ingress creation gets rejected if there are multiple default IngressClasses. Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#default-ingress-class
    default: false

  # Pod Anti-Affinity Role: deploys nginx ingress pods on a different nodes
  # very helpful if you do NOT want to disrupt services during kubernetes rolling
  # upgrades.
  # IMPORTANT: try always to use it.
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - ingress-nginx
        topologyKey: "kubernetes.io/hostname"
  
  # Should at least be 2 or configured auto-scaling
  replicaCount: 1

  # Admission webhooks: verifies the configuration before applying the ingress.
  # E.g. syntax error in the configuration snippet annotation, the generated
  # configuration becomes invalid
  admissionWebhooks:
    enabled: true

  # Ingress is always deployed with some kind of a load balancer. You may use
  # annotations supported by your cloud provider to configure it. E.g. in AWS
  # you can use `aws-load-balancer-type` as the default is `classic`.
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      # Also, if you want to have an internal load balancer with only private
      # IP address. That you can use within your VPC. you can use:
      # service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0

  # We want to enable prometheus metrics on the controller
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels:
        prometheus: monitor
```

```yaml title="ingress.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "Foo: Bar";
spec:
  ingressClassName: external-nginx
  rules:
  - host: prometheus.devopsbyexample.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-kube-prometheus-prometheus
            port:
              number: 9090
```

### Grafana Ingress Dashboard
We recommend using dashboard: `9614`.


## Extras

### Terraform Static Files
Following GCP recommendations [here](https://cloud.google.com/docs/terraform/best-practices-for-terraform#static-files).

Read json into terraform:

```json title="policy.json"
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*"
  }
}
```

```hcl
resource "aws_iam_policy" "example" {
  # ... other configuration ...

  policy = "${file("files/policy.json")}"
}
```

### Route53 Wildcard Records
Please refer to the docs [here](https://aws.amazon.com/route53/faqs/#:~:text=Q.%20Does%20Amazon%20Route%2053%20support,example.com%20and%20subdomain.example.com.).


