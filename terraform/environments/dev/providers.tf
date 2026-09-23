# PETPLAT-5: AWS provider configuration for the dev environment.
#
# default_tags applies the three required tags to every taggable resource
# created by this provider, so individual modules do not have to repeat them.
# Spec: docs/technical-spec.md#required-tags-all-aws-resources

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
