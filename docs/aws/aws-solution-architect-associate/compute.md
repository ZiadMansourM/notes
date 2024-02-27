---
sidebar_position: 4
title: Compute Services
description: AWS Compute Services
---

```mdx-code-block
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
```

## Pre-requisites
```bash title="Create SSH Key Pair"
ssh-keygen -t ed25519 -C "Jenkins key"
ssh-keygen -q -t ed25519 -C "Jenkins key ZiadMansourM" -f /Users/ziadh/.ssh/temp/jenkins/jenkins -N ""
```

## EC2

### EC2 Instance Types
- **General Purpose**: Balanced compute, memory, and networking resources.
- **Compute Optimized**: High performance processors.
- **Memory Optimized**: High memory to CPU ratio.
- **Storage Optimized**: High storage to CPU ratio.
- **GPU Optimized**: Specialized for graphic intensive applications.


### AMi
- **Amazon Machine Image**: A template that contains the software configuration (OS, application server, and applications) required to launch your instance.

#### Types of AMI
- **Public AMI**: Available to everyone.
- **Private AMI**: Available to specific accounts or owners.
- **Shared AMI**: Available to specific accounts or owners.

:::tip AMI Creation
You can create an AMI from an existing EC2 instance and launch a new instance from the created AMI. E.g. Create `users`, `install dependencies`, and `configure firewall` settings then create an AMI from the instance.

![ec2-ami](./assets/compute/ec2-ami.png)
:::

### Instance Lifecycle
![lifecycle](./assets/compute/lifecycle.png)


### User Data
Bootstrap script that runs when the instance is launched. Has a limit of `16 KB`.

### ELB && ASG
- **Elastic Load Balancer (ELB)**: Distributes incoming traffic across multiple targets.
- **Auto Scaling Group (ASG)**: Ensures that you have the correct number of EC2 instances running to handle the load across multiple availability zones.


![elb-asg](./assets/compute/elb-asg.png)


### Launch Templates
A specification of different launch parameters for an EC2 instance. Used in an Auto Scaling Group.

:::tip EC2 Launch Templates 
Provide an easy way to define and launch EC2 instances that conform to the company's standards, including security and governance, and can be used repeatedly to streamline the launch process.
:::


![launch-template](./assets/compute/launch-template.png)


### Instance Placements
![instance-placement](./assets/compute/instance-placement.png)

### EC2 Purchasing Options
![purchasing-options](./assets/compute/purchasing-options.png)

:::note Dedicated hosts vs instances
- `Dedicated hosts` are physical servers with EC2 instance capacity fully dedicated to your use. They can help you reduce costs by allowing you to use your existing server-bound software licenses.

- `Dedicated instances` are Amazon EC2 instances that run in a VPC on hardware that's dedicated to a single customer. Your Dedicated instances are `physically isolated` at the host hardware level from instances that belong to other AWS accounts.
:::


### IMP Notes
:::note AMI ID
AMI ID is a unique identifier for an AMI in a region. So, it is `region specific`.
:::

### Image Builder

![image-builder](./assets/compute/image-builder.png)

#### Golden Image 
A pre-configured image that is used as a template for creating new instances.

![golden-image](./assets/compute/golden-image.png)

#### Steps
![image-build-steps](./assets/compute/image-build-steps.png)

![image-build-pipeline](./assets/compute/image-build-pipeline.png)

#### Features

![image-features](./assets/compute/image-features.png)



### Elastic Network Interfaces (ENI)
A virtual network interface that can be attached to ec2 instances in a VPC.

![eni](./assets/compute/eni.png)

:::note Primary and Secondary ENI
![secondary-eni](./assets/compute/secondary-eni.png)
:::

#### Features

![eni-features](./assets/compute/eni-features.png)


## Elastic Beanstalk
AWS Elastic Beanstalk is a service for deploying and managing applications in the AWS Cloud without having to worry about the infrastructure. It automates the deployment process, including provisioning, load balancing, auto-scaling, and application health monitoring.

![beanstalk](./assets/compute/beanstalk.png)

### Environment Types
![envs](./assets/compute/envs.png)

