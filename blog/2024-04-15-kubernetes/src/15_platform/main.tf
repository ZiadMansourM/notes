# 1. Deployed Kube Prometheus Stack
# 2. Deployed Ingress Nginx and Exposed metrics
# 3. Deployed Cert Manager and Exposed metrics. Plus Configured Route53 DNS-01 challenge

# 4. Create a Cluster Issuer with dns01 challenge
# 5. Expose Prometheus at: https://prometheus.goviolin.k8s.sreboy.com
# 6. Expose Grafana at: https://grafana.govioline.k8s.sreboy.com
# 7. Expose Alert Manager at: https://alertmanager.goviolin.k8s.sreboy.com
# 8. Expose GoVioLin app at: https://goviolin.k8s.sreboy.com

data "aws_route53_zone" "k8s" {
  name = "k8s.sreboy.com."
}

resource "kubernetes_manifest" "cluster_deployment" {
  manifest = file("files/deployment.yaml")
}

resource "kubernetes_manifest" "ingress-nginx-dashboard-14314" {
  manifest = file("files/dashboards/ingress-nginx-dashboard-14314.yaml")
}

resource "kubernetes_manifest" "cert-manager-dashboard-20842" {
  manifest = file("files/dashboards/cert-manager-dashboard-20842.yaml")
}