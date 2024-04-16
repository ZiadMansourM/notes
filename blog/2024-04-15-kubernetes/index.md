---
slug: eks-cluster
title: EKS Cluster
authors: [ziadh]
tags: [kubernetes, eks, terraform, cert-manager, ingress]
---

In this blog we will go through the deployment of the [GoViolin](https://github.com/ZiadMansourM/GoViolin) App. We will aim to deploy a production grade and HA EKS cluster with the following steps:
- [ ] Dockerize the GoViolin App.
    - [ ] Utilize multi-stage builds.
    - [ ] Build a minimal image.
    - [ ] Support Multi-Architecture.
- [ ] Provision the EKS cluster using Terraform.
    - [ ] Use Terraform resources.
    - [ ] Use Terraform modules.
- [ ] Add Cert-Manager and Ingress Controller.
- [ ] Deploy the GoViolin App.
- [ ] Expose Prometheus and Grafana.
    - [ ] Expose them to the internet.
    - [ ] Expose them internally and use VPN connection.


## Dockerize GoViolin


