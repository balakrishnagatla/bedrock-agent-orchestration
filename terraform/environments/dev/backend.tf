terraform {
  backend "s3" {
    bucket         = "acme-terraform-state-dev"
    key            = "bedrock-agent-orchestration/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
