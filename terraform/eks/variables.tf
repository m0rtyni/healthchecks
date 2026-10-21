variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "availability_zone_count" {
  type        = number
  description = "Number of availability zones"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDR blocks"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDR blocks"
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to create NAT gateways"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for worker nodes"
}

variable "node_min_size" {
  type        = number
  description = "Minimum worker node count"
}

variable "node_max_size" {
  type        = number
  description = "Maximum worker node count"
}

variable "node_desired_size" {
  type        = number
  description = "Desired worker node count"
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Whether the EKS API endpoint is publicly accessible"
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Whether the EKS API endpoint is privately accessible"
}

variable "tags" {
  type        = map(string)
  description = "Common resource tags"
}

variable "ecr_repository_name" {
  description = "Name of the private ECR repository"
  type        = string
}

variable "ecr_image_mutability" {
  description = "Whether image tags can be overwritten"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_mutability)
    error_message = "ecr_image_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "db_password" {
  description = "Password for the Healthchecks PostgreSQL database"
  type        = string
  sensitive   = true
  nullable    = false
}
