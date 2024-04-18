# 1. Deployed Kube Prometheus Stack
# 2. Deployed Ingress Nginx and Exposed metrics
# 3. Deployed Cert Manager and Exposed metrics. Plus Configured Route53 DNS-01 challenge

# 4. Create a Cluster Issuer with dns01 challenge
# 5. Expose Prometheus at: https://prometheus.goviolin.k8s.sreboy.com
# 6. Expose Grafana at: https://grafana.govioline.k8s.sreboy.com
# 7. Expose Alert Manager at: https://alertmanager.goviolin.k8s.sreboy.com
# 8. Expose GoVioLin app at: https://goviolin.k8s.sreboy.com

data "aws_route53_zone" "k8s" {
  name = "k8s.sreboy.com"
}

resource "kubernetes_manifest" "cluster_prod_dns01_issuer" {
  manifest = <<YAML
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-dns01-production
  namespace: monitoring
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ziadmansour.4.9.2000@gmail.com
    privateKeySecretRef:
      name: letsencrypt-production-dns01-key-pair
    solvers:
    - dns01:
        route53:
          region: ${var.region}
          hostedZoneID: ${aws_route53_zone.k8s.zone_id}
  YAML
}

resource "kubernetes_manifest" "grafana_ingress" {
  manifest = <<YAML
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
  YAML
}

resource "kubernetes_manifest" "prometheus_ingress" {
  manifest = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    cert-manager.io/issuer: letsencrypt-dns01-production
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
            name: prometheus-kube-prometheus-stack-prometheus
            port:
              number: 9090
  YAML
}

resource "kubernetes_manifest" "goviolin_deployment" {
  manifest = <<YAML
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
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-dns01-production
  namespace: goviolin
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ziadmansour.4.9.2000@gmail.com
    privateKeySecretRef:
      name: letsencrypt-production-dns01-key-pair
    solvers:
    - dns01:
        route53:
          region: ${var.region}
          hostedZoneID: ${aws_route53_zone.k8s.zone_id}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: goviolin
  namespace: goviolin
  annotations:
    cert-manager.io/issuer: letsencrypt-dns01-production
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
  YAML
}