---
sidebar_position: 5
title: Sealed Secrets
description: Sealed Secrets Setup Kubernetes
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm search repo sealed
helm install sealed-secrets --version 2.15.3 sealed-secrets/sealed-secrets --namespace sealed-secrets --create-namespace
```

```bash
kubectl create secret generic argocd-notifications-secret -n argocd --from-literal slack-token=<slack-token> --dry-run=client -o yaml | kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets --format yaml > sealed-argocd-notifications-secret.yaml
```

```yaml title="builtin-config.yaml"
nameReference:
  - kind: Secret
    fieldSpecs:
    - kind: SealedSecret
      path: metadata/name
    - kind: SealedSecret
      path: spec/template/metadata/name
```

```yaml title="kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ./pod.yaml
  - ./sealedsecret.yaml

secretGenerator:
  - name: test
    files:
      - ./sealedsecret.yaml
    options:
      annotations:
        config.kubernetes.io/local-config: "true"

configurations:
  - ./builtin-config.yaml
```


Make sure to include `sealedsecrets.bitnami.com/namespace-wide: "true"` in the sealed secret as annotations.




