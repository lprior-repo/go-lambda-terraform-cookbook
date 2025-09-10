# Go Lambda Terraform Cookbook

A production-grade repository pattern for building, testing, and deploying Go-based AWS Lambda functions with superior developer ergonomics using Terraform for deployments and AWS SAM for local debugging.

## 🚀 Features

- **Dual-Tool Approach**: Terraform for infrastructure deployment, AWS SAM for local development and debugging
- **Security First**: GitHub's OIDC for keyless, short-lived credentials
- **Ephemeral Environments**: Support for temporary, isolated environments for pull requests
- **Cost-Effective**: ARM64 architecture for Lambda functions (20% cost reduction)
- **Production-Ready CI/CD**: Automated testing, building, and deployment pipelines
- **Local Development Parity**: High-fidelity local environment matching AWS Lambda runtime
- **Multi-Environment Support**: Dev, staging, and production environments
- **Infrastructure as Code**: Complete Terraform configuration with best practices
- **Automated Cleanup**: Automatic cleanup of ephemeral PR environments

## 📁 Repository Structure

```
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines
│       ├── deploy.yml      # Main deployment workflow
│       └── cleanup.yml     # Environment cleanup workflow
├── src/                    # Go Lambda function source code
│   └── main.go            # Lambda function handler
├── terraform/             # Terraform infrastructure configuration
│   ├── serverless.tf      # Main infrastructure resources
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   └── terraform.tfvars.example # Example variables file
├── template.yaml          # AWS SAM template for local development
├── go.mod                # Go module configuration
├── go.sum                # Go dependencies checksums
└── README.md            # This file
```

## 🏃 Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with your credentials
3. **Docker** for local SAM development
4. **Go 1.25+** for development
5. **Terraform 1.13.1+** for infrastructure deployment
6. **AWS SAM CLI** for local development and testing

### Installation

#### Install AWS SAM CLI

**macOS:**
```bash
brew install aws-sam-cli
```

**Linux:**
```bash
# Download and install the latest version
wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
sudo ./sam-installation/install
```

