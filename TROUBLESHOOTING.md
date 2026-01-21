# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the WBI Fleet Upgrader.

## Table of Contents

1. [Authentication Issues](#authentication-issues)
2. [Permission Errors](#permission-errors)
3. [API and Rate Limiting](#api-and-rate-limiting)
4. [Instance State Issues](#instance-state-issues)
5. [Timeout Problems](#timeout-problems)
6. [Rollback Issues](#rollback-issues)
7. [Cloud Build Problems](#cloud-build-problems)
8. [Performance Issues](#performance-issues)
9. [Getting Help](#getting-help)

## Authentication Issues

### Problem: "Could not automatically determine credentials"

**Symptoms:**
```
google.auth.exceptions.DefaultCredentialsError: Could not automatically determine credentials
```

**Solutions:**

1. **Authenticate with Application Default Credentials (ADC)**:
   ```bash
   gcloud auth application-default login
   ```

2. **Verify authentication**:
   ```bash
   gcloud auth list
   ```

3. **Set active account**:
   ```bash
   gcloud config set account YOUR_EMAIL@example.com
   ```

4. **Check environment variables**:
   ```bash
   # These should NOT be set unless using a service account
   echo $GOOGLE_APPLICATION_CREDENTIALS
   unset GOOGLE_APPLICATION_CREDENTIALS  # If needed
   ```

### Problem: "Invalid authentication credentials"

**Solutions:**

1. **Re-authenticate**:
   ```bash
   gcloud auth application-default revoke
   gcloud auth application-default login
   ```

2. **Verify project access**:
   ```bash
   gcloud projects describe YOUR_PROJECT_ID
   ```

3. **Check for expired credentials**:
   ```bash
   # Clear cached credentials
   rm -rf ~/.config/gcloud/legacy_credentials
   rm -rf ~/.config/gcloud/application_default_credentials.json
   gcloud auth application-default login
   ```

## Permission Errors

### Problem: "Permission denied" or "403 Forbidden"

**Symptoms:**
```
Error 403: Permission denied
The caller does not have permission
```

**Required Permissions:**

Your account needs these IAM roles:
- `roles/notebooks.admin` - Manage Workbench instances
- `roles/compute.viewer` - View compute resources (optional)

**Solutions:**

1. **Check current permissions**:
   ```bash
   gcloud projects get-iam-policy YOUR_PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.members:user:YOUR_EMAIL"
   ```

2. **Grant required roles** (requires Project IAM Admin):
   ```bash
   # Grant notebooks admin role
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="user:YOUR_EMAIL" \
     --role="roles/notebooks.admin"
   ```

3. **Verify API is enabled**:
   ```bash
   gcloud services list --enabled | grep notebooks
   ```

4. **Enable API if needed**:
   ```bash
   gcloud services enable notebooks.googleapis.com
   ```

### Problem: Cloud Build service account permission denied

**Symptoms:**
```
Error: Service account wbi-cloudbuild@PROJECT.iam.gserviceaccount.com does not have permission
```

**Solutions:**

1. **Apply Terraform IAM configuration**:
   ```bash
   cd terraform/cloudbuild-iam
   terraform init
   terraform apply -var="project_id=YOUR_PROJECT_ID"
   ```

2. **Manual IAM setup**:
   ```bash
   # Get project number
   PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')

   # Grant roles to service account
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:wbi-cloudbuild@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/notebooks.admin"

   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:wbi-cloudbuild@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/logging.logWriter"
   ```

## API and Rate Limiting

### Problem: "429 Too Many Requests" or "Quota exceeded"

**Symptoms:**
```
Error 429: Rate limit exceeded
Quota exceeded for quota metric 'Queries' and limit 'Queries per minute'
```

**Solutions:**

1. **Reduce parallelism**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --max-parallel 3 \
     --stagger-delay 10.0
   ```

2. **Increase stagger delay**:
   ```bash
   # Add 5-10 second delay between operations
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --stagger-delay 10.0
   ```

3. **Process in batches**:
   ```bash
   # Do one location at a time
   python3 main.py --project PROJECT --locations zone-1
   # Wait a few minutes
   python3 main.py --project PROJECT --locations zone-2
   ```

4. **Check quota limits**:
   ```bash
   gcloud compute project-info describe --project=YOUR_PROJECT_ID
   ```

### Problem: "409 Conflict - Operation already in progress"

**Symptoms:**
```
Error 409: Operation already in progress
```

**Solutions:**

1. **Wait for existing operation to complete**:
   ```bash
   # Check instance status
   gcloud notebooks instances describe INSTANCE_NAME --location=ZONE
   ```

2. **Increase stagger delay**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --stagger-delay 5.0
   ```

3. **Reduce parallelism**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --max-parallel 5
   ```

## Instance State Issues

### Problem: "Instance is busy" - Operations skipped

**Symptoms:**
```
Skipping instance-name: instance is busy (state=UPGRADING)
```

**Valid "Busy" States:**
- PROVISIONING
- STARTING
- STOPPING
- UPGRADING
- INITIALIZING
- SUSPENDING

**Solutions:**

1. **Wait for operation to complete**:
   ```bash
   # Monitor instance state
   watch -n 30 'gcloud notebooks instances describe INSTANCE_NAME --location=ZONE --format="value(state)"'
   ```

2. **Check operation status**:
   ```bash
   # List recent operations
   gcloud notebooks operations list --location=ZONE
   ```

3. **If stuck for > 2 hours**, contact Google Cloud support

### Problem: "Instance not found"

**Symptoms:**
```
Instance 'my-instance' not found in any of the specified locations
```

**Solutions:**

1. **List all instances**:
   ```bash
   gcloud notebooks instances list --location=ZONE
   ```

2. **Check correct zone**:
   ```bash
   # List all zones in region
   gcloud compute zones list --filter="region:(europe-west2)"
   ```

3. **Verify instance name**:
   ```bash
   # Instance ID is the last part of the resource name
   # projects/PROJECT/locations/ZONE/instances/INSTANCE_ID
   ```

### Problem: Instances stuck in STOPPED or SUSPENDED

**Symptoms:**
- Instances are STOPPED/SUSPENDED and not starting

**Solution:**

The tool automatically starts STOPPED/SUSPENDED instances before operations. If this fails:

1. **Manually start instance**:
   ```bash
   gcloud notebooks instances start INSTANCE_NAME --location=ZONE
   ```

2. **Check for errors**:
   ```bash
   gcloud notebooks instances describe INSTANCE_NAME --location=ZONE
   ```

3. **Increase timeout**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --timeout 10800 \
     --health-check-timeout 1200
   ```

## Timeout Problems

### Problem: "Timeout upgrading instance after XXX seconds"

**Symptoms:**
```
Timeout upgrading instance-name after 7200s
```

**Solutions:**

1. **Increase operation timeout**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --timeout 10800  # 3 hours
   ```

2. **Increase health check timeout**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --health-check-timeout 1200  # 20 minutes
   ```

3. **Check instance is actually upgrading**:
   ```bash
   gcloud notebooks instances describe INSTANCE_NAME --location=ZONE
   ```

4. **For large instances**, use longer timeouts:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --timeout 14400 \
     --health-check-timeout 1800 \
     --poll-interval 30
   ```

### Problem: Health check timeout after upgrade

**Symptoms:**
```
Health verification failed for instance-name
```

**Solutions:**

1. **Increase health check timeout**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --health-check-timeout 1800  # 30 minutes
   ```

2. **Check instance logs**:
   ```bash
   gcloud notebooks instances describe INSTANCE_NAME \
     --location=ZONE \
     --format="value(state,healthState)"
   ```

3. **Manually verify instance**:
   ```bash
   # Check if instance is actually ACTIVE
   gcloud notebooks instances describe INSTANCE_NAME --location=ZONE
   ```

## Rollback Issues

### Problem: "No upgrade history found" - Rollback not available

**Symptoms:**
```
instance_state check: PASSED
upgrade_history check: FAILED - No upgrade history found
```

**Why rollback isn't available:**
- Instance was never upgraded
- Upgrade history was cleared
- Instance is brand new

**Solution:**
- Rollback is only available for recently upgraded instances
- No action needed - instance cannot be rolled back

### Problem: "No snapshot available" - Rollback not available

**Symptoms:**
```
upgrade_history check: FAILED - No snapshot available from previous upgrade
```

**Why this happens:**
- Previous upgrade didn't create a snapshot
- Snapshot was deleted

**Solution:**
- Rollback not possible without snapshot
- Future upgrades will create snapshots

### Problem: Rollback eligibility check passes but rollback fails

**Symptoms:**
```
Pre-checks all PASSED
Rollback started but failed: Instance is not eligible for rollback
```

**Solutions:**

1. **Check rollback window hasn't expired**:
   - Rollback may have a time window (e.g., 30 days)
   - Pre-checks may pass but rollback API rejects

2. **Verify with GCP directly**:
   ```bash
   gcloud notebooks instances describe INSTANCE_NAME --location=ZONE
   ```

3. **Check upgrade history details**:
   - Look at the JSON report pre-check results
   - Verify snapshot and timing information

## Cloud Build Problems

### Problem: Build fails immediately with "validation failed"

**Symptoms:**
```
ERROR: _PROJECT_ID is required
```

**Solutions:**

1. **Check substitutions**:
   ```bash
   gcloud builds submit --config=cloudbuild.yaml \
     --substitutions=_PROJECT_ID=my-project,_LOCATIONS="zone1 zone2"
   ```

2. **Quote locations properly**:
   ```bash
   # Correct
   --substitutions=_LOCATIONS="zone1 zone2"

   # Wrong
   --substitutions=_LOCATIONS=zone1 zone2  # This breaks parsing
   ```

3. **Verify all required substitutions**:
   ```bash
   # Minimum required:
   --substitutions=_PROJECT_ID=PROJECT,_LOCATIONS="ZONES"
   ```

### Problem: "Service account not found" in Cloud Build

**Symptoms:**
```
Error: Service account wbi-cloudbuild@PROJECT.iam.gserviceaccount.com does not exist
```

**Solution:**

1. **Create service account with Terraform**:
   ```bash
   cd terraform/cloudbuild-iam
   terraform init
   terraform apply -var="project_id=YOUR_PROJECT_ID"
   ```

2. **Or remove service account from cloudbuild.yaml**:
   - Comment out the `serviceAccount` line
   - Cloud Build will use default service account

### Problem: Cloud Build timeout

**Symptoms:**
```
Error: Build timeout
```

**Solutions:**

1. **Increase build timeout in cloudbuild.yaml**:
   ```yaml
   timeout: 14400s  # 4 hours instead of 2
   ```

2. **Or increase via command line**:
   ```bash
   gcloud builds submit --timeout=14400s --config=cloudbuild.yaml ...
   ```

## Performance Issues

### Problem: Upgrades taking very long

**Symptoms:**
- Operations take hours to complete
- Much slower than expected

**Solutions:**

1. **Increase parallelism** (if not rate limited):
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --max-parallel 20
   ```

2. **Check for rate limiting**:
   - Look for 429 errors in logs
   - If present, reduce parallelism

3. **Use appropriate poll interval**:
   ```bash
   # Less frequent polling
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --poll-interval 30  # Check every 30 seconds
   ```

4. **Process regions in parallel**:
   ```bash
   # Run multiple commands in parallel for different regions
   python3 main.py --project P --locations zone1 &
   python3 main.py --project P --locations zone2 &
   wait
   ```

### Problem: High API costs

**Symptoms:**
- Unexpectedly high API usage costs

**Solutions:**

1. **Reduce poll frequency**:
   ```bash
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --poll-interval 30  # Instead of default 20
   ```

2. **Batch operations**:
   - Process fewer locations per run
   - Space out operations over time

## Getting Help

### Collecting Diagnostic Information

When reporting issues, include:

1. **Version information**:
   ```bash
   python3 --version
   gcloud version
   cat pyproject.toml | grep version
   ```

2. **Command used**:
   ```bash
   # Include the exact command you ran
   python3 main.py --project PROJECT --locations ZONE --dry-run --verbose
   ```

3. **Error messages**:
   ```bash
   # Include relevant log excerpts
   tail -50 workbench-upgrade.log
   ```

4. **JSON report** (if available):
   ```bash
   cat upgrade-report-*.json | jq '.statistics'
   ```

5. **Instance state**:
   ```bash
   gcloud notebooks instances describe INSTANCE_NAME --location=ZONE
   ```

### Where to Get Help

1. **Documentation**:
   - [Quickstart Guide](QUICKSTART.md)
   - [Operations Guide](OPERATIONS.md)
   - [Cloud Build Guide](docs/cloud-build.md)

2. **GitHub Issues**:
   - Report bugs: https://github.com/yourusername/wbi-fleet-upgrade/issues
   - Include diagnostic information above

3. **Verbose Logging**:
   ```bash
   # Get detailed debug output
   python3 main.py \
     --project PROJECT \
     --locations ZONE \
     --verbose \
     --dry-run
   ```

4. **Google Cloud Support**:
   - For API-level issues
   - For quota increase requests
   - For instance-specific problems

### Quick Diagnostic Checklist

Run through this checklist before asking for help:

- [ ] Tried with `--dry-run` first
- [ ] Checked authentication with `gcloud auth list`
- [ ] Verified project with `gcloud config get-value project`
- [ ] Confirmed API is enabled with `gcloud services list --enabled | grep notebooks`
- [ ] Checked instance exists with `gcloud notebooks instances list`
- [ ] Reviewed logs with `--verbose` flag
- [ ] Checked JSON report for errors
- [ ] Verified instance state is not "busy"
- [ ] Checked for permission errors in logs
- [ ] Tried increasing timeouts for timeout issues
- [ ] Checked for rate limiting (429 errors)
- [ ] Reviewed pre-check results for rollback issues

---

**Still having issues?** Open a GitHub issue with diagnostic information above.
