# CloudFormation Workspace

This directory keeps infrastructure-as-code artifacts for MetaInspect.

## Structure

- `root.yaml`
  - Parent nested stack that orchestrates child templates.
- `templates/`
  - Nested templates by concern (`network`, `ecr`, `ecs-cluster`, `alb`, `efs`, `ecs-service`, `autoscaling`, `cicd`).
- `params/`
  - Parameter files for environments (for example `dev.json`).

## Workflow

1. Upload nested templates to S3 preserving the `templates/` path used in `root.yaml`.
2. Create stack in bootstrap mode:
   - `DeployService=false` (creates network, ECR, cluster, ALB, EFS only).
3. Build and push the image tag referenced by `ContainerImageTag`.
4. Update stack with `DeployService=true` to create ECS service + autoscaling.
5. Validate health checks and iterate with small updates.

## Suggested target resources

- ECR repository
- VPC + public/service subnets + route tables + **VPC endpoints** (S3 gateway, ECR, CloudWatch Logs — no NAT gateways in this design)
- ECS cluster
- Task definition
- ECS service
- ALB, listener, target group
- ECS auto scaling policy
- IAM roles/policies
- CloudWatch log group
- EFS (if keeping shared persistent storage)

## Example Commands

```bash
# from repo root
aws s3 cp infra/cloudformation/templates s3://<bucket>/cloudformation/templates --recursive

# bootstrap create (no ECS service yet)
aws cloudformation deploy \
  --stack-name metainspect-dev \
  --template-file infra/cloudformation/root.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ProjectName=metainspect \
    EnvironmentName=dev \
    ContainerImageTag=v0.1.0 \
    DeployService=false

# after pushing ECR image tag, enable ECS service
aws cloudformation deploy \
  --stack-name metainspect-dev \
  --template-file infra/cloudformation/root.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ProjectName=metainspect \
    EnvironmentName=dev \
    ContainerImageTag=v0.1.0 \
    DeployService=true
```

Use `aws cloudformation deploy` with the same parameter set for changes.

## One-Command Pipeline (Local)

Run the full flow (bootstrap infra -> build/push image -> enable ECS):

```bash
./infra/cloudformation/scripts/deploy_full.sh
```

Optional environment overrides:

```bash
STACK_NAME=metainspect-root-dev \
PROJECT_NAME=metainspect \
ENVIRONMENT_NAME=dev \
CONTAINER_IMAGE_TAG=v0.1.0 \
AWS_REGION=us-east-1 \
CFN_BUCKET=cloudformation-oriebound \
./infra/cloudformation/scripts/deploy_full.sh
```

## GitHub Actions Pipeline

Workflow file: `.github/workflows/deploy-cloudformation.yml`

Set these repository secrets:

- `AWS_ROLE_ARN` (OIDC role for GitHub Actions)
- `AWS_REGION` (for example `us-east-1`)
- `CFN_BUCKET` (S3 bucket holding nested templates)

Then run the `Deploy CloudFormation` workflow from `workflow_dispatch`.

## AWS CodePipeline + CodeBuild (GitHub-triggered)

Files:

- `buildspec.yml` (build/push/deploy logic run by CodeBuild)
- `infra/cloudformation/templates/cicd.yaml` (pipeline infrastructure)

Preflight inputs you must set:

1. **Nested templates bucket** — `cicd.yaml` **creates** `MetainspectCfnTemplatesBucket` and a **bucket policy** so **CloudFormation** can read synced nested YAML. No manual S3 setup for the pipeline path.
2. Create/authorize a **CodeStar / CodeConnections** link to GitHub; status must be **Available**.
3. Pass **your** `ConnectionArn` and **`FullRepositoryId`** (`owner/repo` only, not a GitHub URL) in **`--parameter-overrides`** on `aws cloudformation deploy` (see main `README.md`). Each AWS account has its own connection ARN.

Flow implemented:

1. GitHub push triggers CodePipeline.
2. CodeBuild syncs nested templates to S3.
3. CodeBuild deploys bootstrap stack (`DeployService=false`).
4. CodeBuild builds Docker image and pushes to ECR with tag derived from commit SHA.
5. CodeBuild updates stack with `DeployService=true` and `ContainerImageTag=<commit-sha-tag>`.

Example deploy command for CI/CD stack:

```bash
aws cloudformation deploy \
  --stack-name metainspect-cicd-dev \
  --template-file infra/cloudformation/templates/cicd.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1 \
  --parameter-overrides \
    ProjectName=metainspect \
    EnvironmentName=dev \
    ConnectionArn=<your-codeconnections-arn> \
    FullRepositoryId=<github-org-or-user>/<repo-name> \
    BranchName=main \
    StackName=metainspect-root-dev \
    BuildSpecFile=buildspec.yml \
    CloudFormationTemplatePrefix=metainspect/templates
```

Notes:

- The GitHub connection must already be created and authorized for your GitHub repo.
- The CodeBuild role in `cicd.yaml` is intentionally broad for bootstrap simplicity; tighten IAM scopes after initial validation.
- If the root stack `StackName` is left in **`ROLLBACK_COMPLETE`**, delete it in CloudFormation before relying on a fresh bootstrap from the pipeline.
