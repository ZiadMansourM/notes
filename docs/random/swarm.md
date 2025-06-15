---
sidebar_position: 10
title: Docker Swarm
description: "Deep Dive into Docker Swarm"
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

## Script
```bash title="show_ips.sh"
#!/bin/bash

# Run the `ip addr show` command and parse its output
ip addr show | awk '
    # Function to print the table header
    BEGIN {
        printf "%-10s %-20s %-30s\n", "Interface", "IPv4 Address", "IPv6 Address";
        printf "%-10s %-20s %-30s\n", "---------", "------------", "------------";
    }
    
    # Match interface line (e.g., 2: ens160: <...>)
    /^[0-9]+: / {
        if (iface) {
            # Print the collected information for the previous interface
            printf "%-10s %-20s %-30s\n", iface, ipv4, ipv6;
        }
        iface = $2;
        sub(/:/, "", iface);  # Remove trailing colon from the interface name
        ipv4 = "N/A";
        ipv6 = "N/A";
    }
    
    # Match IPv4 address line (e.g., inet 10.0.9.45/24 ...)
    $1 == "inet" {
        ipv4 = $2;
    }
    
    # Match IPv6 address line (e.g., inet6 fe80::250:56ff:feb0:95da/64 ...)
    $1 == "inet6" {
        ipv6 = $2;
    }
    
    # Print the last interface details after processing all lines
    END {
        if (iface) {
            printf "%-10s %-20s %-30s\n", iface, ipv4, ipv6;
        }
    }
'
```

## Docker Components
- Docker Daemon: bg process that manages images, containers, networks, and volumes.
- Docker CLI: Interface for interacting with Docker Daemon. Uses REST API to interact with the daemon.
- REST API: Interface for interacting with Docker Daemon.

:::note
Docker CLI need not necessarily be on the same host as the Docker Engine, it could be on another system.

```bash
docker -H=remote-docker-host:2375 ps

docker -H=10.123.2.1:2375 run nginx
```
:::

## Docker Under the Hood
Docker uses namespaces to isolate workspace, processIDs, network, inter-process communication, mounts, and unix time-sharing systems are created in their own namespace. There by providing isolation between containers.

## Namespace Isolation
One of the Namespace isolation techniques: PID Namespaces. When ever a linux system boots up, it starts with just one process with a process ID of 1.

This is the root process and kicks off all the other processes in the system. Note that process IDs are unique and two processes cannot have the same process ID.

If we were to create a container, which is basically a child system within the host system, the child system needs to think that it is an independent system on its own. And it has its own set of processes, originated from a root process with a process ID of 1.

There is no hard isolation between the host and the container, so the process running inside the container, are in fact processes running on the host system. Two processes can not have the same process ID, This is where namespaces come into play.

With ***Process ID Namespaces***, each process can have multiple process IDs associated with it. E.g. when a process start in the container. It is just another set of processes on the host system, but it is isolated from the host system.

### Demo
```bash
docker run -d --rm -p 8888:8888 tomcat:8.0

# Check 127.0.0.1:8888

docker exec -it <container-id> ps -eaf

ps -eaf | grep docker-java-home
```


## Control Groups
We learned that the underlying Docker Host, as well as the containers, share the same system resources such as CPU and Memory. How much of the resources are dedicated to the host and the containers and how does docker manages and share the resources between containers?

By default, there is no restriction as to how much of a resource a container can use. Hence, a container may end up utilizing all the resources on the host system, leaving no resources for the host system or other containers.

Docker uses Control Groups (cgroups) to manage and restrict the resource usage of containers. Control Groups are a Linux kernel feature that limits, accounts for, and isolates the resource usage of a collection of processes.

```bash
# .5 CPU means 50% of the CPU
docker run -d --cpus=".5" ubuntu

# 512MB of memory
docker run -d --memory="512m" ubuntu
```

