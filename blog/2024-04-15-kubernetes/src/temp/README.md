```bash
# ----> [1]: Kube Prometheus Stack # 16.10.0 not 58.1.3
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo kube-prometheus-stack --max-col-width 23
# Release name: monitoring
# Helm chart name: kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack \
--values prometheus-values.yaml \
--version 58.1.3 \
--namespace monitoring \
--create-namespace

kubectl -n monitoring get prometheus -o yaml

helm uninstall monitoring -n monitoring
```

```bash title="With 55.7.0 you get svc"
NAME                                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/alertmanager-operated                     ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   4m9s
service/monitoring-grafana                        ClusterIP   10.98.35.153     <none>        80/TCP                       4m14s
service/monitoring-kube-prometheus-alertmanager   ClusterIP   10.104.231.97    <none>        9093/TCP,8080/TCP            4m14s
service/monitoring-kube-prometheus-operator       ClusterIP   10.103.175.168   <none>        443/TCP                      4m14s
service/monitoring-kube-prometheus-prometheus     ClusterIP   10.102.31.200    <none>        9090/TCP,8080/TCP            4m14s
service/monitoring-kube-state-metrics             ClusterIP   10.102.250.125   <none>        8080/TCP                     4m14s
service/monitoring-prometheus-node-exporter       ClusterIP   10.98.73.132     <none>        9100/TCP                     4m14s
service/prometheus-operated                       ClusterIP   None             <none>        9090/TCP                     4m8s
```

```bash title="With 55.7.0 you get po"
NAME                                                     READY   STATUS                 RESTARTS        AGE
alertmanager-monitoring-kube-prometheus-alertmanager-0   2/2     Running                0               6m1s
monitoring-grafana-c8664884b-hhpzt                       3/3     Running                0               6m5s
monitoring-kube-prometheus-operator-5c67cf46c5-f82zp     1/1     Running                0               6m5s
monitoring-kube-state-metrics-68b7c66d64-zf92j           1/1     Running                0               6m5s
monitoring-prometheus-node-exporter-46n8m                0/1     CreateContainerError   0               6m5s
monitoring-prometheus-node-exporter-kbk98                0/1     CreateContainerError   0               6m5s
monitoring-prometheus-node-exporter-nxjkx                0/1     CreateContainerError   0               6m5s
prometheus-monitoring-kube-prometheus-prometheus-0       1/2     CrashLoopBackOff       5 (2m24s ago)   6m
```

```bash
# ----> [2]: Ingress-Nginx # 4.0.1 not  4.10.0 
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo ingress-nginx --max-col-width 23
helm install ingress-nginx ingress-nginx/ingress-nginx --values ingress-nginx-values.yaml --version 4.0.1 --namespace ingress-nginx --create-namespace

helm uninstall ingress-nginx -n ingress-nginx

# ----> [3]: Cert-Manager # 1.5.3
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo cert-manager --max-col-width 23
helm install cert-manager jetstack/cert-manager \
--values cert-manager-values.yaml \
--version 1.14.4 \ 
--namespace cert-manager \
--create-namespace
```