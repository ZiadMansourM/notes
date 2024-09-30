---
sidebar_position: 9
title: Scripts & Commands
description: "Scripts and Commands"
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```


## Kubernetes
```bash
kubectl run test -it --rm --image ubuntu -- bash

apt update && apt install -y postgresql-client telnet curl traceroute dnsutils

# E.g.(1): psql -h DB_IP_ADDRESS -p 5432 -U DB_USER -d DB_NAME

# E.g.(2): telnet DB_IP_ADDRESS 5432
```


## GitLab

### WorkFlow

<Tabs>

<TabItem value="Old">

```yaml
workflow:
  name: Test and Build Middleware
  rules:
  - if: '$CI_COMMIT_BRANCH == "main"'
  - if: '$CI_PIPELINE_SOURCE == "web"'
  - if: '$CI_MERGE_REQUEST_IID'

variables:
  VIRTUAL_ENV: .venv
  IMAGE_NAME: "registry.gitlab.com/aljfinance.eg/middleware:latest"

cache:
  key:
    files:
    - requirements.txt
  paths:
  - $VIRTUAL_ENV/

stages:
- deps
- test
- build

# Template for jobs that require installing dependencies
.python_job_template: &python_job_template
  image: python:3.12
  rules:
  - if: '$CI_MERGE_REQUEST_ID || $CI_COMMIT_BRANCH == "main"'

# Template for using Middleware Runner in HQ
.middleware_hq_runner: &middleware_hq_runner
  tags:
  - middleware-hq-runner

install_dependencies:
  stage: deps
  <<: [*python_job_template, *middleware_hq_runner]
  script:
  - python -m venv $VIRTUAL_ENV
  - source $VIRTUAL_ENV/bin/activate
  - pip install --upgrade pip
  - pip install -r requirements.txt

check_precommit:
  stage: test
  <<: [*python_job_template, *middleware_hq_runner]
  script:
  - source $VIRTUAL_ENV/bin/activate
  - pre-commit run --all-files

django_test:
  stage: test
  <<: [*python_job_template, *middleware_hq_runner]
  script:
  - source $VIRTUAL_ENV/bin/activate
  - python manage.py test

docker_build_push:
  stage: build
  image: docker:26.1.1
  <<: *middleware_hq_runner
  services:
  - docker:26.1.1-dind
  variables:
    DOCKER_TLS_CERTDIR: ""
  script:
  - unset DOCKER_HOST
  - apk add --no-cache curl
  - docker login $CI_REGISTRY -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD
  - docker build -t $IMAGE_NAME .
  - docker push $IMAGE_NAME
  - chmod +x scripts/gitlab_notify.sh
  - scripts/gitlab_notify.sh "$IMAGE_NAME"
  only:
  - main
```

</TabItem>

<TabItem value="New">

```yaml
workflow:
  rules:
  - when: always

variables:
  VIRTUAL_ENV: .venv

cache:
  key:
    files:
    - requirements.txt
  paths:
  - $VIRTUAL_ENV/

stages:
- deps
- test
- build

# Template for jobs that require installing dependencies
.python_job_template: &python_job_template
  image: python:3.12

# Template for using Middleware Runner in HQ
.middleware_hq_runner: &middleware_hq_runner
  tags:
  - middleware-hq-runner

install_dependencies:
  stage: deps
  <<: [*python_job_template, *middleware_hq_runner]
  script:
  - python -m venv $VIRTUAL_ENV
  - source $VIRTUAL_ENV/bin/activate
  - pip install --upgrade pip
  - pip install -r requirements.txt

check_precommit:
  stage: test
  <<: [*python_job_template, *middleware_hq_runner]
  script:
  - source $VIRTUAL_ENV/bin/activate
  - pre-commit run --all-files

django_test:
  stage: test
  <<: [*python_job_template, *middleware_hq_runner]
  script:
  - source $VIRTUAL_ENV/bin/activate
  - python manage.py test