### Features
![bean-features](./assets/compute/bean-features.png)


## Lightsail
Amazon Lightsail is designed for projects with low, predictable pricing. It provides a simple virtual private server (VPS) solution that includes everything needed to launch a project quickly — instances, storage, databases, and networking.

![lightsail](./assets/compute/lightsail.png)


### Features

![lightsail-features](./assets/compute/lightsail-features.png)

### Benefits

![lightsail-benefits](./assets/compute/lightsail-benefits.png)


## Elastic Container Service (ECS)
Like kubernetes and Apache Mesos. AWS proprietary container orchestration service.

### ECS Launch Types
![ecs-launchtypes](./assets/compute/ecs-launchtypes.png)

### ECS on EC2
![ecs-ec2](./assets/compute/ecs-ec2.png)


### ECS on Fargate
:::tip AWS Fargate
AWS Fargate is a serverless, pay-as-you-go compute engine that lets you focus on building applications without managing servers. Moving tasks such as server management, resource allocation, and scaling to AWS does not only improve your operational posture, but also accelerates the process of going from idea to production on the cloud, and lowers the total cost of ownership. You can check docs [here](https://aws.amazon.com/fargate/).
:::

![ecs-fargate](./assets/compute/ecs-fargate.png)

### EC2 vs Fargate
![ec2-fargate](./assets/compute/ec2-fargate.png)

### ECS Task
The configuration of what to run inside the container.

<hr/>

![task-def](./assets/compute/task-def.png)

<hr/>

![ecs-tasks](./assets/compute/ecs-tasks.png)

<hr/>


### ECS Service
![ecs-service](./assets/compute/ecs-service.png)

### ECS LB

![ecs-lb](./assets/compute/ecs-lb.png)


## Elastic Kubernetes Service (EKS)
Managed kubernetes service by AWS.

![eks](./assets/compute/eks.png)

### Why EKS

![why-eks](./assets/compute/why-eks.png)

### Worker Nodes

![worker-nodes](./assets/compute/worker-nodes.png)

### Self Managed Nodes

![self-managed-nodes](./assets/compute/self-managed-nodes.png)

### Managed Node Groups

![managed-nodes-group](./assets/compute/managed-nodes-group.png)

### Fargate
![eks-fargate](./assets/compute/eks-fargate.png)

### EKS Cluster
![eks-cluster](./assets/compute/eks-cluster.png)

#### Connect
![eks-kubectl](./assets/compute/eks-kubectl.png)

### EKSCTL
eksctl is a simple CLI tool for creating clusters on EKS. You can check the repo [here](https://github.com/eksctl-io/eksctl).

![eksctl](./assets/compute/eksctl.png)


## Elastic Container Registry (ECR)
Fully managed container registry that makes it easy to store, manage, and deploy Docker container images.


![ecr](./assets/compute/ecr.png)


### CICD Pipeline
![ecr-cicd](./assets/compute/ecr-cicd.png)

### Benefits

![ecr-benefits](./assets/compute/ecr-benefits.png)


## App Runner
Fully managed service that makes it easy for developers to quickly deploy containerized web applications and APIs at scale. Without worrying about managing the infrastructure.

![app-runner](./assets/compute/app-runner.png)

![app-runner-ecr](./assets/compute/app-runner-ecr.png)

![app-runner-code-pipeline](./assets/compute/app-runner-code-pipeline.png)

![app-runner-vpc](./assets/compute/app-runner-vpc.png)

### Features
![app-runner-features](./assets/compute/app-runner-features.png)


## AWS Batch
Fully managed batch processing at any scale.

### Jobs Lifecycle

![batch-lifecycle](./assets/compute/batch-lifecycle.png)

### Components

![batch-components](./assets/compute/batch-components.png)


### Benefits

![batch-benefits](./assets/compute/batch-benefits.png)



## Lambda

![lambda](./assets/compute/lambda.png)

### Features
![lambda-benefits](./assets/compute/lambda-benefits.png)


## Step Functions
Serverless function orchestrator that makes it easy to sequence AWS Lambda functions and multiple AWS services into business-critical applications.

:::note AWS Step Functions
Allow coordination of multiple ETL jobs involving AWS Lambda functions and human approval steps. It provides a visual workflow to sequence Lambda functions and other AWS services.
:::

### State Machine
A state machine is a collection of states that can do work and transition between states.



## Serverless Application Model (SAM)
An extension of AWS CloudFormation that provides a simplified way of defining serverless resources.

### SAM Template
![sam-temp](./assets/compute/sam-temp.png)

### SAM CLI
![sam-cli](./assets/compute/sam-cli.png)

### SAM Deploy

![sam-deploy](./assets/compute/sam-deploy.png)


### SAM Repository

![sam-repo](./assets/compute/sam-repo.png)

![sam-repo-example](./assets/compute/sam-repo-example.png)

![sam-repo-example-two](./assets/compute/sam-repo-example-two.png)

### SAM Repo Features

![sam-repo-features](./assets/compute/sam-repo-features.png)

## Amplify
Complete solution for mobile and web app development.

![amplify](./assets/compute/amplify.png)

![amplify-integration](./assets/compute/amplify-integration.png)

### Amplify Studio
Visual builder for building full-stack applications.

![amplify-example](./assets/compute/amplify-example.png)

### Amplify Features

![amplify-features](./assets/compute/amplify-features.png)

## Outposts
Fully managed service that extends AWS infrastructure, AWS services, APIs, and tools to virtually any customer datacenter, co-location space, or on-premises facility for a truly consistent hybrid experience.

Use same AWS APIs, tools, and infrastructure across on-premises and the cloud.

![outposts-model](./assets/compute/outposts-model.png)

Outposts is a family of a fully managed solutions delivering AWS infrastructure and services to virtually any on-premises or edge location for a truly consistent hybrid experience.

What happens is that AWS will deliver a fully managed and configurable server rack to your on-premises location. This server rack will be pre-configured with AWS services and infrastructure. You can then use the same AWS APIs, tools, and infrastructure across on-premises and the cloud.

You provide the power, network, and space. And outpost will connect to the nearest AWS region over an AWS Direct Connect link or VPN.

Basically, run AWS services on-premises.

![outpost-ops](./assets/compute/outpost-ops.png)

![op-dc](./assets/compute/op-dc.png)

Instances in your outpost can securely connect to other instances in your VPC through a private IP address.

![op-vpc](./assets/compute/op-vpc.png)

It will end up looking like this, you got aws cloud and your on-premises outpost.

![outpost-result](./assets/compute/outpost-result.png)


### Benefits

![op-benefits](./assets/compute/op-benefits.png)

## EKS Anywhere

![eks-anywhere](./assets/compute/eks-anywhere.png)

### Benefits

![eks-anywhere-benefits](./assets/compute/eks-anywhere-benefits.png)

## ECS Anywhere

![ecs-anywhere](./assets/compute/ecs-anywhere.png)

### Benefits
![ecs-benefits](./assets/compute/ecs-benefits.png)

## VMWare Cloud on AWS
- **vSphere**: VMware's virtualization platform.
- **vSAN**: VMware's software-defined storage.
- **NSX-T**: VMware's software-defined networking. Network virtualization and security platform.

![vmware](./assets/compute/vmware.png)

![vmware-inaction](./assets/compute/vmware-inaction.png)

### Use Cases

![vmware-usecases](./assets/compute/vmware-usecases.png)

## Snow Cone
Small, portable, rugged, and secure edge computing and data transfer device.

![snowcone-ops](./assets/compute/snowcone-ops.png)

### Snow family
Snow family is a collection of physical devices for edge computing and data transfer. But we will focus on snowcone and snowball edge. Because, they have compute capabilities.

![snow-compute](./assets/compute/snow-compute.png)

### Snowcone

![snowcone-one](./assets/compute/snowcone-one.png)

![scnowcone-two](./assets/compute/scnowcone-two.png)

### Benefits

![snowcone-benefits](./assets/compute/snowcone-benefits.png)


## Results
![results](./assets/compute/results.png)

## Wrong Answers
![wrong-answers](./assets/compute/wrong-answers.png)