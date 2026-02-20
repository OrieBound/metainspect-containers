from flask import Flask, request, jsonify, render_template, abort, redirect
import os
import uuid
import hashlib
import json
import subprocess
import shutil
import socket
import boto3
from datetime import datetime, timezone
from werkzeug.utils import secure_filename
from io import BytesIO
from PIL import Image, UnidentifiedImageError
from urllib import request as urllib_request

app = Flask(__name__, template_folder='templates')

ALLOWED_EXT = {'jpg', 'jpeg', 'png'}
MAX_UPLOAD_BYTES = int(os.getenv('MAX_UPLOAD_BYTES', '20971520'))
app.config['MAX_CONTENT_LENGTH'] = MAX_UPLOAD_BYTES
REDACTION_MODE = os.getenv('REDACTION_MODE', 'true').lower() in ('1', 'true', 'yes')
DELETE_AFTER_PROCESS = os.getenv('DELETE_AFTER_PROCESS', 'true').lower() in ('1', 'true', 'yes')
SHARED_DIR = os.getenv('SHARED_DIR', '/efs/shared')
EXPOSE_RUNTIME_DETAILS = os.getenv('EXPOSE_RUNTIME_DETAILS', 'false').lower() in ('1', 'true', 'yes')

# Comma-separated key fragments to redact from metadata.
# This can be injected from AWS Secrets Manager as an env var in ECS/Lambda/etc.
DEFAULT_REDACT_KEY_PARTS = (
    'gps,latitude,longitude,location,ownername,artist,copyright,credit,creator,'
    'serialnumber,bodynumber,bodyserial,lensserial,usercomment,comment,makernote'
)
REDACT_KEY_PARTS = [
    x.strip().lower()
    for x in os.getenv('REDACT_KEY_PARTS', DEFAULT_REDACT_KEY_PARTS).split(',')
    if x.strip()
]
REDACTED_VALUE = os.getenv('REDACTED_VALUE', '[REDACTED]')
SAMPLE_IMAGES_S3_BUCKET = os.getenv('SAMPLE_IMAGES_S3_BUCKET', 'demo1-oriebound')
SAMPLE_IMAGES_S3_KEY = os.getenv('SAMPLE_IMAGES_S3_KEY', 'metainspect/sample_images_metadata.zip')
SAMPLE_IMAGES_URL_TTL = int(os.getenv('SAMPLE_IMAGES_URL_TTL', '28800'))
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')


@app.route('/')
def index():
    return render_template('index.html', error=None)


@app.route('/health')
def health():
    return 'OK', 200


@app.route('/sample-images/download')
def download_sample_images():
    if not SAMPLE_IMAGES_S3_BUCKET or not SAMPLE_IMAGES_S3_KEY:
        abort(404)
    try:
        s3 = boto3.client('s3', region_name=AWS_REGION)
        url = s3.generate_presigned_url(
            ClientMethod='get_object',
            Params={'Bucket': SAMPLE_IMAGES_S3_BUCKET, 'Key': SAMPLE_IMAGES_S3_KEY},
            ExpiresIn=SAMPLE_IMAGES_URL_TTL,
        )
        return redirect(url, code=302)
    except Exception:
        app.logger.exception('Failed generating sample-images presigned URL')
        abort(503)


def _read_json_url(url):
    with urllib_request.urlopen(url, timeout=2) as resp:
        return json.loads(resp.read().decode('utf-8'))


def _runtime_metadata():
    out = {
        'hostname': socket.gethostname(),
        'timestamp_utc': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        'private_ip': None,
        'availability_zone': None,
        'cluster': None,
        'task_arn': None,
        'container_id': None,
    }

    metadata_uri = os.getenv('ECS_CONTAINER_METADATA_URI_V4') or os.getenv('ECS_CONTAINER_METADATA_URI')
    if not metadata_uri:
        out['source'] = 'local'
        return out

    out['source'] = 'ecs'
    try:
        container_meta = _read_json_url(metadata_uri)
        task_meta = _read_json_url(f'{metadata_uri}/task')

        out['container_id'] = container_meta.get('DockerId')
        out['task_arn'] = task_meta.get('TaskARN')
        out['cluster'] = task_meta.get('Cluster')
        out['availability_zone'] = task_meta.get('AvailabilityZone')

        networks = container_meta.get('Networks') or []
        if networks:
            addrs = networks[0].get('IPv4Addresses') or []
            if addrs:
                out['private_ip'] = addrs[0]
    except Exception as e:
        out['source'] = 'error'
        out['note'] = f'Failed to read ECS metadata: {e}'

    return out


def _masked_token(value, prefix='masked'):
    if not value:
        return None
    digest = hashlib.sha256(str(value).encode('utf-8')).hexdigest()[:8]
    return f'{prefix}-{digest}'


@app.route('/runtime')
def runtime():
    data = _runtime_metadata()
    if EXPOSE_RUNTIME_DETAILS:
        return jsonify(data), 200

    safe = {
        'hostname': _masked_token(data.get('hostname'), prefix='host'),
        'availability_zone': data.get('availability_zone'),
        'region': AWS_REGION,
        'timestamp_utc': data.get('timestamp_utc'),
        'source': data.get('source'),
        'note': data.get(
            'note',
            'Runtime details are portfolio-safe and masked. Set EXPOSE_RUNTIME_DETAILS=true to show full values.'
        ),
    }
    return jsonify(safe), 200


