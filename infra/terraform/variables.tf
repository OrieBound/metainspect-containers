variable "project_name" {
  type    = string
  default = "metainspect"
}

variable "environment_name" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "container_image_tag" {
  type    = string
  default = "v0.1.0"
}

variable "deploy_service" {
  type        = bool
  default     = false
  description = "Set true only after the ECR image tag exists."
}

# ─── Network ────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.42.0.0/24"
}

variable "public_subnet_b_cidr" {
  type    = string
  default = "10.42.1.0/24"
}

variable "service_subnet_a_cidr" {
  type    = string
  default = "10.42.10.0/24"
}

variable "service_subnet_b_cidr" {
  type    = string
  default = "10.42.11.0/24"
}

# ─── ECS Service ────────────────────────────────────────────────────────────────

variable "container_port" {
  type    = number
  default = 80
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "cpu_units" {
  type    = number
  default = 512
}

variable "memory_mib" {
  type    = number
  default = 1024
}

variable "max_upload_bytes" {
  type    = number
  default = 20971520
}

variable "redaction_mode" {
  type    = string
  default = "true"
}

variable "delete_after_process" {
  type    = string
  default = "true"
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "sample_images_object_arn" {
  type    = string
  default = "arn:aws:s3:::demo1-oriebound/metainspect/sample_images_metadata.zip"
}

# ─── EFS ────────────────────────────────────────────────────────────────────────

variable "enable_efs" {
  type    = bool
  default = true
}

variable "efs_performance_mode" {
  type    = string
  default = "generalPurpose"
}

variable "efs_throughput_mode" {
  type    = string
  default = "bursting"
}

# ─── Autoscaling ────────────────────────────────────────────────────────────────

variable "min_count" {
  type    = number
  default = 2
}

variable "max_count" {
  type    = number
  default = 4
}

variable "target_cpu_utilization" {
  type    = number
  default = 60
}
