---
sidebar_position: 5
title: Security Services
description: AWS Security Services
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

## IAM
IAM: Identity Access Management. IAM is about two very specific things `Authentication` and `Authorization`. 

Identity Access Management is going to authenticate the user. Make sure when a user tries to perform some sort of action, that user is who they say they are.

Then IAM is going to be responsible for figuring out if they are allowed to perform that action. All about making sure that the user has the right permissions to do what they are trying to do.

IAM is all about:
- `Security`: Making sure that aws is secure. And only authenticated users are allowed to perform actions.
- `Centralized Management`: Provides a single source to manage all authentication and authorization.
- `Compliance and Auditing`: IAM assists with compliance and auditing.
- `Least Privilege Principle`: IAM allows us to operate on the least privilege principle.

### Users and Groups
When you need to give someone access to AWS, you create an IAM user. 

IAM user represents an ***individual entity*** that can interact with AWS.

Groups are a collection of IAM users with similar access requirements.

> It is a best practice to use groups to assign permissions to IAM users. 

Also note that a user can be a part of multiple groups.

By default a new user has no permissions to do anything in AWS. We have to explicitly grant them permissions.

### Policy
Policies dictate the permissions a user should have access to. E.g. an example policy document:


```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "s3:GetObject",
              "s3:ListBucket"
            ],
            "Resource": [
              "arn:aws:s3:::mybucket",
              "arn:aws:s3:::mybucket/*"
            ]
        }
    ]
}
```

- `Version`: The version of the policy language.
- `Statement`: A list of different roles associated with this policy. A role is going to have a couple of things:
  - `Action`: The action that the user is allowed to perform.
  - `Effect`: Whether the action is allowed or denied.
  - `Resource`: The resource that the action is allowed on.


