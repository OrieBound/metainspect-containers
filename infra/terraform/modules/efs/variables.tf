variable "project_name" {
  type = string
}

variable "environment_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "service_subnet_ids" {
  type = list(string)
}

variable "service_security_group_id" {
  type = string
}

variable "efs_performance_mode" {
  type    = string
  default = "generalPurpose"
}

variable "efs_throughput_mode" {
  type    = string
  default = "bursting"
}
