---
sidebar_position: 6
title: Kubernetes Storage
description: Certified Kubernetes Administrator (CKA) - Storage
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

In this section we will discuss the various storage related concepts in Kubernetes. Such as:
- Persistent Volumes.
- Persistent Volume Claims.
- Access Modes.
- Configure Applications with Persistent Storage.


There are so many storage options available in Kubernetes. But we will focus on kubernetes side of storage. 

## Docker Storage
When it comes to storage in Docker, there are two concepts:
- `Storage Drivers`.
- `Volume Drivers`.

### Storage Drivers
In this section we will discuss Docker Storage Drivers and file systems. Docker creates `/var/lib/docker` directory on the host machine. This directory contains so many folders `aufs`, `containers`, `image`, `volumes` ...etc.

This is where Docker stores all it related data. Data here means files related to images, and containers running on the docker host.

**WHat is Docker Layered Architecture?**

Docker uses a layered architecture to store images. Docker layers are Read Only once you build them and they are stacked on top of each other. When you run a container, a new layer is created on top of the image layer. This layer is Read-Write.

The life of this layer tho is only as long as the container is running. Once the container is stopped, the layer is deleted.

`copy-on-write` is a strategy used by Docker to optimize the storage. When you create a new container, Docker doesn't copy the image to the container. Instead, it creates a new layer on top of the image layer. This new layer is Read-Write and is used by the container. But if you wanted to modify the image, Docker will copy the changed file to the container layer.

So, if you wish to persist the data, you need to use volumes. Run `docker volume create my-vol` it creates a folder called `my-vol` in `/var/lib/docker/volumes` directory. This is where the data is persisted. Then just mount this volume into container read-write layer. `docker run -v my-vol:/data -it ubuntu bash`.

But, what if `docker run -v data-volume:/data -it ubuntu bash`. Here `data-volume` is not created yet. Docker will automatically create it for you. 

The above is called `volume mounting`. 

But for `binding mounting`. You need to create the directory on the host machine first. `docker run -v /host/path:/container/path -it ubuntu bash`.

#### Summary
Docker has two types of mounts `volume mounts` and `bind mounts`. Volume-mounts mounts a volume from the `/var/lib/docker/volumes` directory. Bind-mounts mounts a directory from any location on the docker host.

Using the `-v` is an old style. The new style is to use `--mount` flag. It is the prefred way as it is more verbose and easier to read. `docker run --mount type=bind,source=/host/path,target=/container/path -it ubuntu bash`. Or `docker run --mount type=volume,source=data-volume,target=/data -it ubuntu bash`.

The `Storage Drivers` is responsible for maintaining the layers architecture, creating a writable layer, moving files across layers to enable `copy-on-write` strategy, ...etc.

Some of the common storage drivers for Docker are:
- `aufs`: Default for Ubuntu.
- `zfs`.
- `btrfs`.
- `device mapper`.
- `overlay`.
- `overlay2`.

Docker will choose the best storage driver available based on the host OS. 


### Volume Drivers
Volumes are not handled by `storage drivers`. The default volume driver plugin is `local`. But you can use other volume drivers like `Azure File Storage`, `Convoy`, `DigitalOcean Block Storage`, `Flocker`, `gce-docker`, `GlusterFS`, `NetApp`, `RexRay`, `Portworx`, `VMware vSphere Storage`, ...etc.

Some of the above volume drivers support different storage providers. E.g. `RexRay` can be used to provision storage on AWS EBS, S3, Azure, Google Cloud, ...etc.

WHen you run a docker container you choose to use a specific volume driver. `docker run --volume-driver=rexray/ebs --mount src=rexray-vol-ebs,target=/vara/lib/mysql -it ubuntu bash`.

We used `rexray/ebs` to provision a volume on AWS EBS. 

## Kubernetes Storage
- Container Runtime Interface (CRI) is a standard that defines how Kubernetes would communicate with container runtime.
- Container Network Interface (CNI) is a standard made to extend Kubernetes networking capabilities. Now any new networking vendors can simply develop their plugin based on the CNI standard and it will work with Kubernetes.
- Container Storage Interface (CSI) was developed to support multiple storage solutions. With CSI you can now write your own drivers for your own storage solutions to work with kubernetes. E.g. `Portworx`, `Amazon EBS`, `Azure Disk`, ...etc.

:::note
CSI is not kubernetes standard. It is meant to be a universal standard and if implemented always any container orchestrator tool. to work with any storage vendors. 

CSI defines a set of RPCs that would be called by the container orchestrator, and these must be implemented by the storage driver. E.g. CSI says that when a pod is created it requires a volume. The container orchestrator should call the `CreateVolume` RPC and pass a set of details. Such as volume name, size, ...etc. 

Similarly, when a pod is deleted, the container orchestrator should call the `DeleteVolume` RPC.
:::


## Volumes
Docker containers are meant to be transient in nature. They are meant to last for a short period of time. Just as in docker the pods created in k8s are also transient. 

### Volumes & Mounts
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: <pod-name>
spec:
  volumes:
  - name: data-volume
    hostPath:
      path: /data
      type: Directory
  containers:
  - name: <container-name>
    image: <image-name>
    command: ["/bin/sh", "-c"]
    args: ["shuf -i 0-100 -n 1 >> /opt/number.out;"]
    volumeMounts:
    - name: data-volume
      mountPath: /opt
