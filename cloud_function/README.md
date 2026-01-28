# WBI Fleet Upgrade - Cloud Function

Google Cloud Function implementation of the WBI Fleet Upgrade & Rollback tool.

## Quick Start

```bash
# Deploy with Terraform
cd ../terraform/cloud-function
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

# Or deploy manually
gcloud functions deploy wbi-fleet-upgrade \
  --gen2 \
  --runtime=python311 \
  --region=europe-west2 \
  --source=. \
  --entry-point=main \
  --trigger-http
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API information |
| `/upgrade` | POST | Upgrade instances |
| `/rollback` | POST | Rollback instances |
| `/status` | GET/POST | Instance status |
| `/check-upgradability` | GET/POST | Check upgradeable instances |
| `/health` | GET | Health check |

## Example Usage

```bash
# Get token
TOKEN=$(gcloud auth print-identity-token)
URL="https://REGION-PROJECT.cloudfunctions.net/wbi-fleet-upgrade"

# Check upgradability
curl -X POST "$URL/check-upgradability" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "my-project", "locations": ["europe-west2-a"]}'

# Dry-run upgrade
curl -X POST "$URL/upgrade" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dry_run": true}'
```

## Configuration

Environment variables (set in `.env.yaml` or via `--set-env-vars`):

| Variable | Description | Default |
|----------|-------------|---------|
| GCP_PROJECT_ID | Target project | Required |
| LOCATIONS | Space-separated zones | Required |
| DRY_RUN | Default dry-run mode | true |
| MAX_PARALLEL | Max concurrent ops | 5 |
| ROLLBACK_ON_FAILURE | Auto-rollback failed upgrades | false |

## Documentation

See [CLOUD_FUNCTION_DEPLOYMENT.md](../docs/CLOUD_FUNCTION_DEPLOYMENT.md) for:

- Detailed API reference
- Terraform deployment guide
- IAM & security configuration
- Python/cURL examples
- Monitoring & troubleshooting

## Directory Structure

```
cloud_function/
├── main.py              # Cloud Function entry point
├── requirements.txt     # Python dependencies
├── .env.yaml.example    # Environment config template
├── README.md            # This file
└── src/
    ├── __init__.py
    ├── clients.py       # REST API client
    ├── config.py        # Configuration
    ├── models.py        # Data models
    ├── upgrader.py      # Upgrade logic
    └── rollback.py      # Rollback logic
```

## Security

- IAM authentication required for invocation
- Input validation and sanitization
- Least-privilege service account with custom IAM role
- Terraform-managed IAM bindings

## License

See repository LICENSE file.
