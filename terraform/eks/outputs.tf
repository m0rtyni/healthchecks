output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "rds_endpoint" {
  description = "PostgreSQL endpoint for Healthchecks"
  value       = aws_db_instance.healthchecks.address
}

output "rds_port" {
  description = "PostgreSQL port"
  value       = aws_db_instance.healthchecks.port
}
