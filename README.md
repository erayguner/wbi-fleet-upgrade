# Vertex AI Workbench Fleet Upgrader

[![Linting and Security](https://github.com/erayguner/wbi-fleet-upgrade/actions/workflows/ci.yml/badge.svg)](https://github.com/erayguner/wbi-fleet-upgrade/actions/workflows/ci.yml)
[![CodeQL](https://github.com/erayguner/wbi-fleet-upgrade/actions/workflows/codeql.yml/badge.svg)](https://github.com/erayguner/wbi-fleet-upgrade/actions/workflows/codeql.yml)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)

> **Production-ready tool for managing Vertex AI Workbench instance upgrades and rollbacks at scale**

## Overview

A comprehensive, safe, and well-tested tool for automating Vertex AI Workbench instance lifecycle management. Built for production use with fleet-scale operations, automatic safety features, and comprehensive monitoring.

### What This Tool Does

- **Automates upgrades** across entire fleets of Workbench instances
- **Manages rollbacks** to previous versions when needed
- **Handles complexity** of multi-location operations
- **Ensures safety** with dry-run mode, health checks, and automatic rollback
- **Provides visibility** with detailed logs and JSON reports
- **Integrates with CI/CD** via Google Cloud Build
- **Deploys as serverless API** via Cloud Function (Gen2)
- **Follows best practices** with least-privilege IAM and structured logging

### Deployment Options

| Option | Best For | Documentation |
|--------|----------|---------------|
| **Python CLI** | Local operations, scripting | [Quickstart](QUICKSTART.md) |
| **Container** | CI/CD pipelines, Cloud Run | [Container Deployment](CONTAINER_README.md) |
| **Cloud Function** | Serverless API, scheduled triggers | [Cloud Function](docs/CLOUD_FUNCTION_DEPLOYMENT.md) |

### Key Benefits

- 🚀 **Save time**: Upgrade hundreds of instances in minutes instead of hours
- 🛡️ **Reduce risk**: Automatic health checks and rollback on failure
- 📊 **Full visibility**: Detailed reports and structured logging
- 🔒 **Production-safe**: Dry-run mode, staged deployments, comprehensive testing
- 🌍 **Multi-region**: Upgrade across multiple GCP zones in parallel
- 🔧 **Easy to use**: Simple CLI interface with sensible defaults
- 📖 **Well-documented**: Comprehensive guides and operational runbooks

## Documentation

- 📚 **[Quickstart Guide](QUICKSTART.md)** - Get started in 10 minutes
- 📋 **[Operations Guide](OPERATIONS.md)** - Production operations and procedures
- 🔧 **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Problem diagnosis and resolution
- ☁️ **[Cloud Build Setup](docs/cloud-build.md)** - CI/CD integration
- 🐳 **[Container Deployment](CONTAINER_README.md)** - Containerized deployment guide
- ⚡ **[Cloud Function Deployment](docs/CLOUD_FUNCTION_DEPLOYMENT.md)** - Serverless REST API deployment
- 🚀 **[Release Process](docs/RELEASE_PROCESS.md)** - Automated releases and versioning
- 🤝 **[Contributing](CONTRIBUTING.md)** - Development and testing
- 📖 **[Documentation Index](docs/README.md)** - Complete documentation reference

## Quick Start

**New users**: See the [Quickstart Guide](QUICKSTART.md) for detailed setup instructions.

### 1. Install Dependencies

```bash
# Clone the repository
git clone https://github.com/yourusername/wbi-fleet-upgrade.git
cd wbi-fleet-upgrade

# Install Python dependencies
pip install -r requirements.txt

# Verify installation
python3 main.py --help
```

### 2. Authenticate with Google Cloud

```bash
# Login and set default application credentials
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required API
gcloud services enable notebooks.googleapis.com
```

### 3. Run Your First Dry-Run

**IMPORTANT**: Always start with a dry-run to see what would happen without making changes.

```bash
# Check what instances need upgrading
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --dry-run
```

This will:
- ✅ Scan all instances in the specified location
- ✅ Check which ones need upgrading
- ✅ Show you what would happen
- ✅ **Make NO actual changes**

### 4. Perform Your First Upgrade

After reviewing the dry-run output:

```bash
# Upgrade with automatic rollback protection
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --rollback-on-failure
```

## Common Usage Examples

### Upgrade Fleet Across Multiple Locations

```bash
# Dry-run first
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a europe-west2-b us-central1-a \
  --dry-run

# Execute upgrade
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a europe-west2-b us-central1-a \
  --rollback-on-failure
```

### Upgrade Single Instance

```bash
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --instance my-notebook-instance \
  --rollback-on-failure \
  --verbose
```

### Rollback Recently Upgraded Instance

```bash
# Check rollback eligibility first
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --instance my-notebook-instance \
  --rollback \
  --dry-run

# Execute rollback
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --instance my-notebook-instance \
  --rollback
```

### Production-Safe Upgrade with All Safety Features

```bash
python3 main.py \
  --project YOUR_PROJECT_ID \
  --locations europe-west2-a \
  --max-parallel 5 \
  --rollback-on-failure \
  --health-check-timeout 900 \
  --stagger-delay 5.0 \
  --verbose
```

### Using Bash Wrappers (Environment Variables)

```bash
# Set environment variables
export GCP_PROJECT_ID=YOUR_PROJECT_ID
export LOCATIONS="europe-west2-a europe-west2-b"

# Upgrade (dry-run)
./wb-upgrade.sh --dry-run

# Upgrade (actual)
./wb-upgrade.sh

# Rollback (dry-run)
./wb-rollback.sh --dry-run

# Rollback (actual)
./wb-rollback.sh
```

## Features

### Core Capabilities

- ✅ **Fleet Operations**: Upgrade or rollback entire fleets across multiple GCP zones
- ✅ **Single Instance Operations**: Target specific instances for precise control
- ✅ **Parallel Processing**: Control concurrency with `--max-parallel` (default: 5-10)
- ✅ **Dry-Run Mode**: Preview operations without making any changes
- ✅ **Auto-Start Instances**: Automatically start STOPPED/SUSPENDED instances before operations
- ✅ **Health Checks**: Pre and post-operation health validation (ACTIVE state verification)

### Safety Features

- 🛡️ **Automatic Rollback**: Auto-rollback failed upgrades with `--rollback-on-failure`
- 🔍 **Pre-Flight Checks**: Comprehensive validation before rollback operations
- ⏱️ **Configurable Timeouts**: Per-instance timeouts with health check monitoring
- 🚦 **Stagger Delay**: Prevents API throttling with configurable delays between operations
- 📊 **State Validation**: Only operates on eligible instances (ACTIVE, ready state)
- 🔄 **Retry Logic**: Exponential backoff for transient API errors

### Monitoring & Reporting

- 📋 **Detailed Logs**: Structured logs to `workbench-upgrade.log` or `workbench-rollback.log`
- 📊 **JSON Reports**: Machine-readable reports with full operation details
- 📈 **Statistics**: Success/failure counts, timing, duration analysis
- 🔍 **Verbose Mode**: Detailed debugging output with `--verbose`
- ☁️ **Cloud Logging**: Integration with Google Cloud Logging (Cloud Build)
- 📦 **Artifact Storage**: Automatic upload of reports to Cloud Storage

### Advanced Features

- 🔄 **Manual Rollback Mode**: Dedicated rollback workflow with eligibility pre-checks
- 🌍 **Multi-Location Support**: Parallel operations across multiple GCP zones
- ⚙️ **Configurable Parameters**: Tune all operational parameters via CLI flags
- 🔐 **Least-Privilege IAM**: Terraform configurations for secure service accounts
- 🚀 **CI/CD Integration**: Production-ready Cloud Build configuration
- 🧪 **Comprehensive Testing**: 80%+ test coverage with unit and integration tests

## How to Use It

### Basic Commands

```bash
# Check which instances need upgrading (dry run)
python3 main.py --project <project-id> --locations LOCATION --dry-run

# Upgrade all instances in a location
python3 main.py --project <project-id> --locations LOCATION

# Upgrade one specific instance
python3 main.py --project <project-id> --locations LOCATION --instance INSTANCE_ID

# Upgrade with automatic rollback on failure
python3 main.py --project <project-id> --locations LOCATION \
  --rollback-on-failure

# Check rollback eligibility for all instances (dry run)
python3 main.py --project <project-id> --locations LOCATION \
  --rollback --dry-run

# Roll back one instance to previous version
python3 main.py --project <project-id> --locations LOCATION \
  --instance INSTANCE_ID --rollback
```

### All Options

```text
--project <project-id>              Your GCP project ID (required)
--locations LOC1 LOC2          Zone locations to check (required)
--instance INSTANCE_ID         Specific instance to upgrade or
                               roll back (optional)
--rollback                     Rollback mode: revert to previous
                               version (instead of upgrade)
--dry-run                      Check without upgrading or rolling
                               back
--max-parallel NUM             How many to upgrade/rollback at
                               once (default: 10)
--timeout SECONDS              How long to wait per operation
                               (default: 7200)
--poll-interval SECONDS        How often to check progress
                               (default: 20)
--rollback-on-failure          In upgrade mode, roll back if
                               upgrade fails
--health-check-timeout SECS    How long to wait for health check
                               (default: 800)
--stagger-delay SECONDS        Delay between starting operations
                               (default: 5.0)
--verbose                      Show detailed output
```

## Project Structure

```text
/
├── fleet_upgrader/         Main Python package (CLI)
│   ├── clients.py          API client for Workbench
│   ├── upgrader.py         Upgrade logic
│   ├── rollback.py         Rollback logic
│   ├── models.py           Data structures
│   ├── config.py           Configuration
│   └── log_utils.py        Logging setup
├── cloud_function/         Cloud Function deployment
│   ├── main.py             HTTP entry point
│   ├── requirements.txt    Dependencies
│   └── src/                Core modules
├── terraform/              Infrastructure as Code
│   ├── cloud-function/     Cloud Function Terraform
│   ├── cloudbuild-iam/     Cloud Build IAM
│   └── artifact-registry/  Docker registry
├── main.py                 Python CLI tool
├── wb-upgrade.sh           Bash wrapper for upgrades
├── wb-rollback.sh          Bash wrapper for rollback
├── docs/                   Documentation
└── tests/                  Unit tests
```

## Real Examples

### Example 1: Test Before Upgrading

```bash
# Always test with --dry-run first
python3 main.py \
  --project <project-id> \
  --locations europe-west2-a \
  --dry-run
```

### Example 2: Upgrade Multiple Locations

```bash
# Upgrade all instances in three locations
python3 main.py \
  --project <project-id> \
  --locations europe-west2-a europe-west2-b europe-west2-c \
  --max-parallel 10
```

### Example 3: Upgrade One Critical Instance

```bash
# Upgrade one instance with rollback protection
python3 main.py \
  --project <project-id> \
  --locations europe-west2-a \
  --instance wbi \
  --rollback-on-failure \
  --verbose
```

### Example 4: Use Environment Variables

```bash
export GCP_PROJECT_ID=<project-id>
export LOCATIONS="europe-west2-a europe-west2-b"

./wb-upgrade.sh --dry-run
```

### Example 5: Check Rollback Eligibility (Fleet)

```bash
python3 main.py \
  --project <project-id> \
  --locations europe-west2-a europe-west2-b \
  --rollback \
  --dry-run
```

### Example 6: Roll Back One Instance

```bash
python3 main.py \
  --project <project-id> \
  --locations europe-west2-a \
  --instance wbi \
  --rollback \
  --verbose
```

## Safety & Best Practices

### Built-in Safety Features

1. **Dry-Run by Default**: Cloud Build defaults to dry-run mode for safety
2. **Health Checks**: Automatic pre and post-operation health validation
3. **Automatic Rollback**: Optional auto-rollback on upgrade failure
4. **State Validation**: Only operates on eligible instances (ACTIVE, ready state)
5. **Pre-Flight Checks**: Comprehensive rollback eligibility validation
6. **API Rate Limiting**: Stagger delay and parallelism controls prevent throttling
7. **Detailed Logging**: Track every operation step with structured logs
8. **JSON Reports**: Machine-readable reports for audit and analysis

### Operational Best Practices

#### Before Any Operation

1. ✅ **Always dry-run first** - Understand impact before making changes
2. ✅ **Start small** - Test with one instance before fleet operations
3. ✅ **Backup critical data** - Ensure important work is saved
4. ✅ **Check maintenance windows** - Schedule during low-usage periods
5. ✅ **Notify stakeholders** - Alert teams of planned operations
6. ✅ **Verify rollback eligibility** - Confirm rollback capability before upgrading

#### During Operations

1. 📊 **Monitor logs actively** - Watch for errors and warnings
2. ⏱️ **Track progress** - Monitor operation duration and success rate
3. 🚨 **Watch for failures** - Be ready to halt operations if issues arise
4. 📱 **Stay available** - Have on-call engineer during critical operations

#### After Operations

1. ✅ **Verify all instances** - Confirm all instances are ACTIVE and healthy
2. 📋 **Review reports** - Check JSON reports for any issues
3. 📝 **Document results** - Record outcomes for audit trail
4. 🔄 **Update procedures** - Improve runbooks based on learnings

### Production Deployment Checklist

- [ ] Tested in development environment
- [ ] Dry-run completed successfully
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified
- [ ] On-call engineer available
- [ ] Rollback plan prepared
- [ ] Monitoring configured
- [ ] IAM permissions verified
- [ ] Cloud Build service account configured
- [ ] Backup of critical data completed

## What Happens During an Upgrade

1. **Scan**: Find all instances in specified locations
2. **Pre-Start (Fleet)**: Start all STOPPED/SUSPENDED instances in
   parallel; skip actual start in --dry-run
3. **Check**: Verify each instance is ACTIVE and ready; if
   STOPPED/SUSPENDED and not yet started, the tool will start it
   automatically
4. **Test Upgradeability**: Ask GCP if upgrade is available
5. **Upgrade**: Start the upgrade operation
6. **Monitor**: Poll the operation until complete
7. **Verify**: Check instance is ACTIVE and healthy
8. **Report**: Generate detailed logs and reports

## Rollback Guide

### When You Can Roll Back

Rollback is only available if the instance was upgraded recently and a
valid snapshot/previous version exists. The tool performs pre-checks to
confirm:

- Instance is in ACTIVE state (STOPPED/SUSPENDED instances are started
  in parallel first, unless --dry-run)
- Recent successful upgrade is present in history
- A valid snapshot/rollback target exists
- Rollback timing window is still valid

Use `--rollback --dry-run` to check eligibility safely.

### How Rollback Works

1. **Scan**: Find instances in specified locations (or a single
   instance)
2. **Pre-Start (Fleet)**: Start all STOPPED/SUSPENDED instances in
   parallel prior to eligibility checks; skip actual start in --dry-run
3. **Pre-Checks**: Validate state, upgrade history, snapshot, and
   timing window
4. **Rollback**: Trigger rollback to the previous version
5. **Monitor**: Poll until the operation completes
6. **Verify**: Confirm the instance returns to ACTIVE and is healthy
7. **Report**: Write logs to `workbench-rollback.log` and JSON report
   `rollback-report-*.json`

### Rollback Commands

```bash
# Fleet rollback eligibility (dry run) - shows which
# STOPPED/SUSPENDED instances would be started
python3 main.py --project <project-id> --locations LOCATIONS \
  --rollback --dry-run

# Single instance rollback (auto-start if STOPPED/SUSPENDED)
python3 main.py --project <project-id> --locations LOCATIONS \
  --instance INSTANCE_ID --rollback

# Bash wrapper (with env vars)
export GCP_PROJECT_ID=<project-id>
export LOCATIONS="europe-west2-a europe-west2-b"
./wb-rollback.sh --dry-run
```

### Rollback Troubleshooting

#### Rollback Not Available

```bash
# Check upgrade history for the instance
# Ensure a recent successful upgrade exists
# Confirm snapshot/previous version is available
```

#### Permission Denied

```bash
# Check you're logged in
gcloud auth list

# Check project access
gcloud projects describe PROJECT_ID
```

#### Instance Busy or Not Running

```bash
# Ensure instance is ACTIVE
# Wait for ongoing operations to finish (UPGRADING/STARTING/STOPPING)
```

## Development

### Run Tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=fleet_upgrader --cov-report=html
```

## Requirements

- Python 3.8 or newer
- Google Cloud SDK (`gcloud`)
- Active GCP authentication
- Notebooks API enabled: [Notebooks API (v2)](https://notebooks.googleapis.com/$discovery/rest?version=v2)
- Required Python packages (see `requirements.txt`)

## Support

- File issues on GitHub
- Check logs in `workbench-upgrade.log` and `workbench-rollback.log`
- Review JSON reports for detailed information
- Use `--verbose` for debugging
