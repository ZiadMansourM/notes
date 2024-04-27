---
sidebar_position: 3
title: VPN
description: VPN Masterclass
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```


OpenVPN allows you to create secure `point-to-point` or `site-to-site` connections. We will use OpenVPN to connect to a private aws vpc.

1. Create openvpn profile manually.
2. Create a simple bash script to automate profile generation.
3. We will use the open source gate SSo project to use google SSO to automate client certificate and profile generation with an elastic IP. Name: `public`. Keep no preference for the AZ. We can place all the VMs in the same AZ "***To avoid data transfer charges***". ***Notice***: that we will intentionally create all the subnets with different CIDRs. TO show you how to configure the OpenVPN server to push routes to the clients. This one is `/22` will have 1,024 IP addresses.
4. Add a route table to that subnet with a default route to the Internet GW.

## Pre-requisites
First we need to create a VPC in AWS:
- Name: `main`.
- CIDR: `10.0.0.0/16`. That is 65,536 IP addresses.
- To create a public subnet we need to have an Internet GW: Name: `igw`. And attach it to the VPC.
- Create a public subnet: with a default route to the Internet GW. We will use that subnet to place our OpenVPN server.
- Allocate an Elastic IP for the NAT gateway. NAT GW will allow VMs in those subnets with private IP addresses only to reach the internet. Name: `nat`.
- Use this IP address and create a NAT gateway in the public subnet.
- Create a couple of private subnets for example: `private-large` and allocate `10.0.16.0/20` that is `4,096` IP addresses. And `private-small` with `10.0.32.0/24` that is `256` IP addresses.
- Create a private route table and associate it with the private subnets. Add a default route to the NAT GW.
- Allocate a static public IP address for our OpenVPN server. Name: `openvpn`.
- Create an EC2 instance `Ubuntu 20.04` and `t3.small` place the openvpn server in the ***public subnet***. And disable the auto-assign public IP address. Name: `openvpn`. Create a new security group `OpenVPN` that will be the only one instance in our infrastructure that will be open to any source to SSH. When we deploy our OpenVPN server we will use this security group as source for any other EC2 instances that we want to SSH. Add a `UDP` port note that you may want to use `tcp` in some situations. But `UDP` port `1194` is recommended. For `Gate SSO` we need to open `tcp` port `443` and `tcp` port `80` "***LATER*** tho".
- Create a new key-pair. New `ED25519` key. Name: `devops`.
- Assign the elastic IP to the OpenVPN server.
- `chmod 400 devops.pem`.
- `ssh -i devops.pem ubuntu@<public-ip>`.
```bash
sudo apt update
apt policy openvpn # Check the version

# Ref: https://github.com/OpenVPN/openvpn/releases/tag/v2.6.10
sudo -s
wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg|apt-key add -

# Add OpenVPN ubuntu repository, best practice to create a separate list
echo "deb http://build.openvpn.net/debian/openvpn/stable focal main" > /etc/apt/sources.list.d/openvpn-aptrepo.list
apt update
apt policy openvpn # Check the version

sudo apt install openvpn=2.5.3-focal0 -y

# We need a tool to manage PKi "east-rsa" is the default
apt policy easy-rsa
# Ref: https://github.com/OpenVPN/easy-rsa/releases/tag/v3.1.7
wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.7/EasyRSA-3.1.7.tgz
tar zxf EasyRSA-3.1.7.tgz
rm EasyRSA-3.1.7.tgz
sudo mv EasyRSA-3.1.7/ /etc/openvpn/easy-rsa
sudo ln -s /etc/openvpn/easy-rsa/easyrsa /usr/local/bin/
easyrsa --version

cd /etc/openvpn/easy-rsa
easyrsa init-pki

# We can create vars files to customize the certificates.
vi vars

# HUGE WARNING: nopass is not recommended for production environments.
# Common Name: OpenVPN CA
easyrsa build-ca nopass

ls /etc/openvpn/easy-rsa/pki
ls /etc/openvpn/easy-rsa/pki/private

# Generate certificate for the server and the client
# No Common Name
easyrsa gen-req openvpn-server nopass
easyrsa sign-req server openvpn-server # Confirm with yes
# Done: /etc/openvpn/easy-rsa/pki/issued/openvpn-server.crt