check_migrations:
  stage: test
  <<: [*python_job_template, *middleware_hq_runner]
  script:
  - source $VIRTUAL_ENV/bin/activate
  - python manage.py makemigrations --dry-run --check

docker_build_push:
  stage: build
  image: docker:26.1.1
  <<: *middleware_hq_runner
  services:
  - docker:26.1.1-dind
  variables:
    DOCKER_TLS_CERTDIR: ""
  script:
  - unset DOCKER_HOST
  - docker login $CI_REGISTRY -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD
  - docker build -t $IMAGE_NAME .
  - docker push $IMAGE_NAME
  rules:
  - if: '$CI_COMMIT_BRANCH == "main"'
    variables:
      ENVIRONMENT: "dev"
      IMAGE_NAME: "registry.gitlab.com/aljfinance.eg/middleware:latest-dev"
    when: always
  - if: '$CI_COMMIT_BRANCH == "uat"'
    variables:
      ENVIRONMENT: "uat"
      IMAGE_NAME: "registry.gitlab.com/aljfinance.eg/middleware:latest-uat"
    when: always
  - if: '$CI_COMMIT_BRANCH == "production"'
    variables:
      ENVIRONMENT: "production"
      IMAGE_NAME: "registry.gitlab.com/aljfinance.eg/middleware:latest-production"
    when: always
  - when: never
```

</TabItem>

</Tabs>

```bash title="gitlab_notify.sh"
#!/bin/sh
set -euo pipefail

# Variables
IMAGE_NAME="$1"

# Decode the Base64-encoded Teams webhook URL
if [ -z "${TEAMS_WEBHOOK_URL_BASE64:-}" ]; then
    echo "Error: TEAMS_WEBHOOK_URL_BASE64 is not set."
    exit 1
fi

TEAMS_WEBHOOK_URL=$(echo "$TEAMS_WEBHOOK_URL_BASE64" | base64 -d)

# Escape any double quotes in variables to prevent JSON parsing errors
COMMIT_MESSAGE=$(echo "$CI_COMMIT_MESSAGE" | sed 's/"/\\"/g')
GITLAB_USER_NAME_ESCAPED=$(echo "$GITLAB_USER_NAME" | sed 's/"/\\"/g')

# Get the image digest
IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_NAME" | cut -d'@' -f2)

echo "$IMAGE_DIGEST"

# Prepare the JSON payload for Teams using Adaptive Cards
payload=$(cat <<EOF
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "contentUrl": null,
      "content": {
        "\$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [
          {
            "type": "TextBlock",
            "text": "New Docker Image Pushed",
            "weight": "Bolder",
            "size": "Medium",
            "color": "Good"
          },
          {
            "type": "TextBlock",
            "text": "A new Docker image has been pushed to the GitLab registry.",
            "wrap": true
          },
          {
            "type": "FactSet",
            "facts": [
              {
                "title": "Image:",
                "value": "$IMAGE_NAME"
              },
              {
                "title": "Digest:",
                "value": "$IMAGE_DIGEST"
              },
              {
                "title": "Commit:",
                "value": "$CI_COMMIT_SHORT_SHA"
              },
              {
                "title": "Message:",
                "value": "$COMMIT_MESSAGE"
              },
              {
                "title": "Pushed by:",
                "value": "$GITLAB_USER_NAME_ESCAPED"
              },
              {
                "title": "Time:",
                "value": "$(date)"
              }
            ]
          }
        ],
        "actions": [
          {
            "type": "Action.OpenUrl",
            "title": "View Pipeline",
            "url": "$CI_PIPELINE_URL"
          }
        ]
      }
    }
  ]
}
EOF
)

