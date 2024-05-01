---
sidebar_position: 3
title: Loki
description: Loki Setup Kubernetes
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

```bash
helm repo add prometheus-community \
https://prometheus-community.github.io/helm-charts

helm repo update
helm search repo kube-prometheus-stack --max-col-width 23

# Release name: monitoring
# Helm chart name: kube-prometheus-stack
helm install monitoring prometheus-community/kube-prometheus-stack \
--values prometheus-values.yaml \
--version 58.1.3 \
--namespace monitoring \
--create-namespace

helm uninstall monitoring -n monitoring
```

```bash
helm repo add grafana https://grafana.github.io/helm-charts

helm search repo grafana --max-col-width 35
```

We will install:
- grafana/promtail // 6.15.5
- grafana/loki-distributed // 0.79.0

```bash
helm install loki grafana/loki-distributed \
--version 0.79.0 \
--namespace monitoring \
--create-namespace

helm install promtail grafana/promtail \
--values promtail-values.yaml \
--version 6.15.5 \
--namespace monitoring \
--create-namespace
```

