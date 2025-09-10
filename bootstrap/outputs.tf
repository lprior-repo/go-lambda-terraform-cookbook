# Outputs for bootstrap infrastructure

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_region" {
  description = "AWS region of the Terraform state bucket"
  value       = var.aws_region
}

output "github_actions_role_dev_arn" {
  description = "ARN of the GitHub Actions role for development"
  value       = aws_iam_role.github_actions_dev.arn
}

output "github_actions_role_staging_arn" {
  description = "ARN of the GitHub Actions role for staging"
  value       = aws_iam_role.github_actions_staging.arn
}

output "github_actions_role_prod_arn" {
  description = "ARN of the GitHub Actions role for production" 
  value       = aws_iam_role.github_actions_prod.arn
}

output "setup_commands" {
  description = "Commands to run after bootstrap deployment"
  value = <<-EOT
    # Update your Terraform backend configuration:
    # Add this to your terraform/backend.tf file:
    
    terraform {
      backend "s3" {
        bucket = "${aws_s3_bucket.terraform_state.bucket}"
        key    = "terraform.tfstate"
        region = "${var.aws_region}"
      }
    }
    
    # Add these secrets to your GitHub repository:
    AWS_ROLE_ARN_DEV     = "${aws_iam_role.github_actions_dev.arn}"
    AWS_ROLE_ARN_STAGING = "${aws_iam_role.github_actions_staging.arn}"  
    AWS_ROLE_ARN_PROD    = "${aws_iam_role.github_actions_prod.arn}"
  EOT
}