# Send the payload to Teams using curl
curl -s -X POST "$TEAMS_WEBHOOK_URL" \
-H "Content-Type: application/json" \
-d "$payload"
```

```bash title="Download Crane"
# Download crane v0.20.2
curl -Lo crane.tar.gz https://github.com/google/go-containerregistry/releases/download/v0.20.2/go-containerregistry_Linux_x86_64.tar.gz
tar -xzf crane.tar.gz
sudo mv crane /usr/local/bin/
rm crane.tar.gz
```

```bash title="Sudo Cron Job"
* * * * * /home/dev_ops/middleware/scripts/check_and_deploy.sh >> /home/dev_ops/middleware/logs/check_and_deploy.log 2>&1
0 0 * * 0 > /home/dev_ops/middleware/logs/check_and_deploy.log
```

```bash title="check_and_deploy.sh"
#!/bin/bash

# Variables
REPO="registry.gitlab.com/aljfinance.eg/middleware"
TAG="latest"
LOGFILE="/home/ziad_mansour/middleware/logs/auto_pull_latest.log"
TEAMS_WEBHOOK_URL="TEAMS_WEBHOOK_URL_BASE64"

notify_local() {
  local message=$1
  echo "$(date) - $message" >> "$LOGFILE"
}

# Function to send notifications to Microsoft Teams
notify() {
    local title=$1
    local message=$2
    local color=$3  # Accept color parameter

    # Prepare the JSON payload for Teams using Adaptive Cards
    local payload=$(cat <<EOF
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "contentUrl": null,
      "content": {
        "\$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [
          {
            "type": "TextBlock",
            "text": "$title",
            "weight": "Bolder",
            "size": "Medium",
            "color": "$color"
          },
          {
            "type": "TextBlock",
            "text": "$message",
            "wrap": true
          },
          {
            "type": "FactSet",
            "facts": [
              {
                "title": "Sent by:",
                "value": "Deployment Script"
              },
              {
                "title": "Time:",
                "value": "$(date)"
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF
)
    # Send the payload to Teams using curl
    curl -s -X POST "$TEAMS_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$payload"

    # Log the message to the log file
    echo "$(date) - $title - $message" >> "$LOGFILE"
}

# New function to send "New Image Detected" notification with enhanced formatting
notify_new_image() {
    local digest=$1

    # Prepare the JSON payload for Teams using Adaptive Cards
    local payload=$(cat <<EOF
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "contentUrl": null,
      "content": {
        "\$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [
          {
            "type": "TextBlock",
            "text": "New Image Detected",
            "weight": "Bolder",
            "size": "Medium",
            "color": "Accent"
          },
          {
            "type": "Container",
            "items": [
              {
                "type": "FactSet",
                "facts": [
                  {
                    "title": "Repository:",
                    "value": "$REPO"
                  },
                  {
                    "title": "Tag:",
                    "value": "$TAG"
                  },
                  {
                    "title": "Digest:",
                    "value": "$digest"
                  },
                  {
                    "title": "Sent by:",
                    "value": "Deployment Script"
                  },
                  {
                    "title": "Time:",
                    "value": "$(date)"
                  }
                ]
              }
            ]
          },
          {
            "type": "TextBlock",
            "text": "Currently pulling the latest image and restarting the container.",
            "weight": "Lighter",
            "size": "Small",
            "color": "good",
            "wrap": true
          }
        ]
      }
    }
  ]
}
EOF
)
    # Send the payload to Teams using curl
    curl -s -X POST "$TEAMS_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$payload"

    # Log the message to the log file
    echo "$(date) - New Image Detected - Digest: $digest" >> "$LOGFILE"
}

# Get the digest of the remote image
REMOTE_DIGEST=$(/usr/local/bin/crane digest $REPO:$TAG 2>/dev/null || true)
if [ -z "$REMOTE_DIGEST" ]; then
    notify "Error" "Failed to get remote digest." "Attention"
    exit 1
fi

# Get the digest of the local image
LOCAL_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $REPO:$TAG 2>/dev/null | cut -d'@' -f2 || true)
if [ -z "$LOCAL_DIGEST" ]; then
    notify "Error" "Failed to get local digest." "Attention"
    exit 1
fi

notify_local "REMOTE_DIGEST: $REMOTE_DIGEST"
notify_local "LOCAL_DIGEST : $LOCAL_DIGEST"

