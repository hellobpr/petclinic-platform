# PETPLAT-4: S3 remote state backend for the prod environment.
# Spec: docs/technical-spec.md#terraform-state-backend
#
# Same bucket and lock table as dev — only the state key differs.
#
# PARTIAL CONFIGURATION — `bucket` is deliberately omitted.
# The bucket name is petclinic-terraform-state-{account-id} (spec), and a
# backend block cannot interpolate variables or data sources. The account ID is
# therefore supplied at init time. scripts/bootstrap-state.sh generates
# backend.hcl for you:
#
#   ../../../scripts/bootstrap-state.sh
#   terraform init -backend-config=backend.hcl
#
# backend.hcl is gitignored (it embeds the AWS account ID); backend.hcl.example
# is committed as the template.

terraform {
  backend "s3" {
    key            = "petclinic/prod/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
