---
sidebar_position: 1
title: Enterprise
description: "PostgreSQL Enterprise offering?"
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

# Community vs Enterprise

In this section we will discuss the most popular **PostgreSQL Enterprise offerings** and compare them with the **Community PostgreSQL**.


## Pre-requisites
First, we need to understand that:
- [🔗](https://www.postgresql.org/about/press/faq/#:~:text=A%3A%20PostgreSQL%20is%20released%20under,use%20in%20commercial%20software%20products.) PostgreSQL itself is an open-source database, and it does not have an "enterprise license" per se.
- [🔗](https://www.postgresql.org/support/versioning/) The latest release of PostgreSQL is `16.3` as of today "2024-05-17".
    - PostgreSQL versioning has a two-part number scheme. The first number (e.g. 16) represents the major version, which is a new feature release. The second number represents a patch version, which is a bug / security fix release.
    - Major version releases happen roughly once-a-year around `September`.
    - Patch releases are scheduled once-a-quarter (`February`, `May`, `August`, `November`).

:::warning
Since version `10`, the project has adopted a two-part version numbering scheme. 

But, before that and because of the long history of postgresql the first two decimals are major releases. Thus 9.6, 9.5 etc. were all major releases. Minor releases have numbers like 9.6.6.
:::

## PostgreSQL Enterprise Offerings
There are several companies that offer enterprise-level support, services, and enhancements for PostgreSQL.

These companies typically provide `additional tools`, `features`, and `professional support`, which are often bundled under their own ***licensing terms***. Some of the key providers of enterprise-level PostgreSQL solutions include:
- [X] [EDB (EnterpriseDB):](https://www.enterprisedb.com/) EDB provides the EDB Postgres Platform, which includes enhanced versions of PostgreSQL, additional tools for management and monitoring, and enterprise-grade support.
- [X] [2ndQuadrant:](https://www.2ndquadrant.com/en/about-2ndquadrant/) 2ndQuadrant is now part of EDB. In September 2020 EDB acquired 2ndQuadrant, bringing together some of the world’s top PostgreSQL experts to create the largest dedicated Postgres global development team. The new unified roster of experts has a remarkable history of building and optimizing PostgreSQL for the most demanding international organizations. To learn more, read the [press release](https://www.enterprisedb.com/news/edb-completes-acquisition-2ndquadrant-becomes-largest-dedicated-provider-postgresql-products).
- [ ] [Crunchy Data:](https://www.crunchydata.com/) Crunchy Data provides enterprise support, cloud solutions, and additional tools for PostgreSQL, focusing on security and high availability.
- [ ] [Citus Data:](https://www.citusdata.com/) Acquired by Microsoft, Citus Data offers a `distributed` version of PostgreSQL for horizontal scaling, with enterprise support and services.
- [ ] [Postgres Professional](https://postgrespro.com/): They offer Postgres Pro Enterprise, a commercial fork of PostgreSQL with additional enhancements and features.


These companies provide various levels of support and additional features that are not part of the core PostgreSQL project but are valuable for ***SOME*** enterprise deployments over `Community PostgreSQL`.

We will do a detailed comparison of these offerings in the next sections. And then a detailed summary.

## EnterpriseDB (EDB):
The Biggest Contributor to PostgreSQL. EDB builds Postgres, alongside a vibrant, independent community. As the biggest contributor, with the most committers, nobody supports Postgres better than EDB. You have direct access to the experts shaping the direction of the technology.


EnterpriseDB (EDB) Products are categorized into two main categories:
- **Postgres Cloud**: Postgres Database as a Service.
    - BigAnimal.
    - (Soon) BigAnimal Performance Insights.
    - (Soon) BigAnimal Data Migration Service.
- **EDB Enterprise Advanced**: Commercial Software with Enterprise Support.
    - Postgres Advanced Server.
    - Postgres Distributed.
    - Postgres for Kubernetes.

With two subscription plans available [more here](https://www.enterprisedb.com/products/plans-comparison):
- ❌ EDB BigAnimal - Fully Managed Postgres in the Cloud.
- Self Managed Postgres Plans:
    - EDB Community 360.
    - EDB Standard.
    - EDB Enterprise.

| According To | Community 360 | Standard | Enterprise |
| :--: | :--: | :--: | :--: |
| Overview | Open-source-first strategy leveraging the power of Community PostgreSQL, managed by you. | Increase the Power of PostgreSQL with Enterprise Tooling when legacy database compatibility is not needed. | Legacy database migrations; Oracle compatibility; extending PostgreSQL with security and performance capabilities for enterprises. |
| Benefits | - Open source PostgreSQL. <br/>- CloudNativePG. <br/>- Open Source Tools | - ***Everything in Community 360 Plan***. <br/>- EDB Postgres Extended Server. <br/>- EDB Postgres for Kubernetes. <br/>- EDB Tools: High Availability, Migration, Monitoring, and Backup and Recovery. <br/>- Transparent Data Encryption (TDE) | - ***Everything in Community 360 and Standard***. <br/>- <mark>EDB Postgres Advanced Server</mark>. <br/>- Oracle Compatibility |
| Bundled Support Options | ***Production*** - 24x7 Support. <br/> ***Premium*** - 24x7 Support with Aggressive SLO | ***Basic*** - 10x5 for development and test environments. <br/>***Production*** - 24x7 Support. <br/>***Premium*** - 24x7 Support with Aggressive SLO | ***Basic*** - 10x5 for development and test environments, ***Production*** - 24x7 Support, ***Premium*** - 24x7 Support with Aggressive SLO 
Pricing | Pricing based on software, database cores and bundled support options. | Pricing based on software, database cores and bundled support options. | Pricing based on software, database cores and bundled support options. |
Recommended Add-Ons | - Remote DBA Services. <br/>- Monitor Only. | - EDB Postgres Distributed. <br/>- Remote DBA Services. | - EDB Postgres Distributed. <br/>- Remote DBA Services. |

### Questions
- What is:
    - [EDB Postgres Extended Server](https://www.enterprisedb.com/docs/pge/latest/).
    - [EDB Postgres Advanced Server](https://www.enterprisedb.com/docs/epas/latest/).
    - EDB Tools: High Availability, Migration, Monitoring, and Backup and Recovery.
    - Transparent Data Encryption (TDE).
    - Oracle Compatibility.

### Keywords Mentioned:
- Oracle database compatibility.
- Extend the power and security of PostgreSQL.
- With EDB Enterprise Plan, you get proven reliable Oracle compatibility without sacrificing performance and all the advantages of PostgreSQL with mission-critical features. Migrate your enterprise-grade applications with hybrid cloud deployment options.
- EDB Enterprise Plan gives you access to [EDB Postgres Advanced Server (EPAS)](https://www.enterprisedb.com/products/edb-postgres-advanced-server), which extends the functionality of open source PostgreSQL.

## Postgres Advanced Server
EPAS enhances the world's most loved database with all of the features enterprises need in a modern DBMS. EPAS gives you the most `secure`, `highly available` and `high performance` Postgres available on premises, in the cloud, and in hybrid environments.

Enterprises need a robust database solution to meet their demanding business goals and fulfill the promise of the cloud. EPAS is built for the enterprise. Simply, Postgres Made for the Enterprise.
- Enhanced Oracle Compatibility: EDB makes Postgres look, feel and operate more like Oracle, so when you migrate, your developers will have less code to rewrite and your DBAs can leverage their existing experience.
- Greater Control to Deploy Anywhere: Deploy `on-prem` or in the `cloud`. Choose `fully-managed`, like BigAnimal, or `cloud native` Kubernetes, `bare-metal` and VMs.
- Embedded Application Functionality: EPAS comes with over 200 pre-packaged utility functions. It works with existing tools so your developers can hit the ground running.

### EPAS Benefits:
- Save Time, Reduce Migration Risk: Gain expertise, increase flexibility and ease the move to Postgres with their enhanced [migration tools](https://www.enterprisedb.com/products/migration) and [industry-leading services](https://www.enterprisedb.com/services-support/professional-services) and support.
- The Most Secure Postgres, EPAS extends Postgres security with advanced features like:
    - [Transparent Data Encryption (TDE)](https://www.enterprisedb.com/docs/tde/latest/).
    - [Data Redaction](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/05_data_redaction/).
    - [Privilege Analysis](https://www.enterprisedb.com/docs/epas/latest/reference/oracle_compatibility_reference/epas_compat_bip_guide/03_built-in_packages/10_dbms_privilege_capture/).
    - [EDB Audit](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/05_edb_audit_logging/).
    - [User Profiles](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/).
    - [SQL/Protect](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/02_protecting_against_sql_injection_attacks/01_sql_protect_overview/) and many other security enhancements.
- Postgres that Performs, Supercharge Postgres with:
    - [Auto tuning](https://www.enterprisedb.com/docs/pg_extensions/pg_tuner/).
    - [Wait states](https://www.enterprisedb.com/docs/epas/latest/managing_performance/evaluating_wait_states/#edb-wait-states) for low-level performance analytics.
    - AWR-like [snapshot reports](https://www.enterprisedb.com/docs/epas/12/epas_compat_tools_guide/04_dynamic_runtime_instrumentation_tools_architecture_DRITA/) from EPAS.

### Transparent Data Encryption
Transparent data encryption (TDE) is an optional feature supported by EDB Postgres Advanced Server and EDB Postgres Extended Server from version 15.

It encrypts any user data stored in the database system. This encryption is transparent to the user. User data includes the actual data stored in tables and other objects as well as system catalog data such as the names of objects.

![alt text](https://www.enterprisedb.com/docs/static/5921573166ce686017b13caa5bb2c57d/00d43/tde1.png)

What's encrypted with TDE? TDE encrypts:
- The files underlying tables, sequences, indexes, including TOAST tables and system catalogs, and including all forks. These files are known as data files.
- The write-ahead log (WAL).
- Various temporary files that are used during query processing and database system operation.

:::warning Implications
- Any WAL fetched from a server using TDE, including by streaming replication and archiving, is encrypted.
- A physical replica is necessarily encrypted (or not encrypted) in the same way and using the same keys as its primary server.
- If a server uses TDE, a base backup is automatically encrypted.
:::

The following aren't encrypted or otherwise disguised by TDE:
- Metadata internal to operating the database system that doesn't contain user data, such as the transaction status (for example, `pg_subtrans` and `pg_xact`).
- The file names and file system structure in the data directory. That means that the overall size of the database system, the number of databases, the number of tables, their relative sizes, as well as file system metadata such as last access time are all visible without decryption.
- Data in foreign tables.
- The server diagnostics log.
- Configuration files.

:::waring Implications
Logical replication isn't affected by TDE. `Publisher` and `subscriber` can have different encryption settings. The payload of the logical replication protocol isn't encrypted. (You can use SSL.)
:::

### How does TDE affect performance?
The performance impact of TDE is low. For details, see the [Transparent Data Encryption Impacts on EDB Postgres Advanced Server 15](https://www.enterprisedb.com/blog/TDE-Postgres-Advanced-Server-15-Launch) blog.

### How does TDE work?
TDE prevents unauthorized viewing of data in operating system files on the database server and on backup storage. Data becomes unintelligible for unauthorized users if it's stolen or misplaced.

Data encryption and decryption is managed by the database and doesn't require application changes or updated client drivers.

EDB Postgres Advanced Server and EDB Postgres Extended Server provide hooks to key management that's external to the database. These hooks allow for simple passphrase encrypt/decrypt or integration with enterprise key management solutions. See [Securing the data encryption key](https://www.enterprisedb.com/docs/tde/latest/key_stores/) for more information.

How does TDE encrypt data?
Starting with ***version 16***, EDB TDE introduces the option to choose between `AES-128` and `AES-256` encryption algorithms during the initialization of the Postgres cluster. The choice between AES-128 and AES-256 hinges on balancing performance and security requirements. AES-128 is commonly advised for environments where performance efficiency and lower power consumption are pivotal, making it suitable for most applications. Conversely, AES-256 is recommended for scenarios demanding the highest level of security, often driven by regulatory mandates.

TDE uses `AES-128-XTS` or `AES-256-XTS` algorithms for encrypting data files. XTS uses a second value, known as the tweak value, to enhance the encryption. The XTS tweak value with TDE uses the database OID, the relfilenode, and the block number.

For write-ahead log (WAL) files, TDE uses AES-128-CTR or AES-256-CTR, incorporating the WAL's log sequence number (LSN) as the counter component.

Temporary files that are accessed by block are also encrypted using AES-128-XTS or AES-256-XTS. Other temporary files are encrypted using AES-128-CBC or AES-256-CBC.

### Redacting data
EDB Postgres Advanced Server includes features to help you to maintain, secure, and operate EDB Postgres Advanced Server databases. The DB Postgres Advanced Server Data redaction feature limits sensitive data exposure by dynamically changing data as it's displayed for certain users.

### Privilege Analysis
EDB Postgres Advanced Server provides support for capturing and analyzing the privilege usage by the users.

There are two ways to capture and analyze the privilege usage:
- Using DBMS_PRIVILEGE_CAPTURE package compatible to Oracle.
- Using SQL commands.

### EDB Audit
EDB Postgres Advanced Server allows database and security administrators, auditors, and operators to track and analyze database activities using EDB audit logging. EDB audit logging generates audit log files, which can be configured to record information such as:
- When a role establishes a connection to an EDB Postgres Advanced Server database
- The database objects a role creates, modifies, or deletes when connected to EDB Postgres Advanced Server
- When any failed authentication attempts occur

The parameters specified in the configuration files `postgresql.conf` or `postgresql.auto.conf` control the information included in the audit logs.


### Managing user profiles
EDB Postgres Advanced Server allows a database superuser to create named profiles. The following sections describe how to manage profiles with EDB Postgres Advanced Server:
- [Profile management](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/profile_overview/).
- [Creating a new profile](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/01_creating_a_new_profile/).
- [Altering a profile](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/02_altering_a_profile/).
- [Dropping a profile](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/03_dropping_a_profile/).
- [Associating a profile with an existing role](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/04_associating_a_profile_with_an_existing_role/).
- [Unlocking a locked account](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/05_unlocking_a_locked_account/).
- [Creating a new role associated with a profile](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/06_creating_a_new_role_associated_with_a_profile/).
- [Backing up profile management functions](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/04_profile_management/07_backing_up_profile_management_functions/).

### SQL/Protect 
SQL/Protect guards against different types of SQL injection attacks. More information about types of attacks and how SQL/Protect guards against them can be found [here](https://www.enterprisedb.com/docs/epas/latest/epas_security_guide/02_protecting_against_sql_injection_attacks/01_sql_protect_overview/).

### Auto Tuning
EDB Postgres Tuner is a PostgreSQL extension that automates 15+ years of EDB Postgres tuning experience.

Postgres uses some conservative settings to cover different host sizes. Some of the settings provided by Postgres are unsuitable because they don't take advantage of the available resources. Configuration parameters set by initdb don't account for the amount of memory, the number of CPU cores, and the kind of storage devices available to set appropriate values for parameters. Some parameters depend on the workload. The workload provides metrics to use to fine-tune some parameters dynamically.

This extension provides safe recommendations that maximize the use of available resources. It also allows you to control if and when to apply the changes. EDB Postgres Tuner enables you to apply tuning recommendations automatically or view tuning recommendations and selectively apply them. It's now possible to successfully manage demanding Postgres databases without tuning expertise.

### Wait States
EDB Wait States is a tool for analyzing performance and tuning by allowing the collection and querying of wait event data. Wait events, introduced in PostgreSQL 9.6, are recorded alongside other session activity and provide a snapshot of whether a session is waiting for I/O, CPU, IPC, locks, or timeouts. Snapshots of this information are gathered by the EDB Wait States background worker (BGW) at regular intervals.

The EDB Wait States interface allows you to control when and for how long the wait events are sampled and to extract the gathered samples in `edb_wait_states_data` for further analysis. By gathering this data over time, you can discover optimization opportunities and gain insight into what resources sessions are waiting on when performance is lower than expected.

### AWR-like snapshot reports
Called ***Dynamic Runtime Instrumentation Tools Architecture (DRITA)***:
The Dynamic Runtime Instrumentation Tools Architecture (DRITA) allows a DBA to query catalog views to determine the ***wait events*** that affect the performance of individual sessions or the system as a whole. DRITA records the number of times each event occurs as well as the time spent waiting; you can use this information to diagnose performance problems. DRITA offers this functionality, while consuming minimal system resources.

DRITA compares snapshots to evaluate the performance of a system. A snapshot is a saved set of system performance data at a given point in time. Each snapshot is identified by a unique ID number; you can use snapshot ID numbers with DRITA reporting functions to return system performance statistics.


### Learn more about EPAS
- [Webinar](https://info.enterprisedb.com/Introducing-EPAS-15-The-Most-Secure-Postgres.html) Introducing EPAS 15 - The Most Secure Postgres.
- [Configuring and Tuning PostgreSQL and EDB Postgres Advanced Server - Guide for Windows Users](https://info.enterprisedb.com/Whitepaper_PostgreSQL-EPAS-Guide-Windows-users.html).

## Postgres Community Encryption Options
PostgreSQL offers encryption at several levels, and provides flexibility in protecting data from disclosure due to ***database server theft***, **unscrupulous administrators**, and ***insecure networks***. Encryption might also be required to secure sensitive data such as `medical records` or `financial transactions`.

### Password Encryption
Database user passwords are stored as hashes (determined by the setting password_encryption), so the administrator cannot determine the actual password assigned to the user. If `SCRAM` or `MD5` encryption is used for client authentication, the unencrypted password is never even temporarily present on the server because the client encrypts it before being sent across the network. `SCRAM` is preferred, because it is an Internet standard and is more secure than the PostgreSQL-specific MD5 authentication protocol.

### Encryption For Specific Columns
The [pgcrypto](https://www.postgresql.org/docs/current/pgcrypto.html) module allows certain fields to be stored encrypted. This is useful if only ***some of the data is sensitive***. The client supplies the decryption key and the data is decrypted on the server and then sent to the client.

The decrypted data and the decryption key are present on the server for a brief time while it is being decrypted and communicated between the client and server. This presents a brief moment where the data and keys can be intercepted by someone with complete access to the database server, such as the system administrator.

### Data Partition Encryption
Storage encryption can be performed at the file system level or the block level. Linux file system encryption options include `eCryptfs` and `EncFS`, while FreeBSD uses `PEFS`. Block level or full disk encryption options include `dm-crypt + LUKS` on Linux and GEOM modules `geli` and `gbde` on FreeBSD. Many other operating systems support this functionality, including Windows.

This mechanism prevents unencrypted data from being read from the drives if the drives or the entire computer is stolen. 

:::warning 
This does not protect against attacks while the file system is mounted, because when mounted, the operating system provides an unencrypted view of the data. However, to mount the file system, you need some way for the encryption key to be passed to the operating system, and sometimes the key is stored ***somewhere*** on the host that mounts the disk.
:::

### Encrypting Data Across A Network
SSL connections encrypt all data sent across the network: the password, the queries, and the data returned. The `pg_hba.conf` file allows administrators to specify which hosts can use non-encrypted connections (host) and which require SSL-encrypted connections (hostssl). Also, clients can specify that they connect to servers only via SSL.

GSSAPI-encrypted connections encrypt all data sent across the network, including queries and data returned. (No password is sent across the network.) The pg_hba.conf file allows administrators to specify which hosts can use non-encrypted connections (host) and which require GSSAPI-encrypted connections (hostgssenc). Also, clients can specify that they connect to servers only on GSSAPI-encrypted connections (gssencmode=require).

Stunnel or SSH can also be used to encrypt transmissions.

### SSL Host Authentication
It is possible for both the client and server to provide SSL certificates to each other. It takes some extra configuration on each side, but this provides stronger verification of identity than the mere use of passwords. It prevents a computer from pretending to be the server just long enough to read the password sent by the client. It also helps prevent “man in the middle” attacks where a computer between the client and server pretends to be the server and reads and passes all data between the client and server.

### Client-Side Encryption
If the system administrator for the server's machine cannot be trusted, it is necessary for the client to encrypt the data; this way, unencrypted data never appears on the database server. Data is encrypted on the client before being sent to the server, and database results have to be decrypted on the client before being used.



