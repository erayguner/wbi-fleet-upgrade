# Operations Guide: WBI Fleet Upgrade & Rollback

This guide provides detailed operational procedures, best practices, and troubleshooting for managing Vertex AI Workbench instance upgrades and rollbacks at scale.

## Table of Contents

1. [Operational Overview](#operational-overview)
2. [Pre-Flight Checklist](#pre-flight-checklist)
3. [Standard Operating Procedures](#standard-operating-procedures)
4. [Rollback Procedures](#rollback-procedures)
5. [Monitoring and Alerting](#monitoring-and-alerting)
6. [Incident Response](#incident-response)
7. [Best Practices](#best-practices)

## Operational Overview

### What This Tool Does

The WBI Fleet Upgrader automates the upgrade and rollback of Vertex AI Workbench instances with:

- **Fleet-wide operations** across multiple GCP zones
- **Parallel processing** for efficiency
- **Automatic health checks** before and after operations
- **Auto-start** for STOPPED/SUSPENDED instances
- **Automatic rollback** on upgrade failures (optional)
- **Comprehensive logging** and JSON reports

### Key Features for Operations Teams

| Feature | Description | When to Use |
|---------|-------------|-------------|
| **Dry Run** | Simulate operations without changes | Always before actual operations |
| **Health Checks** | Verify instance ACTIVE state | Automatic - always enabled |
| **Auto-Start** | Start stopped/suspended instances | Automatic before upgrade/rollback |
| **Rollback Protection** | Auto-rollback on failure | Critical production instances |
| **Parallel Control** | Limit concurrent operations | Prevent API throttling |
| **Stagger Delay** | Delay between operation starts | Avoid overwhelming GCP APIs |

## Pre-Flight Checklist

### Before Any Upgrade Operation

- [ ] **Verify authentication**: `gcloud auth list`
- [ ] **Check project access**: `gcloud config get-value project`
- [ ] **Confirm API enabled**: `gcloud services list --enabled | grep notebooks`
- [ ] **Review maintenance window**: Ensure sufficient time for operation
- [ ] **Run dry-run first**: Always test with `--dry-run`
- [ ] **Notify stakeholders**: Alert teams of planned upgrades
- [ ] **Backup critical data**: Ensure important work is saved
- [ ] **Check instance states**: Verify instances are accessible
- [ ] **Review recent changes**: Check for recent upgrades or issues
- [ ] **Prepare rollback plan**: Know rollback eligibility

### Before Rollback Operation

- [ ] **Confirm rollback eligibility**: Run dry-run with `--rollback`
- [ ] **Verify snapshot exists**: Check pre-check results
- [ ] **Check rollback window**: Ensure within supported timeframe
- [ ] **Document reason**: Record why rollback is needed
- [ ] **Get approval**: Obtain necessary sign-offs
- [ ] **Prepare stakeholders**: Notify teams of rollback

## Standard Operating Procedures

### SOP 1: Fleet Upgrade (Development Environment)

**Purpose**: Upgrade all instances in development zones with minimal risk.

**Prerequisites**:
- Development environment instances
- Maintenance window scheduled
- Team notified

**Procedure**:

```bash
# Step 1: Dry run to check what will be upgraded
python3 main.py \
  --project dev-project-id \
  --locations europe-west2-a \
  --dry-run \
  --verbose

# Step 2: Review dry-run output
# - Check number of instances found
# - Verify which instances are upgradeable
# - Note any skipped instances and reasons

# Step 3: Execute upgrade with monitoring
python3 main.py \
  --project dev-project-id \
  --locations europe-west2-a \
  --max-parallel 10 \
  --verbose

# Step 4: Monitor logs in real-time
tail -f workbench-upgrade.log

# Step 5: Review results
cat upgrade-report-*.json | jq '.statistics'
cat upgrade-report-*.json | jq '.results[] | select(.status=="failed")'

# Step 6: Document results
# - Record success/failure counts
# - Note any issues encountered
# - Update runbook if needed
```

**Success Criteria**:
- All instances successfully upgraded
- All instances in ACTIVE state
- No errors in logs

**Rollback Plan**: If failures occur, use automatic rollback (see SOP 4).

---

### SOP 2: Fleet Upgrade (Production Environment)

**Purpose**: Safely upgrade production instances with maximum protection.

**Prerequisites**:
- Change approval obtained
- Maintenance window scheduled (2-4 hours)
- Stakeholders notified
- Rollback plan prepared
- On-call engineer available

**Procedure**:

```bash
# Step 1: Pre-upgrade validation (dry run)
python3 main.py \
  --project prod-project-id \
  --locations europe-west2-a europe-west2-b \
  --dry-run \
  --verbose

# Step 2: Review and document dry-run results
# Save output for change record
python3 main.py \
  --project prod-project-id \
  --locations europe-west2-a europe-west2-b \
  --dry-run \
  --verbose > pre-upgrade-dryrun.log 2>&1

# Step 3: Start upgrade with all safety features
python3 main.py \
  --project prod-project-id \
  --locations europe-west2-a europe-west2-b \
  --max-parallel 5 \
  --rollback-on-failure \
  --health-check-timeout 900 \
  --stagger-delay 5.0 \
  --timeout 10800 \
  --verbose

# Step 4: Monitor progress (in separate terminal)
watch -n 30 'tail -20 workbench-upgrade.log'

# Step 5: Post-upgrade verification
# Check all instances are ACTIVE
gcloud notebooks instances list \
  --filter="state=ACTIVE" \
  --format="table(name,state,location)"

# Step 6: Generate and review report
cat upgrade-report-*.json | jq '.'

# Step 7: Validate instance functionality
# Test key instances manually
gcloud notebooks instances describe CRITICAL_INSTANCE \
  --location=LOCATION

# Step 8: Document and communicate results
# - Send summary to stakeholders
# - Update change record
# - Close maintenance window
```

**Safety Features Enabled**:
- Low parallelism (5 concurrent)
- Automatic rollback on failure
- Extended health check timeout (15 min)
- Stagger delay (5 seconds)
- Extended operation timeout (3 hours)
- Verbose logging

**Success Criteria**:
- Zero failed upgrades
- All instances ACTIVE
- Functionality verified

**Escalation**: If > 10% failure rate, halt operations and escalate to team lead.

---

### SOP 3: Single Instance Upgrade (Critical Production Instance)

**Purpose**: Upgrade a single critical instance with maximum safety.

**Prerequisites**:
- Instance not actively in use
- User notified and work saved
- Rollback plan confirmed

**Procedure**:

```bash
# Step 1: Verify instance state and rollback eligibility
gcloud notebooks instances describe INSTANCE_NAME --location=LOCATION

# Step 2: Check upgrade availability (dry run)
python3 main.py \
  --project prod-project-id \
  --locations LOCATION \
  --instance INSTANCE_NAME \
  --dry-run \
  --verbose

# Step 3: Verify rollback is available BEFORE upgrading
python3 main.py \
  --project prod-project-id \
  --locations LOCATION \
  --instance INSTANCE_NAME \
  --rollback \
  --dry-run

# Step 4: Execute upgrade with rollback protection
python3 main.py \
  --project prod-project-id \
  --locations LOCATION \
  --instance INSTANCE_NAME \
  --rollback-on-failure \
  --health-check-timeout 1200 \
  --timeout 7200 \
  --verbose

# Step 5: Verify upgrade success
gcloud notebooks instances describe INSTANCE_NAME --location=LOCATION

# Step 6: Test instance functionality
# Have user verify their environment works

# Step 7: Document results
```

**Success Criteria**:
- Instance successfully upgraded
- Instance in ACTIVE state
- User confirms functionality

**If Failed**: Automatic rollback will trigger. Verify rollback completed successfully.

---

### SOP 4: Staged Fleet Upgrade (Canary Deployment)

**Purpose**: Upgrade fleet gradually to minimize risk.

**Strategy**: Upgrade in waves with validation between each wave.

**Procedure**:

```bash
# Wave 1: Canary instances (5% of fleet)
python3 main.py \
  --project prod-project-id \
  --locations europe-west2-a \
  --max-parallel 2 \
  --rollback-on-failure \
  --verbose

# Validation checkpoint 1: Wait 1 hour, monitor for issues
# - Check all upgraded instances
# - Monitor user feedback
# - Review logs for errors

# Wave 2: Early adopters (20% of fleet)
python3 main.py \
  --project prod-project-id \
  --locations europe-west2-b \
  --max-parallel 5 \
  --rollback-on-failure \
  --verbose

# Validation checkpoint 2: Wait 2 hours
# - Check metrics and monitoring
# - Verify no performance degradation

# Wave 3: Majority (remaining fleet)
python3 main.py \
  --project prod-project-id \
  --locations europe-west2-c us-central1-a \
  --max-parallel 10 \
  --rollback-on-failure \
  --verbose

# Final validation: Complete upgrade
# - Generate final report
# - Document any issues
# - Close change ticket
```

**Abort Criteria**:
- > 5% failure rate in canary wave
- User-reported issues
- Performance degradation
- Any critical errors

---

## Rollback Procedures

### SOP 5: Single Instance Rollback

**Purpose**: Revert a recently upgraded instance to previous version.

**Prerequisites**:
- Instance was recently upgraded
- Snapshot exists (verified via dry-run)
- Within rollback window

**Procedure**:

```bash
# Step 1: Verify rollback eligibility
python3 main.py \
  --project PROJECT_ID \
  --locations LOCATION \
  --instance INSTANCE_NAME \
  --rollback \
  --dry-run \
  --verbose

# Step 2: Review pre-check results
# Verify all checks PASSED:
# - Instance state: PASSED
# - Upgrade history: PASSED
# - Snapshot validity: PASSED
# - Rollback window: PASSED

# Step 3: Execute rollback
python3 main.py \
  --project PROJECT_ID \
  --locations LOCATION \
  --instance INSTANCE_NAME \
  --rollback \
  --health-check-timeout 900 \
  --verbose

# Step 4: Monitor rollback progress
tail -f workbench-rollback.log

# Step 5: Verify rollback success
gcloud notebooks instances describe INSTANCE_NAME --location=LOCATION

# Step 6: Test instance functionality
# Have user verify their environment

# Step 7: Document incident
# - Why rollback was needed
# - Rollback duration
# - Any issues encountered
```

**Success Criteria**:
- Instance rolled back to previous version
- Instance in ACTIVE state
- Functionality verified

---

### SOP 6: Fleet Rollback (Emergency)

**Purpose**: Rollback multiple instances after widespread upgrade failure.

**When to Use**: Critical issues affecting multiple instances after upgrade.

**Procedure**:

```bash
# Step 1: STOP any ongoing upgrades
# Kill any running upgrade processes

# Step 2: Assess scope of issue
# Identify affected instances
gcloud notebooks instances list \
  --filter="state!=ACTIVE" \
  --format="table(name,state,location)"

# Step 3: Check rollback eligibility for fleet
python3 main.py \
  --project PROJECT_ID \
  --locations LOCATION1 LOCATION2 \
  --rollback \
  --dry-run \
  --verbose

# Step 4: Review eligible instances
# Check pre-check results in dry-run output

# Step 5: Execute fleet rollback
python3 main.py \
  --project PROJECT_ID \
  --locations LOCATION1 LOCATION2 \
  --rollback \
  --max-parallel 10 \
  --health-check-timeout 1200 \
  --verbose

# Step 6: Monitor rollback progress
watch -n 30 'tail -20 workbench-rollback.log'

# Step 7: Verify all rollbacks completed
cat rollback-report-*.json | jq '.statistics'

# Step 8: Check instance states
gcloud notebooks instances list --format="table(name,state,location)"

# Step 9: Incident documentation
# - Root cause analysis
# - Number of instances affected
# - Rollback duration
# - Lessons learned
```

---

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Operation Success Rate**
   ```bash
   # Check success percentage
   cat upgrade-report-*.json | jq '.statistics |
     {total, upgraded, failed, success_rate: ((.upgraded / .total) * 100)}'
   ```

2. **Operation Duration**
   ```bash
   # Average upgrade time
   cat upgrade-report-*.json | jq '[.results[] |
     select(.duration_seconds != null) | .duration_seconds] |
     add / length'
   ```

3. **Health Check Failures**
   ```bash
   # Instances with health issues
   cat upgrade-report-*.json | jq '.results[] |
     select(.error_message | contains("Health"))'
   ```

### Log Analysis

**Find failures**:
```bash
grep "FAILED" workbench-upgrade.log
```

**Find timeouts**:
```bash
grep "Timeout" workbench-upgrade.log
```

**Check rollbacks triggered**:
```bash
grep "Rollback started" workbench-upgrade.log
```

**Analyze pre-check failures (rollback)**:
```bash
cat rollback-report-*.json | jq '.results[] |
  select(.status=="skipped") |
  {instance: .instance_name, reason: .error_message}'
```

### Cloud Build Monitoring

**Query Cloud Build logs**:
```bash
gcloud logging read 'resource.type="build" AND
  jsonPayload.message:*upgrade*' \
  --project=PROJECT_ID \
  --limit=100 \
  --format=json
```

**Filter failed builds**:
```bash
gcloud builds list \
  --filter="status=FAILURE" \
  --limit=10
```

---

## Incident Response

### Incident Response Plan

#### Severity 1: Multiple Production Instances Down

**Immediate Actions**:
1. Page on-call engineer
2. Assess scope of outage
3. Check if automatic rollback triggered
4. If not, initiate manual rollback (SOP 6)
5. Monitor rollback progress
6. Communicate status to stakeholders every 15 minutes

**Communication Template**:
```
INCIDENT: WBI Upgrade Failure
SEVERITY: 1
AFFECTED: X instances in [locations]
STATUS: Rollback in progress
ETA: [time]
UPDATES: Every 15 minutes
```

#### Severity 2: Single Critical Instance Failed

**Immediate Actions**:
1. Verify automatic rollback triggered
2. If not, initiate manual rollback (SOP 5)
3. Notify instance owner
4. Monitor rollback
5. Verify functionality post-rollback

#### Severity 3: Upgrade Slower Than Expected

**Actions**:
1. Check timeout settings
2. Review instance logs
3. Verify no API throttling
4. Consider increasing timeout
5. Document for future operations

### Escalation Path

1. **Level 1**: On-call Engineer (0-15 min)
2. **Level 2**: Team Lead (15-30 min)
3. **Level 3**: Engineering Manager (30-60 min)
4. **Level 4**: Director (> 60 min, critical outage)

---

## Best Practices

### Upgrade Best Practices

1. **Always Dry-Run First**
   - Never skip dry-run in production
   - Review dry-run output carefully
   - Document expected vs actual results

2. **Start Small**
   - Test with single instance first
   - Use canary deployments
   - Gradually increase scope

3. **Use Appropriate Parallelism**
   - Dev: 10-20 concurrent operations
   - Prod: 5-10 concurrent operations
   - Critical: 1-3 concurrent operations

4. **Enable Rollback Protection**
   - Always use `--rollback-on-failure` in production
   - Verify rollback eligibility before upgrading
   - Document rollback procedures

5. **Monitor Actively**
   - Watch logs in real-time
   - Check progress every 15-30 minutes
   - Set alerts for failures

6. **Maintain Documentation**
   - Document all upgrades
   - Record any issues
   - Update runbooks

### Rollback Best Practices

1. **Verify Eligibility First**
   - Always dry-run rollback before executing
   - Check all pre-check results
   - Confirm snapshot availability

2. **Understand Limitations**
   - Rollback only available if recently upgraded
   - Requires valid snapshot
   - Must be within rollback window

3. **Test Rollback in Dev**
   - Practice rollback procedures
   - Verify rollback functionality
   - Document rollback duration

4. **Document Every Rollback**
   - Why rollback was needed
   - What went wrong
   - How to prevent in future

### Safety Best Practices

1. **Use Safe Defaults**
   - Default to dry-run in scripts
   - Use conservative timeout values
   - Enable verbose logging

2. **Implement Health Checks**
   - Verify instances before operations
   - Check health after operations
   - Set appropriate health check timeouts

3. **Control API Rate**
   - Use stagger delay (3-5 seconds)
   - Limit parallelism appropriately
   - Handle 429 (rate limit) errors gracefully

4. **Backup Critical Data**
   - Ensure important work is saved
   - Verify backup snapshots exist
   - Test restore procedures

### Operational Excellence

1. **Automation**
   - Use Cloud Build for scheduled upgrades
   - Implement automatic monitoring
   - Set up alerting

2. **Testing**
   - Test in dev before prod
   - Run dry-runs regularly
   - Verify rollback capability

3. **Documentation**
   - Keep runbooks updated
   - Document all procedures
   - Share lessons learned

4. **Communication**
   - Notify stakeholders
   - Provide status updates
   - Document results

---

## Appendix: Command Reference

### Common Commands

```bash
# Fleet upgrade (dry-run)
python3 main.py --project P --locations L --dry-run

# Fleet upgrade (production-safe)
python3 main.py --project P --locations L \
  --max-parallel 5 --rollback-on-failure --verbose

# Single instance upgrade
python3 main.py --project P --locations L --instance I \
  --rollback-on-failure

# Check rollback eligibility
python3 main.py --project P --locations L --rollback --dry-run

# Execute rollback
python3 main.py --project P --locations L --instance I --rollback

# Cloud Build upgrade
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=P,_LOCATIONS="L",_OPERATION=upgrade,_DRY_RUN=false

# Cloud Build rollback
gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_PROJECT_ID=P,_LOCATIONS="L",_OPERATION=rollback,_DRY_RUN=false
```

### Monitoring Commands

```bash
# List instances
gcloud notebooks instances list --location=L

# Describe instance
gcloud notebooks instances describe I --location=L

# Check instance state
gcloud notebooks instances list --filter="state!=ACTIVE"

# Review logs
tail -f workbench-upgrade.log
grep "FAILED\|ERROR" workbench-upgrade.log

# Analyze reports
cat upgrade-report-*.json | jq '.statistics'
cat upgrade-report-*.json | jq '.results[] | select(.status=="failed")'
```

---

**Document Version**: 1.0
**Last Updated**: 2026-01-21
**Owner**: Platform Engineering Team
**Review Frequency**: Quarterly
