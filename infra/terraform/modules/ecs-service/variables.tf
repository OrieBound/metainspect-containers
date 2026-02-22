variable "project_name" {
  type = string
}

variable "environment_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "ecr_repository_uri" {
  type = string
}

variable "container_image_tag" {
  type = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "service_subnet_ids" {
  type = list(string)
}

variable "service_security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
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

variable "enable_efs" {
  type    = bool
  default = true
}

variable "file_system_id" {
  type    = string
  default = ""
}

variable "access_point_id" {
  type    = string
  default = ""
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "sample_images_object_arn" {
  type = string
}
