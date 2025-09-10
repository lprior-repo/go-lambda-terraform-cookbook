# Bootstrap infrastructure for Go Lambda Terraform Cookbook
# This creates the OIDC provider, S3 backend, and IAM roles needed for GitHub Actions

terraform {
  required_version = ">= 1.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "bootstrap"
    }
  }
}

locals {
  # GitHub repository details
  github_org  = split("/", var.github_repository)[0]
  github_repo = split("/", var.github_repository)[1]

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "bootstrap"
  }
}

# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = local.common_tags
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket              = "${var.project_name}-terraform-state-${var.aws_region}-${random_string.bucket_suffix.result}"
  object_lock_enabled = true

  tags = local.common_tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "terraform_state_pab" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_lifecycle" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "state_lifecycle"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 object locking for Terraform state (instead of DynamoDB)
resource "aws_s3_bucket_object_lock_configuration" "terraform_state_lock" {
  depends_on = [aws_s3_bucket_versioning.terraform_state_versioning]

  bucket = aws_s3_bucket.terraform_state.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 1
    }
  }
}

# IAM role for GitHub Actions (Development)
resource "aws_iam_role" "github_actions_dev" {
  name = "${var.project_name}-github-actions-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repository}:ref:refs/heads/develop",
              "repo:${var.github_repository}:pull_request"
            ]
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM role for GitHub Actions (Staging)
resource "aws_iam_role" "github_actions_staging" {
  name = "${var.project_name}-github-actions-staging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM role for GitHub Actions (Production)
resource "aws_iam_role" "github_actions_prod" {
  name = "${var.project_name}-github-actions-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda and API Gateway deployment
resource "aws_iam_policy" "serverless_deployment" {
  name        = "${var.project_name}-serverless-deployment"
  description = "Policy for deploying serverless applications"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 permissions for Lambda artifacts
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:GetPublicAccessBlock",
          "s3:ListBucket",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutPublicAccessBlock",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-lambda-artifacts-*",
          "arn:aws:s3:::${var.project_name}-lambda-artifacts-*/*"
        ]
      },
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:TagResource",
          "lambda:UntagResource"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${var.project_name}-*"
      },
      # API Gateway permissions
      {
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = "*"
      },
      # IAM permissions for Lambda execution role
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = "arn:aws:iam::*:role/${var.project_name}-*"
      },
      # CloudWatch Logs permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-*"
      },
      # Archive provider permissions
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::*/archive_*"
      },
      # Random provider permissions (no AWS resources)
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Terraform state access
resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.project_name}-terraform-state-access"
  description = "Policy for accessing Terraform state in S3 and DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
    ]
  })

  tags = local.common_tags
}

# Attach policies to development role
resource "aws_iam_role_policy_attachment" "github_actions_dev_serverless" {
  policy_arn = aws_iam_policy.serverless_deployment.arn
  role       = aws_iam_role.github_actions_dev.name
}

resource "aws_iam_role_policy_attachment" "github_actions_dev_state" {
  policy_arn = aws_iam_policy.terraform_state_access.arn
  role       = aws_iam_role.github_actions_dev.name
}

# Attach policies to staging role
resource "aws_iam_role_policy_attachment" "github_actions_staging_serverless" {
  policy_arn = aws_iam_policy.serverless_deployment.arn
  role       = aws_iam_role.github_actions_staging.name
}

resource "aws_iam_role_policy_attachment" "github_actions_staging_state" {
  policy_arn = aws_iam_policy.terraform_state_access.arn
  role       = aws_iam_role.github_actions_staging.name
}

# Attach policies to production role
resource "aws_iam_role_policy_attachment" "github_actions_prod_serverless" {
  policy_arn = aws_iam_policy.serverless_deployment.arn
  role       = aws_iam_role.github_actions_prod.name
}

resource "aws_iam_role_policy_attachment" "github_actions_prod_state" {
  policy_arn = aws_iam_policy.terraform_state_access.arn
  role       = aws_iam_role.github_actions_prod.name
}