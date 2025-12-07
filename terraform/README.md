# Terraform ECS Infrastructure

This Terraform configuration creates a complete ECS infrastructure with VPC, subnets, ALB, and all necessary resources for running containerized applications on AWS Fargate.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     VPC (10.0.0.0/16)                   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │           Public Subnets (2 AZs)                 │  │
│  │  - Application Load Balancer                     │  │
│  │  - NAT Gateways                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │           Private Subnets (2 AZs)                │  │
│  │  - ECS Fargate Tasks                             │  │
│  │  - API Services                                  │  │
│  │  - Worker Services                               │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## What Gets Created

### Network Infrastructure
- **VPC** with DNS support
- **2 Public Subnets** across 2 availability zones
- **2 Private Subnets** across 2 availability zones
- **Internet Gateway** for public internet access
- **2 NAT Gateways** (one per AZ) for private subnet internet access
- **Route Tables** for public and private subnets
- **Security Groups** for ALB and ECS tasks

### Compute Resources
- **ECS Fargate Cluster** with Container Insights enabled
- **IAM Execution Role** for ECS task execution
- **IAM Task Role** for running containers
- **CloudWatch Log Group** for container logs

### Load Balancing
- **Application Load Balancer** (ALB)
- **HTTP Listener** on port 80
- Default 404 response (services add their own rules)

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (or GitHub Actions with AWS credentials)
- Docker (for building images)

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Variables (Optional)

Edit `terraform.tfvars` if you want to customize:

```hcl
aws_region   = "us-east-1"
project_name = "email-platform"
environment  = "dev"
vpc_cidr     = "10.0.0.0/16"
use_localstack = false
```

### 3. Deploy Infrastructure

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply
```

### 4. Get Outputs

```bash
terraform output
```

## Using with LocalStack

For local testing with LocalStack:

```bash
# Start LocalStack
docker-compose up -d

# Update terraform.tfvars
use_localstack = true
localstack_endpoint = "http://localhost:4566"

# Deploy
terraform apply
```

## Outputs

After deployment, you'll get:

- `vpc_id` - VPC ID
- `public_subnet_ids` - Public subnet IDs (for ALB)
- `private_subnet_ids` - Private subnet IDs (for ECS tasks)
- `alb_dns_name` - Load balancer DNS name
- `alb_url` - Load balancer URL
- `ecs_cluster_name` - ECS cluster name
- `ecs_cluster_arn` - ECS cluster ARN
- `ecs_execution_role_arn` - IAM role for task execution
- `ecs_task_role_arn` - IAM role for tasks
- `ecs_security_group_id` - Security group for ECS tasks
- `alb_listener_arn` - ALB listener ARN (for adding rules)
- `log_group_name` - CloudWatch log group name


### Workflow

The workflow (`.github/workflows/deploy.yml`) will:

1. **Deploy Infrastructure** - Run Terraform to create/update infrastructure
2. **Build Docker Images** - Build and push images to ECR
3. **Deploy Services** - Deploy ECS services using task definitions

### Triggering Deployment

```bash
# Push to main branch
git push origin main

# Or manually trigger via GitHub UI
```

## Task Definitions

Task definitions are stored in `task-definitions/` as JSON files:

- `sampleapi.json` - API service task definition
- `sampleworker.json` - Worker service task definition

These use environment variable substitution for dynamic values:

- `${IMAGE_URI}` - Docker image URI
- `${EXECUTION_ROLE_ARN}` - ECS execution role ARN
- `${TASK_ROLE_ARN}` - ECS task role ARN
- `${LOG_GROUP}` - CloudWatch log group name
- `${AWS_REGION}` - AWS region
- `${SECRET_ARN}` - Secrets Manager ARN (for worker)

## Adding a New Service

### 1. Create Task Definition

Create `task-definitions/myservice.json`:

```json
{
  "family": "email-platform-dev-myservice",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "${EXECUTION_ROLE_ARN}",
  "taskRoleArn": "${TASK_ROLE_ARN}",
  "containerDefinitions": [
    {
      "name": "myservice",
      "image": "${IMAGE_URI}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "LOG_LEVEL",
          "value": "info"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${LOG_GROUP}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "myservice"
        }
      }
    }
  ]
}
```

### 2. Add to GitHub Actions

Add a new job to `.github/workflows/deploy.yml` similar to existing services.

### 3. Deploy

Push your changes and the workflow will deploy the new service.

## Monitoring

### CloudWatch Logs

View logs:

```bash
aws logs tail /ecs/email-platform/dev --follow
```

### ECS Service Status

```bash
aws ecs describe-services \
  --cluster email-platform-dev \
  --services email-platform-dev-sampleapi
```

### Task Status

```bash
aws ecs list-tasks \
  --cluster email-platform-dev \
  --service-name email-platform-dev-sampleapi
```

## Cost Optimization

- **NAT Gateways**: Most expensive resource (~$32/month each)
- **Fargate**: Pay per vCPU and memory per second
- **ALB**: Pay per hour + LCU usage

### Cost Saving Tips

1. Use a single NAT Gateway for dev (reduce count to 1)
2. Right-size Fargate tasks (CPU and memory)
3. Use Fargate Spot for non-critical workloads
4. Delete resources when not in use: `terraform destroy`

## Clean Up

To destroy all infrastructure:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all resources including data in CloudWatch Logs.

## Troubleshooting

### Tasks Not Starting

Check task logs:
```bash
aws ecs describe-tasks \
  --cluster email-platform-dev \
  --tasks TASK_ARN
```

### Network Issues

- Verify security groups allow traffic
- Check NAT Gateway status
- Verify route tables

### IAM Issues

- Ensure execution role has ECR and CloudWatch permissions
- Ensure task role has necessary service permissions

## File Structure

```
terraform/
├── main.tf              # Main infrastructure
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
├── terraform.tfvars     # Variable values
├── docker-compose.yml   # LocalStack setup
└── README.md           # This file

task-definitions/
├── sampleapi.json       # API task definition
└── sampleworker.json    # Worker task definition

.github/workflows/
└── deploy.yml          # GitHub Actions workflow
```

## Next Steps

1. ✅ Deploy infrastructure with Terraform
2. 📦 Build Docker images
3. 📝 Create ECS services
4. 🚀 Deploy via GitHub Actions
5. 📊 Monitor with CloudWatch
6. 🔧 Add more services as needed

## Support

For issues or questions:
- Check AWS CloudWatch Logs
- Review ECS service events
- Verify security group rules
- Check task definition configuration

