# Go Lambda Terraform Cookbook - Makefile

.PHONY: help build test clean sam-build sam-invoke sam-api terraform-init terraform-plan terraform-apply terraform-destroy lint format

# Variables
GO_VERSION = 1.25
TERRAFORM_VERSION = 1.13.1
AWS_REGION = us-east-1
PROJECT_NAME = go-lambda-cookbook
ENVIRONMENT = dev

# Default target
help: ## Show this help message
	@echo "Go Lambda Terraform Cookbook - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Go commands
build: ## Build the Lambda binary for ARM64
	@echo "Building Lambda binary..."
	@mkdir -p build
	@cd src && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -tags lambda.norpc -o ../build/bootstrap .
	@echo "Binary built successfully: build/bootstrap"

test: ## Run Go tests
	@echo "Running Go tests..."
	@go test -v ./...

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	@go test -v -cover ./...

lint: ## Run Go linting
	@echo "Running Go vet..."
	@go vet ./...
	@echo "Running gofmt check..."
	@if [ "$$(gofmt -s -l . | wc -l)" -gt 0 ]; then \
		echo "The following files are not properly formatted:"; \
		gofmt -s -l .; \
		exit 1; \
	fi

format: ## Format Go code
	@echo "Formatting Go code..."
	@gofmt -s -w .
	@go mod tidy

clean: ## Clean build artifacts
	@echo "Cleaning up..."
	@rm -rf build/
	@rm -rf .aws-sam/
	@rm -rf terraform/.terraform/
	@rm -f terraform/*.tfplan
	@echo "Clean complete"

# AWS SAM commands
sam-build: ## Build with AWS SAM
	@echo "Building with SAM..."
	@sam build

sam-invoke: sam-build ## Invoke Lambda function locally with sample event
	@echo "Invoking Lambda locally..."
	@sam local invoke -e events/api-gateway-event.json

sam-invoke-post: sam-build ## Invoke Lambda locally with POST event
	@echo "Invoking Lambda locally with POST event..."
	@sam local invoke -e events/api-gateway-post-event.json

sam-api: sam-build ## Start local API Gateway
	@echo "Starting local API Gateway on http://localhost:3000"
	@sam local start-api --port 3000

sam-api-debug: sam-build ## Start local API Gateway with debug port
	@echo "Starting local API Gateway with debug on http://localhost:3000"
	@echo "Debugger port: 5986"
	@sam local start-api --port 3000 --debug-port 5986

sam-logs: ## View SAM logs (requires deployed stack)
	@sam logs -n GoLambdaFunction --stack-name $(PROJECT_NAME)-$(ENVIRONMENT) --tail

# Terraform commands
terraform-init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	@cd terraform && terraform init

terraform-workspace: terraform-init ## Create and select Terraform workspace
	@echo "Setting up Terraform workspace: $(ENVIRONMENT)"
	@cd terraform && (terraform workspace new $(ENVIRONMENT) || terraform workspace select $(ENVIRONMENT))

terraform-plan: terraform-workspace ## Plan Terraform deployment
	@echo "Planning Terraform deployment for $(ENVIRONMENT)..."
	@cd terraform && terraform plan \
		-var="environment=$(ENVIRONMENT)" \
		-var="aws_region=$(AWS_REGION)" \
		-var="project_name=$(PROJECT_NAME)" \
		-out=tfplan-$(ENVIRONMENT)

terraform-apply: build ## Apply Terraform deployment
	@echo "Applying Terraform deployment for $(ENVIRONMENT)..."
	@cd terraform && terraform apply tfplan-$(ENVIRONMENT)
	@echo "Deployment complete!"
	@echo "API Gateway URL: $$(cd terraform && terraform output -raw api_gateway_url)"

terraform-destroy: terraform-workspace ## Destroy Terraform infrastructure
	@echo "Destroying Terraform infrastructure for $(ENVIRONMENT)..."
	@cd terraform && terraform destroy \
		-var="environment=$(ENVIRONMENT)" \
		-var="aws_region=$(AWS_REGION)" \
		-var="project_name=$(PROJECT_NAME)" \
		-auto-approve

terraform-output: ## Show Terraform outputs
	@cd terraform && terraform output

terraform-format: ## Format Terraform files
	@echo "Formatting Terraform files..."
	@cd terraform && terraform fmt -recursive

# Combined commands
local-dev: sam-build sam-api ## Start local development environment

deploy-dev: ## Deploy to development environment
	@$(MAKE) ENVIRONMENT=dev terraform-plan terraform-apply

deploy-staging: ## Deploy to staging environment
	@$(MAKE) ENVIRONMENT=staging terraform-plan terraform-apply

deploy-prod: ## Deploy to production environment
	@$(MAKE) ENVIRONMENT=prod terraform-plan terraform-apply

# Testing commands
test-local: sam-build ## Test the local Lambda function
	@echo "Testing local Lambda function..."
	@sam local invoke -e events/api-gateway-event.json
	@echo "Testing POST endpoint..."
	@sam local invoke -e events/api-gateway-post-event.json

test-deployed: ## Test the deployed Lambda function
	@echo "Testing deployed Lambda function..."
	@API_URL=$$(cd terraform && terraform output -raw api_gateway_url) && \
	echo "Testing GET: $$API_URL" && \
	curl -f "$$API_URL" && \
	echo -e "\n\nTesting GET with params: $$API_URL?name=Test" && \
	curl -f "$$API_URL?name=Test" && \
	echo -e "\n\nTesting POST: $$API_URL/api/test" && \
	curl -f -X POST "$$API_URL/api/test" \
		-H "Content-Type: application/json" \
		-d '{"message": "Test from Makefile"}'

# Setup commands
setup: ## Set up development environment
	@echo "Setting up development environment..."
	@echo "Checking Go version..."
	@go version
	@echo "Checking AWS CLI..."
	@aws --version
	@echo "Checking SAM CLI..."
	@sam --version
	@echo "Checking Terraform..."
	@terraform version
	@echo "Installing Go dependencies..."
	@go mod download
	@echo "Setup complete!"

# Documentation
docs: ## Open relevant documentation
	@echo "Opening documentation..."
	@echo "AWS Lambda Go: https://docs.aws.amazon.com/lambda/latest/dg/lambda-golang.html"
	@echo "AWS SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/"
	@echo "Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs"