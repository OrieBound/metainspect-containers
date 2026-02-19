# Contributing

Thanks for contributing to MetaInspect Containers.

## Development Workflow

1. Create a feature branch from `main`.
2. Make focused changes with clear commit messages.
3. Validate locally with Docker:
   - `docker build -t metainspect:local .`
   - `docker run --rm -p 8080:80 metainspect:local`
4. Open a pull request with:
   - What changed
   - Why it changed
   - How it was tested

## Scope Guidelines

- Keep infrastructure changes in `infra/cloudformation/` minimal and reviewable.
- Prefer parameterized values over hardcoded environment-specific values.
- Avoid introducing static credentials or secrets in code or templates.

## Pull Request Checklist

- [ ] No secrets committed
- [ ] Local build succeeds
- [ ] README/infra docs updated if behavior changed
- [ ] CloudFormation parameters and template references are consistent
