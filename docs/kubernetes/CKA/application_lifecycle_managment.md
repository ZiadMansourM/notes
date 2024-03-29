---
sidebar_position: 5
title: Application Lifecycle Management
description: Certified Kubernetes Administrator (CKA) - ALM
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

We start as `Rolling Updates` and `Rollbacks`. The different ways to configure an application and scale an application. Finally, we will look at the primitives of a self healing application.

When you first create a deployment, it triggers a `rollout`. A new rollout creates a new deployment `revision`. Let's call it revision-one. In the future when the application is upgraded, a new rollout is triggered and a new deployment revision is created named revision-two. 

The above helps us keep track of the changes made to our deployment. And enables us to rollback to a previous revision if needed.

You can see the status of your rollout by running `kubectl rollout status deployment/<deployment-name>`. And you can see the history of your rollout by running `kubectl rollout history deployment/<deployment-name>`.

There are two types of deployments strategies:
- Recreate: Application Down for this period.
- Rolling Update: Application is always up and accessible. "Default".


## Under the Hood
When a deployment is created it creates a `ReplicaSet`. Which in turn creates `Pods`. When you upgrade your application, the kubernetes deployment object creates a new `ReplicaSet` under the hood and starts creating new `Pods` there. At the same time, it starts terminating the old `Pods` in the old `ReplicaSet`. This is how the rolling update works. That can be seen if you run `kubectl get rs`.

To undo a change you can run `kubectl rollout undo deployment/<deployment-name>`. The deployment will then destroy the pods in the new replica set and bring the old ones up.


```sh title="curl-test.sh"
for i in {1..35}; do
   kubectl exec --namespace=kube-public curl -- sh -c 'test=`wget -qO- -T 2  http://webapp-service.default.svc.cluster.local:8080/info 2>&1` && echo "$test OK" || echo "Failed"';
   echo ""
done
```


## Application Configuration
In this section we will discuss Commands and Arguments in a pod definition file. Remember that unlike VMs containers are not meant to host an operating systems. Containers are meant to run a specific task or process. Such as to host an instance of a web server or a database or simply carry out some kind of computation or analysis. Once the tasks is complete the container `exits`. The container only lives as long as the process inside it is alive.

in the ubuntu image the command is `bash`. And bash is a shell that listens for inputs from a terminal, so if it can not find a terminal it will exit. And when you ran the ubuntu container. Docker will create a container and launch the bash process inside it. By default, docker does not attach a terminal to the container. So the bash program will not find a terminal and will exit. Since the main process of the container has exited, the container will also exit too.

### Ubuntu Sleeper
```Dockerfile title="Dockerfile"
FROM ubuntu
CMD ["sleep", "5"]
```

```bash title="Run the container"
docker run ubuntu-sleeper sleep 10 # This will sleep for 10 seconds
```

```Dockerfile title="Dockerfile"
FROM ubuntu
ENTRYPOINT ["sleep"]
```

```bash title="Run the container"
docker run ubuntu-sleeper 10 # This will sleep for 10 seconds
```

In case of the CMD instruction the command line parameters passed will get replaced entirely. Where as in case of ENTRYPOINT the command line parameters will get appended. But, if you forget to pass the command line parameters, `Error: sleep missing operand` will be thrown.

```Dockerfile title="Dockerfile"
FROM ubuntu
ENTRYPOINT ["sleep"]
CMD ["5"]
```

```bash title="Run the container"
docker run ubuntu-sleeper # This will sleep for 5 seconds
```

:::warning
For the above to work, you should always specify the entrypoint and the command in the **JSON array format**. 
:::

But if you are an upper Egyptian like me with a stubborn head, and you want to change the entrypoint at runtime. You can do so by running `docker run --entrypoint <new-entrypoint> <image-name> <command>`. E.g. `docker run --entrypoint sleep2.0 ubuntu-sleeper 10`.


### Commands and Arguments in k8s
Note first that the command filed in the pod definition file is the equivalent of the ENTRYPOINT in the Dockerfile. And the args field is the equivalent of the CMD in the Dockerfile.




```Dockerfile title="Dockerfile"
FROM ubuntu
ENTRYPOINT ["sleep"]
CMD ["5"]
```

```bash
docker build -t ubuntu-sleeper .
```

<Tabs>

<TabItem value="Overriding Time">

```yaml title="pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper-pod
spec:
  containers:
  - name: ubuntu-sleeper
    image: ubuntu-sleeper
    args: ["10"]
```

</TabItem>

<TabItem value="Overriding Entry Point">

```yaml title="pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper-pod
spec:
  containers:
  - name: ubuntu-sleeper
    image: ubuntu-sleeper
    command: ["sleep2.0"] # Equivalent to --entrypoint
    args: ["10"]
