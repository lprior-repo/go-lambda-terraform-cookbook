# Variables for bootstrap infrastructure

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "go-lambda-terraform-cookbook"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository in the format 'owner/repo'"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$", var.github_repository))
    error_message = "GitHub repository must be in the format 'owner/repo'."
  }
}