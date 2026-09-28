# Module: eks — provider constraints.
# Spec: docs/technical-spec.md#general-project-parameters

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Used only to read the OIDC issuer's certificate thumbprint for the IAM
    # OpenID Connect provider (main.tf).
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