```

</TabItem>

</Tabs>


## Configure Env Variables
You can use the `env` field in the pod definition file to set environment variables. Or use the `ConfigMap` or `Secrets` to store the environment variables.

```yaml title="pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper-pod
spec:
  containers:
  - name: ubuntu-sleeper
    image: ubuntu-sleeper
    env:
    - name: APP_COLOR
      value: pink
```

## ConfigMaps
When you have a lot of pod definition files, it will become difficult to manage the environment variables stored within those files. We can use `ConfigMaps` to store the environment variables. And then reference the `ConfigMap` in the pod definition file.

ConfigMaps are used to pass configuration data in the form of key-value pairs in kubernetes. When the pod is created inject the ConfigMap and the key-values are available as environment variables in the pod.

```bash
kubectl create configmap app-config --from-literal=APP_COLOR=blue --from-literal=APP_NAME=myapp
kubectl get configmaps
```


```yaml title="configmap.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_COLOR: blue
  APP_NAME: myapp
```

```yaml title="pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper-pod
spec:
  containers:
  - name: ubuntu-sleeper
    image: ubuntu-sleeper
    envFrom:
    - configMapRef:
        name: app-config
```

## Secrets
```bash
kubectl create secret generic <secret-name> --from-literal=<key>=<value>
kubectl create secret generic app-secret --from-literal=DB_Host=sql01 
kubectl get secrets
kubectl create secret generic <secret-name> --from-file=<path-to-file>
```

```yaml title="secret.yaml"
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
data:
  DB_Host: c3FsMDEK
```

```bash
echo "sql01" | base64
echo "c3FsMDEK" | base64 -d
```

```yaml title="pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: ubuntu-sleeper-pod
spec:
  containers:
  - name: ubuntu-sleeper
    image: ubuntu-sleeper
    envFrom:
    - secretRef:
      name: app-secret
```

:::warning
Secrets are not encrypted. They are just base64 encoded. So, do not check them into source control.

Secrets are stored in etcd without encryption. `Consider Encryption at Rest`.

Anyone able to create pods/deployments in the same namespace can access the secrets. Configure least-privilege access to the secrets - `RBAC`.

Consider using a third-party secrets store providers e.g. HashiCorp Vault, AWS, ...etc.
:::


### Encryption at Rest
You can check the docs [here](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/).

1. Check for `--encryption-provider-config` in the kube-apiserver.yaml file in `/etc/kubernetes/manifests/`. Or run `ps -aux | grep kube-api | grep "encryption-provider-config"` to see the flags.
2. Create a configuration file. And watch out for the order of the providers. When encrypting happens it uses the first provider in the list. 


#### Exa
```yaml title="encryption-config.yaml"
---
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
      - pandas.awesome.bears.example
    providers:
      - aescbc:
          keys:
            - name: key1
              # See the following text for more details about the secret value
              secret: <BASE 64 ENCODED SECRET> # Run: head -c 32 /dev/urandom | base64 
      - identity: {} # this fallback allows reading unencrypted secrets;
                     # for example, during initial migration
```

Then go and modify the `/etc/kubernetes/manifests/kube-apiserver.yaml` file to include the `--encryption-provider-config` flag. And point it to the file you just created. And add volume mounts.


:::danger
`Old secrets` will `NOT` be re-encrypted. Everything that existed previously will still be in `PLAIN TEXT`.
:::

:::tip
Remember that secrets encode data in base64 format. Anyone with the base64 encoded secret can easily decode it. As such the secrets can be considered not very safe.

The concept of safety of the Secrets is a bit confusing in Kubernetes. The [Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/secret/) page and a lot of blogs out there refer to secrets as a “safer option” to store sensitive data. They are safer than storing in plain text as they reduce the risk of accidentally exposing passwords and other sensitive data. In my opinion, it’s not the secret itself that is safe, it is the practices around it.

Secrets are not encrypted, so it is not safer in that sense. However, some best practices around using secrets make it safer. As in best practices like:

- Not checking in secret object definition files to source code repositories.
- [Enabling Encryption at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) for Secrets so they are stored encrypted in ETCD.

Also, the way Kubernetes handles secrets. Such as:
- A secret is only sent to a node if a pod on that node requires it.
- Kubelet stores the secret into a tmpfs so that the secret is not written to disk storage.
- Once the Pod that depends on the secret is deleted, kubelet will delete its local copy of the secret data as well.

Read about the [protections](https://kubernetes.io/docs/concepts/configuration/secret/#protections) and [risks](https://kubernetes.io/docs/concepts/configuration/secret/#risks) of using secrets [here](https://kubernetes.io/docs/concepts/configuration/secret/#risks).

Having said that, there are other better ways of handling sensitive data like passwords in Kubernetes, such as using tools like Helm Secrets, and [HashiCorp Vault](https://www.vaultproject.io/).
:::

### CSI Driver
Kubernetes Secret Store CSI Driver. CSI stands for Container Storage Interface. 

**Why do we need the Secret Store CSI Driver?!**

Usually, we store any credentials in a Kubernetes Secret Object. 

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database
data:
  DB_PASSWORD: cGFzc3dvcmQ=
```

