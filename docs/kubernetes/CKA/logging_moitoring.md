---
sidebar_position: 4
title: Logging and Monitoring
description: Certified Kubernetes Administrator (CKA) - Observability
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

In this section we discuss the various logging and monitoring tools available in Kubernetes. First we will see how to monitor the k8s cluster components as well as the application hosted on them. Then we will see how to view and manage the logs for the cluster components and the application.

## Monitoring CLuster Components
How to monitor resources consumption in kubernetes cluster ? We would like to know low level metrics like number of nodes in the cluster. How many are healthy. As well as performance metrics like CPU and memory usage of the nodes along side with disk utilization...etc. Also, pod level metrics like number of pods and performance metrics like CPU and memory usage of the pods.

There are several solutions, but as of October 2018. Kubernetes does not come with a full featured built-in monitoring solution. However, there are a number of open-source solutions available. Such as `Metrics Server`, `Prometheus`, `Elastic Stack` and proprietary solutions such as  `Datadog`, `Dynatrace`.

`HEAPSTER` was one of the original monitoring solutions for Kubernetes. It was deprecated in favor of `Metrics Server`. You can have one `Metrics Server` per cluster. The metrics server retrieves metrics from each of the cluster nodes and pods. Aggregates them and stores them in memory. `The metrics server is an in-memory monitoring solution`. And doesn't store the metrics on the disk. And as a result you can't see historical data.

The kubelet contains the `cAdvisor` which is an agent that monitors resource usage and performance metrics of the pods.

```bash title="Minikube"
minikube addons enable metrics-server
```

```bash title="Metrics Server"
git clone https://github,com/kubernetes-incubator/metrics-server
kubectl apply -f deploy/1.8+/
# After some time, view metrics with
kubectl top node
kubectl top pod
# head -1 to get the node with the highest CPU usage
kubectl top node --sort-by='cpu' --no-headers | head -1
kubectl top node --sort-by='memory' --no-headers | head -1 
kubectl top pod --sort-by='cpu' --no-headers | tail -1 
```

### Application logs
```bash title="Application logs"
kubectl logs <pod-name> <container-name> # (-f) flag to follow the logs
```


## Prometheus

:::warning
This section will be added soon. It is being migrated from the old notes hub ^^.
:::














