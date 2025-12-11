# Sample Monorepo

A production-ready monorepo demonstrating microservices architecture with ECS Fargate, Terraform infrastructure-as-code, and comprehensive CI/CD pipelines.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Services](#services)
- [Prerequisites](#prerequisites)
- [Important Points](#important-points)
- [Scenario 1: IaC Provisioning for the Platform](#scenario-1-iac-provisioning-for-the-platform)
- [Scenario 2: Release New Version Application](#scenario-2-release-new-version-application)
- [Scenario 3: Monitoring (SLO and Distributed Tracing)](#scenario-3-monitoring-slo-definition-and-distributed-tracing-stacks)
- [License](#license)

---

## Architecture Overview

![Architecture Diagram](images/overall-architecture.png)

### Project Structure

```
sample-monorepo/
├── cmd/                          # Service entrypoints
│   ├── sampleapi/                # HTTP API service
│   │   ├── main.go
│   │   └── Dockerfile
│   └── sampleworker/             # Background worker service
│       ├── main.go
│       └── Dockerfile
├── internal/                     # Shared libraries
│   ├── tracing/                  # OpenTelemetry tracing
│   └── utils/                    # Logging utilities
├── task-definitions/             # ECS task definitions (Jsonnet)
│   ├── lib/base.libsonnet        # Shared task definition library
│   ├── sampleapi.jsonnet
│   └── sampleworker.jsonnet
├── terraform/aws/                # Infrastructure as Code
│   ├── modules/                  # Reusable Terraform modules
│   │   ├── ecs-fargate-service/  # ECS Fargate service module
│   │   └── sqs-queue/            # SQS queue module
│   ├── environments/             # Environment-specific configs
│   │   ├── staging.tfvars
│   │   └── prod.tfvars
│   └── *.tf                      # Main Terraform configs
├── monitoring/                   # Observability stack
│   ├── prometheus/               # Metrics collection
│   ├── grafana/                  # Dashboards & visualization
│   └── promtail/                 # Log aggregation
├── .github/workflows/            # CI/CD pipelines
│   ├── ci.yml                    # Build & test on PRs
│   ├── terraform.yml             # Infrastructure deployment
│   ├── release-sampleapi.yml     # API service release
│   └── release-sampleworker.yml  # Worker service release
└── docker-compose.local.yml      # Local development stack
```

---

## Services

### sampleapi
HTTP API service that:
- Exposes REST endpoints (`/health`, `/api/*`)
- Publishes messages to SQS queue
- Exposes Prometheus metrics on `/metrics`

### sampleworker
Background worker service that:
- Consumes messages from SQS queue
- Processes tasks asynchronously
- Includes distributed tracing with OpenTelemetry
- Exposes Prometheus metrics

---

## Prerequisites

- Go 1.23+
- Docker & Docker Compose
- Terraform 1.13+
- jsonnet CLI (`brew install jsonnet` or `apt-get install jsonnet`)
- AWS CLI v2
- LocalStack (Pro license required for ECS features in CI/CD)

---

### **Important points**:
- The implementation is not running on a real cloud services, so there will be some **limitation**:
  - Using localstack to demo and validate `terraform plan` only, the applied part already done in local, so the github action PR only support showing diff from `plan`, `terraform apply` steps only a mock behaviors
  - Application release requiring applying new task-definitions to ECS services which running in localstack, to update a new task on ECS in localstack via github action, `Docker in Docker` currently not supporting, so applying task definition is only mocking ref
  - Monitoring stacks requiring spin up from mounted volume services stack (with loki, prometheus and jaeger), localstack has some limitation and requiring complex setup, so this part will be set up and run locally

## Scenario 1: IaC provisioning for the Platform

### User Story

> *"As a Backend Engineer, I only need to provide my code and define basic infrastructure configuration (CPU, memory, replicas, autoscaling rules, ALB paths). The platform should handle the rest."*

> *"As a Backend Engineer, I want CI/CD to automatically provision/update infrastructure when I change configurations."*

### What

#### Infrastructure Overview

![terraform-flow](images/terraform-flow-architecture.png)

### Terraform Modules

| Module | Description | Used In | Key Features |
|--------|-------------|---------|--------------|
| `ecs-fargate-service` | ECS Fargate service | `service-*.tf` (Backend Engineer) | ALB integration, auto-scaling, CloudWatch logs, health checks |
| `sqs-queue` | SQS queue with DLQ | `shared-infrastructure.tf` (Devops Team) | Dead letter queue, IAM policies for publishers/consumers |

### Infrastructure Files Overview

| File | Purpose | Responsible Owner |
|------|---------|-------|
| `vpc.tf` | VPC, subnets, NAT gateway | Devops Team |
| `alb.tf` | Application Load Balancer | Devops Team |
| `ecs.tf` | ECS Cluster, IAM roles | Devops Team |
| `shared-infrastructure.tf` | SQS queues, Secrets Manager | Devops Team |
| `service-sampleapi.tf` | API service definition | Backend Engineer |
| `service-sampleworker.tf` | Worker service definition | Backend Engineer |

### Workspaces

Infrastructure uses Terraform workspaces to manage environments:

```bash
# List available workspaces
terraform workspace list

# Switch to staging
terraform workspace select staging

# Switch to production
terraform workspace select prod
```


The infrastructure is organized into two categories:

```
terraform/aws/
├── shared-infrastructure.tf    # Platform team manages (SQS, Secrets)
├── service-sampleapi.tf        # Developer defines (per-service)
├── service-sampleworker.tf     # Developer defines (per-service)
├── ...
└── modules/
    ├── ecs-fargate-service/    # Reusable service module
    └── sqs-queue/              # Reusable queue module
```

| Category | Owner | Examples | File |
|----------|-------|----------|------|
| **Shared Infrastructure** | Devops Team | SQS queues, Secrets Manager, VPC, ALB | `shared-infrastructure.tf` |
| **Service Infrastructure** | Backend Engineers | ECS services, auto-scaling, ALB rules | `service-*.tf` |

#### Shared Infrastructure (`shared-infrastructure.tf`)

Resources shared across all services are managed centrally by the devops team but allow backend engineer to provision:

```hcl
# terraform/aws/shared-infrastructure.tf

# ===========================================
# SQS Queue for Tasks (shared by api → worker)
# ===========================================
module "tasks_queue" {
  source = "./modules/sqs-queue"

  name         = "tasks"
  project_name = var.project_name
  environment  = var.environment

  # Queue configuration
  visibility_timeout_seconds = 300     # 5 minutes
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 20      # Long polling

  # Dead Letter Queue for failed messages
  enable_dlq        = true
  max_receive_count = 3  # Max 3 attempts before moving to DLQ

  # IAM: Grant permissions to ECS task roles
  publisher_role_names = [aws_iam_role.ecs_task_role.name]  # sampleapi can publish
  consumer_role_names  = [aws_iam_role.ecs_task_role.name]  # sampleworker can consume
}

# ===========================================
# Secrets Manager (for sensitive configuration)
# ===========================================
resource "aws_secretsmanager_secret" "worker_secret" {
  name        = "${var.project_name}/${var.environment}/worker-secret"
  description = "Secret key for sampleworker service"
}
```

**Why Shared Infrastructure?**
- **SQS Queues**: Multiple services may publish/consume from the same queue
- **Secrets Manager**: Centralized secret management with rotation support

### Developers provision resources to their own service

#### Step 1: Developer Creates Service Configuration

To add a new service, developers create a Terraform file that uses the `ecs-fargate-service` module:

```hcl
# terraform/aws/service-myservice.tf

locals {
  myservice_config = {
    staging = {
      cpu            = 256
      memory         = 512
      desired_count  = 1
      min_count      = 1
      max_count      = 2
    }
    prod = {
      cpu            = 512
      memory         = 1024
      desired_count  = 2
      min_count      = 2
      max_count      = 10
    }
  }
  myservice = lookup(local.myservice_config, var.environment, local.myservice_config["staging"])
}

module "myservice" {
  source = "./modules/ecs-fargate-service"

  name         = "myservice"
  project_name = var.project_name
  environment  = var.environment
  
  # Resource configuration
  cpu           = local.myservice.cpu
  memory        = local.myservice.memory
  desired_count = local.myservice.desired_count
  
  # Auto Scaling
  enable_autoscaling = true
  min_count          = local.myservice.min_count
  max_count          = local.myservice.max_count
  
  # Load Balancer (optional)
  enable_load_balancer = true
  lb_path_patterns     = ["/api/myservice/*"]
  lb_health_check_path = "/health"
  
  # ... other required fields
}
```

#### Step 2: Developer Creates Task Definition (Jsonnet)

```jsonnet
// task-definitions/myservice.jsonnet
local base = import 'lib/base.libsonnet';

local container = base.container('myservice', '%s:%s' % [ecrRepository, imageTag], {
  port: 8080,
  environment: [
    base.envVar('LOG_LEVEL', envConfig.logLevel),
    base.envVar('ENVIRONMENT', environment),
  ],
  healthCheck: base.healthCheck('wget -q --spider http://localhost:8080/health || exit 1'),
});

base.taskDefinition('myservice', [container], { cpu: 256, memory: 512 })
```

#### Step 3: CI/CD Provisions Infrastructure

```
PR Created → terraform.yml triggered
    │
    ├── terraform plan (staging) → Comment on PR with diff
    ├── terraform plan (prod)    → Comment on PR with diff
    │
PR Merged → Manual workflow_dispatch
    │
    ├── Apply staging (auto)
    └── Apply prod (requires approval)
```

### Automated IaC with CI/CD Pipeline: `terraform.yml`

![terraform interaction](images/terraform-interaction.png)

| Trigger | Action | Environment |
|---------|--------|-------------|
| PR to `main` | `terraform plan` | staging + prod (parallel) |
| `workflow_dispatch` | `terraform apply` | staging (auto) or prod (approval required) |

**Workflow Diagram:**

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│    PR Open    │────▶│    Plan PR    │────▶│  Comment on   │
│               │     │   (matrix)    │     │      PR       │
└───────────────┘     └───────────────┘     └───────────────┘

┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   workflow    │────▶│     Apply     │────▶│     Apply     │
│   dispatch    │     │    Staging    │     │     Prod      │
└───────────────┘     └───────────────┘     └───────────────┘
                                                    │
                                            (approval required)
```

### Pull Request Example:
- Create a new service `terraform plan`: https://github.com/tnqv/sample-monorepo/pull/11

---

## Scenario 2: Release New Version Application

### User Story

> *"As a Backend Engineer, when I merge code to the release branch, CI/CD should automatically deploy my application to staging, and after approval, to production."*

![terraform-flow](./images/ci-cd-release-application.png)

### CI/CD Pipelines

| Workflow | Service | Trigger |
|----------|---------|---------|
| `release-sampleapi.yml` | sampleapi | Push to `release` + paths `cmd/sampleapi/**` |
| `release-sampleworker.yml` | sampleworker | Push to `release` + paths `cmd/sampleworker/**` |

### How It Works

#### Step 1: Backend Developers Open a new PR (with feature branch)

Code changes to `cmd/sampleapi/**` or `task-definitions/sampleapi.jsonnet` trigger CI checks:

```
Developer creates feature branch & opens PR
    │
    ▼
┌───────────────────────────────────────────────────────┐
│                 CI Pipeline (ci.yml)                  │
├───────────────────────────────────────────────────────┤
│                                                       │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│   │    Lint     │  │  Unit Test  │  │    Build    │   │
│   │ (golangci)  │  │  (go test)  │  │    Check    │   │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │
│          │                │                │          │
│          └────────────────┼────────────────┘          │
│                           │                           │
│                           ▼                           │
│                    ┌─────────────┐                    │
│                    │  All Pass?  │                    │
│                    └──────┬──────┘                    │
│                           │                           │
└───────────────────────────┼───────────────────────────┘
                            │
                            ▼
                     ┌─────────────┐
                     │  PR Ready   │  ← Code review & merge to `main`
                     │  to Merge   │
                     └─────────────┘
```

**CI Checks (`ci.yml`) include:**

| Job | Tool | Description |
|-----|------|-------------|
| **Lint** | `golangci-lint` | Go code style, best practices, static analysis |
| **Test** | `go test -race` | Unit tests with race detection + coverage |
| **Build** | Docker Buildx | Verify Docker images can be built |
...

#### Step 2: Merge to `main` and Release

After PR is approved and merged to `main`:

```
Merge PR to 'main' → Push 'main' to 'release' branch
    │
    ▼
┌───────────────────────────────────────────────────────┐
│            Release Pipeline (release-*.yml)           │
├───────────────────────────────────────────────────────┤
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Build & Push Image                 │  │
│  ├─────────────────────────────────────────────────┤  │
│  │  1. Generate image tag (commit + timestamp)     │  │
│  │     └── sampleapi-abc123-20241211120000         │  │
│  │  2. Build Docker image from Dockerfile          │  │
│  │  3. Tag image for ECR                           │  │
│  │  4. Push to LocalStack ECR                      │  │
│  └────────────────────┬────────────────────────────┘  │
│                       │                               │
│                       ▼                               │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Deploy Staging (auto)              │  │
│  ├─────────────────────────────────────────────────┤  │
│  │  1. Render task definition (Jsonnet)            │  │
│  │  2. Register task definition                    │  │
│  │  3. Update ECS service                          │  │
│  └────────────────────┬────────────────────────────┘  │
│                       │                               │
│                       ▼                               │
│  ┌─────────────────────────────────────────────────┐  │
│  │           Approval Required (GitHub)            │  │
│  │           ← Manual approval needed              │  │
│  └────────────────────┬────────────────────────────┘  │
│                       │                               │
│                       ▼                               │
│  ┌─────────────────────────────────────────────────┐  │
│  │            Deploy Prod (after approval)         │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
└───────────────────────────────────────────────────────┘
```

#### During `Deploy Staging`

##### Step 3: Task Definition Rendering

The release pipeline uses Jsonnet to render task definitions with environment-specific values:

```bash
jsonnet \
  --ext-str IMAGE_TAG="sampleapi-abc123-20241211" \
  --ext-str ENVIRONMENT="staging" \
  --ext-str ECR_REPOSITORY="..." \
  --ext-str EXECUTION_ROLE_ARN="..." \
  --ext-str TASK_ROLE_ARN="..." \
  --ext-str SQS_QUEUE_URL="..." \
  sampleapi.jsonnet > task-definition.json
```

##### Step 4: ECS Service Update

```bash
# Register new task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Update service with new task definition
aws ecs update-service \
  --cluster email-platform-staging \
  --service email-platform-staging-sampleapi \
  --task-definition <new-task-def-arn> \
  --force-new-deployment
```

*Note: this step is mocking with localstack, `update-service` requiring `Docker in Docker`, but currently it's not supporting in Github Action


### Release pipeline examples:
- Github Action: https://github.com/tnqv/sample-monorepo/actions/runs/20109325967

---

## Scenario 3: Monitoring (SLO Definition and Distributed Tracing Stacks)

### User Story

> *"As a Product Developer, I need to know if my application is running and healthy."*

> *"As a Product Developer, I want to collect some abnormal metrics that affect the application's performance as quickly as possible.."*

> *"As a Product Developer, when something goes wrong, I want to trace the request flow across services to find the root cause."*

> *"As the Devops Team, I need to have bird's-eye view to the overall for the Platform"*

### How

The monitoring stack provides three pillars of observability:

```
┌───────────────────────────────────────────────────────────────┐
│                     Observability Stack                       │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│    ┌──────────┐    ┌──────────┐    ┌──────────┐               │
│    │  Metrics │    │   Logs   │    │  Traces  │               │
│    │          │    │          │    │          │               │
│    │Prometheus│    │   Loki   │    │  Jaeger  │               │
│    └────┬─────┘    └────┬─────┘    └────┬─────┘               │
│         │               │               │                     │
│         └───────────────┼───────────────┘                     │
│                         │                                     │
│                         ▼                                     │
│                 ┌──────────────┐                              │
│                 │   Grafana    │                              │
│                 │  Dashboards  │                              │
│                 └──────────────┘                              │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

#### 1. Metrics (Prometheus)

Services expose metrics at `/metrics` endpoint:

```go
// Example metrics in sampleapi
http_requests_total{method="GET", endpoint="/health", status="200"}
http_request_duration_seconds{method="GET", endpoint="/health"}
```

**Key SLIs tracked:**
- Request latency (p50, p95, p99)
- Request throughput (requests/sec)
- Error rate (4xx, 5xx)
- Go runtime metrics (goroutines, memory, GC)

#### 2. Logs (Loki + Promtail)

Promtail collects container logs and sends them to Loki with labels:

```yaml
# Log labels
job: sampleworker
container: sampleworker
trace_id: abc123  # Correlated with traces
```

**Querying logs in Grafana:**
```logql
{job="sampleworker"} |= "error"
{job="sampleapi"} | json | status >= 500
{job="sampleworker"} |= "trace_id=abc123"
```

#### 3. Traces (Jaeger + OpenTelemetry)

Services are instrumented with OpenTelemetry to capture distributed traces:

```go
// Example trace in sampleworker
ctx, span := tracing.StartSpan(ctx, "ProcessTask")
defer span.End()

// Log with trace correlation
utils.LogWithTrace(ctx).Info("Processing task", "task_id", taskID)
```

**Trace attributes:**
- `service.name`: Service identifier
- `environment`: staging/prod
- `host.name`: Container ID
- `trace_id`, `span_id`: For log correlation

### Local Development Setup

1. **Start the monitoring stack:**
   ```bash
   docker-compose -f docker-compose.local.yml up -d
   ```

2. **Access services:**

   | Service    | URL                          | Credentials |
   |------------|------------------------------|-------------|
   | Prometheus | http://localhost:9090        | N/A |
   | Grafana    | http://localhost:3000        | admin/admin |
   | Jaeger UI  | http://localhost:16686       | N/A |
   | Loki       | http://localhost:3100        | N/A |

3. **Run services locally:**
   ```bash
   # Terminal 1: API
   cd cmd/sampleapi && go run main.go
   
   # Terminal 2: Worker
   cd cmd/sampleworker && go run main.go
   ```

4. **Generate test traffic:**
   ```bash
   # Health check
   curl http://localhost:8080/health
   
   # Generate load
   for i in {1..100}; do curl -s http://localhost:8080/health > /dev/null; done
   ```

### Pre-built Dashboards

| Dashboard | File | Description |
|-----------|------|-------------|
| Services Overview | `services-overview.json` | Real-time health, request rates, error rates |
| SLO Dashboard | `slo-dashboard.json` | SLI metrics, error budgets, latency percentiles |

### Correlating Logs and Traces

When investigating an issue:

1. **Find the trace in Jaeger** → Note the `trace_id`
2. **Search logs in Grafana/Loki:**
   ```logql
   {job="sampleworker"} |= "trace_id=<your-trace-id>"
   ```
3. **View the complete request flow** with timing for each span

### SLO Definitions

| SLI | Target | Measurement |
|-----|--------|-------------|
| Availability | 99.9% | `sum(rate(http_requests_total{status!~"5.."})) / sum(rate(http_requests_total))` |
| Latency (p99) | < 500ms | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` |
| Error Rate | < 0.1% | `sum(rate(http_requests_total{status=~"5.."})) / sum(rate(http_requests_total))` |
