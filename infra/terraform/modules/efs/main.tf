resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-efs-"
  description = "${var.project_name} EFS SG"
  vpc_id      = var.vpc_id

  ingress {
    protocol                 = "tcp"
    from_port                = 2049
    to_port                  = 2049
    security_groups          = [var.service_security_group_id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_efs_file_system" "this" {
  encrypted        = true
  performance_mode = var.efs_performance_mode
  throughput_mode   = var.efs_throughput_mode

  tags = { Name = "${var.project_name}-efs-${var.environment_name}" }
}

resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.service_subnet_ids[0]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.service_subnet_ids[1]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/metainspect"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }
}