```

**What are the volume storage options?!**
We just use the `hostPath` option to configure a directory on the host as storage space for the volume. That works fine on a single node. It is not recommended to use in a multi-node cluster. The pod will use the `/data` directory on _**ALL the nodes**_.

```yaml title="aws-ebs-volume.yaml"
volumes:
- name: data-volume
  awsElasticBlockStore:
    volumeID: <volume-id>
    fsType: ext4
```


## Persistent Volumes
A `Persistent Volume` is a cluster wide pool of storage volumes configured by an administrator to be used by users deploying applications on the cluster.

The users can select storage from this pool using `Persistent Volume Claims`.

Available Access Modes:
- `ReadWriteOnce`: The volume can be mounted as read-write by a single node.
- `ReadOnlyMany`: The volume can be mounted read-only by many nodes.
- `ReadWriteMany`: The volume can be mounted as read-write by many nodes.

```yaml title="pv.yaml"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-vol-one
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  # [Option One]
  hostPath:
    path: /tmp/data
  # [Option Two]
  awsElasticBlockStore:
    volumeID: <volume-id>
    fsType: ext4
```

## Persistent Volume Claims
A `Persistent Volume` and `Persistent Volume Claim` are two separate objects in the kubernetes namespace. An administrator creates a set of `Persistent Volumes` and the users create `Persistent Volume Claims` to use them.

Once the PVC are created, k8s binds PV to claims based on the request, and properties set on the volume. `Every PVC is bound to a single PV`. During the binding process, k8s tries to find a PV, that has sufficient capacity as requested by the claim, and any other request properties such as `accessModes`, `volumeModes`, `storageClass`, ...etc. 

If there are multiple PVs that satisfy the claim, you can use labels and selectors to bind the claim to a specific PV. 

> Also, remember PV and PVC are one-to-one relationship. 

If there are no PVs available that satisfy the claim, the claim will remain in a `Pending` state. 

```yaml title="pvc.yaml"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

After you delete a PVC,, you can choose what happens to the volume. By default, it is set to `persistentVolumeReclaimPolicy: Retain`. This means the volume is not deleted. You can also set it to `Delete` or `Recycle`. 

- `Retain`: Means the volume is not deleted, until the administrator deletes it manually. It is not available for reuse by another PVC. 
- `Delete`: Means the volume is deleted when the PVC is deleted.
- `Recycle`: Means the volume is formatted and made available for reuse by another PVC.

```yaml title="pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: <pod-name>
spec:
  volumes:
  - name: my-pvc
    persistentVolumeClaim:
      claimName: my-pvc
  containers:
  - name: <container-name>
    image: <image-name>
    volumeMounts:
    - name: my-pvc
      mountPath: /data
```

### Example
```yaml title="app.yaml"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-vol-one
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  # [Option One]
  hostPath:
    path: /tmp/data
  # [Option Two]
  awsElasticBlockStore:
    volumeID: <volume-id>
    fsType: ext4
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <deployment-name>
spec:
  replicas: 3
    selector:
        matchLabels:
        app: <app-name>  
  template:
    metadata:
      labels:
        app: <app-name>
    spec:
      containers:
      - name: <container-name>
        image: <image-name>
        volumeMounts:
        - name: my-pvc
          mountPath: /data
      volumes:
      - name: my-pvc
        persistentVolumeClaim:
          claimName: my-pvc
```

```yaml title="Just a simple volume"
apiVersion: v1
kind: Pod
metadata:
  name: webapp
spec:
  containers:
  - name: event-simulator
    image: kodekloud/event-simulator
    env:
    - name: LOG_HANDLERS
      value: file
    volumeMounts:
    - mountPath: /log
      name: log-volume

  volumes:
  - name: log-volume
    hostPath:
      # directory location on host
      path: /var/log/webapp
      # this field is optional
      type: Directory
```


## Storage Classes
In the last example when we used `awsElasticBlockStore` we had to provision the volume manually. That is called `static provisioning`. Storage Classes are used to provision storage dynamically.

```yaml title="sc.yaml"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  zone: us-west-2a
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: my-container
    image: nginx
    volumeMounts:
    - mountPath: /data
      name: my-pvc-volume
  volumes:
  - name: my-pvc-volume
    persistentVolumeClaim:
      claimName: my-pvc
```

Once we have a storage class we no longer need to create PVs `manually`. But the dynamic provisioner will create the PVs for us.

<Tabs>

<TabItem value="Silver Class">

```yaml title="sc.yaml" {7}
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: silver
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: none
```

</TabItem>

<TabItem value="Gold Class">

```yaml title="sc.yaml" {7}
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: silver
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: none
```

</TabItem>

<TabItem value="Platinum Class">

```yaml title="sc.yaml" {7,8}
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: silver
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
```

</TabItem>

</Tabs>


#### WaitForFirstConsumer
```yaml title="sc.yaml"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
      - name: local-persistent-storage
        mountPath: /var/www/html
  volumes:
    - name: local-persistent-storage
      persistentVolumeClaim:
        claimName: local-pvc
```


## REFERENCES
- [Persistent Volumes.](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Claims As Volumes.](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#claims-as-volumes)




