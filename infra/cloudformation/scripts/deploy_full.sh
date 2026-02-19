#!/usr/bin/env bash
set -euo pipefail

# One-command deployment pipeline:
# 1) Upload nested templates to S3
# 2) Deploy bootstrap stack (DeployService=false)
# 3) Build and push container image to ECR
# 4) Update stack to enable ECS service (DeployService=true)

STACK_NAME="${STACK_NAME:-metainspect-root-dev}"
PROJECT_NAME="${PROJECT_NAME:-metainspect}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CONTAINER_IMAGE_TAG="${CONTAINER_IMAGE_TAG:-v0.1.0}"
CFN_BUCKET="${CFN_BUCKET:-cloudformation-oriebound}"
CFN_TEMPLATE_PREFIX="${CFN_TEMPLATE_PREFIX:-metainspect/templates}"
ROOT_TEMPLATE_PATH="${ROOT_TEMPLATE_PATH:-infra/cloudformation/root.yaml}"

TEMPLATE_BASE_URL="https://${CFN_BUCKET}.s3.${AWS_REGION}.amazonaws.com/${CFN_TEMPLATE_PREFIX}"
S3_TEMPLATE_URI="s3://${CFN_BUCKET}/${CFN_TEMPLATE_PREFIX}"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found" >&2
    exit 1
  fi
}

require_cmd aws
require_cmd docker

log "Using stack=${STACK_NAME}, region=${AWS_REGION}, image_tag=${CONTAINER_IMAGE_TAG}"
log "Uploading nested templates to ${S3_TEMPLATE_URI}"
aws s3 sync infra/cloudformation/templates "${S3_TEMPLATE_URI}" --region "${AWS_REGION}"

log "Deploying bootstrap infrastructure (DeployService=false)"
aws cloudformation deploy \
  --stack-name "${STACK_NAME}" \
  --template-file "${ROOT_TEMPLATE_PATH}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "${AWS_REGION}" \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    TemplateBaseUrl="${TEMPLATE_BASE_URL}" \
    ContainerImageTag="${CONTAINER_IMAGE_TAG}" \
    DeployService=false

log "Reading ECR repository URI from stack outputs"
REPOSITORY_URI="$({ aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='RepositoryUri'].OutputValue" \
  --output text; } | tr -d '[:space:]')"

if [[ -z "${REPOSITORY_URI}" || "${REPOSITORY_URI}" == "None" ]]; then
  echo "Error: failed to resolve RepositoryUri output from stack ${STACK_NAME}" >&2
  exit 1
fi

REGISTRY_HOST="${REPOSITORY_URI%%/*}"
IMAGE_URI="${REPOSITORY_URI}:${CONTAINER_IMAGE_TAG}"

log "Logging in to ECR registry ${REGISTRY_HOST}"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY_HOST}"

log "Building Docker image ${IMAGE_URI}"
docker build -t "${IMAGE_URI}" .

log "Pushing Docker image ${IMAGE_URI}"
docker push "${IMAGE_URI}"

log "Enabling ECS service (DeployService=true)"
aws cloudformation deploy \
  --stack-name "${STACK_NAME}" \
  --template-file "${ROOT_TEMPLATE_PATH}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "${AWS_REGION}" \
  --no-fail-on-empty-changeset \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    TemplateBaseUrl="${TEMPLATE_BASE_URL}" \
    ContainerImageTag="${CONTAINER_IMAGE_TAG}" \
    DeployService=true

log "Deployment pipeline complete. Stack ${STACK_NAME} is updated with ECS enabled."