# Next step is to create another secret that is not related to PKI
# called ta.key
# It is like a crypto firewall, each packet going over the internet
# will be signed using a shared secret on both the server and the client.
# When OpenVPN receives a packet. It will calculate a signature and check it
# against the signature provided in the received packet. If it does not match
# OpenVPN will drop the packet. When coupled with UDP this can be a good way to
# avoid troubles with port scanners, as it will not see OpenVPN port at all.
# This feature is also a good way to protect yourself against unknown bugs in
# the SSl library or protocol, as it reduces the attack surface to only your
# own users. Enabling TLS authentication is HIGHLY recommended.
# This secret need to be securely copied to all OpenVPN clients. And Servers.
openvpn --genkey secret ta.key

sudo vi /etc/sysctl.conf # Enable IP forwarding `net.ipv4.ip_forward=1`
sudo sysctl -p

# Use server as a NAT to translate client IPs 
# to the OpenVPN server ip. That is the reason why we use the OpenVPN
# security group as the source for any instance in our VPC.
sudo iptables -t nat -S 

# Find the default network interface that is used by the server
ip route list default # ens5

# Create a NAT rule that will translate all the source IP coming from
# this range 10.8.0.0/24 to the OpenVPN server IP. This range is a 
# virtual network that we define later for VPN. All the clients and the
# OpenVPN server will get IP from this range. If you are using plain 
# iptables 
sudo iptables -t nat POSTROUTING -s 10.8.0.0/24 -o ens5 -j MASQUERADE

sudo apt-get install iptables-persistent -y

sudo vi /etc/openvpn/server/server.conf
```

```ini title="vars"
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "CA"
set_var EASYRSA_REQ_CITY       "San Jose"
set_var EASYRSA_REQ_ORG        "SREboy.com"
set_var EASYRSA_REQ_EMAIL      "me@sreboy.com"
set_var EASYRSA_REQ_OU         "Trial"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"

```

``` title="server.conf"
# Port for OpenVPN
port 1194
proto udp

# tun will create a layer 3 tunnel
dev tun # Possible values are: tun, tap

ca /etc/openvpn/easy-rsa/pki/ca.crt

cert /etc/openvpn/easy-rsa/pki/issued/openvpn-server.crt
key /etc/openvpn/easy-rsa/pki/private/openvpn-server.key

# Disable Diffie-Hellman
dh none

tls-crypt /etc/openvpn/easy-rsa/ta.key 0
cipher AES-256-GCM
auth SHA256
# That is how many clients you can connect to the server
server 10.8.0.0 255.255.255.0 

# Location to save records of clients <--> virtual IP address
ifconfig-pool-persist /var/log/openvpn/ipp.txt
# Ping like messages to be sent back and forth to check 
# the status of the connection
keepalive 10 120

# Used to reduce OpenVPN daemon privileges.
@ Otherwise OpenVPN server will fail to start.
user nobody
group nogroup

# Persist certain options that may no longer be available
# because of the privilege downgrade.
ngrade
persist-key
persist-tun

# Show current connections: used by Prometheus && Grafana
status /var/log/openvpn/openvpn-status.log

# Log verbosity
verb 3

# Notify the client when the server restarts so it can 
# reconnect automatically.
explicit-exit-notify 1

# Network topology
topology subnet

# Push route from AWS, 10.0.0.0/22
push "route 10.0.0.0 255.255.252.0"
# Push route from AWS, 10.0.16.0/20
push "route 10.0.16.0 255.255.240.0"
# Push route from AWS, 10.0.32.0/24
push "route 10.0.32.0 255.255.255.0"

# Push AWS name server since we want to use private
# hosted zones.
push "dhcp-option DNS 10.0.0.2" # Always VPC CIDR + 2
```

```bash
cat /etc/passwd | grep nobody
cat /etc/group | grep nogroup

sudo systemctl start openvpn-server@server
sudo systemctl status openvpn-server@server
sudo systemctl enable openvpn-server@server

journalctl --no-pager --full -u openvpn-server@server -f
```

### First Client
```bash
easyrsa gen-req example-1 nopass
# req: /etc/openvpn/easy-rsa/pki/reqs/example-1.req
# key: /etc/openvpn/easy-rsa/pki/private/example-1.key

easyrsa sign-req client example-1
# cert: /etc/openvpn/easy-rsa/pki/issued/example-1.crt
```

### Profile
Then install an openvpn client e.g. tunnelblick. Double click this file to import it.
```ovpn title="example-1.ovpn"
client
dev tun
proto udp
remote <public-ip> 1194 ; Of the OpenVPN server, or dns.
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3

; Mac and Windows: Ignore the next two blocks

; if linux client do NOT use systemd-resolved
; script-security 2
; up /etc/openvpn/update-resolv-conf
; down /etc/openvpn/update-resolv-conf

