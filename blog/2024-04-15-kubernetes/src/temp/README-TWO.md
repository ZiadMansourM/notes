- First 25 Resource applied in total of 12 minutes. And destroyed in 11 minutes.
    - All resources were configured in 2 minutes the rest for `eks-cluster` and `eks-nodegroup`.
    - Eks took around 9 minutes.
    - Nodegroup took around one minute.
- Second Ten Resources in 4 minutes. Destroyed in 2 minutes.


- **Pre-requisites**
- [X] Ensure that no oidc provider is configured on AWS.
- No hosted Zone is configured.
- [X] The Policy and Roles are deleted.

- **Apply 00_foundation**
```bash
rm ~/.kube/config

aws eks --region eu-central-1 update-kubeconfig --name eks-cluster-production --profile terraform

kubectl get nodes,svc
```
- **Apply 10_platform**
- [X] Verify oidc provider were created.
- [X] Add NS on Namecheap for `k8s.sreboy.com`.
- [X] Verify the wildcard CNAME was created.
- **Apply 15_platform**
- `kubectl apply -f 15_platform/files/`
- `kubectl -n monitoring get certificates,challenges,ingress,all`
- `kubectl -n goviolin get certificates,challenges,ingress,all`
- [X] Ensure Cert Manager is able to create TXT records.
- [X] External Access through:
    - grafana.goviolin.k8s.sreboy.com
    - prometheus.goviolin.k8s.sreboy.com
    - goviolin.k8s.sreboy.com
- [X] Verify Default Prometheus Targets are created.
- [X] Verify Default Grafana Dashboards are created.
- [X] Verify Cert Manager, Ingress Targets and Custom Dashboards are created.

Unexpected:
- Forgot CNAME record
- Forgot to set the aws_region

Extra:
- [X] Cluster Issuer.
- Automate Namecheap DNS Configuration.
- Multiple Nginx Controllers `Internal` and `External`. Plus VPN.
- Deploy `Sample Voting App`.
- Karpenter.

<hr/>

```bash
kubectl create configmap ingress-nginx-dashboard-14314 --from-file=/Users/ziadh/Desktop/courses/notes/blog/2024-04-15-kubernetes/src/15_platform/files/dashboards/ingress-nginx-14314.json --dry-run=client -o yaml > ingress-nginx-dashboard-14314.yaml

kubectl create configmap cert-manager-dashboard-20842 --from-file=/Users/ziadh/Desktop/courses/notes/blog/2024-04-15-kubernetes/src/15_platform/files/dashboards/cert-manager-20842.json --dry-run=client -o yaml > cert-manager-dashboard-20842.yaml
```

Add:
```yaml
labels:
    grafana_dashboard: "1"
```

```bash
kubectl apply -f cert-manager-dashboard-11001.yaml

kubectl label configmaps cert-manager-dashboard-11001 grafana_dashboard=1
```