It is only base64 encoded and not encrypted. So, anyone with access to the cluster can decode it. Totally insecure.

Also a lot of organizations have started using external secret stores things like HashiCorp Vault, AWS Secrets Manager, Google Secret Manager, Azure Key Vault, ...etc. They allow organizations to manage all their secrets in one place and have better control over who can access them.

The Secret Store CSI Driver synchronizes secrets from external APIs and mounts them into containers as volumes. You still get to manage all your secrets in one central place, like hashicorp vault. Do NOT need to check secrets into git.

There are several other tools that helps us manage secrets in kubernetes. Like `Sealed Secrets` and `External Secrets Operator`.

The main advantage of using the Secret Store CSI Driver is that `You no longer store credentials in kubernetes secrets`. Usually, we you use ESO or Sealed Secrets, what is gonna happen is that you gonna grab your secret from an external secret store and you are going to sync it into a kubernetes secret. But here you don't actually create a kubernetes secret. Just polling dynamically from your central secret store.

**What is the benefit of not creating a native k8s secret?!**
- Minimize attack surface as mush as possible. One less place where we store our secret. Only in our secret manager.
- Great from a compliance and regulatory perspective. One less platform that has to adhere to the compliance and regulatory bindings. And one less platform that we have to audit.

STOPPED at 05:25 @https://youtu.be/MTnQW9MxnRI?si=_6QVadgUa1vrPgaA&t=325

## Multi-Container Pods
Multi-container pods share the same life cycle. They are always scheduled on the same node. They are always started together and stopped together. They share the same network space which means they can refer to each other using localhost. And they have access to the very same storage volume. This way you don't have to establish volume sharing or services between the pods.

```yaml title="multi-container-pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: container-one
    image: ziadh/container-one
    ports:
    - containerPort: 80
  - name: log-agent-container
    image: ziadh/log-agent-container
    command: ["log-agent", "serve"]
```

:::tip Multi-container Pods Design Patterns
There are 3 common patterns when it comes to designing multi-container PODs. The first, and what we just saw with the logging service example, is known as a `sidecar pattern`. The others are the `adapter` and the `ambassador` pattern.

However, these fall under the `CKAD curriculum` and are not required for the CKA exam. So, we will discuss these in more detail in the `CKAD course`.
:::

## Init Containers
In a multi-container pod, each container is expected to run a process that stays alive as long as the POD's lifecycle.

For example in the multi-container pod that we talked about earlier that has a web application and logging agent, both the containers are expected to stay alive at all times.

The process running in the log agent container is expected to stay alive as long as the web application is running. If any of them fail, the POD restarts.

But at times you may want to run a process that runs to completion in a container. For example, a process that pulls a code or binary from a repository that will be used by the main web application.

That is a task that will be run only one time when the pod is first created. Or a process that waits for an external service or database to be up before the actual application starts.

That's where **initContainers** comes in. An **initContainer** is configured in a pod-like all other containers, except that it is specified inside a **initContainers** section, like this:

```yaml title="init-container-pod-definition.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox:1.28
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: busybox
    command: ['sh', '-c', 'git clone  ;']
```

When a POD is first created the initContainer is run, and the process in the initContainer must run to a completion `before the real container hosting the application starts`.

You can configure multiple such initContainers as well, like how we did for multi-containers pod. In that case, each init container is run **one at a time in sequential order**.

If any of the initContainers fail to complete, Kubernetes restarts the Pod repeatedly until the Init Container succeeds.

```yaml title="init-container-pod-definition.yaml"
apiVersion: v1 
kind: Pod 
metadata: 
  name: myapp-pod 
  labels: 
    app: myapp 
spec: 
  containers:
  - name: myapp-container 
    image: busybox:1.28 
    command: ['sh', '-c', 'echo The app is running! && sleep 3600'] 
  initContainers:
  - name: init-myservice 
    image: busybox:1.28 
    command: ['sh', '-c', 'until nslookup myservice; do echo waiting for myservice; sleep 2; done;']
  - name: init-mydb 
    image: busybox:1.28 
    command: ['sh', '-c', 'until nslookup mydb; do echo waiting for mydb; sleep 2; done;']
```

Read more about initContainers [here](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/).


## Self Healing Applications
Kubernetes supports self-healing applications through ReplicaSets and Replication Controllers. The replication controller helps ensure that a POD is re-created automatically when the application within the POD crashes. It helps in ensuring enough replicas of the application are running at all times.

Kubernetes provides additional support to check the health of applications running within PODs and take necessary actions through `Liveness and Readiness Probes`. However, these are not required for the CKA exam and as such, they are not covered here. These are topics for the Certified Kubernetes Application Developers (`CKAD`) exam and are covered in the `CKAD` course.