## Storage and File Systems
Docker storage driver and file systems. First how Docker stores data on the local file system ?! When you install Docker on a system. it creates this folder structure `/var/lib/docker`. Under it you have multiple folders called `aufs`, `containers`, `image`, `volumes`, etc.

This is where Docker stores all its data by default. Data here means: files related to images and containers running on the Host. E.g. all files related to containers are stored in the `containers` folder. And all files related to images are stored in the `images` folder.

***Docker Layered Architecture***: When docker builds images, it builds these in a layered architecture. Each line of instruction in the Docker file creates a new layer in the Docker image with just the changes from the previous layer.

```Dockerfile
FROM ubuntu:latest

RUN apt-get update && apt-get install -y python

RUN pip install flask flask-mysql

COPY . /opt/source-code

ENTRYPOINT FLASK_APP=/opt/source-code/app.py flask run
```

```bash
docker build Dockerfile -t my-flask-app
```

***What are the advantages of this layered architecture?*** Let's consider a different application that has a different Dockerfile.

<Tabs>

<TabItem value="Image One">

```Dockerfile
FROM ubuntu:latest

RUN apt-get update && apt-get install -y python

RUN pip install flask flask-mysql

COPY . /opt/source-code

ENTRYPOINT FLASK_APP=/opt/source-code/app.py flask run
```

</TabItem>

<TabItem value="Image Two">

```Dockerfile
FROM ubuntu:latest

RUN apt-get update && apt-get install -y python

RUN pip install flask flask-mysql

COPY app2.py /opt/source-code

ENTRYPOINT FLASK_APP=/opt/source-code/app2.py flask run
```

</TabItem>

</Tabs>

The first three layers of both images are the same. This way docker build images faster, and efficiently saves disk space. They are read only layers. When you run a container based of this image using `docker run`, a read-write layer is added on top of the read-only layers.

:::note
The live of this read-write layer is the life of the container. When the container is deleted, the read-write layer is also deleted. This is why when you delete a container, all the data in the container is lost.
:::

Copy on Write: When you make changes to a file in the container, Docker doesn't actually change the file in the read-only-layers. Instead, it creates a new file in the read-write layer and writes the changes to this new file. This is called ***Copy on Write***.

### Persistent Volumes
Volumes are used to persist data generated by and used by Docker containers. When you create a volume, Docker creates a directory on the host system, typically under `/var/lib/docker/volumes`. 

When you run `docker volume create data_volume`, Docker creates a directory called `data_volume` under `/var/lib/docker/volumes`. You can then mount this volume to a container read-write-layer using the `-v` flag. 

***Bind Mounting is different from Volume Mounting***. There are two types of mounts:
- Bind Mount: mounts a directory from any location on the host system.
- Volume Mount: mounts a volume from the volumes directory.


:::note
Using the -v is an old style. The new way is to use the --mount flag. It is the preferred approach as you have to specify each paramter in a key equals value format.

```bash
docker run -v data_volume:/var/lib/mysql mysql
docker run -v /data/mysql:/var/lib/mysql mysql
```

```bash
docker run --mount type=bind,source=/data/mysql,target=/var/lib/mysql mysql
docker run --mount type=volume,source=data_volume,target=/var/lib/mysql mysql
```
:::


**Who is responsible for doing all these operations?** Maintaining the layered architecture, creating a writable layer, moving files across layers to enable copy on write, ... etc. It is the storage drivers.

Docker uses storage drivers to enable layered architecture. Some of the common storage drivers are: `aufs`, `overlay2`, `btrfs`, `zfs`, `overlay`, `devicemapper`.

The selection of a storage driver depends on the underlying OS being used. E.g. with Ubuntu the default storage driver is `aufs`. Where as this storage driver is not available on CentOS, or Fedora. The default storage driver on CentOS and Fedora is `devicemapper`.

Docker will automatically select the storage driver based on the underlying OS. The different storage drivers have different capabilities and performance characteristics.

