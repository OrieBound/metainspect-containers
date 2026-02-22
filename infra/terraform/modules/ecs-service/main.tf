data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ─── CloudWatch Log Group ───────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}-${var.environment_name}"
  retention_in_days = var.log_retention_days
}

# ─── IAM: Task Execution Role ──────────────────────────────────────────────────

resource "aws_iam_role" "task_execution" {
  name_prefix = "${var.project_name}-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ─── IAM: Task Role ────────────────────────────────────────────────────────────

resource "aws_iam_role" "task" {
  name_prefix = "${var.project_name}-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "efs_access" {
  name = "efs-client-access"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite",
        "elasticfilesystem:ClientRootAccess",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "s3_sample_images" {
  name = "sample-images-s3-read"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = var.sample_images_object_arn
    }]
  })
}

# ─── Task Definition ───────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project_name}-task-${var.environment_name}"
  cpu                      = var.cpu_units
  memory                   = var.memory_mib
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  dynamic "volume" {
    for_each = var.enable_efs ? [1] : []
    content {
      name = "shared-volume"
      efs_volume_configuration {
        file_system_id     = var.file_system_id
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = var.access_point_id
          iam             = "ENABLED"
        }
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container"
      image     = "${var.ecr_repository_uri}:${var.container_image_tag}"
      essential = true

      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      mountPoints = var.enable_efs ? [{
        sourceVolume  = "shared-volume"
        containerPath = "/efs/shared"
        readOnly      = false
      }] : []

      environment = [
        { name = "MAX_UPLOAD_BYTES", value = tostring(var.max_upload_bytes) },
        { name = "REDACTION_MODE", value = var.redaction_mode },
        { name = "DELETE_AFTER_PROCESS", value = var.delete_after_process },
        { name = "SHARED_DIR", value = var.enable_efs ? "/efs/shared" : "/tmp/metainspect" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ─── ECS Service ────────────────────────────────────────────────────────────────

resource "aws_ecs_service" "this" {
  name                              = var.service_name
  cluster                           = var.cluster_name
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 60
  enable_ecs_managed_tags           = true
  task_definition                   = aws_ecs_task_definition.this.arn

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    assign_public_ip = false
    security_groups  = [var.service_security_group_id]
    subnets          = var.service_subnet_ids
  }

  load_balancer {
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
    target_group_arn = var.target_group_arn
  }
}
