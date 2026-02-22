module "network" {
  source = "./modules/network"

  project_name          = var.project_name
  environment_name      = var.environment_name
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  service_subnet_a_cidr = var.service_subnet_a_cidr
  service_subnet_b_cidr = var.service_subnet_b_cidr
}

module "ecr" {
  source = "./modules/ecr"

  project_name     = var.project_name
  environment_name = var.environment_name
}

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  project_name     = var.project_name
  environment_name = var.environment_name
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment_name  = var.environment_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  container_port    = var.container_port
  health_check_path = "/health"
}

module "efs" {
  source = "./modules/efs"

  project_name              = var.project_name
  environment_name          = var.environment_name
  vpc_id                    = module.network.vpc_id
  service_subnet_ids        = module.network.service_subnet_ids
  service_security_group_id = module.alb.service_security_group_id
  efs_performance_mode      = var.efs_performance_mode
  efs_throughput_mode        = var.efs_throughput_mode
}

module "ecs_service" {
  source = "./modules/ecs-service"
  count  = var.deploy_service ? 1 : 0

  project_name              = var.project_name
  environment_name          = var.environment_name
  cluster_name              = module.ecs_cluster.cluster_name
  service_name              = "${var.project_name}-svc-${var.environment_name}"
  ecr_repository_uri        = module.ecr.repository_uri
  container_image_tag       = var.container_image_tag
  container_port            = var.container_port
  service_subnet_ids        = module.network.service_subnet_ids
  service_security_group_id = module.alb.service_security_group_id
  target_group_arn          = module.alb.target_group_arn
  desired_count             = var.desired_count
  cpu_units                 = var.cpu_units
  memory_mib                = var.memory_mib
  max_upload_bytes          = var.max_upload_bytes
  redaction_mode            = var.redaction_mode
  delete_after_process      = var.delete_after_process
  enable_efs                = var.enable_efs
  file_system_id            = module.efs.file_system_id
  access_point_id           = module.efs.access_point_id
  log_retention_days        = var.log_retention_days
  sample_images_object_arn  = var.sample_images_object_arn
}

module "autoscaling" {
  source = "./modules/autoscaling"
  count  = var.deploy_service ? 1 : 0

  cluster_name           = module.ecs_cluster.cluster_name
  service_name           = module.ecs_service[0].service_name
  min_count              = var.min_count
  max_count              = var.max_count
  target_cpu_utilization = var.target_cpu_utilization
}
