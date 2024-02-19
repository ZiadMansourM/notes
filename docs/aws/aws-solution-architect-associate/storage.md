---
sidebar_position: 3
title: Storage Services
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

## Pre-requisites
- [ ] Understand file systems types.
:::note File Systems
- **Windows File System** - FAT, NTFS, exFAT
- **macOS** - HFS, APFS, HFS+
- **Linux** - EXT2/3/4, XFS, JFS, Btrfs
:::


## Elastic Block Store (EBS)
- Breaks data into blocks and stores them across a number of physical devices. Each with a unique identifier.
- A collection of blocks can be presented to an operating system as a `volume`.
- Create a `file system` on top of this volume.
- We can also present them as a `hard drive` to the operating system. Which allow us to install an operating system on it. And make it `bootable`.
- **Summary**: Block storage are both `mountable` and `bootable`.

![block storage](./assets/storage/block-storage.png)

:::warning Multi-Attach
- Certain EBS volumes can be attached to multiple EC2 instances. This is called `multi-attach`.
- Your application must be intelligent enough to have multiple instances write to the same data at the same time. **Data Corruption alert**.
- Database Cluster is a good example of multi-attach. Master node writes to the volume and the slave node reads from it.
:::

:::note EBS Resilience
- EBS volumes are `replicated` within the same availability zone.
- Both EC2 and EBS needs to be in the `same availability zone`.
:::


### EBS multi-az replication
We have an EBS volume in `us-east-1a` and we want to move it to `us-east-1b`. We can do this by taking a `snapshot` of the volume and then deploy an EBS volume in `us-east-1b`. Snapshots are stored in `S3` and are `region specific`.

![multi-az-replication](./assets/storage/multi-az-replication.png)

### EBS multi-region replication
- Copy snapshots from one region to another.

![multi-region-replication](./assets/storage/multi-region-replication.png)



### Volume Types

![volume-types](./assets/storage/volume-types.png)

- **General Purpose SSD**: 
    - (gp2): General purpose, balances price and performance. `Default` volume type.
    - (gp3): General purpose, balances price and performance. Higher performance and lower cost `20%`.
- **Provisioned IOPS SSD**:
    - Highest performance SSD volume for mission-critical low-latency or high-throughput workloads.
    - (io2):
    - (io2) - Block Express: 
    - (io1): 
- **Throughput Optimized HDD** and **Cold HDD**:
    - They have hard disk drives.
    - Throughput optimized HDD: Low cost, frequently accessed throughput-intensive workloads.
    - Cold HDD: Lowest cost, infrequently accessed workloads.
- **Magnetic**:
    - Previous generation. Packed by magnetic drives. Suitable for workloads where data is accessed infrequently.
    

![volume-types-summary](./assets/storage/volume-types-summary.png)

![hdd-volumes-summary](./assets/storage/hdd-volumes-summary.png)

![magnetic-volumes](./assets/storage/magnetic-volumes.png)


### EBS demo
:::note Volume Devices Names
- `/dev/xvda` is the root volume.
- Newer Linux kernels may rename your devices to `/dev/xvdf`  through `/dev/xvdp` internally, even when the device name entered is `/dev/sdf` through `/dev/sdp`.
:::


```bash title="Attach EBS Volume"
lsblk
# [1]: Verify if the device volume has filesystem on it. "data" means no filesystem.
sudo file -s /dev/xvdf
sudo mkfs -t xfs /dev/xvdf
sudo file -s /dev/xvdf # Verify
# [2]: Mount the volume
sudo mkdir /mnt/data
sudo mount /dev/xvdf /mnt/data
# [3]: Verify if the volume is mounted
df -k
# [4]: Persist the volume. 
sudo blkid 
sudo vi /etc/fstab
sudo sh -c 'echo "UUID=4c16e25e-2203-432d-b4f7-0e3c9ce5238a /mnt/data xfs defaults,nofail" >> /etc/fstab'
sudo mount -a # but it's already mounted.

sudo sh -c 'echo "Hello World" > /mnt/data/hello.txt'
sudo umount /mnt/data
```