# Check if the remote digest and local digest match
if [ "$REMOTE_DIGEST" != "$LOCAL_DIGEST" ]; then
    # Locking mechanism
    lockdir=/tmp/check_and_deploy.lock
    if mkdir -- "$lockdir"
    then
        notify_local "Successfully acquired lock"
        # Ensure the lock directory is removed when the script exits
        trap 'rm -rf -- "$lockdir"' EXIT
    else
        notify_local "Another instance is running. Exiting."
        exit 1
    fi

    # If the digests do not match, pull the new image and restart the container
    notify_new_image "$REMOTE_DIGEST"

    # Pull the new image
    if docker compose -f /home/ziad_mansour/middleware/compose.yaml pull web; then
        # Restart the container
        if docker compose -f /home/ziad_mansour/middleware/compose.yaml up -d; then
            notify "Deployment Successful" "Image pulled and container restarted successfully." "Good"
        else
            notify "Deployment Failed" "Failed to restart the container." "Attention"
            exit 1
        fi
    else
        notify "Deployment Failed" "Failed to pull the new image." "Attention"
        exit 1
    fi

else
    # If the digests match, do nothing
    notify_local "No new image found. No action required."
fi
```

### Init Repo
```bash
git init

git add .

git commit -m "INIT: commit"

git remote add origin REPO_URL

git fetch origin main
git checkout -b my-local-changes
git checkout main
git reset --hard origin/main
git merge my-local-changes --allow-unrelated-histories

# Solve, Add, Commit

git push origin main
```


## Linux

### SSH Keygen
```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/dev_ops -C "dev_ops@domain.com"

ssh-copy-id -i ~/.ssh/dev_ops.pub dev_ops@SERVER_IP_ADDRESS
```

### Add User
```bash
sudo useradd -m -s /bin/bash ziadh
sudo passwd ziadh
sudo usermod -aG sudo ziadh

sudo userdel -r dev_ops
```

## Docker

### Docker Compose
```yaml
name: middleware

x-logging: &logging
  logging:
    driver: loki
    options:
      loki-url: https://loki-internal.aljfinance.com.eg/loki/api/v1/push
      loki-retries: "5"
      loki-batch-size: "100"

services:
  web:
    image: registry.gitlab.com/aljfinance.eg/middleware:latest
    <<: *logging
    env_file:
    - .env.staging
    restart: unless-stopped
    volumes:
    - ./staticfiles:/app/staticfiles
    depends_on:
    - redis
  
  redis:
    # This sha256 belongs to redis:7
    image: redis@sha256:eadf354977d428e347d93046bb1a5569d701e8deb68f090215534a99dbcb23b9
    <<: *logging
    command: redis-server --save 60 1 --loglevel warning
    volumes:
    - ./redis_data:/data
    restart: unless-stopped

  nginx:
    image: nginx@sha256:516475cc129da42866742567714ddc681e5eed7b9ee0b9e9c015e464b4221a00
    <<: *logging
    volumes:
    - ./conf/nginx-staging.conf:/etc/nginx/nginx.conf
    - ./ssl:/etc/nginx/ssl
    - ./staticfiles:/app/staticfiles
    ports:
    - "80:80"
    - "443:443"
    restart: unless-stopped
    depends_on:
    - web

  node_exporter:
    image: prom/node-exporter@sha256:4032c6d5bfd752342c3e631c2f1de93ba6b86c41db6b167b9a35372c139e7706
    restart: unless-stopped
    volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /:/rootfs:ro
    network_mode: host
    command:
    - '--path.procfs=/host/proc'
    - '--path.sysfs=/host/sys'
    - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
```

```yaml
name: hq_monitoring

x-logging: &logging
  logging:
    driver: loki
    options:
      loki-url: http://10.5.0.2:3100/loki/api/v1/push
      loki-retries: "5"
      loki-batch-size: "100"

