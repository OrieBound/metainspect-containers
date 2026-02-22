variable "project_name" {
  type = string
}

variable "environment_name" {
  type = string
}

variable "aws_region" {
  type = string
}

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
