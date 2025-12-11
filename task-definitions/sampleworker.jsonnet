// ===========================================
// Sample Worker Task Definition
// ===========================================
// Usage: jsonnet --ext-str IMAGE_TAG=v1.0.0 --ext-str ENVIRONMENT=dev sampleworker.jsonnet

local base = import 'lib/base.libsonnet';

// External variables (passed from CI/CD)
local imageTag = std.extVar('IMAGE_TAG');
local environment = std.extVar('ENVIRONMENT');
local ecrRepository = std.extVar('ECR_REPOSITORY');
local executionRoleArn = std.extVar('EXECUTION_ROLE_ARN');
local taskRoleArn = std.extVar('TASK_ROLE_ARN');
local sqsQueueUrl = std.extVar('SQS_QUEUE_URL');
local sqsDlqUrl = std.extVar('SQS_DLQ_URL');
local awsRegion = std.extVar('AWS_REGION');
local secretArn = std.extVar('SECRET_ARN');
local sesSenderEmail = std.extVar('SES_SENDER_EMAIL');

// Project configuration
local projectName = 'email-platform';
local serviceName = 'sampleworker';

// Environment-specific config
local envConfig = base.envConfig[environment];

// Worker-specific config per environment
local workerConfig = {
  dev: { interval: '5s', concurrency: 2 },
  staging: { interval: '10s', concurrency: 5 },
  prod: { interval: '10s', concurrency: 10 },
};

local workerEnvConfig = workerConfig[environment];

// Container definition (no port for workers)
local container = base.container(serviceName, '%s:%s' % [ecrRepository, imageTag], {
  environment: [
    base.envVar('LOG_LEVEL', envConfig.logLevel),
    base.envVar('ENVIRONMENT', environment),
    base.envVar('WORKER_INTERVAL', workerEnvConfig.interval),
    base.envVar('WORKER_CONCURRENCY', workerEnvConfig.concurrency),
    base.envVar('SQS_QUEUE_URL', sqsQueueUrl),
    base.envVar('SQS_DLQ_URL', sqsDlqUrl),
    base.envVar('AWS_REGION', awsRegion),
    base.envVar('SES_SENDER_EMAIL', sesSenderEmail),
  ],
  
  secrets: [
    base.secret('SECRET_KEY', secretArn),
  ],
  
  logConfiguration: base.logConfig(projectName, environment, serviceName, awsRegion),
});

// Task definition
base.taskDefinition(
  '%s-%s-%s' % [projectName, environment, serviceName],
  [container],
  {
    cpu: 256,
    memory: 512,
    executionRoleArn: executionRoleArn,
    taskRoleArn: taskRoleArn,
  }
)

