---
sidebar_position: 6
title: Go
description: "Build an API with Go 1.22"
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

## Init
```bash
go mod init github.com/ZiadMansourM/api

go mod tidy

curl -H "Authorization: Bearer token" http://127.0.0.1:8080/api/v1/users/42
```

:::warning
Any white spaces between `router.HandleFunc("GET /users/{userID}", func(w http.ResponseWriter, r *http.Request) {}` the `[METHOD ][HOST]/[PATH]` will cause an error _ONLY_ use one space.
:::

