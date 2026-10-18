resource "aws_ecr_repository" "healthchecks" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.ecr_image_mutability
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
  tags = var.tags
}

output "ecr_repository_url" {
  description = "URL of the private ECR repository"
  value       = aws_ecr_repository.healthchecks.repository_url
}