@app.errorhandler(413)
def request_entity_too_large(_):
    max_mb = MAX_UPLOAD_BYTES / (1024 * 1024)
    return render_template('index.html', error=f'File too large. Maximum size is {max_mb:.1f} MB.'), 413


def allowed_filename(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXT


@app.route('/upload', methods=['POST'])
def upload():
    if 'file' not in request.files:
        return render_template('index.html', error='No file selected. Please choose an image to upload.')
    file = request.files['file']
    if file.filename == '':
        return render_template('index.html', error='No file selected. Please choose an image to upload.')
    if not allowed_filename(file.filename):
        return render_template('index.html', error='Unsupported file type. Please upload a JPG or PNG image.')

    data = file.stream.read(MAX_UPLOAD_BYTES + 1)
    if len(data) > MAX_UPLOAD_BYTES:
        max_mb = MAX_UPLOAD_BYTES / (1024 * 1024)
        return render_template('index.html', error=f'File too large. Maximum size is {max_mb:.1f} MB.')

    # Validate image contents using Pillow to prevent accepting arbitrary files
    try:
        bio = BytesIO(data)
        img = Image.open(bio)
        img_format = (img.format or '').upper()
        img.verify()
    except UnidentifiedImageError:
        return render_template('index.html', error='Invalid image file. Please upload a valid JPG or PNG image.')
    except Exception:
        return render_template('index.html', error='Invalid image file. Please upload a valid JPG or PNG image.')

    if img_format not in ('JPEG', 'PNG', 'MPO'):
        return render_template('index.html', error='Unsupported image format. Please upload a JPG or PNG image.')

    job_id = str(uuid.uuid4())
    job_dir = os.path.join(SHARED_DIR, 'uploads', job_id)
    os.makedirs(job_dir, exist_ok=True)

    filename = secure_filename(file.filename)
    ext = os.path.splitext(filename)[1].lower()
    filepath = os.path.join(job_dir, 'input' + ext)
    with open(filepath, 'wb') as f:
        f.write(data)

    sha256 = hashlib.sha256(data).hexdigest()
    file_size = len(data)

    # Extract metadata via exiftool
    try:
        out = subprocess.check_output(['exiftool', '-j', '-n', filepath], stderr=subprocess.STDOUT, timeout=30)
        meta_list = json.loads(out.decode('utf-8') or '[]')
        metadata = meta_list[0] if meta_list else {}
    except subprocess.CalledProcessError as e:
        metadata = {'exiftool_error': e.output.decode('utf-8', errors='ignore')}
    except Exception as e:
        metadata = {'exiftool_error': str(e)}

    # Sanitize metadata: remove filesystem/internal fields and any values
    # that reference the shared path or job directory. Keep only image-related tags.
    FILE_BLACKLIST = {
        'SourceFile', 'Directory', 'FileName', 'FileModifyDate', 'FileAccessDate',
        'FilePermissions', 'FileType', 'FileTypeExtension', 'FileSize', 'FileInodeChangeDate'
    }

    def sanitize(obj):
        if isinstance(obj, dict):
            out = {}
            for k, v in obj.items():
                if k in FILE_BLACKLIST:
                    continue
                # remove keys that clearly reference filesystem paths
                if isinstance(v, str) and (SHARED_DIR and SHARED_DIR in v):
                    continue
                # recursively sanitize
                cleaned = sanitize(v)
                # skip empty values
                if cleaned is None or cleaned == '' or cleaned == [] or cleaned == {}:
                    continue
                out[k] = cleaned
            return out
        if isinstance(obj, list):
            cleaned_list = [sanitize(v) for v in obj]
            return [v for v in cleaned_list if v is not None and v != '' and v != {}]
        return obj

    metadata = sanitize(metadata)

    if REDACTION_MODE:
        def is_sensitive_key(key):
            k = str(key).lower()
            return any(part in k for part in REDACT_KEY_PARTS)

        def redact(obj):
            if isinstance(obj, dict):
                out = {}
                for k, v in obj.items():
                    if is_sensitive_key(k):
                        out[k] = REDACTED_VALUE
                        continue
                    cleaned = redact(v)
                    if cleaned is None or cleaned == '' or cleaned == [] or cleaned == {}:
                        continue
                    out[k] = cleaned
                return out
            if isinstance(obj, list):
                cleaned_list = [redact(v) for v in obj]
                return [v for v in cleaned_list if v is not None and v != '' and v != {}]
            return obj

        metadata = redact(metadata)

    result = {
        'job_id': job_id,
        'file_name': filename,
        'file_size': file_size,
        'sha256': sha256,
        'metadata': metadata,
    }

    if DELETE_AFTER_PROCESS:
        try:
            os.remove(filepath)
            shutil.rmtree(job_dir, ignore_errors=True)
        except Exception:
            pass

    return render_template('result.html', result=result)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
