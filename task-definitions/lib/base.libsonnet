// ===========================================
// Base Task Definition Library
// ===========================================
// Shared functions and defaults for ECS task definitions

{
  // Default values
  defaults:: {
    cpu: '256',
    memory: '512',
    networkMode: 'awsvpc',
    requiresCompatibilities: ['FARGATE'],
    logDriver: 'awslogs',
  },

  // Environment configuration
  envConfig:: {
    dev: {
      logLevel: 'debug',
      region: 'us-east-1',
    },
    staging: {
      logLevel: 'info',
      region: 'us-east-1',
    },
    prod: {
      logLevel: 'warn',
      region: 'us-east-1',
    },
  },

  // Helper: Create environment variable
  envVar(name, value):: {
    name: name,
    value: std.toString(value),
  },

  // Helper: Create secret reference
  secret(name, arn):: {
    name: name,
    valueFrom: arn,
  },

  // Helper: Create log configuration
  logConfig(projectName, environment, serviceName, region):: {
    logDriver: $.defaults.logDriver,
    options: {
      'awslogs-group': '/ecs/%s-%s' % [projectName, environment],
      'awslogs-region': region,
      'awslogs-stream-prefix': serviceName,
    },
  },

  // Helper: Create port mapping
  portMapping(containerPort, hostPort=null, protocol='tcp'):: {
    containerPort: containerPort,
    hostPort: if hostPort != null then hostPort else containerPort,
    protocol: protocol,
  },

  // Helper: Create health check
  healthCheck(command, interval=30, timeout=5, retries=3, startPeriod=60):: {
    command: if std.isArray(command) then command else ['CMD-SHELL', command],
    interval: interval,
    timeout: timeout,
    retries: retries,
    startPeriod: startPeriod,
  },

  // Base container definition
  container(name, image, config={}):: {
    name: name,
    image: image,
    essential: true,
    portMappings: if std.objectHas(config, 'port') then [$.portMapping(config.port)] else [],
    environment: if std.objectHas(config, 'environment') then config.environment else [],
    secrets: if std.objectHas(config, 'secrets') then config.secrets else [],
    logConfiguration: if std.objectHas(config, 'logConfiguration') then config.logConfiguration else {},
    healthCheck: if std.objectHas(config, 'healthCheck') then config.healthCheck else null,
  },

  // Base task definition
  taskDefinition(family, containers, config={}):: {
    family: family,
    networkMode: $.defaults.networkMode,
    requiresCompatibilities: $.defaults.requiresCompatibilities,
    cpu: if std.objectHas(config, 'cpu') then std.toString(config.cpu) else $.defaults.cpu,
    memory: if std.objectHas(config, 'memory') then std.toString(config.memory) else $.defaults.memory,
    executionRoleArn: if std.objectHas(config, 'executionRoleArn') then config.executionRoleArn else error 'executionRoleArn is required',
    taskRoleArn: if std.objectHas(config, 'taskRoleArn') then config.taskRoleArn else error 'taskRoleArn is required',
    containerDefinitions: containers,
  },
}

