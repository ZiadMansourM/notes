---
sidebar_position: 1
title: Prerequisites
description: Quick Review of the Prerequisites Concepts
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

## Yaml

YAML is a human-readable data serialization standard that can be used in conjunction with all programming languages and is often used to write configuration files.

### Anchors & Aliases

The below `docker-compose.yml` file is using `Anchors` and `Aliases` to reduce the duplication of the code. It was aimed to create one master server and six worker servers. Three of them are using `ubuntu` and the other three are using `centos` as their base image. To test and Ansible.

<details>
<summary>click me</summary>

To see Dockerfiles:

```Dockerfile title="Dockerfile.master"
FROM ubuntu:22.04

RUN apt update && \
    apt -y upgrade && \
    apt -y dist-upgrade && \
    apt -y install iputils-ping && \
    apt -y install openssh-client && \
    apt -y install ansible && \
    echo 'root:root' | chpasswd && \
    mkdir -p /root/.ssh

RUN echo "Host *" >> /root/.ssh/config && \
    echo "    IdentityFile /root/.ssh/root" >> /root/.ssh/config && \
    echo "    User root" >> /root/.ssh/config && \
    chmod 600 /root/.ssh/config

COPY ./secrets/master_keys/ /root/.ssh/
COPY ./secrets/ansible_keys/ /root/.ssh/

RUN mkdir -p ~/src

COPY ./scripts/init_master.bash /tmp/init.bash
RUN chmod +x /tmp/init.bash

WORKDIR /root/src/

ENTRYPOINT [ "/tmp/init.bash" ]
```

```Dockerfile title="Dockerfile.worker.ubuntu"
FROM ubuntu:22.04

RUN apt update && \
    apt -y upgrade && \
    apt -y dist-upgrade && \
    apt -y install python3-apt && \
    apt -y install openssh-server && \
    apt -y install sudo && \
    rm -rf /var/lib/apt/lists/* && \
    echo 'root:root' | chpasswd && \
    mkdir -p /root/.ssh && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime

COPY ./secrets/master_keys/root.pub /tmp/root.pub
RUN cat /tmp/root.pub >> /root/.ssh/authorized_keys && \
    rm /tmp/root.pub

COPY ./scripts/init_ubuntu_worker.bash /tmp/init.bash
RUN chmod +x /tmp/init.bash

ENTRYPOINT [ "/tmp/init.bash" ]
```

```Dockerfile title="Dockerfile.worker.centos"
FROM centos:8

RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
    dnf -y update && \
    dnf -y upgrade && \
    dnf -y install openssh-server && \
    dnf -y install sudo && \
    groupadd sudo && \
    echo 'root:root' | chpasswd && \
    mkdir -p /root/.ssh && chmod 700 /root/.ssh && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime && \
    ssh-keygen -q -N '' -t rsa -f /etc/ssh/ssh_host_rsa_key && \
    ssh-keygen -q -N '' -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key && \
    ssh-keygen -q -N '' -t ed25519 -f /etc/ssh/ssh_host_ed25519_key && \
    rm /var/run/nologin

COPY ./secrets/master_keys/root.pub /tmp/root.pub
RUN cat /tmp/root.pub >> /root/.ssh/authorized_keys && \
    rm /tmp/root.pub

COPY ./scripts/init_centos_worker.bash /tmp/init.bash
RUN chmod +x /tmp/init.bash

ENTRYPOINT [ "/tmp/init.bash" ]
```

</details>

<Tabs>

<TabItem value="After">

