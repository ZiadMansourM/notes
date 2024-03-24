---
sidebar_position: 1
title: Introduction
description: Kubernetes Certification Plan
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

In this page you will see my certification path plan, and some quick commands that I use frequently.

## Plan
- [ ] Certified Kubernetes Administrator - (CKA).
- [ ] Certified Kubernetes Security Specialist - (CKS).

## Quick Commands
```bash title="Version of etcd cluster"
kubectl get pod etcd-controlplane -n kube-system -o json | jq '.spec.containers[0].image'
```

```bash title="Get daemonsets and show their namespace & name only"
kubectl get daemonsets -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name
# Get pod name and node hosted on it
kubectl get pods -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
```

```bash title="Taint/Untaint and Query a Node"
controlplane ~ ➜  kubectl taint nodes controlplane special=true:PreferNoSchedule
node/controlplane tainted

controlplane ~ ➜  k get nodes controlplane -o json | jq '.spec.taints'
[
  {
    "effect": "PreferNoSchedule",
    "key": "special",
    "value": "true"
  }
]

controlplane ~ ➜  kubectl taint nodes controlplane special=true:PreferNoSchedule-
node/controlplane untainted
```

```bash title="Identify the kubelet configuration file"
ps -aux | grep /usr/bin/kubelet | grep config
grep -i staticpodpath /var/lib/kubelet/config.yaml
```

```bash
# Create a static pod named static-busybox that uses the busybox image and the command sleep 1000
kubectl run --restart=Never --image=busybox static-busybox --dry-run=client -o yaml --command -- sleep 1000 > /etc/kubernetes/manifests/static-busybox.yaml
# Edit the image on the static pod to use busybox:1.28.4
kubectl run --restart=Never --image=busybox:1.28.4 static-busybox --dry-run=client -o yaml --command -- sleep 1000 > /etc/kubernetes/manifests/static-busybox.yaml
```


```bash title="Get count of Pods"
kubectl get po -l env=dev --no-headers | wc -l
```

```bash title="Hot fix a pod"
kubectl get po <pod-name> -o yaml > pod.yaml
vi pod.yaml
kubectl replace -f pod.yaml --force
```





