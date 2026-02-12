provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "IAC-Terraform-AWS"
      Environment = "Dev"
      ManagedBy   = "Terraform"
    }
  }
}
