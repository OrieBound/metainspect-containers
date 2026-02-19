# Conversion Checklist

Use this checklist while refining the CloudFormation templates in this folder.

## 1. Define Target IaC Scope

- [ ] Decide single stack vs nested stacks
- [ ] Confirm naming convention and tag strategy
- [ ] Confirm parameters (region, VPC/subnets, image tag, desired count)

## 2. Build Templates (`root.yaml` + `templates/`)

- [ ] ECR
- [ ] VPC + subnet/networking layer (or clear inputs for existing network)
- [ ] ECS cluster
- [ ] IAM roles/policies
- [ ] Task definition (container image, env vars, port mapping, logs)
- [ ] ALB + target group + listener
- [ ] ECS service
- [ ] Auto scaling target + policy
- [ ] EFS resources (if in scope)

## 3. Validate

- [ ] Deploy to new stack name
- [ ] Verify `/health` and UI availability via ALB
- [ ] Confirm scale-out/scale-in behavior
- [ ] Confirm storage path behavior (EFS or alternative)

## 4. Finalize

- [ ] Remove deprecated or hardcoded assumptions
- [ ] Document deploy/update commands
