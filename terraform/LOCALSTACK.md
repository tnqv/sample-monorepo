# Using Terraform with LocalStack

This guide shows you how to test your infrastructure locally using LocalStack.

## What is LocalStack?

LocalStack is a fully functional local AWS cloud stack that allows you to develop and test AWS applications offline without connecting to AWS.

## Prerequisites

- Docker and Docker Compose installed
- Terraform installed

## Quick Start

### Option 1: Automated Script

```bash
cd terraform
./localstack-deploy.sh
```

This script will:
1. Start LocalStack
2. Wait for it to be ready
3. Enable LocalStack in terraform.tfvars
4. Deploy infrastructure
5. Show outputs and useful commands

### Option 2: Manual Steps

#### 1. Start LocalStack

```bash
cd terraform
docker-compose up -d
```

#### 2. Check LocalStack Health

```bash
curl http://localhost:4566/_localstack/health | jq
```

You should see all services showing as "available" or "running".

#### 3. Enable LocalStack Mode

Edit `terraform.tfvars`:

```hcl
use_localstack      = true
localstack_endpoint = "http://localhost:4566"
```

#### 4. Deploy Infrastructure

```bash
terraform init
terraform apply
```

## Verify Deployment

### Set up AWS CLI for LocalStack

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Create an alias for convenience
alias awslocal='aws --endpoint-url=http://localhost:4566'
```

### Check Resources

```bash
# List VPCs
awslocal ec2 describe-vpcs

# List Subnets
awslocal ec2 describe-subnets

# List Security Groups
awslocal ec2 describe-security-groups

# List ECS Clusters
awslocal ecs list-clusters

# Describe ECS Cluster
awslocal ecs describe-clusters --clusters email-platform-dev

# List Load Balancers
awslocal elbv2 describe-load-balancers

# List CloudWatch Log Groups
awslocal logs describe-log-groups
```

## LocalStack Services Configuration

The `docker-compose.yml` configures these AWS services:

- **ec2** - VPC, Subnets, Security Groups, NAT, IGW
- **ecs** - ECS Cluster, Task Definitions, Services
- **ecr** - Container Registry (for Docker images)
- **elbv2** - Application Load Balancer
- **iam** - IAM Roles and Policies
- **logs** - CloudWatch Logs
- **sqs** - SQS Queues (if you add them)
- **sns** - SNS Topics (if you add them)
- **secretsmanager** - Secrets Manager
- **s3** - S3 Buckets (if you add them)

## What Works in LocalStack

### ✅ Fully Functional

- VPC and networking resource creation
- Subnet creation (public/private)
- Internet Gateway
- Route tables
- Security Groups
- ECS Cluster
- IAM Roles and Policies
- CloudWatch Log Groups
- Application Load Balancer (basic)

### ⚠️ Partially Functional

- NAT Gateways (created but don't route traffic)
- ECS Task Definitions (can register)
- ECS Services (created but tasks don't actually run)
- ALB Target Groups (basic functionality)

### ❌ Not Functional (Free Version)

- Actual container execution
- Container Insights
- Full ALB routing with real traffic
- X-Ray tracing

## LocalStack Pro Features

If you have LocalStack Pro, you get:

- Full ECS Fargate support with actual containers
- Better ALB/ELB support
- Lambda execution
- More services
- Better compatibility

## Use Cases

### ✅ Good For

1. **Terraform Validation**
   ```bash
   # Test your Terraform code without AWS costs
   terraform plan
   terraform apply
   ```

2. **CI/CD Testing**
   ```yaml
   # In GitHub Actions
   - name: Start LocalStack
     run: docker-compose up -d
   - name: Test Infrastructure
     run: terraform apply -auto-approve
   ```

3. **Learning and Experimentation**
   - Practice AWS without charges
   - Learn Terraform safely
   - Experiment with configurations

4. **Development**
   - Quick feedback loop
   - No AWS account needed
   - Faster iteration

### ❌ Not Suitable For

1. **Full Application Testing** - Containers won't actually run
2. **Performance Testing** - Not representative of AWS
3. **Integration Testing** - Limited service interactions
4. **Production-like Environments** - Use real AWS dev environment

## Troubleshooting

### LocalStack Won't Start

```bash
# Check Docker
docker ps

# View LocalStack logs
docker logs email-platform-localstack

# Restart LocalStack
docker-compose restart

# Full restart
docker-compose down
docker-compose up -d
```

### Terraform Can't Connect

```bash
# Verify LocalStack is running
curl http://localhost:4566/_localstack/health

# Check endpoint in terraform.tfvars
cat terraform.tfvars | grep localstack

# Ensure use_localstack is true
```

### Resources Not Creating

```bash
# Check LocalStack logs for errors
docker logs email-platform-localstack -f

# Verify service is available
curl http://localhost:4566/_localstack/health | jq '.services.ecs'

# Try terraform with debug
TF_LOG=DEBUG terraform apply
```

## Switching Between LocalStack and AWS

### Switch to LocalStack

```bash
# 1. Update terraform.tfvars
use_localstack = true

# 2. Apply
terraform apply
```

### Switch to AWS

```bash
# 1. Update terraform.tfvars
use_localstack = false

# 2. Ensure AWS credentials are configured
aws configure

# 3. Apply
terraform apply
```

## Clean Up

### Destroy Infrastructure

```bash
terraform destroy
```

### Stop LocalStack

```bash
docker-compose down
```

### Remove All Data

```bash
# Stop and remove containers
docker-compose down -v

# Remove persistent data
rm -rf localstack-data/
```

## Cost Savings

Using LocalStack for development and testing:

- **No AWS charges** for development
- **No NAT Gateway costs** (~$32/month saved per gateway)
- **No ALB costs** (~$16/month saved)
- **No Fargate costs** (pay per second saved)
- **No data transfer costs**

**Estimated monthly savings**: $50-100+ depending on usage

## Advanced Tips

### 1. Persist Data Between Restarts

Already configured in `docker-compose.yml`:

```yaml
environment:
  - PERSISTENCE=1
  - DATA_DIR=/tmp/localstack/data
volumes:
  - "./localstack-data:/tmp/localstack"
```

### 2. Debug Mode

Already enabled:

```yaml
environment:
  - DEBUG=1
```

View detailed logs:
```bash
docker logs email-platform-localstack -f
```

### 3. Use LocalStack CLI

```bash
# Install
pip install localstack

# Check status
localstack status

# View services
localstack status services
```

### 4. Environment-Specific Configs

Create separate tfvars files:

```bash
# localstack.tfvars
use_localstack = true

# aws.tfvars
use_localstack = false
```

Use them:

```bash
terraform apply -var-file="localstack.tfvars"
terraform apply -var-file="aws.tfvars"
```

## Resources

- [LocalStack Documentation](https://docs.localstack.cloud)
- [LocalStack GitHub](https://github.com/localstack/localstack)
- [Terraform with LocalStack](https://docs.localstack.cloud/user-guide/integrations/terraform/)

## Summary

✅ **Easy to set up** - Just Docker Compose
✅ **Cost-effective** - No AWS charges
✅ **Fast feedback** - Quick iterations
✅ **Safe testing** - No production impact
✅ **CI/CD friendly** - Great for pipelines

⚠️ **Limited** - Not all features work
⚠️ **Not production-like** - Use real AWS for final testing

---

Happy testing! 🚀

