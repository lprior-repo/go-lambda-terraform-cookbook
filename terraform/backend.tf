# Terraform backend configuration
# This file should be updated with the actual S3 bucket name after running bootstrap

terraform {
  backend "s3" {
    # bucket = "REPLACE_WITH_ACTUAL_BUCKET_NAME"  # Update after running bootstrap
    # key    = "terraform.tfstate"
    # region = "us-east-1"
    
    # Uncomment the lines above and replace REPLACE_WITH_ACTUAL_BUCKET_NAME 
    # with the actual bucket name from the bootstrap output
  }
}