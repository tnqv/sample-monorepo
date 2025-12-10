# ===========================================
# Terraform Backend Configuration
# ===========================================
# Uses S3 for state storage and DynamoDB for state locking.
# Uncomment below when ready to use remote state.

# terraform {
#   backend "s3" {
#     bucket         = "email-platform-terraform-state"
#     key            = "terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "email-platform-terraform-locks"
#   }
# }