**Windows:**
Download and run the installer from the [AWS SAM CLI releases page](https://github.com/aws/aws-sam-cli/releases).

#### Install Terraform
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.13.1/terraform_1.13.1_linux_amd64.zip
unzip terraform_1.13.1_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Local Development with AWS SAM

The `template.yaml` file in the repository root is specifically designed for local development and testing. It's separate from the Terraform deployment configuration.

#### 1. Build the Lambda Function

```bash
# Build the Go binary for Lambda runtime
sam build
```

This command:
- Compiles your Go code inside a Docker container that replicates the Lambda environment
- Creates a `.aws-sam/build` directory with the compiled artifacts
- Uses the `provided.al2023` runtime with ARM64 architecture

#### 2. Test Locally with Sample Events

```bash
# Test with a sample API Gateway event
sam local invoke -e events/api-gateway-event.json

# Start a local API Gateway server
sam local start-api --port 3000
```

#### 3. Test the Local API

Once the local API is running:

```bash
# Test the root endpoint
curl http://localhost:3000/

# Test with query parameters
curl "http://localhost:3000/?name=World&message=Hello"

# Test a POST request
curl -X POST http://localhost:3000/api/test \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

#### 4. Debug with IDE

You can attach a debugger to your running Lambda function:

```bash
# Start with debug mode
sam local start-api --debug-port 5986
```

Then connect your IDE's debugger to port 5986.

### Cloud Deployment with Terraform

#### 1. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### 2. Set Up Terraform Variables

```bash
# Copy the example variables file
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit the variables to match your environment
vim terraform.tfvars
```

#### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Create and select a workspace for your environment
terraform workspace new dev
terraform workspace select dev

# Plan the deployment
terraform plan -var="environment=dev"

# Apply the changes
terraform apply -var="environment=dev"
```

#### 4. Test the Deployed Function

```bash
# Get the API Gateway URL from Terraform outputs
API_URL=$(terraform output -raw api_gateway_url)

# Test the deployed function
curl $API_URL
```

## 🔧 Development Workflow

### Local Development Loop

1. **Make code changes** in `src/main.go`
2. **Build and test locally**:
   ```bash
   sam build
   sam local invoke
   ```
3. **Test with local API server**:
   ```bash
   sam local start-api
   curl http://localhost:3000/
   ```
4. **Run Go tests**:
   ```bash
   go test ./...
   ```

### Deployment Process

1. **Push to feature branch** for development
2. **Create Pull Request** to main branch
3. **GitHub Actions automatically**:
   - Runs tests and linting
   - Builds the Lambda binary
   - Creates Terraform plans
   - Comments on PR with plan details
4. **Merge PR** to trigger deployment
5. **Automatic deployment** to appropriate environment
6. **Environment cleanup** when PR is closed

## 🏗️ Infrastructure Overview

### AWS Resources Created

- **Lambda Function**: Go runtime on ARM64 architecture
- **API Gateway**: RESTful API with proxy integration
- **S3 Bucket**: Stores Lambda deployment packages
- **CloudWatch Log Groups**: For Lambda and API Gateway logs
- **IAM Roles**: Least-privilege permissions for Lambda execution

### Environment Strategy

- **Development**: `develop` branch → `dev` environment
- **Staging**: `main` branch → `staging` environment  
- **Production**: `main` branch → `prod` environment (manual approval)
- **Pull Requests**: Create ephemeral `pr-{number}` environments

### Security Features

- **OIDC Authentication**: No long-lived AWS credentials in GitHub
- **Least Privilege IAM**: Minimal permissions for each component
- **Encrypted Storage**: S3 bucket encryption enabled
- **VPC Support**: Ready for VPC deployment (commented out by default)

## 🧪 Testing

### Local Testing

```bash
# Run Go unit tests
go test -v ./...

# Run with coverage
go test -v -cover ./...

# Run specific test
go test -v -run TestHandlerFunction ./...
```

### Integration Testing

```bash
# Test with SAM CLI
sam build && sam local invoke -e events/test-event.json

# Load testing with curl
for i in {1..100}; do
  curl http://localhost:3000/ &
done
wait
```

## 🔄 CI/CD Pipeline

### GitHub Actions Workflows

#### Deploy Workflow (`deploy.yml`)
- **Triggered by**: Push to `main`/`develop`, Pull Requests
- **Jobs**:
  1. **Test**: Go tests, vet, formatting checks
  2. **Build**: Compile Lambda binary for ARM64
  3. **Plan**: Terraform plan for each environment
  4. **Deploy**: Apply Terraform changes

#### Cleanup Workflow (`cleanup.yml`)
- **Triggered by**: PR closure, schedule (daily), manual dispatch
- **Purpose**: Clean up ephemeral environments and orphaned resources

### Required GitHub Secrets

Set up the following secrets in your GitHub repository:

```
AWS_ROLE_ARN_DEV      # IAM role ARN for dev environment
AWS_ROLE_ARN_STAGING  # IAM role ARN for staging environment  
AWS_ROLE_ARN_PROD     # IAM role ARN for production environment
```

### OIDC Setup

Create IAM roles with the following trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR-ORG/YOUR-REPO:*"
        }
      }
    }
  ]
}
```

## 📊 Monitoring and Observability

### CloudWatch Integration

- **Lambda Logs**: Automatic log group creation with configurable retention
- **API Gateway Logs**: Access logs with structured JSON format
- **X-Ray Tracing**: Enabled for distributed tracing
- **CloudWatch Metrics**: Built-in Lambda and API Gateway metrics

### Log Analysis

```bash
# View Lambda logs
aws logs tail /aws/lambda/go-lambda-cookbook-dev --follow

# View API Gateway logs
aws logs tail /aws/apigateway/go-lambda-cookbook-dev --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/go-lambda-cookbook-dev \
  --filter-pattern "ERROR"
```

## 🔧 Configuration

### Environment Variables

Configure Lambda environment variables in `terraform/variables.tf`:

```hcl
variable "lambda_environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default = {
    LOG_LEVEL = "INFO"
    ENVIRONMENT = "dev"
  }
}
```

### Lambda Settings

Adjust Lambda configuration in `terraform/variables.tf`:

```hcl
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}
```

## 🚨 Troubleshooting

### Common Issues

#### SAM Build Failures

```bash
# Clear SAM cache
rm -rf .aws-sam/

# Rebuild from scratch
sam build --use-container
```

#### Go Module Issues

```bash
# Clean module cache
go clean -modcache

# Update dependencies
go mod tidy
go mod download
```

#### Terraform State Issues

```bash
# Refresh state
terraform refresh

# Import existing resources
terraform import aws_lambda_function.main function-name
```

### Debug Mode

Enable debug logging:

```bash
# SAM debug mode
sam local start-api --debug

# Terraform debug mode
export TF_LOG=DEBUG
terraform apply
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** and test locally with SAM
4. **Commit your changes**: `git commit -m 'Add amazing feature'`
5. **Push to the branch**: `git push origin feature/amazing-feature`
6. **Open a Pull Request**

### Code Standards

- **Go**: Follow standard Go conventions, use `gofmt` for formatting
- **Terraform**: Use consistent formatting with `terraform fmt`
- **Testing**: Maintain test coverage above 80%
- **Documentation**: Update README for any configuration changes

## 📚 Additional Resources

- [AWS Lambda Go Programming Model](https://docs.aws.amazon.com/lambda/latest/dg/lambda-golang.html)
- [AWS SAM CLI Documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-command-reference.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋 Support

- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check the repository Wiki for additional guides

---

**Made with ❤️ for the serverless community**