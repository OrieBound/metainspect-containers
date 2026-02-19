# MetaInspect (local dev)

This repository contains a local development scaffold for MetaInspect — a file upload and metadata extraction service.

Quick start (build and run locally):

```bash
# from the repo root
docker build -t metainspect:local .
# mount a local folder as /efs/shared to simulate EFS
mkdir -p /tmp/metainspect_shared
docker run --rm -p 8080:80 -v /tmp/metainspect_shared:/efs/shared -e MAX_UPLOAD_BYTES=20971520 metainspect:local
```

Open http://localhost:8080 in a browser and upload a JPG/PNG.

Environment variables:
- `REDACTION_MODE` (true/false, default `true`) — redact sensitive metadata keys when true (keys are retained, values are replaced)
- `REDACT_KEY_PARTS` (comma-separated fragments) — key fragments to redact; default includes GPS/location and common owner/serial/comment tags
- `REDACTED_VALUE` (default `REDACTED`) — replacement text used for redacted values
- `MAX_UPLOAD_BYTES` — max upload size in bytes
- `DELETE_AFTER_PROCESS` (true/false) — remove files after processing
- `SHARED_DIR` — path to shared filesystem (defaults to `/efs/shared`)
- `SAMPLE_IMAGES_S3_BUCKET` — S3 bucket for sample image downloads
- `SAMPLE_IMAGES_S3_KEY` — object key in that bucket (for example `sample_images_metadata.zip`)
- `SAMPLE_IMAGES_URL_TTL` — presigned URL expiry in seconds (default `28800`, 8 hours)
