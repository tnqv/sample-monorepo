// ===========================================
// Sample API Task Definition
// ===========================================
// Usage: jsonnet --ext-str IMAGE_TAG=v1.0.0 --ext-str ENVIRONMENT=dev sampleapi.jsonnet

local base = import 'lib/base.libsonnet';

// External variables (passed from CI/CD)
local imageTag = std.extVar('IMAGE_TAG');
local environment = std.extVar('ENVIRONMENT');
local ecrRepository = std.extVar('ECR_REPOSITORY');
local executionRoleArn = std.extVar('EXECUTION_ROLE_ARN');
local taskRoleArn = std.extVar('TASK_ROLE_ARN');
local sqsQueueUrl = std.extVar('SQS_QUEUE_URL');
local awsRegion = std.extVar('AWS_REGION');

// Project configuration
local projectName = 'email-platform';
local serviceName = 'sampleapi';
local containerPort = 8080;

// Environment-specific config
local envConfig = base.envConfig[environment];

// Container definition
local container = base.container(serviceName, '%s:%s' % [ecrRepository, imageTag], {
  port: containerPort,
  
  environment: [
    base.envVar('PORT', containerPort),
    base.envVar('LOG_LEVEL', envConfig.logLevel),
    base.envVar('ENVIRONMENT', environment),
    base.envVar('SQS_QUEUE_URL', sqsQueueUrl),
    base.envVar('AWS_REGION', awsRegion),
  ],
  
  logConfiguration: base.logConfig(projectName, environment, serviceName, awsRegion),
  
  healthCheck: base.healthCheck(
    'wget -q --spider http://localhost:%d/health || exit 1' % containerPort
  ),
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
