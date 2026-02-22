variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

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
