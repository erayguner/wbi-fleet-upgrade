# Cloud Build Configuration for WBI Fleet Upgrade/Rollback

This guide explains how to deploy and use Google Cloud Build for running
WBI upgrade and rollback operations in a controlled CI/CD environment.

## Prerequisites

1. **Google Cloud SDK** installed and authenticated
2. **Cloud Build API** enabled in your project
3. **Terraform** (for IAM setup)
4. **Required permissions** to create service accounts and IAM bindings

## Quick Start

### 1. Set Up IAM (One-Time)

Create the dedicated service account with least-privilege roles:

```bash
cd terraform/cloudbuild-iam

# Get your project number
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')

# Initialize and apply Terraform
terraform init
terraform plan \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="project_number=$PROJECT_NUMBER"

terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="project_number=$PROJECT_NUMBER"
```

### 2. Run a Dry-Run Upgrade

```bash
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=YOUR_PROJECT_ID,_LOCATIONS="europe-west2-a europe-west2-b europe-west2-c",_OPERATION=upgrade,_DRY_RUN=true
```

### 3. Run an Actual Upgrade

```bash
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=YOUR_PROJECT_ID,_LOCATIONS="europe-west2-a europe-west2-b europe-west2-c",_OPERATION=upgrade,_DRY_RUN=false,_ROLLBACK_ON_FAILURE=true
```

### 4. Run a Rollback

```bash
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=YOUR_PROJECT_ID,_LOCATIONS="europe-west2-a europe-west2-b europe-west2-c",_OPERATION=rollback,_DRY_RUN=false
```

---

## Environment Variables Reference

| Variable                | Required | Default   | Description                     |
| ----------------------- | -------- | --------- | ------------------------------- |
| `_PROJECT_ID`           | **Yes**  | -         | GCP project ID                  |
| `_LOCATIONS`            | **Yes**  | -         | Space-separated zones           |
| `_OPERATION`            | No       | `upgrade` | `upgrade` or `rollback`         |
| `_DRY_RUN`              | No       | `true`    | Dry-run mode (safe default)     |
| `_INSTANCE_ID`          | No       | -         | Specific instance ID            |
| `_MAX_PARALLEL`         | No       | `10`      | Max concurrent operations       |
| `_TIMEOUT`              | No       | `7200`    | Timeout per operation (seconds) |
| `_POLL_INTERVAL`        | No       | `20`      | Poll interval (seconds)         |
| `_HEALTH_CHECK_TIMEOUT` | No       | `600`     | Health check timeout            |
| `_STAGGER_DELAY`        | No       | `3.0`     | Delay between starts            |
| `_ROLLBACK_ON_FAILURE`  | No       | `false`   | Auto-rollback on failure        |
| `_VERBOSE`              | No       | `false`   | Verbose logging                 |
| `_JSON_LOGGING`         | No       | `true`    | Structured JSON logs            |

---

## IAM Roles (Least Privilege)

The dedicated service account (`wbi-cloudbuild@<project>.iam.gserviceaccount.com`) requires only:

| Role                          | Purpose                    |
| ----------------------------- | -------------------------- |
| `roles/notebooks.admin`       | Manage Workbench instances |
| `roles/logging.logWriter`     | Write structured logs      |
| `roles/storage.objectCreator` | Upload reports (optional)  |

> **Note**: The service account does NOT need `roles/editor` or `roles/owner`.

---

## Structured Logging

All Cloud Build steps output JSON-formatted logs for Cloud Logging:

```json
{
  "severity": "INFO",
  "message": "Starting upgrade operation",
  "timestamp": "2024-01-21T20:00:00Z",
  "project": "my-project",
  "operation": "upgrade"
}
```

### Query Logs

```bash
gcloud logging read 'resource.type="build" AND jsonPayload.message:*' \
  --project=YOUR_PROJECT_ID \
  --limit=100 \
  --format=json
```

---

## Artifacts

Build reports are automatically saved to:

```
gs://YOUR_PROJECT_ID-cloudbuild-artifacts/wbi-fleet-upgrade/BUILD_ID/
```

Files include:

- `upgrade-report-*.json` or `rollback-report-*.json`
- `workbench-upgrade.log` or `workbench-rollback.log`

---

## Examples

### Single Instance Upgrade (Dry Run)

```bash
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=my-project,_LOCATIONS="europe-west2-a",_INSTANCE_ID=my-notebook,_OPERATION=upgrade,_DRY_RUN=true
```

### Fleet Rollback with Verbose Logging

```bash
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=my-project,_LOCATIONS="europe-west2-a europe-west2-b europe-west2-c",_OPERATION=rollback,_DRY_RUN=false,_VERBOSE=true
```

### Upgrade with Auto-Rollback on Failure

```bash
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=my-project,_LOCATIONS="europe-west2-a",_OPERATION=upgrade,_DRY_RUN=false,_ROLLBACK_ON_FAILURE=true
```

---

## Cloud Build Triggers

For automated builds, create a Cloud Build trigger:

```bash
gcloud builds triggers create github \
  --name="wbi-upgrade-manual" \
  --repo-name="wbi-fleet-upgrade" \
  --repo-owner="ONSdigital" \
  --branch-pattern="^main$" \
  --build-config="cloudbuild.yaml" \
  --substitutions="_PROJECT_ID=my-project,_LOCATIONS=europe-west2-a,_DRY_RUN=true" \
  --service-account="projects/my-project/serviceAccounts/wbi-cloudbuild@my-project.iam.gserviceaccount.com"
```

---

## Troubleshooting

### Permission Denied

Ensure the service account has the required roles:

```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --filter="bindings.members:wbi-cloudbuild@" \
  --format="table(bindings.role)"
```

### Build Timeout

Increase the timeout substitution:

```bash
--substitutions=...,_TIMEOUT=10800  # 3 hours
```

### Dry Run Always Enabled

The configuration defaults to `_DRY_RUN=true` for safety.
Explicitly set `_DRY_RUN=false` for actual operations.