:::note 
- `/mnt`: Mount point for a temporarily mounted filesystem.
- `/media`: Mount point for removable media
:::

## Instance Store
`Temporary` block storage for EC2 instances. It is physically attached to the host computer. It is `ephemeral` and `non-persistent`.

:::warning EC2 Instance Store Support
- Not all EC2 instances support instance store volumes.
- Rebooting an instance will not delete the data on the instance store. But `stopping and starting` the instance will.
:::

## EFS (Elastic File System)
- First of two `file storage` services provided by AWS. `EFS` and `FSx`.
- Supports `NFSv4` protocol. 
- Does not work with windows based ec2 instances. Only Linux.
- You can mount EFS to multiple EC2 instances.
- `VPC Specific`. Visible through `Mount Targets`.
- Mount targets are `subnet specific`. Just an IP address.

![efs-fs](./assets/storage/efs-fs.png)

### EFS Storage Classes
1. **Standard Storage Class**: 
    - Multi-AZ resilience and the highest levels of durability and availability.
    - `EFS Standard`.
    - `EFS Standard-IA`.
2. **One Zone Storage Class**:
    - The choice of additional savings by choosing to save your data in a single availability zone.
    - `EFS One Zone`.
    - `EFS One Zone-IA`.

### EFS Performance Modes
Handle `Throughput`, `Latency` and `IOPS`. Needed for broad range of workloads.

1. **General Purpose Performance Mode**:
    - Latency-sensitive Applications:
        - e.g. web serving, content management, home directories, and general file serving.
2. **Elastic Throughput Mode**:
    - Automatically scale throughput performance up or down to meet the needs of your workload activities.
3. **Max I/O Performance Mode**:
    - Higher levels of aggregate throughput and operations per second.
4. **Provisioned Throughput Mode**:
    - Level of throughput the file system can drive independent of the file system's size or burst credit balance.
5. **Bursting Throughput Mode**:
    - Scales with the amount of storage in your file system and supports bursting to higher levels for up to 12 hours per day.

### Setup EFS on EC2
```bash title="Setup EFS on EC2"
# Install amazon-efs-utils
sudo dnf -y install amazon-efs-utils
sudo mount.efs efs:id /mnt/efs
```

## FSx (File Storage)
- Fully managed file system storage service that provides high performance file storage. wide range of workloads.

### With FSx
No need to worry about:
- Provisioning file servers and storage volumes.
- Replicating data.
- Patching file server.
- Addressing hardware failures.
- Performing manual backups.

### Benefits
- Storage.
- Managed.
- Scalable.
- Shared Access.
- Backup.

### FSx for Windows File Server
- Supports `Server Message Block (SMB)` protocol.
- You can easily integrate it with Microsoft Active Directory.
- It supports data deduplication.
- You can set quotas.

### FSx for Lustre
Optimized for high-performance parallel file processing. It is used for machine learning, high-performance computing.
- Provides low-latency, high-throughput access to data.
- Build on the Luster file system.
- Integrates seamlessly with other AWS services like S3, DataSync and AWS Batch.
- You can easily scale the file systems's capacity and throughput.

### FSx for NetApp ONTAP
- Offeres high-performance storage that is accessible from `linux`, `MacOS` and `Windows`. Via `NFS`, `SMB`, and `iSCSI` protocols.
- Can scale you r file system up or down in response to workload demands.
- Can perform: `Snapshots`, `Replication`, `Clones`, ...etc.

### FSx for OpenZFS
- Built on top of the open-source OpenZFS file system.
- Supports access from `Linux`, `MacOS`, and `Windows` via `NFS` protocol.
- Utilizes the power OpenZFS capabilities including `data compression`, `snapshots`, `clones`, ...etc.
- Built-in data protection and security features.

### Deployment Options
- FSx for Windows, ONTAP, and OpenZFS support:
    - `Single-AZ`.
    - `Multi-AZ`.
- FSx for Lustre supports:
    - `Single-AZ`.

### FSx Comparison
![fsx-comparison](./assets/storage/fsx-comparison.png)

