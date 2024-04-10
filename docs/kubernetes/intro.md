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

```bash title="Watch Resources Changes"
kubectl get all -w 

watch -n 1 kubectl get all
```

```bash title="What is the networking Plugin Used"
ls /etc/cni/net.d/

#  How many weave peer deployed 
kubectl get pods -n kube-system -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName

# Identify the name of the bridge network/interface created by weave on each node.
ip a
ip a show type bridge
ip a show weave
ip link show type bridge

# What is the default gateway configured on the PODs scheduled on node01?
ssh <node01>
ip route
```

```bash title="What network range are the nodes in the cluster part of?!"
kubectl get nodes # And get internal ip address of the node you are on
# Use this IP address to find the network interface
ip a | grep eth0
ip a show eth0
ipcalc -b 192.29.184.12

# What is the range of IP addresses configured for PODs on this cluster?
k -n kube-system get po -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName
k -n kube-system logs  weave-net-sptm5 weave | grep ipalloc-range

# What is the IP Range configured for the services within the cluster?
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep service-cluster-ip-range
```


```bash title="Get All Namespaced Resources"
kubectl get $(kubectl api-resources --namespaced --verbs=list -o name | paste -sd, -) --ignore-not-found

# Exclude events,events.events.k8s.io
kubectl get $(kubectl api-resources --namespaced --verbs=list -o name | grep -Ev 'events(\.events\.k8s\.io)?' | paste -sd, -) --ignore-not-found

# Exclude events.events.k8s.io only
kubectl get $(kubectl api-resources --namespaced --verbs=list -o name | grep -Ev 'events\.events\.k8s\.io' | paste -sd, -) --ignore-not-found

# Add Sort by Name
kubectl get $(kubectl api-resources --namespaced --sort-by name --verbs=list -o name | grep -Ev 'events\.events\.k8s\.io' | paste -sd, -) --ignore-not-found

# kgr = kubectl get namespaced resources
alias kgr='kubectl get $(kubectl api-resources --namespaced --sort-by name --verbs=list -o name | grep -Ev 'events\.events\.k8s\.io' | paste -sd, -) --ignore-not-found'
# kgnr = kubectl get non-namespaced resources
alias kgnr='kubectl get $(kubectl api-resources --namespaced=false --sort-by name --verbs=list -o name | grep -Ev 'componentstatuses' | paste -sd, -) --ignore-not-found'
# kgrc = kubectl get resources combined
alias kgrc='kubectl get $(kubectl api-resources --sort-by name --verbs=list -o name | grep -Ev 'events\.events\.k8s\.io|componentstatuses' | paste -sd, -) --ignore-not-found'
```

















