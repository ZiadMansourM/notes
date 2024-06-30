---
sidebar_position: 4
title: Ansible
description: "Deep dive into Ansible."
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

Ansible is an it automation tool that automates:
- Provisioning.
- Configuration management.
- Continuous delivery.
- Application deployment.
- Security and compliance.

## Ansible Configuration file
The default ansible configuration file at `/etc/ansible/ansible.cfg` governs the default behavior of ansible using a set of parameters. It is divided into several sections:
```cfg
[defaults]
inventory = /etc/ansible/hosts
log_path = /var/log/ansible.log

[inventory]
enable_plugins = host_list, virtualbox, yaml, constructed

[privilege_escalation]

[paramiko_connection]

[ssh_connection]

[persistent_connection]

[colors]
```
With in these sections you have options and values. Most of them in th default section.

***How to work, override default configuration files?!***
- Global at `/etc/ansible/ansible.cfg`
- Add `ansible.cfg` for Application Specific at:
    - `/opt/network-playbooks`.
    - `/opt/web-playbooks`.
    - `/opt/db-playbooks`.
- Or `$ANSIBLE_CONFIG=/opt/ansible-web-reusable.cfg ansible-playbook playbook.yml`.

### Precedence
1. `ANSIBLE_CONFIG` environment variable.
2. `ansible.cfg` in the current directory.
3. `.ansible.cfg` in the home directory.
4. `/etc/ansible/ansible.cfg`.
