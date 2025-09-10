# Go Lambda Terraform Cookbook - Setup Guide

This guide walks you through setting up the complete infrastructure and CI/CD pipeline for deploying serverless Go applications on AWS using Terraform and AWS SAM.

## Prerequisites

Before starting, ensure you have the following tools installed:

- [AWS CLI](https://aws.amazon.com/cli/) v2.x
- [Terraform](https://www.terraform.io/downloads.html) v1.13.1+
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
- [Go](https://golang.org/dl/) v1.23.1+
- [Git](https://git-scm.com/downloads)

## Step 1: AWS Account Setup

1. **Create or use an existing AWS account**
2. **Configure AWS CLI with administrative privileges**:
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, region (e.g., us-east-1), and output format (json)
   ```

3. **Verify AWS CLI configuration**:
   ```bash
   aws sts get-caller-identity
   ```

## Step 2: Fork and Clone Repository

1. **Fork this repository** to your GitHub account
2. **Clone your fork locally**:
   ```bash
   git clone https://github.com/YOUR_GITHUB_USERNAME/go-lambda-terraform-cookbook.git
   cd go-lambda-terraform-cookbook
   ```

## Step 3: Bootstrap Infrastructure (One-time Setup)

The bootstrap process creates the necessary infrastructure for OIDC authentication, Terraform state management, and IAM roles.

### 3.1 Deploy Bootstrap Infrastructure

```bash
cd bootstrap

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan -var="github_repository=YOUR_GITHUB_USERNAME/go-lambda-terraform-cookbook"

# Deploy the bootstrap infrastructure
terraform apply -var="github_repository=YOUR_GITHUB_USERNAME/go-lambda-terraform-cookbook"
```

**Important**: Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

### 3.2 Save Bootstrap Outputs

After successful deployment, save the outputs:

```bash
# Display all outputs
terraform output

# Save specific outputs for later use
terraform output terraform_state_bucket
terraform output github_actions_role_dev_arn
terraform output github_actions_role_staging_arn  
terraform output github_actions_role_prod_arn
```

## Step 4: Configure Terraform Backend

### 4.1 Update Backend Configuration

Edit `terraform/backend.tf` and uncomment the backend configuration, replacing the placeholder with the actual S3 bucket name from the bootstrap output:

```hcl
terraform {
  backend "s3" {
    bucket = "go-lambda-terraform-cookbook-terraform-state-us-east-1-abc12345"  # Use actual bucket name
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
```

### 4.2 Initialize Main Terraform Configuration

```bash
cd ../terraform

# Initialize with the new backend
terraform init

# You may be prompted to migrate existing state - answer 'yes' if applicable
```

## Step 5: GitHub Repository Secrets Setup

Add the following secrets to your GitHub repository:

1. **Go to your GitHub repository** → Settings → Secrets and variables → Actions
2. **Click "New repository secret"** and add each of the following:

| Secret Name | Value | Description |
|------------|--------|-------------|
| `AWS_ROLE_ARN_DEV` | `arn:aws:iam::ACCOUNT:role/PROJECT-github-actions-dev` | Development environment role |
| `AWS_ROLE_ARN_STAGING` | `arn:aws:iam::ACCOUNT:role/PROJECT-github-actions-staging` | Staging environment role |
| `AWS_ROLE_ARN_PROD` | `arn:aws:iam::ACCOUNT:role/PROJECT-github-actions-prod` | Production environment role |

**Note**: Get the exact ARN values from the bootstrap terraform output.

## Step 6: Enable GitHub Actions Deployment (Optional)

If you want to enable automatic deployment via GitHub Actions:

### 6.1 Enable Deploy Workflow

```bash
# Rename the disabled deploy workflow
mv .github/workflows/deploy.yml.disabled .github/workflows/deploy.yml
```

### 6.2 Update Workflow Configuration

Edit `.github/workflows/deploy.yml` and verify:
- AWS region matches your setup
- Environment names match your preferences
- Branch protection rules align with your workflow

### 6.3 Test Deployment

```bash
# Commit and push changes to trigger CI
git add .
git commit -m "feat: enable deployment workflow"
git push origin main
```

## Step 7: Local Development with SAM

### 7.1 Test SAM Build

```bash
# Build the application locally
sam build

# Test the function locally
sam local invoke --event events/test-event.json

# Start local API Gateway
sam local start-api
```

### 7.2 Create Test Events

Create test events for local development:

```bash
mkdir -p events
```

Create `events/test-event.json`:
```json
{
  "httpMethod": "GET",
  "path": "/",
  "headers": {
    "Content-Type": "application/json"
  },
  "queryStringParameters": {
    "name": "SAM"
  },
  "body": null
}
```

## Step 8: Manual Deployment (Alternative to GitHub Actions)

If you prefer manual deployment or want to test locally:

### 8.1 Deploy with Terraform

```bash
cd terraform

# Plan the deployment
terraform plan -var="environment=dev"

# Apply the changes
terraform apply -var="environment=dev"

# Get the API Gateway URL
terraform output api_gateway_url
```

### 8.2 Deploy with SAM

```bash
# Deploy using SAM
sam deploy --guided

# Follow the prompts to configure deployment
```

## Step 9: Testing Your Deployment

### 9.1 Test API Gateway Endpoint

```bash
# Get the API Gateway URL from Terraform output
ENDPOINT=$(terraform output -raw api_gateway_url)

# Test the endpoint
curl $ENDPOINT
```

### 9.2 Monitor CloudWatch Logs

```bash
# View Lambda function logs
sam logs -n GoLambdaFunction --stack-name YOUR_STACK_NAME --tail

# Or use AWS CLI
aws logs tail /aws/lambda/FUNCTION_NAME --follow
```

## Step 10: Cleanup (Optional)

To tear down all resources:

### 10.1 Destroy Main Infrastructure

```bash
cd terraform
terraform destroy -var="environment=dev"
```

### 10.2 Destroy Bootstrap Infrastructure

```bash
cd ../bootstrap
terraform destroy -var="github_repository=YOUR_GITHUB_USERNAME/go-lambda-terraform-cookbook"
```

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure your AWS credentials have sufficient permissions
2. **State Lock Issues**: If using S3 object locking, wait for lock expiration or contact AWS support
3. **GitHub Actions Failures**: Check that repository secrets are correctly configured
4. **SAM Build Failures**: Ensure Go is installed and accessible in PATH

### Getting Help

- Check the [AWS Documentation](https://docs.aws.amazon.com/)
- Review [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Consult [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)

## Security Considerations

- **Least Privilege**: IAM roles follow least privilege principle
- **OIDC Authentication**: Uses GitHub OIDC instead of long-lived access keys
- **Encryption**: All S3 buckets and DynamoDB tables use encryption at rest
- **Object Locking**: Terraform state uses S3 object locking for protection
- **Public Access**: All S3 buckets block public access by default

## Architecture Overview

This setup creates:

- **OIDC Provider**: For secure GitHub Actions authentication
- **S3 Bucket**: For Terraform state storage with versioning and locking
- **IAM Roles**: Separate roles for dev, staging, and production environments  
- **Lambda Function**: Go-based serverless function with ARM64 architecture
- **API Gateway**: RESTful API with CORS support
- **CloudWatch**: Logging and monitoring for all components

## Environment Strategy

The setup supports three environments:

- **Development**: Triggered by pushes to `develop` branch and pull requests
- **Staging**: Triggered by pushes to `main` branch (first deployment)
- **Production**: Triggered by pushes to `main` branch (second deployment)

Each environment has its own workspace and isolated resources.