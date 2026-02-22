output "repository_uri" {
  value = module.ecr.repository_uri
}

output "cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "service_subnet_ids" {
  value = module.network.service_subnet_ids
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "efs_file_system_id" {
  value = module.efs.file_system_id
}

output "service_name" {
  value = var.deploy_service ? module.ecs_service[0].service_name : null
}