; if linux client do USE systemd-resolved
; script-security 2
; up /etc/openvpn/update-systemd-resolved
; down /etc/openvpn/update-systemd-resolved
; down-pre
; dhcp-option DOMAIN-ROUTE .


<ca>
; cat /etc/openvpn/easy-rsa/pki/ca.crt
</ca>

<cert>
; cat /etc/openvpn/easy-rsa/pki/issued/example-1.crt
</cert>

; private client key
<key>
; cat /etc/openvpn/easy-rsa/pki/private/example-1.key
</key>

; shared secret
<tls-crypt>
; cat /etc/openvpn/easy-rsa/ta.key
</tls-crypt>
```

```bash
brew install --cask tunnelblick

# Open the profile `example-1.ovpn` with tunnelblick

# Check the logs
journalctl --no-pager --full -u openvpn-server@server -f # On OpenVPN server

netstat -r
```

### Test Connection
Create another ec2 instance. Put it in `private-small`. For the security group add the security group of the OpenVPN server under source for ssh rule for example. 

Ports will be open to VPN clients only. Then use Private IP of the server to SSH into the instance. You need to be connected to the VPN to be able to SSH into the instance. 

### Route53
We will create a private route53 hosted zone. Give any name you would like `devops.pvt`. Select a `private hosted zone`. And select the VPC `main`.

Record Name | Type | Value
--- | --- | ---
test.devops.pvt | A | 10.10.10.10

```bash
# Make sure that the DNS server is the same as the VPC CIDR + 2
# Make sure that the VPC has DNS resolution enabled and DNS hostnames enabled.
# Wait for 5 or 10 minutes for the DNS to propagate.
dig test.devops.pvt
```

## Revoke access to the VPN
```bash
easyrsa revoke example-1

easyrsa gen-crl
# CRL file: /etc/openvpn/easy-rsa/pki/crl.pem

sudo vim /etc/openvpn/server/server.conf
```

```conf title="server.conf"
# Location of the revoked certificates
crl-verify /etc/openvpn/easy-rsa/pki/crl.pem
```

```bash
sudo systemctl restart openvpn-server@server

journalctl --no-pager --full -u openvpn-server@server -f
```

## Script

```bash
cd /etc/openvpn
sudo mkdir client-configs # To store profiles
cd client-configs

sudo vi base.ovpn
```

```ovpn title="base.ovpn"
client
dev tun
proto udp
remote  !public-ip-openvpn-server! 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3

; Mac and Windows: Ignore the next two blocks

; if linux client do NOT use systemd-resolved
; script-security 2
; up /etc/openvpn/update-resolv-conf
; down /etc/openvpn/update-resolv-conf

; if linux client do USE systemd-resolved
; script-security 2
; up /etc/openvpn/update-systemd-resolved
; down /etc/openvpn/update-systemd-resolved
; down-pre
; dhcp-option DOMAIN-ROUTE .
```

```bash
cd /etc/openvpn/easy-rsa

easyrsa gen-req example-2 nopass
# req: /etc/openvpn/easy-rsa/pki/reqs/example-2.req
# key: /etc/openvpn/easy-rsa/pki/private/example-2.key

easyrsa sign-req client example-2
# cert: /etc/openvpn/easy-rsa/pki/issued/example-2.crt

vi gen_client_profile.sh
```

```bash title="gen_client_profile.sh"
#!/bin/bash

KEY_DIR=/etc/openvpn/easy-rsa
OUTPUT_DIR=/etc/openvpn/client-configs
BASE_CONFIG=/etc/openvpn/client-configs/base.ovpn

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/pki/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/pki/issued/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/pki/private/${1}.key \
    <(echo -e '</key>\n<tls-crypt>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-crypt>') \
    > ${OUTPUT_DIR}/${1}.ovpn

```

```bash
sudo chmod +x gen_client_profile.sh
sudo ./gen_client_profile.sh example-2

# Copy it from the server to the client
cat /etc/openvpn/client-configs/example-2.ovpn
```

```bash
dig test.devops.pvt
```

## Gate SSO
1. Install docker on the OpenVPN server.
```bash
sudo apt install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


sudo apt update
sudo apt install \
  docker-ce docker-ce-cli containerd.io

sudo apt install docker-compose

vim docker-compose.yaml
```

```yaml title="docker-compose.yaml"
---
version: '3'
services:
  db:
    # For the Gate SSO we need mysql
    # Use RDS for production use.
    image: mysql:5.7
    volumes:
      - db_data:/var/lib/mysql
    ports:
    - 127.0.0.1:3306:3306
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root123
      MYSQL_DATABASE: openvpn
