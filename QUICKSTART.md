# Quickstart Guide: WBI Fleet Upgrade & Rollback

This guide will get you up and running with the Vertex AI Workbench Fleet Upgrader in under 10 minutes.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [First Run (Dry Run)](#first-run-dry-run)
4. [Common Workflows](#common-workflows)
5. [Troubleshooting](#troubleshooting)

## Prerequisites

Before you begin, ensure you have:

- **Python 3.11+** installed
- **Google Cloud SDK** (gcloud CLI) installed and configured
- **Active GCP authentication** with appropriate permissions
- **Vertex AI Notebooks API** enabled in your project

### Required GCP Permissions

Your account or service account needs:

```text
roles/notebooks.admin           # Manage Workbench instances
roles/logging.logWriter         # Write logs (optional for Cloud Build)
roles/storage.objectCreator     # Upload reports (optional for Cloud Build)
```

### Enable Required APIs

```bash
gcloud services enable notebooks.googleapis.com --project=YOUR_PROJECT_ID
```

## Installation

### Option 1: Quick Install (Recommended for First-Time Users)

```bash
# Clone the repository
git clone https://github.com/yourusername/wbi-fleet-upgrade.git
cd wbi-fleet-upgrade

# Install dependencies
pip install -r requirements.txt

# Verify installation
python3 main.py --help
```

### Option 2: Development Install

```bash
# Clone and setup virtual environment
git clone https://github.com/yourusername/wbi-fleet-upgrade.git
cd wbi-fleet-upgrade

python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

pip install -r requirements.txt
pip install -r requirements-dev.txt  # For testing and development

# Run tests to verify
pytest tests/ -v
```

### Verify Google Cloud Authentication

```bash
# Check current authentication
gcloud auth list

# Login if needed
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

## First Run (Dry Run)

**IMPORTANT**: Always start with a dry run to understand what would happen without making any changes.

### 1. Check What Instances Exist

```bash
# List instances in one location
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --dry-run
```

**What this does:**
- Scans all Workbench instances in the specified location
- Checks which instances need upgrading
- Shows what would be upgraded
- **Does NOT make any changes**

### 2. Check Multiple Locations

```bash
# Scan multiple zones
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a europe-west2-b europe-west2-c \
  --dry-run
```

### 3. Check a Single Instance

```bash
# Check one specific instance
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --instance my-notebook-instance \
  --dry-run
```

### Understanding Dry Run Output

After running a dry run, you'll see:

```text
======================================================================
Vertex AI Workbench Instances Fleet Upgrade (REST v2)
======================================================================
Project: your-project-id
Locations: europe-west2-a
Dry run: True
...
======================================================================

UPGRADE REPORT
======================================================================
TIMING SUMMARY
----------------------------------------
...

STATISTICS
----------------------------------------
total                : 5
upgradeable          : 3
up_to_date           : 2
...

DRY RUN - WOULD UPGRADE
----------------------------------------
Instance                  Location             Target Version
----------------------------------------------------------------------
notebook-1                europe-west2-a       v1.2.3
notebook-2                europe-west2-a       v1.2.3
```

## Common Workflows

### Workflow 1: Upgrade All Instances in a Location

```bash
# Step 1: Dry run first
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --dry-run

# Step 2: Review output, then run actual upgrade
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a

# Step 3: Check the reports
cat upgrade-report-*.json
cat workbench-upgrade.log
```

### Workflow 2: Upgrade with Automatic Rollback Protection

```bash
# Upgrade with automatic rollback if anything fails
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --rollback-on-failure \
  --verbose
```

**When to use this:**
- Critical production environments
- When you need automatic recovery
- For instances where downtime is expensive

### Workflow 3: Upgrade Multiple Locations in Parallel

```bash
# Upgrade across multiple zones with controlled parallelism
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a europe-west2-b us-central1-a \
  --max-parallel 10 \
  --rollback-on-failure
```

### Workflow 4: Rollback Recently Upgraded Instance

```bash
# Step 1: Check rollback eligibility (dry run)
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --instance my-notebook \
  --rollback \
  --dry-run

# Step 2: Perform rollback if eligible
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --instance my-notebook \
  --rollback
```

**When rollback is available:**
- Instance was recently upgraded (within rollback window)
- A valid snapshot exists from the previous version
- Instance is currently ACTIVE (or STOPPED/SUSPENDED - will be auto-started)

### Workflow 5: Using Environment Variables

```bash
# Set environment variables for convenience
export GCP_PROJECT_ID=your-project-id
export LOCATIONS="europe-west2-a europe-west2-b"

# Use bash wrappers
./wb-upgrade.sh --dry-run      # Dry run upgrade
./wb-upgrade.sh                # Actual upgrade
./wb-rollback.sh --dry-run     # Check rollback eligibility
```

### Workflow 6: Production-Safe Upgrade with All Safety Features

```bash
# The safest way to upgrade in production
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --max-parallel 5 \
  --rollback-on-failure \
  --health-check-timeout 900 \
  --stagger-delay 5.0 \
  --verbose
```

**Safety features enabled:**
- Low parallelism (5 concurrent operations)
- Automatic rollback on failures
- Extended health check timeout (15 minutes)
- Stagger delay to prevent API throttling
- Verbose logging for detailed tracking

## Troubleshooting

### Issue: "Permission Denied" Error

**Solution:**

```bash
# Check your authentication
gcloud auth list

# Re-authenticate if needed
gcloud auth application-default login

# Verify project access
gcloud projects describe YOUR_PROJECT_ID

# Check IAM permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"
```

### Issue: "API Not Enabled"

**Solution:**

```bash
# Enable the Notebooks API
gcloud services enable notebooks.googleapis.com --project=YOUR_PROJECT_ID

# Verify it's enabled
gcloud services list --enabled | grep notebooks
```

### Issue: No Instances Found

**Solution:**

```bash
# Verify instances exist in the location
gcloud notebooks instances list --location=europe-west2-a

# Try a different location
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations us-central1-a us-central1-b \
  --dry-run
```

### Issue: "Instance is Busy"

**Symptom:** Instance shows state like "UPGRADING", "STARTING", "STOPPING"

**Solution:**
- Wait for the current operation to complete
- Check instance status: `gcloud notebooks instances describe INSTANCE_NAME --location=LOCATION`
- The tool will skip busy instances automatically

### Issue: Upgrade Timeout

**Solution:**

```bash
# Increase timeout for slow instances
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --timeout 10800 \
  --health-check-timeout 1200
```

### Issue: Rollback Not Available

**Why this happens:**
- Instance wasn't recently upgraded
- No snapshot available from previous version
- Rollback window has expired

**Check eligibility:**

```bash
# Always dry-run rollback first
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --instance my-notebook \
  --rollback \
  --dry-run \
  --verbose
```

Review the pre-check output to understand why rollback isn't available.

## Next Steps

Now that you've completed the quickstart:

1. **Read the Operations Guide**: See `OPERATIONS.md` for detailed operational workflows
2. **Set Up Cloud Build**: See `docs/cloud-build.md` for CI/CD integration
3. **Configure Terraform IAM**: See `terraform/cloudbuild-iam/` for least-privilege setup
4. **Run Tests**: See `CONTRIBUTING.md` for development and testing guidelines

## Quick Reference Commands

```bash
# Dry run upgrade (fleet)
python3 main.py --project PROJECT --locations LOCATION --dry-run

# Actual upgrade (fleet)
python3 main.py --project PROJECT --locations LOCATION

# Single instance upgrade
python3 main.py --project PROJECT --locations LOCATION --instance ID

# Check rollback eligibility
python3 main.py --project PROJECT --locations LOCATION --rollback --dry-run

# Rollback instance
python3 main.py --project PROJECT --locations LOCATION --instance ID --rollback

# Upgrade with all safety features
python3 main.py --project PROJECT --locations LOCATION \
  --rollback-on-failure --max-parallel 5 --verbose

# Using bash wrappers
export GCP_PROJECT_ID=project
export LOCATIONS="zone1 zone2"
./wb-upgrade.sh --dry-run
./wb-rollback.sh --dry-run
```

## Getting Help

- **GitHub Issues**: Report bugs and request features
- **Logs**: Check `workbench-upgrade.log` or `workbench-rollback.log`
- **Reports**: Review JSON reports for detailed information
- **Verbose Mode**: Add `--verbose` for detailed debugging output

## Safety Reminders

1. **Always dry-run first** - Understand what will happen before making changes
2. **Start small** - Test with one instance before upgrading fleets
3. **Use rollback protection** - Add `--rollback-on-failure` for critical instances
4. **Monitor logs** - Watch for errors and warnings during operations
5. **Backup data** - Ensure critical data is backed up before major upgrades
6. **Test in dev first** - Try upgrades in development/staging environments first

---

**Ready to get started?** Run your first dry-run command above!
