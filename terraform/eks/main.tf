data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    var.availability_zone_count
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = false

  map_public_ip_on_launch = true

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      name           = "${var.cluster_name}-nodes"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = module.vpc.public_subnets

      labels = {
        role = "application"
      }
    }
  }

  tags = var.tags
}
