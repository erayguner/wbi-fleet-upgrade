#!/bin/bash
# Cloud Build Entrypoint Script for WBI Fleet Upgrade/Rollback
#
# This script is designed for non-interactive Cloud Build execution.
# It handles validation, structured logging, and proper error handling.
#
# Environment Variables:
#   GCP_PROJECT_ID    - GCP project ID (required)
#   LOCATIONS         - Space-separated zones (required)
#   OPERATION         - Operation type: upgrade or rollback (default: upgrade)
#   DRY_RUN           - Dry-run mode: true or false (default: true)
#   INSTANCE_ID       - Specific instance ID (optional)
#   MAX_PARALLEL      - Max concurrent operations (default: 10)
#   TIMEOUT           - Timeout per operation in seconds (default: 7200)
#   POLL_INTERVAL     - Seconds between polls (default: 20)
#   HEALTH_CHECK_TIMEOUT - Health check timeout (default: 600)
#   STAGGER_DELAY     - Delay between starting operations (default: 3.0)
#   ROLLBACK_ON_FAILURE - Auto-rollback on upgrade failure (default: false)
#   JSON_LOGGING      - Enable JSON logging (default: true)
#   VERBOSE           - Enable verbose output (default: false)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration with defaults
PROJECT_ID="${GCP_PROJECT_ID:-}"
LOCATIONS="${LOCATIONS:-}"
OPERATION="${OPERATION:-upgrade}"
DRY_RUN="${DRY_RUN:-true}"
INSTANCE_ID="${INSTANCE_ID:-}"
MAX_PARALLEL="${MAX_PARALLEL:-10}"
TIMEOUT="${TIMEOUT:-7200}"
POLL_INTERVAL="${POLL_INTERVAL:-20}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-600}"
STAGGER_DELAY="${STAGGER_DELAY:-3.0}"
ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE:-false}"
JSON_LOGGING="${JSON_LOGGING:-true}"
VERBOSE="${VERBOSE:-false}"

# Logging functions
timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log_json() {
    local severity="$1"
    local message="$2"
    shift 2
    
    local extra_fields=""
    while [[ $# -gt 0 ]]; do
        extra_fields="$extra_fields,\"$1\":\"$2\""
        shift 2
    done
    
    echo "{\"severity\":\"$severity\",\"message\":\"$message\",\"timestamp\":\"$(timestamp)\"${extra_fields}}"
}

log_info() {
    if [[ "$JSON_LOGGING" == "true" ]]; then
        log_json "INFO" "$@"
    else
        echo "[INFO] $(timestamp) - $1"
    fi
}

log_error() {
    if [[ "$JSON_LOGGING" == "true" ]]; then
        log_json "ERROR" "$@"
    else
        echo "[ERROR] $(timestamp) - $1" >&2
    fi
}

log_warn() {
    if [[ "$JSON_LOGGING" == "true" ]]; then
        log_json "WARNING" "$@"
    else
        echo "[WARN] $(timestamp) - $1"
    fi
}

# Validation
validate_inputs() {
    local errors=0
    
    if [[ -z "$PROJECT_ID" ]]; then
        log_error "GCP_PROJECT_ID environment variable is required"
        errors=$((errors + 1))
    fi
    
    if [[ -z "$LOCATIONS" ]]; then
        log_error "LOCATIONS environment variable is required"
        errors=$((errors + 1))
    fi
    
    if [[ "$OPERATION" != "upgrade" && "$OPERATION" != "rollback" ]]; then
        log_error "OPERATION must be 'upgrade' or 'rollback', got: $OPERATION"
        errors=$((errors + 1))
    fi
    
    if [[ ! -f "$REPO_ROOT/main.py" ]]; then
        log_error "main.py not found at $REPO_ROOT/main.py"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Validation failed with $errors error(s)"
        return 1
    fi
    
    log_info "Validation passed" "project" "$PROJECT_ID" "operation" "$OPERATION"
    return 0
}

# Main execution
main() {
    log_info "Starting Cloud Build entrypoint" "operation" "$OPERATION" "dry_run" "$DRY_RUN"
    
    # Validate inputs
    validate_inputs || exit 1
    
    # Change to repository root
    cd "$REPO_ROOT"
    
    # Check Python availability
    if ! command -v python3 &>/dev/null; then
        log_error "Python3 is not available"
        exit 1
    fi
    
    log_info "Python version: $(python3 --version)"
    
    # Install dependencies if not already installed
    if ! python3 -c "import google.cloud.notebooks" 2>/dev/null; then
        log_info "Installing Python dependencies"
        pip install --quiet -r requirements.txt
    fi
    
    # Build Python arguments
    # Convert space-separated LOCATIONS to array for proper handling
    # shellcheck disable=SC2206
    local -a location_array=($LOCATIONS)
    
    PYTHON_ARGS=(
        "--project" "$PROJECT_ID"
        "--locations" "${location_array[@]}"
        "--max-parallel" "$MAX_PARALLEL"
        "--timeout" "$TIMEOUT"
        "--poll-interval" "$POLL_INTERVAL"
        "--health-check-timeout" "$HEALTH_CHECK_TIMEOUT"
        "--stagger-delay" "$STAGGER_DELAY"
    )
    
    # Add optional instance ID
    if [[ -n "$INSTANCE_ID" ]]; then
        PYTHON_ARGS+=("--instance" "$INSTANCE_ID")
    fi
    
    # Add dry-run flag
    if [[ "$DRY_RUN" == "true" ]]; then
        PYTHON_ARGS+=("--dry-run")
    fi
    
    # Add operation-specific flags
    if [[ "$OPERATION" == "rollback" ]]; then
        PYTHON_ARGS+=("--rollback")
    elif [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
        PYTHON_ARGS+=("--rollback-on-failure")
    fi
    
    # Add verbose flag
    if [[ "$VERBOSE" == "true" ]]; then
        PYTHON_ARGS+=("--verbose")
    fi
    
    log_info "Executing: python3 main.py ${PYTHON_ARGS[*]}"
    
    # Execute the Python script
    local exit_code=0
    if python3 main.py "${PYTHON_ARGS[@]}"; then
        log_info "$OPERATION completed successfully" "operation" "$OPERATION"
    else
        exit_code=$?
        log_error "$OPERATION failed with exit code: $exit_code" "operation" "$OPERATION" "exit_code" "$exit_code"
    fi
    
    # Report summary
    local report_pattern
    if [[ "$OPERATION" == "rollback" ]]; then
        report_pattern="rollback-report-*.json"
    else
        report_pattern="upgrade-report-*.json"
    fi
    
    # shellcheck disable=SC2086
    if ls $report_pattern 1>/dev/null 2>&1; then
        log_info "Report files generated" "pattern" "$report_pattern"
    fi
    
    return $exit_code
}

# Run main
main "$@"
