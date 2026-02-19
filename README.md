# MetaInspect Containers

Containerized image metadata extraction service with AWS-native deployment automation.

This project demonstrates:
- Secure image upload and metadata extraction (`JPG/JPEG/PNG`)
- Metadata sanitization and configurable sensitive-field redaction
- ECS Fargate deployment behind ALB with optional EFS shared storage
- Nested CloudFormation IaC
- GitHub-triggered CodePipeline + CodeBuild flow

## Core Stack

- Python Flask + Gunicorn
- ExifTool for metadata extraction
- Docker
- AWS CloudFormation (nested stacks)
- Amazon ECR, ECS Fargate, ALB, EFS, CloudWatch
- AWS CodePipeline + CodeBuild + CodeConnections

## Repository Structure

```text
.
|-- app.py
|-- Dockerfile
|-- buildspec.yml
|-- templates/
|-- static/
`-- infra/
    |-- cloudformation/
    |   |-- root.yaml
    |   |-- templates/
    |   |-- params/
    |   `-- scripts/
    `-- diagrams/
```

## Local Run

```bash
docker build -t metainspect:local .
docker run --rm -p 8080:80 \
  -v metainspect_shared:/efs/shared \
  -e MAX_UPLOAD_BYTES=20971520 \
  metainspect:local
```

Open the app at the mapped host port (`8080`).

## Runtime Endpoints

- `GET /` - upload UI
- `POST /upload` - image upload and metadata extraction
- `GET /health` - health check
- `GET /runtime` - live task/runtime metadata
- `GET /sample-images/download` - redirect to presigned S3 sample ZIP

## AWS Deployment Model

Two-phase deployment is built into CI/CD:

1. Deploy core infrastructure with `DeployService=false`
2. Build and push image to ECR
3. Update stack with `DeployService=true` and the image tag

This avoids ECS service creation before the image exists in ECR.

See `infra/cloudformation/README.md` for commands and parameter files.

## CI/CD Trigger Flow

1. Push to GitHub (`main`)
2. CodePipeline Source stage pulls repository via CodeConnections
3. CodeBuild runs `buildspec.yml`
4. CloudFormation root stack is applied in bootstrap + service-enable phases

## Configuration

Application environment variables:
- `REDACTION_MODE` (default `true`)
- `REDACT_KEY_PARTS` (comma-separated key fragments)
- `REDACTED_VALUE` (default `[REDACTED]`)
- `MAX_UPLOAD_BYTES` (default `20971520`)
- `DELETE_AFTER_PROCESS` (default `true`)
- `SHARED_DIR` (default `/efs/shared`)
- `SAMPLE_IMAGES_S3_BUCKET`
- `SAMPLE_IMAGES_S3_KEY`
- `SAMPLE_IMAGES_URL_TTL` (default `28800`)
- `AWS_REGION` (default `us-east-1`)

## Security Notes

- No static AWS credentials are required in code.
- In AWS, presigned URL generation should use ECS task role permissions.
- Keep local secrets out of source control (`.env` files, cloud credentials, private keys).
- Redaction mode is enabled by default to reduce exposure of sensitive EXIF fields.

## Architecture Diagrams

Draw.io source files are under:
- `infra/diagrams/metainspect-aws-architecture.drawio`
- `infra/diagrams/metainspect-aws-architecture-presentation.drawio`
- `infra/diagrams/metainspect-aws-architecture-aws-icons.drawio`

## Additional Documentation

- Contribution guide: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`
- Infrastructure/deployment guide: `infra/cloudformation/README.md`
