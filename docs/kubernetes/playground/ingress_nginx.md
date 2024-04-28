---
sidebar_position: 6
title: Ingress Nginx
description: Multiple Ingress Nginx Controllers
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

In this section we will try to deploy two ingress controllers in the same cluster. We will use the following ingress controllers:
- We will put the `external-nginx` ingress controller in the `ingress-nginx-external` namespace.
- We will put the `internal-nginx` ingress controller in the `ingress-nginx-internal` namespace.

```yaml title="external-nginx-values.yaml"
---
# Ref: https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml

controller:
  # name: external-controller
  # -- Election ID to use for status update, by default it uses the controller name combined with a suffix of 'leader'
  # electionID: ""
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
    name: external-nginx
    # ENABLED: Create the IngressClass or not
    enabled: true
    # DEFAULT: If true, Ingresses without ingressClassName get assigned to this IngressClass on creation. Ingress creation gets rejected if there are multiple default IngressClasses. Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#default-ingress-class
    default: false
    # Ref: https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/#using-ingressclasses
    controllerValue: "k8s.io/ingress-nginx-external"

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
      # Ref: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/
      service.beta.kubernetes.io/aws-load-balancer-name: "load-balancer-external"
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      # service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      # Also, if you want to have an internal load balancer with only private
      # IP address. That you can use within your VPC. you can use:
      # Ref: https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html
      # service.beta.kubernetes.io/aws-load-balancer-scheme: "internet"
      # service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
      # service.beta.kubernetes.io/aws-load-balancer-internal: "true"

  # We want to enable prometheus metrics on the controller
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      # additionalLabels:
      #   prometheus: monitor

```

```yaml title="internal-nginx-values.yaml"
---
# Ref: https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml

controller:
  # name: external-controller
  # -- Election ID to use for status update, by default it uses the controller name combined with a suffix of 'leader'
  # electionID: ""
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
  ingressClass: internal-nginx

  # New kubernetes APIs starting from 1.18 let us create an ingress class resource
  ingressClassResource:
    name: internal-nginx
    # ENABLED: Create the IngressClass or not
    enabled: true
    # DEFAULT: If true, Ingresses without ingressClassName get assigned to this IngressClass on creation. Ingress creation gets rejected if there are multiple default IngressClasses. Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#default-ingress-class
    default: true
    # Ref: https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/#using-ingressclasses
    controllerValue: "k8s.io/ingress-nginx-internal"

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
    external:
      enabled: false
    internal:
      enabled: true
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: nlb
        service.beta.kubernetes.io/aws-load-balancer-name: "load-balancer-internal"
        service.beta.kubernetes.io/aws-load-balancer-schema: "internal"
    # annotations:
      # Ref: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/
    #   service.beta.kubernetes.io/aws-load-balancer-name: "load-balancer-external"
    #   service.beta.kubernetes.io/aws-load-balancer-type: nlb
      # service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      # Also, if you want to have an internal load balancer with only private
      # IP address. That you can use within your VPC. you can use:
      # Ref: https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html
      # service.beta.kubernetes.io/aws-load-balancer-scheme: "internet"
      # service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
      # service.beta.kubernetes.io/aws-load-balancer-internal: "true"

  # We want to enable prometheus metrics on the controller
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      # additionalLabels:
      #   prometheus: monitor

```


```yaml title="internal-nginx-values.yaml"
controller:
  ingressClassByName: true

  ingressClassResource:
    name: nginx
    enabled: true
    default: true
    controllerValue: "k8s.io/ingress-nginx"

  service:
    external:
      enabled: false
    internal:
      enabled: true
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-internal: "true"
        service.beta.kubernetes.io/aws-load-balancer-name: "load-balancer-internal"
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
        service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
        service.beta.kubernetes.io/aws-load-balancer-type: nlb
```


```yaml
controller:
  ingressClassByName: true

  ingressClassResource:
    name: nginx-public
    enabled: true
    default: false
    controllerValue: "k8s.io/ingress-nginx-public"

  ingressClass: nginx-public
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
    # Disable the external LB
    external:
      enabled: true
```


```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo kube-prometheus-stack --max-col-width 23
# Release name: monitoring
# Helm chart name: kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack \
--values kube-prometheus-stack-values.yaml \
--version 58.1.3 \
--namespace monitoring \
--create-namespace
# Later when you are done
helm uninstall monitoring -n monitoring
```


```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo ingress-nginx --max-col-width 23

helm install ingress-nginx-external ingress-nginx/ingress-nginx \
--values external-nginx-values.yaml \
--version 4.10.0 \
--namespace ingress-nginx-external \
--create-namespace

helm install ingress-nginx-internal ingress-nginx/ingress-nginx \
--values internal-nginx-values.yaml \
--version 4.10.0 \
--namespace ingress-nginx-internal \
--create-namespace

# Later when you are done
helm uninstall ingress-nginx-external -n ingress-nginx-external
helm uninstall ingress-nginx-internal -n ingress-nginx-internal
```


```bash
kubectl -n ingress-nginx-external get po
kubectl -n ingress-nginx-internal get po

kubectl -n ingress-nginx-external get svc ingress-nginx-external-controller -o wide -w
kubectl -n ingress-nginx-internal get svc ingress-nginx-internal-controller-internal -o wide -w

kubectl -n ingress-nginx-external get svc ingress-nginx-external-controller -o json | jq .status.loadBalancer
kubectl -n ingress-nginx-internal get svc ingress-nginx-internal-controller-internal -o json | jq .status.loadBalancer

kubectl -n ingress-nginx-external get po -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
kubectl -n ingress-nginx-internal get po -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
```