### Demo
```bash
ls -l /var/lib/docker

docker info  

docker pull hello-world
docker ls -la /var/lib/docker/aufs/diff
# Check the layer of the image then ls it to see the files in it

# Will show you the list of steps followed to create the image
docker history hello-world

# Instead of running the container, you can run the script directly
```
 
## Swarm

```bash
# Run on Master
docker swarm init --advertise-addr <ip-address>

# On Worker
docker swarm join --token <token> # <ip-address>:2377
```

> Multi-Leader Setup: RAFT COnsensus Algorithm


> Quorum: Minimum number of majority required to make a decision.

> Docker Recommends No more than 7 nodes in a swarm.

Manager | Majority (quorum) 
:--: | :--:
1 | 1
2 | 2
3 | 2
4 | 3
5 | 3
6 | 4
7 | 4

> By default, all manager nodes are also worker nodes. `docker node update --availability drain <node-name>`.



### Demo
```bash
# On Master Node
docker swarm init --advertise-addr <ip-address>
# Will Output: docker swarm join --token <token> <ip-address>:2377
# To add a manager: docker swarm join-token manager
# To add a worker: docker swarm join-token worker

docker node ls

# On worker nodes
docker swarm leave

# Then on Master:
docker node rm <node-name>
docker node promote <node-name>

# Force recreate the cluster cuz the quorum is lost
docker swarm init --force-new-cluster
```

## Swarm Orchestration
```bash
# On Manager Node
docker service create --replicas 3 my-web-server

# The orchestrator: on manger node decides how many tasks to create.
# The scheduler: Use that many tasks on each worker node.
# The Task: is a process on the worker nodes that kicks off the actual container
#           instances. Has a one to one relationship with each container. Responsible
#           for updating the state of the container to manager node.

docker service create --mode global my-monitoring-agent

# Types of services:
# Replicated: Created with the `--replicas` flag. 
# Global: `--mode global` flag. One task per node in the swarm. E.g. monitoring agents.
#         Or a log collection agent.

# Service Naming: <service-name>.<replica-id>.<task-id>.<swarm-id>.<domain>
docker service create --name my-web-server --replicas 3 nginx
docker service update --replicas 5 my-web-server
```

### Demo
```bash
docker service --help

docker service update my-web-server --publish-add 5000:80

docker service rm my-web-server

# To Not Host any container on a specific node
docker node update --availability drain <node-name>
```

## Advanced Networking
```bash
# Docker has three types of networks: "bridge (Default)", "host", "none"
#   - Bridge: Private Internal Network. Usually "172.17.0.0/16".
#   - Host: No isolation between the container and the host.
#   - None: No networking.
# Overlay Networks in Docker Swarm
# Ingress Network.

docker network create --driver overlay --subnet 10.0.9.0/24 my-overlay-network
docker service create --replicas 3 --network my-overlay-network nginx

# When you create a docker swarm it automatically creates an ingress Network.
# The Ingress Network has a built in load balancer that direct traffic from the
# Published Port to all mapped ports e.g. 5000 on each container.
```

## DNS in Swarm
```bash
# The built in DNS server can be accessed at 127.0.0.11
```

## Docker Stacks
```yaml title="compose.yml"
services:
    web:
        image: nginx
        ports:
        - 80:80
    db:
        image: postgres
```

```bash
docker stack deploy --compose-file compose.yml my-stack
```

```yaml
services:
    redis:
        image: redis
        deploy:
            replicas: 1
            resources:
                limits:
                    cpus: 0.01
                    memory: 50M
    db:
        image: postgres:16
        deploy:
            replicas: 1
            placement:
                constraints:
                - node.hostname == node1
                - node.role == manager
    vote:
        image: voting-app
        deploy:
            replicas: 2
    result:
        image: result
        deploy:
            replicas: 1
    worker:
        image: worker
        deploy:
            replicas: 3        
```