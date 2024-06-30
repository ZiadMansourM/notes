---
sidebar_position: 3
title: HashiCorp Vault
description: "Deep dive into HashiCorp Vault."
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

In this section we will discuss the content of `Vault Associate Certification` exam. 

Here is the course [repo](https://github.com/btkrausen/hashicorp).

## Exam
![Vault Associate Exam Details](./assets/vault/imgs/vault-associate-exam.png)

## Exam Objectives
![Vault Associate Exam Objectives](./assets/vault/imgs/vault-associate-exam-objectives.png)


## Introduction to Vault
![What is Vault](./assets/vault/imgs/what-is-vault.png)

## Benefits of Vault
![Benefits of Vault](./assets/vault/imgs/benefits-of-vault.png)


## Vault Components
- Storage Backends
    - Consul
- Secrets Engines
    - Store.
    - Generate.
    - Encrypt.
- Authentication Methods
- Audit Devices

### Storage Backends
![Storage Backends](./assets/vault/imgs/storage-backends.png)

### Secrets Engines
![Secrets Engines](./assets/vault/imgs/secrets-engines.png)

### Authentication Methods
![Authentication Methods](./assets/vault/imgs/authentication-methods.png)

### Audit Devices
![Audit Devices](./assets/vault/imgs/audit-devices.png)

## Vault Architecture
![Vault Architecture](./assets/vault/imgs/vault-architecture.png)

## Vault Paths
![Vault Paths](./assets/vault/imgs/vault-paths.png)

<hr/>

![Vault Paths](./assets/vault/imgs/vault-paths-2.png)

## Vault Data Protection
![Vault Data Protection](./assets/vault/imgs/vault-data-protection.png)

<hr/>

![Vault Data Protection](./assets/vault/imgs/vault-data-protection-2.png)


## Seal and Unseal
![Seal and Unseal](./assets/vault/imgs/seal-and-unseal.png)

<hr/>

![Seal and Unseal](./assets/vault/imgs/seal-and-unseal-2.png)

<hr/>

![Seal and Unseal](./assets/vault/imgs/seal-and-unseal-3.png)


### Unsealing with Key Shards (Shamir's Secret Sharing Algorithm)
![Unsealing with Key Shards](./assets/vault/imgs/unsealing-with-key-shards.png)

<hr/>

Pick five trusted employees and give them a key shard. To unseal vault, you need at least three key shards.

```bash
vault status
# Shamir
# Sealed True
```

![Unsealing with Key Shards](./assets/vault/imgs/unsealing-with-key-shards-2.png)


## Vault Unseal Process
```bash
vault status

vault operator init
```

## Vault Auto Unseal
![Vault Auto Unseal](./assets/vault/imgs/vault-auto-unseal.png)

<hr/>

![Vault Auto Unseal](./assets/vault/imgs/vault-auto-unseal-2.png)

## Vault Transit Auto Unseal
![Vault Transit Auto Unseal](./assets/vault/imgs/vault-transit-auto-unseal.png)

<hr/>

![Vault Transit Auto Unseal](./assets/vault/imgs/vault-transit-auto-unseal-2.png)

<hr/>

![Vault Transit Auto Unseal](./assets/vault/imgs/vault-transit-auto-unseal-3.png)

## Vault Initialization

![Vault Initialization](./assets/vault/imgs/vault-initialization.png)

## Vault Configuration File
![Vault Configuration File](./assets/vault/imgs/vault-configuration-file.png)

<hr/>

![Vault Configuration File](./assets/vault/imgs/vault-configuration-file-2.png)

<hr/>

You will typically have multiple stanzas and global level parameters.

```hcl
listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_disable = "true"
}
seal "awskms" {
    region = "us-west-2"
    kms_key_id = "<kms_key>"
}
api_addr = "https://IP_ADDRESS:8200"
ui = true
cluster_name = "vault-cluster"
```

## Available Stanzas
- Seal: seal type.
- Listener (Required): addresses, ports for Vault.
- Storage: backend storage.
- Telemetry: Where to publish metrics to upstream systems.

## Diagnose
```bash
vault operator diagnose - config=/etc/vault.d/vault.hcl
```

## Storage Backends
![Storage Backends](./assets/vault/imgs/storage-backends.png)

So support HA and some do not.

![Storage Backends Types](./assets/vault/imgs/storage-backends-types.png)

<hr/>

![Storage Backends Types](./assets/vault/imgs/storage-backends-types-2.png)

## Choosing a Storage Backend
![Choosing a Storage Backend](./assets/vault/imgs/choosing-a-storage-backend.png)
