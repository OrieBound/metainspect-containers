# CI/CD parameter files

Values here are **per AWS account** and **per GitHub identity**. What you commit to the repo should stay generic.

- **`cicd-dev.json`** — Checked in with placeholders (`<your-codeconnections-arn>`, and optionally `<org/repo>`). Safe for anyone who clones the repo.
- **`cicd-dev.local.json`** — **Gitignored.** Copy from `cicd-dev.json`, replace with **your** Connection ARN (from **Developer Tools → Connections** in **your** account) and **your** `FullRepositoryId` if you use a fork. Use this file with the `jq` deploy one-liner in `infra/cloudformation/README.md` so you never commit secrets.

```bash
cp cicd-dev.json cicd-dev.local.json
# Edit cicd-dev.local.json — set ConnectionArn and FullRepositoryId
```

Do **not** commit real connection ARNs; they are tied to **your** account and useless (or misleading) for everyone else.
