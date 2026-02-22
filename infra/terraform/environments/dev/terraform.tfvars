project_name     = "metainspect"
environment_name = "dev"
aws_region       = "us-east-1"

container_image_tag = "v0.1.0"
deploy_service      = false

vpc_cidr              = "10.42.0.0/16"
public_subnet_a_cidr  = "10.42.0.0/24"
public_subnet_b_cidr  = "10.42.1.0/24"
service_subnet_a_cidr = "10.42.10.0/24"
service_subnet_b_cidr = "10.42.11.0/24"

container_port       = 80
desired_count        = 2
cpu_units            = 512
memory_mib           = 1024
max_upload_bytes     = 20971520
redaction_mode       = "true"
delete_after_process = "true"
log_retention_days   = 14

enable_efs           = true
efs_performance_mode = "generalPurpose"
efs_throughput_mode  = "bursting"

min_count              = 2
max_count              = 4
target_cpu_utilization = 60

sample_images_object_arn = "arn:aws:s3:::demo1-oriebound/metainspect/sample_images_metadata.zip"
