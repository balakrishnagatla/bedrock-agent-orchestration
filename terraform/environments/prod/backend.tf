## -----------------------------------------------------------------------------
## Remote state: S3 backend with native S3 locking (Terraform >= 1.10) and a
## DynamoDB fallback lock table for OpenTofu / older Terraform compatibility.
## Bucket and table are provisioned once via terraform/bootstrap.
##
## Backend config values contain no secrets but ARE environment-specific, so
## they are intentionally NOT interpolated (Terraform disallows variables in
## backend blocks). Override at init time in CI via -backend-config, e.g.:
##
##   terraform init \
##     -backend-config="bucket=acme-terraform-state-prod" \
##     -backend-config="key=bedrock-agent-orchestration/prod/terraform.tfstate" \
##     -backend-config="region=us-east-1" \
##     -backend-config="dynamodb_table=terraform-state-locks"
## -----------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "acme-terraform-state-prod"
    key            = "bedrock-agent-orchestration/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