volumes:
  db_data: {}
```

```bash
sudo docker-compose up -d

sudo apt install mysql-client

mysql -u root -p -h 127.0.0.1 -P 3306

CREATE USER 'gate' IDENTIFIED BY 'devops123'; # Password is `devops123`
GRANT ALL PRIVILEGES ON gate_development.* TO 'gate';
GRANT ALL PRIVILEGES ON gate_test.* TO 'gate';
FLUSH PRIVILEGES;

# Gate SSO is a ruby on rails application
ruby -v

curl -L https://get.rvm.io | bash -s stable
curl -sSL https://rvm.io/mpapis.asc | gpg --import -
curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
curl -L https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install 2.4.3
gem install bundler

cd /opt
sudo git clone https://github.com/gate-sso/gate.git
sudo chown -R ubuntu:ubuntu gate
cd gate
sudo apt-get install libmysqlclient-dev
bundle install
sudo apt install nodejs

rake app:init
vi .env
```

```.env
GATE_SERVER_URL=http://gate.devopsbyexample.io ; Better use https, gate.devopsbyexample.io will point to the Public IP address of the OpenVPN server.

GATE_OAUTH_CLIENT_ID= ; Google OAuth client ID
; Create a GCP Project and navigate to API and services and `OAuth consent screen` edit OpenVPN app
; ref: https://youtu.be/yaXiAqH-4LE?si=a9f6rBeIap1RCt11&t=2684
```

Create a public DNS record for the gate:
Record Name | Type | Value
--- | --- | ---
gate.devopsbyexample.io | A | public-ip-openvpn-server


```bash
rake app:setup
```

Open Port 80 on the OpenVPN server.

:::note
Gate SSO will not generate your profiles. It will only invoke a couple of scripts.

```bash
# The first script if the client does not have a key-pair
sudo vi /etc/openvpn/easy-rsa/gen-client-keys
```

```bash title="gen-client-keys"
#!/bin/bash

set -e