```yaml showLineNumbers
version: '3.8'

x-defaults: &default-config
  restart: always
  stdin_open: true
  tty: true
  networks:
    - servers-network

x-worker: &worker
  build:
    context: ./images
    dockerfile: Dockerfile.worker.${WORKER_OS}
  image: ziadmmh/${WORKER_NAME}:v0.0.1
  container_name: ${WORKER_NAME}
  hostname: ${WORKER_NAME}
  ports:
  - "800${WORKER_NUMBER}:80"
  <<: *default-config

services:
  srvmaster:
    build:
      context: ./images
      dockerfile: Dockerfile.master
    <<: *default-config
    image: ziadmmh/srvmaster:v0.0.1
    container_name: srvmaster
    hostname: srvmaster
    volumes:
      - ./volumes:/root/src
    depends_on:
      - srvone
      - srvtwo
      - srvthree
      - srvfour
      - srvfive
      - srvsix
  srvone:
    <<: *worker
    environment: [WORKER_OS=ubuntu, WORKER_NAME=srvone, WORKER_NUMBER=1]
  srvtwo:
    <<: *worker
    environment: [WORKER_OS=centos, WORKER_NAME=srvtwo, WORKER_NUMBER=2]
  srvthree:
    <<: *worker
    environment: [WORKER_OS=ubuntu, WORKER_NAME=srvthree, WORKER_NUMBER=3]
  srvfour:
    <<: *worker
    environment: [WORKER_OS=centos, WORKER_NAME=srvfour, WORKER_NUMBER=4]
  srvfive:
    <<: *worker
    environment: [WORKER_OS=ubuntu, WORKER_NAME=srvfive, WORKER_NUMBER=5]
  srvsix:
    <<: *worker
    environment: [WORKER_OS=centos, WORKER_NAME=srvsix, WORKER_NUMBER=6]

networks:
  servers-network:
    name: servers-network

```

</TabItem>

<TabItem value="Before">

```yaml showLineNumbers
version: '3.8'

services:
  srvmaster:
    build:
      context: ./images
      dockerfile: Dockerfile.master
    restart: always
    stdin_open: true
    tty: true
    networks:
      - servers-network
    image: ziadmmh/srvmaster:v0.0.1
    container_name: srvmaster
    hostname: srvmaster
    volumes:
      - ./volumes:/root/src
    depends_on:
      - srvone
      - srvtwo
      - srvthree
      - srvfour
      - srvfive
      - srvsix
  srvone:
    build:
      context: ./images
      dockerfile: Dockerfile.worker.ubuntu
    restart: always
    stdin_open: true
    tty: true
    networks:
      - servers-network
    image: ziadmmh/srvone:v0.0.1
    container_name: srvone
    hostname: srvone
    ports:
      - "8001:80"
  srvtwo:
    build:
      context: ./images
      dockerfile: Dockerfile.worker.centos
    restart: always
    stdin_open: true
    tty: true
    networks:
      - servers-network
    image: ziadmmh/srvtwo:v0.0.1
    container_name: srvtwo
    hostname: srvtwo
    ports:
      - "8002:80"
  srvthree:
    build:
      context: ./images
      dockerfile: Dockerfile.worker.ubuntu
    restart: always
    stdin_open: true
    tty: true
    networks:
      - servers-network
    image: ziadmmh/srvthree:v0.0.1
    container_name: srvthree
    hostname: srvthree
    ports:
      - "8003:80"
  srvfour:
    build:
      context: ./images
      dockerfile: Dockerfile.worker.centos
    restart: always
    stdin_open: true
    tty: true
    networks:
      - servers-network
    image: ziadmmh/srvfour:v0.0.1
    container_name: srvfour
    hostname: srvfour
    ports:
      - "8004:80"
  srvfive:
    build:
      context: ./images
      dockerfile: Dockerfile.worker.ubuntu
    restart: always
    stdin_open: true
    tty: true
    networks:
      - servers-network
    image: ziadmmh/srvfive:v0.0.1
    container_name: srvfive
    hostname: srvfive
    ports:
      - "8005:80"
  srvsix:
    build:
      context: ./images
      dockerfile: Dockerfile.worker.centos
    restart: always
    stdin_open: true
    tty: true
    networks:
      - servers-network
    image: ziadmmh/srvsix:v0.0.1
    container_name: srvsix
    hostname: srvsix
    ports:
      - "8006:80"
    
networks:
  servers-network:
    name: servers-network

```

</TabItem>

</Tabs>