services:
  nginx:
    image: nginx@sha256:516475cc129da42866742567714ddc681e5eed7b9ee0b9e9c015e464b4221a00
    <<: *logging
    volumes:
    - ./conf/nginx.conf:/etc/nginx/nginx.conf
    - ./ssl:/etc/nginx/ssl
    ports:
    - "80:80"
    - "443:443"
    depends_on:
    - grafana
    restart: unless-stopped
    networks:
      vpcbr:
        ipv4_address: 10.5.0.3

  loki:
    image: grafana/loki@sha256:8b5bd7748d0e4da66cd741ac276e485517514af0bea32167e27c0e1a95bcf8aa
    restart: unless-stopped
    networks:
      vpcbr:
        ipv4_address: 10.5.0.2
  
  prometheus:
    image: prom/prometheus:latest
    ports:
    - "9090:9090"
    volumes:
    - ./conf/prometheus.yml:/etc/prometheus/prometheus.yml
    - ./conf/alert_rules.yml:/etc/prometheus/alert_rules.yml
    restart: unless-stopped
    networks:
      vpcbr:
        ipv4_address: 10.5.0.4
  
  alertmanager:
    image: prom/alertmanager:latest
    ports:
    - "9093:9093"
    volumes:
    - ./conf/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    restart: unless-stopped
    networks:
      vpcbr:
        ipv4_address: 10.5.0.6

  prometheus-msteams:
    image: bzon/prometheus-msteams:v1.1.4
    ports:
    - "127.0.0.1:2000:2000"
    volumes:
    - ./conf/prometheus-msteams-config.yml:/tmp/config.yml
    - ./conf/card.tmpl:/tmp/card.tmpl
    environment:
    - CONFIG_FILE=/tmp/config.yml
    - TEMPLATE_FILE=/tmp/card.tmpl
    restart: unless-stopped
    networks:
      vpcbr:
        ipv4_address: 10.5.0.7

  grafana:
    image: grafana/grafana@sha256:0dc5a246ab16bb2c38a349fb588174e832b4c6c2db0981d0c3e6cd774ba66a54
    <<: *logging
    environment:
    - GF_SECURITY_ADMIN_PASSWORD=loki@aljf
    volumes:
    - ./conf/provisioning/:/etc/grafana/provisioning/
    depends_on:
    - loki
    restart: unless-stopped
    networks:
      vpcbr:
        ipv4_address: 10.5.0.5

networks:
  vpcbr:
    name: vpcbr
    driver: bridge
    ipam:
     config:
       - subnet: 10.5.0.0/16
         gateway: 10.5.0.1
```

```conf
events {}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name grafana-internal.aljfinance.com.eg;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl;
        http2 on;
        server_name grafana-internal.aljfinance.com.eg;

        location / {
            proxy_pass http://grafana:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_redirect off;
        }

        ssl_certificate /etc/nginx/ssl/ssl-bundle.crt;
        ssl_certificate_key /etc/nginx/ssl/star_aljfinance_com_eg.key;
        ssl_protocols TLSv1.2;
    }

    server {
        listen 80;
        server_name prometheus-internal.aljfinance.com.eg;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl;
        http2 on;
        server_name prometheus-internal.aljfinance.com.eg;

        location / {
            proxy_pass http://prometheus:9090;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_redirect off;
        }

        ssl_certificate /etc/nginx/ssl/ssl-bundle.crt;
        ssl_certificate_key /etc/nginx/ssl/star_aljfinance_com_eg.key;
        ssl_protocols TLSv1.2;
    }

    server {
        listen 80;
        server_name loki-internal.aljfinance.com.eg;
        return 301 https://$host$request_uri;
    }

    server {
        listen 443 ssl;
        http2 on;
        server_name loki-internal.aljfinance.com.eg;

        location / {
            proxy_pass http://loki:3100;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_redirect off;
        }

        ssl_certificate /etc/nginx/ssl/ssl-bundle.crt;
        ssl_certificate_key /etc/nginx/ssl/star_aljfinance_com_eg.key;
        ssl_protocols TLSv1.2;
    }
}
```
