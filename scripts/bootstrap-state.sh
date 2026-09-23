#!/usr/bin/env bash
set -euo pipefail

#
# bootstrap-state.sh — Provision the Terraform remote state backend (PETPLAT-2)
#
# Creates the S3 bucket and DynamoDB table that hold Terraform state and locks.
# This runs ONCE, before the first `terraform init`, and deliberately lives
# outside Terraform: Terraform cannot manage the bucket that stores its own
# state without a chicken-and-egg problem.
#
# Spec: docs/technical-spec.md#terraform-state-backend
#   S3 bucket    petclinic-terraform-state-{account-id}
#   Encryption   AES256 (SSE-S3)
#   Versioning   enabled
#   Public access all 4 settings blocked
#   DynamoDB     petclinic-terraform-locks, partition key LockID (String)
#
# The script is idempotent — every step checks for existing resources first, so
# re-running it is safe and makes no changes.
#
# Usage:
#   ./scripts/bootstrap-state.sh
#   ./scripts/bootstrap-state.sh --region eu-west-1
#   ./scripts/bootstrap-state.sh --dry-run
#

REGION="${AWS_DEFAULT_REGION:-eu-central-1}"
DYNAMODB_TABLE="petclinic-terraform-locks"
DRY_RUN=false

usage() {
  echo "Usage: $0 [--region <aws-region>] [--dry-run]"
  echo ""
  echo "Options:"
  echo "  --region <region>   AWS region for the state bucket and lock table"
  echo "                      (default: \$AWS_DEFAULT_REGION or eu-central-1)"
  echo "  --dry-run           Show what would be created, change nothing"
  echo "  -h, --help          Show this help"
  echo ""
  echo "Examples:"
  echo "  $0                            # Bootstrap in eu-central-1"
  echo "  $0 --region eu-west-1         # Bootstrap in eu-west-1"
  echo "  $0 --dry-run                  # Preview only"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      [[ $# -ge 2 ]] || { echo "ERROR: --region requires a value" >&2; exit 1; }
      REGION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      ;;
  esac
done

# --- Preflight -------------------------------------------------------------

command -v aws >/dev/null 2>&1 || {
  echo "ERROR: aws CLI not found. Install it and run 'aws configure' first." >&2
  exit 1
}

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" || {
  echo "ERROR: Could not determine AWS account. Are your credentials configured?" >&2
  echo "       Try: aws sts get-caller-identity" >&2
  exit 1
}

BUCKET="petclinic-terraform-state-${ACCOUNT_ID}"

echo "Terraform state backend bootstrap"
echo "  Account:  ${ACCOUNT_ID}"
echo "  Region:   ${REGION}"
echo "  Bucket:   ${BUCKET}"
echo "  Lock table: ${DYNAMODB_TABLE}"
$DRY_RUN && echo "  MODE:     DRY RUN (no changes)"
echo ""

run() {
  if $DRY_RUN; then
    echo "    [dry-run] $*"
  else
    "$@"
  fi
}

# --- S3 bucket -------------------------------------------------------------

echo "[1/6] S3 bucket"
if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "    exists, skipping"
else
  # us-east-1 rejects LocationConstraint; every other region requires it.
  if [[ "$REGION" == "us-east-1" ]]; then
    run aws s3api create-bucket \
      --bucket "$BUCKET" \
      --region "$REGION"
  else
    run aws s3api create-bucket \
      --bucket "$BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
  echo "    created"
fi

echo "[2/6] Bucket versioning"
CURRENT_VERSIONING="$(aws s3api get-bucket-versioning --bucket "$BUCKET" \
  --query 'Status' --output text 2>/dev/null || echo "None")"
if [[ "$CURRENT_VERSIONING" == "Enabled" ]]; then
  echo "    already enabled, skipping"
else
  run aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled
  echo "    enabled"
fi

echo "[3/6] Bucket encryption (AES256)"
if aws s3api get-bucket-encryption --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "    already configured, skipping"
else
  run aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
  echo "    configured"
fi

echo "[4/6] Block public access (all 4 settings)"
# Applied unconditionally — it is idempotent and we want drift corrected.
run aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo "    all blocked"

echo "[5/6] Bucket tags"
run aws s3api put-bucket-tagging \
  --bucket "$BUCKET" \
  --tagging 'TagSet=[{Key=Project,Value=petclinic},{Key=Environment,Value=shared},{Key=ManagedBy,Value=bootstrap-script}]'
echo "    tagged"

# --- DynamoDB lock table ---------------------------------------------------

echo "[6/6] DynamoDB lock table"
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "    exists, skipping"
else
  # Note: the redirect must stay inside this branch. Putting >/dev/null on a
  # `run` call would also swallow the [dry-run] echo and hide the command.
  if $DRY_RUN; then
    echo "    [dry-run] aws dynamodb create-table --table-name ${DYNAMODB_TABLE}" \
      "--attribute-definitions AttributeName=LockID,AttributeType=S" \
      "--key-schema AttributeName=LockID,KeyType=HASH" \
      "--billing-mode PAY_PER_REQUEST --region ${REGION}"
  else
    aws dynamodb create-table \
      --table-name "$DYNAMODB_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$REGION" \
      --tags Key=Project,Value=petclinic Key=Environment,Value=shared Key=ManagedBy,Value=bootstrap-script \
      >/dev/null
    echo "    created, waiting for ACTIVE..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
  fi
  echo "    ready"
fi

# --- Backend config for each environment -----------------------------------

echo ""
echo "Writing backend config (bucket name embeds the account ID, so it is gitignored)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for env in dev prod; do
  ENV_DIR="${REPO_ROOT}/terraform/environments/${env}"
  if [[ -d "$ENV_DIR" ]]; then
    if $DRY_RUN; then
      echo "    [dry-run] would write ${ENV_DIR}/backend.hcl"
    else
      printf 'bucket = "%s"\n' "$BUCKET" > "${ENV_DIR}/backend.hcl"
      echo "    wrote terraform/environments/${env}/backend.hcl"
    fi
  fi
done

echo ""
echo "Done. Next:"
echo "  cd terraform/environments/dev"
echo "  terraform init -backend-config=backend.hcl"
echo "  terraform validate"
