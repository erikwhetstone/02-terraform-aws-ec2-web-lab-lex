provider "aws" {
  region = var.aws_region

  # Stop before any AWS operation if the credentials belong to a different
  # account. A check block alone only produces a warning.
  allowed_account_ids = [var.expected_aws_account_id]

  default_tags {
    tags = {
      ManagedBy    = "Terraform"
      Purpose      = "Training"
      Project      = var.project_name
      Lab          = "ec2-web"
      Owner        = var.owner_name
      DeploymentId = var.deployment_id
      Environment  = "Lab"
      CreatedFrom  = "terraform-aws-security-training"
      ExpiresOn    = var.expiration_date
    }
  }
}