## Tested
```yaml title="external-nginx-values.yaml"
---
# Ref: https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml

controller:
  # name: controller
  # -- Election ID to use for status update, by default it uses the controller name combined with a suffix of 'leader'
  # electionID: ""
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
    name: external-nginx
    # ENABLED: Create the IngressClass or not
    enabled: true
    # DEFAULT: If true, Ingresses without ingressClassName get assigned to this IngressClass on creation. Ingress creation gets rejected if there are multiple default IngressClasses. Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#default-ingress-class
    default: false
    # Ref: https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/#using-ingressclasses
    controllerValue: "k8s.io/ingress-nginx-external"

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
      # Ref: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/
      service.beta.kubernetes.io/aws-load-balancer-name: "load-balancer-external"
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      # service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"

  # We want to enable prometheus metrics on the controller
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      # additionalLabels:
      #   prometheus: monitor

```

```yaml title="internal-nginx-values.yaml"
---
# Ref: https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml

controller:
  # name: controller
  # -- Election ID to use for status update, by default it uses the controller name combined with a suffix of 'leader'
  # electionID: ""
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
  ingressClass: internal-nginx

  # New kubernetes APIs starting from 1.18 let us create an ingress class resource
  ingressClassResource:
    name: internal-nginx
    # ENABLED: Create the IngressClass or not
    enabled: true
    # DEFAULT: If true, Ingresses without ingressClassName get assigned to this IngressClass on creation. Ingress creation gets rejected if there are multiple default IngressClasses. Ref: https://kubernetes.io/docs/concepts/services-networking/ingress/#default-ingress-class
    default: true
    # Ref: https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/#using-ingressclasses
    controllerValue: "k8s.io/ingress-nginx-internal"

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
    external:
      enabled: false
    internal:
      enabled: true
      annotations:
        # Ref: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/
        # if you want to have an internal load balancer with only private
        # IP address. That you can use within your VPC. you can use:
        # Ref: https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html
        service.beta.kubernetes.io/aws-load-balancer-type: nlb
        service.beta.kubernetes.io/aws-load-balancer-name: "load-balancer-internal"
        service.beta.kubernetes.io/aws-load-balancer-schema: "internal"
        # service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"

  # We want to enable prometheus metrics on the controller
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      # additionalLabels:
      #   prometheus: monitor

```


After they are applied, aws will create two load balancers:
- `load-balancer-external`:
  - The nodes of an `internet-facing` load balancer have `public IP addresses`. The DNS name of an internet-facing load balancer is `publicly resolvable to the public IP addresses` of the nodes. Therefore, internet-facing load balancers can route requests from clients over the internet.
- `load-balancer-internal`:
  - The nodes of an `internal` load balancer have `only private IP addresses`. The DNS name of an internal load balancer is `publicly resolvable to the private IP addresses` of the nodes. Therefore, internal load balancers can only route requests from clients with access to the VPC for the load balancer.


We will have two DNS records:
- For `load-balancer-external`: aws will craete `load-balancer-external-<hash>.elb.amazonaws.com`.
- For `load-balancer-internal`: aws will craete `load-balancer-internal-<hash>.elb.amazonaws.com`.

We will access the `load-balancer-external` from the internet and the `load-balancer-internal` with VPN.

For route53, we delegated the `*.k8s.sreboy.com` from Namecheap to Route53.

Create a wildcard CNAME in the public hosted zone to point to the `load-balancer-external`.
Create a wildcard CNAME in the private hosted zone to point to the `load-balancer-internal`.

```yaml title="goviolin-ingress.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: goviolin
  namespace: goviolin
  annotations:
    cert-manager.io/issuer: letsencrypt-dns01-production-cluster-issuer
spec:
  ingressClassName: external-nginx
  tls:
  - hosts:
    - goviolin.k8s.sreboy.com
    secretName: goviolin-k8s-sreboy-com-key-pair
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
```

```yaml title="monitoring-ingress.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-dns01-production-cluster-issuer
spec:
  ingressClassName: internal-nginx
  tls:
  - hosts:
    - grafana.k8s.sreboy.com
    secretName: grafana-k8s-sreboy-com-key-pair
  rules:
  - host: grafana.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-dns01-production-cluster-issuer
spec:
  ingressClassName: internal-nginx
  tls:
  - hosts:
    - prometheus.k8s.sreboy.com
    secretName: prometheus-k8s-sreboy-com-key-pair
  rules:
  - host: prometheus.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-kube-prometheus-prometheus
            port:
              number: 9090
---
```

```yaml title="monitoring-ingress.yaml"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-dns01-production-cluster-issuer
spec:
  ingressClassName: internal-nginx
  tls: 
  - hosts:
    - grafana.k8s.sreboy.com
    secretName: grafana-k8s-sreboy-com-key-pair
  - hosts:
    - prometheus.k8s.sreboy.com
    secretName: prometheus-k8s-sreboy-com-key-pair
  - hosts:
    - alertmanager.k8s.sreboy.com
    secretName: alertmanager-k8s-sreboy-com-key-pair
  - hosts:
    - kube-state-metrics.k8s.sreboy.com
    secretName: kube-state-metrics-k8s-sreboy-com-key-pair
  rules:
  - host: grafana.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
  - host: prometheus.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-kube-prometheus-prometheus
            port:
              number: 9090
  - host: alertmanager.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-kube-prometheus-alertmanager
            port:
              number: 9093
  - host: kube-state-metrics.k8s.sreboy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-kube-state-metrics
            port:
              number: 8080
---
```