if [[ $# -lt 1 ]]; then
  echo "$0 <user-name>"
  exit 1
fi

mkdir -p /etc/openvpn/keys/
mkdir -p /opt/vpnkeys/

touch /etc/openvpn/keys/$1.ovpn

cat > /etc/openvpn/keys/$1.ovpn <<EOF
client
dev tun
proto udp
remote <ip> 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3
tls-crypt ta.key
ca ca.crt
cert $1.crt
key $1.key
EOF

yes "" | easyrsa gen-req $1 nopass
yes "yes" | easyrsa sign-req client $1

cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/keys/
cp /etc/openvpn/easy-rsa/ta.key /etc/openvpn/keys/
cp /etc/openvpn/easy-rsa/pki/issued/$1.crt /etc/openvpn/keys/
cp /etc/openvpn/easy-rsa/pki/private/$1.key /etc/openvpn/keys/

cd /etc/openvpn/keys/ && tar zcf $1.tar.gz ca.crt $1.crt $1.key $1.ovpn ta.key
chmod 0600 $1.tar.gz

cp $1.tar.gz /opt/vpnkeys/
rm $1.*
```

```bash
# Will be run if you already have a private key, and you want to gen
# a new cert. E.g. it was expired.
sudo vi /etc/openvpn/easy-rsa/gen-client-conf
```

```bash title="gen-client-conf"
#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo "$0 <user-name>"
  exit 1
fi

mkdir -p /etc/openvpn/keys/
mkdir -p /opt/vpnkeys/

# Generate a new certificate since private key exists
yes "yes" | easyrsa sign-req client $1

cd /etc/openvpn/keys
cp /opt/vpnkeys/$1.tar.gz ./
tar -xf $1.tar.gz
rm $1.ovpn
touch $1.ovpn

cat > /etc/openvpn/keys/$1.ovpn <<EOF
client
dev tun
proto udp
remote <ip> 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3
tls-crypt ta.key
ca ca.crt
cert $1.crt
key $1.key
EOF

cp /etc/openvpn/easy-rsa/ta.key /etc/openvpn/keys/
cp /etc/openvpn/easy-rsa/pki/issued/$1.crt /etc/openvpn/keys/
cp /etc/openvpn/easy-rsa/pki/private/$1.key /etc/openvpn/keys/

tar zcf $1.tar.gz ca.crt $1.crt $1.key $1.ovpn ta.key
chmod 0600 $1.tar.gz

cp $1.tar.gz /opt/vpnkeys/
rm $1.*
```

```bash
rmvsudo rails server --port 80 --binding 0.0.0.0 --daemon
```
:::


## Summary
1. Create a VPC.
2. Create an Internet GW. And attach it to the VPC.
3. Create aws public subnet.
4. AWS NAT with an elastic IP. And place it in the public subnet.
5. AWS Private Subnets.
6. Create an EC2 instance. With Elastic IP. `t3.small` Ubuntu 20.04. SGL: OpenVPN 1194 Udp from anywhere.
7. Install OpenVPN on EC2 instance.
8. Install easy-rsa on the EC2 instance.
9. Create a PKi for the OpenVPN server.
10. Generate Certificate for OpenVPN Server.
11. Configure OpenVPN Cryptographic Material. `ta.key`.
12. Configure OpenVPN server.
13. Create Route53 Private Hosted Zone.
14. Install Ruby on Rails on Ubuntu 20.04. Then Install gate-sso.
15. Create SSO in gcp. And configure it in the `.env` file.
16. Create a public DNS record for the gate.

## Map
1. Setup Storage Class.
```yaml title="storage-class-aws-generic.yaml"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-generic-storage-class
parameters:
  type: gp2
  zone: us-east-1a
allowVolumeExpansion: true
provisioner: kubernetes.io/aws-ebs
reclaimPolicy: Retain
volumeBindingMode: Immediate
```
2. Create the `openvpn` namespace.
```yaml title="namespace-openvpn.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: openvpn
```
3. Create a Persistent Volume Claims.

The first PVC will be used to keep track of all the `certificate` data and `data in general` for the ***server***.

```yaml title="pvc-openvpn.yaml" {7}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    app: openvpn-server
  name: openvpn-server-pv-claim
  namespace: openvpn
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: aws-generic-storage-class
```

The next PVC is used to keep track of any of the ***configurations***.

```yaml title="openvpn-server-data.yaml" {7}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    app: openvpn-server
  name: openvpn-server-data-pv-claim
  namespace: openvpn
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: aws-generic-storage-class
```

:::warning
The PVCs must be provisioned prior to adding the deployment.
:::

4. Setup the Deployment for the OpenVPN Service.
This image is no longer supported by OpenVPN.

```yaml title="openvpn-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: openvpn-server
  name: openvpn-server
  namespace: openvpn
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: openvpn-server
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: openvpn-server
    spec:
      containers:
      - env:
        - name: PUID
          value: "1000"
        - name: PGID
          value: "1000"
        - name: TZ
          value: America/Chicago
        - name: INTERFACE
          value: eth0
        image: linuxserver/openvpn-as
        imagePullPolicy: IfNotPresent
        name: openvpn-server
        ports:
        - containerPort: 1194
          name: openvpn-server
          protocol: UDP
        - containerPort: 943
          name: port1
          protocol: TCP
        - containerPort: 9443
          name: port2
          protocol: TCP
        resources:
          limits:
            cpu: "1"
            memory: 800Mi
          requests:
            cpu: "1"
            memory: 800Mi
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
          privileged: true
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /etc/openvpn
          name: openvpn-data
        - mountPath: /config
          name: configs
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - emptyDir: {}
        name: openvpn-data
      - name: configs
        persistentVolumeClaim:
          claimName: openvpn-server-pv-claim
```

Now we should have our deployment connected to our PVCs.

5. Setup OpenVPN Services.
There are two main services to set up for the OpenVPN:
- GUI Service for the Web Console and Mobile.
- Server Service utilized for Connections.

```yaml title="openvpn-gui-service.yaml"
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: ambassador-service
  name: openvpn-gui-service
  namespace: openvpn
spec:
  ports:
  - name: http
    port: 443
    protocol: TCP
    targetPort: 943
  selector:
    app: openvpn-server
  sessionAffinity: None
  type: ClusterIP
```

```yaml title="openvpn-server-service.yaml"
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: ambassador-service
  name: openvpn-server-service
  namespace: openvpn
spec:
  ports:
  - name: server
    port: 9443
    protocol: TCP
    targetPort: 9443
  selector:
    app: openvpn-server
  sessionAffinity: None
  type: ClusterIP
```


## Extra

```bash
# Ref: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html
# Ref: https://stackoverflow.com/a/57971006
aws ec2 describe-instance-types --filters "Name=instance-type,Values=t3.*" --query "InstanceTypes[].{Type: InstanceType, MaxENI: NetworkInfo.MaximumNetworkInterfaces, IPv4addr: NetworkInfo.Ipv4AddressesPerInterface}" --output table --region eu-central-1 --profile terraform
```
