#!/bin/bash
# ========================================
# Docker Entrypoint for WBI Fleet Upgrader
# ========================================
# Handles container initialization and command execution
# Supports environment variable configuration

set -euo pipefail

# ========================================
# Configuration
# ========================================

# Default values (can be overridden by environment variables)
: "${GCP_PROJECT_ID:=}"
: "${LOCATIONS:=}"
: "${INSTANCE_ID:=}"
: "${DRY_RUN:=false}"
: "${OPERATION:=upgrade}"
: "${MAX_PARALLEL:=5}"
: "${TIMEOUT:=7200}"
: "${POLL_INTERVAL:=20}"
: "${HEALTH_CHECK_TIMEOUT:=600}"
: "${STAGGER_DELAY:=3.0}"
: "${ROLLBACK_ON_FAILURE:=false}"
: "${VERBOSE:=false}"
: "${JSON_LOGGING:=false}"

# ========================================
# Functions
# ========================================

log() {
    local level="${1}"
    local message="${2}"

    if [[ "${JSON_LOGGING}" == "true" ]]; then
        echo "{\"severity\":\"${level}\",\"message\":\"${message}\",\"timestamp\":\"$(date -Iseconds)\"}"
    else
        echo "[$(date -Iseconds)] [${level}] ${message}"
    fi
}

# Input validation functions for security
validate_project_id() {
    local project_id=$1
    # GCP project ID: 6-30 chars, lowercase letters, digits, hyphens
    # Must start with letter, cannot end with hyphen
    if [[ ! "$project_id" =~ ^[a-z][-a-z0-9]{4,28}[a-z0-9]$ ]]; then
        log "ERROR" "Invalid GCP project ID format: $project_id"
        log "ERROR" "Project ID must be 6-30 characters: lowercase letters, digits, hyphens"
        log "ERROR" "Must start with a letter and cannot end with a hyphen"
        return 1
    fi
    return 0
}

validate_zone() {
    local zone=$1
    # GCP zone format: region-zone (e.g., us-central1-a, europe-west2-b)
    if [[ ! "$zone" =~ ^[a-z]+-[a-z]+[0-9]+-[a-z]$ ]]; then
        log "ERROR" "Invalid GCP zone format: $zone"
        log "ERROR" "Zone must match pattern: region-zone (e.g., us-central1-a)"
        return 1
    fi
    return 0
}

validate_instance_id() {
    local instance_id=$1
    # Instance ID: lowercase letters, digits, hyphens (RFC 1123)
    if [[ ! "$instance_id" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        log "ERROR" "Invalid instance ID format: $instance_id"
        log "ERROR" "Instance ID must contain only lowercase letters, digits, and hyphens"
        return 1
    fi
    return 0
}

validate_numeric_range() {
    local value=$1
    local min=$2
    local max=$3
    local name=$4

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log "ERROR" "$name must be a positive integer: $value"
        return 1
    fi

    if [[ $value -lt $min || $value -gt $max ]]; then
        log "ERROR" "$name must be between $min and $max: $value"
        return 1
    fi
    return 0
}

show_help() {
    cat <<EOF
WBI Fleet Upgrader - Container Entrypoint

USAGE:
    docker run [OPTIONS] IMAGE [COMMAND] [ARGS...]

ENVIRONMENT VARIABLES:
    GCP_PROJECT_ID           GCP project ID (required)
    LOCATIONS                Space-separated list of locations (required)
    INSTANCE_ID              Specific instance ID (optional)
    OPERATION                Operation: upgrade or rollback (default: upgrade)
    DRY_RUN                  Enable dry-run mode (default: false)
    MAX_PARALLEL             Max parallel operations (default: 5)
    TIMEOUT                  Operation timeout in seconds (default: 7200)
    POLL_INTERVAL            Poll interval in seconds (default: 20)
    HEALTH_CHECK_TIMEOUT     Health check timeout (default: 600)
    STAGGER_DELAY            Delay between operations (default: 3.0)
    ROLLBACK_ON_FAILURE      Auto-rollback on failure (default: false)
    VERBOSE                  Enable verbose output (default: false)
    JSON_LOGGING             Enable JSON logging (default: false)

COMMANDS:
    upgrade                  Run upgrade operation (default)
    rollback                 Run rollback operation
    bash                     Start interactive bash shell
    --help, help             Show this help message

EXAMPLES:
    # Upgrade with environment variables
    docker run -e GCP_PROJECT_ID=my-project \\
               -e LOCATIONS="europe-west2-a" \\
               -e DRY_RUN=true \\
               IMAGE upgrade

    # Rollback specific instance
    docker run -e GCP_PROJECT_ID=my-project \\
               -e LOCATIONS="europe-west2-a" \\
               -e INSTANCE_ID=my-notebook \\
               IMAGE rollback

    # Interactive shell
    docker run -it IMAGE bash

    # Show Python help
    docker run IMAGE --help

MOUNTING CREDENTIALS:
    # Using service account key
    docker run -v /path/to/key.json:/app/key.json \\
               -e GOOGLE_APPLICATION_CREDENTIALS=/app/key.json \\
               -e GCP_PROJECT_ID=my-project \\
               -e LOCATIONS="europe-west2-a" \\
               IMAGE upgrade

    # Using gcloud credentials
    docker run -v ~/.config/gcloud:/root/.config/gcloud:ro \\
               -e GCP_PROJECT_ID=my-project \\
               -e LOCATIONS="europe-west2-a" \\
               IMAGE upgrade

For more information, visit:
    https://github.com/erayguner/wbi-fleet-upgrade
EOF
}

build_python_args() {
    local args=()

    # Required arguments
    if [[ -n "${GCP_PROJECT_ID}" ]]; then
        args+=(--project "${GCP_PROJECT_ID}")
    fi

    if [[ -n "${LOCATIONS}" ]]; then
        # shellcheck disable=SC2206
        args+=(--locations ${LOCATIONS})
    fi

    # Optional arguments
    if [[ -n "${INSTANCE_ID}" ]]; then
        args+=(--instance "${INSTANCE_ID}")
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        args+=(--dry-run)
    fi

    if [[ "${OPERATION}" == "rollback" ]]; then
        args+=(--rollback)
    elif [[ "${ROLLBACK_ON_FAILURE}" == "true" ]]; then
        args+=(--rollback-on-failure)
    fi

    if [[ "${VERBOSE}" == "true" ]]; then
        args+=(--verbose)
    fi

    # Operational parameters
    args+=(--max-parallel "${MAX_PARALLEL}")
    args+=(--timeout "${TIMEOUT}")
    args+=(--poll-interval "${POLL_INTERVAL}")
    args+=(--health-check-timeout "${HEALTH_CHECK_TIMEOUT}")
    args+=(--stagger-delay "${STAGGER_DELAY}")

    echo "${args[@]}"
}

validate_environment() {
    local errors=0

    # Validate project ID
    if [[ -z "${GCP_PROJECT_ID}" ]]; then
        log "ERROR" "GCP_PROJECT_ID is required"
        errors=$((errors + 1))
    elif ! validate_project_id "$GCP_PROJECT_ID"; then
        errors=$((errors + 1))
    fi

    # Validate locations
    if [[ -z "${LOCATIONS}" ]]; then
        log "ERROR" "LOCATIONS is required"
        errors=$((errors + 1))
    else
        # Validate each zone in the space-separated list
        IFS=' ' read -ra ZONES <<< "$LOCATIONS"
        for zone in "${ZONES[@]}"; do
            if ! validate_zone "$zone"; then
                errors=$((errors + 1))
            fi
        done
    fi

    # Validate instance ID if provided
    if [[ -n "${INSTANCE_ID}" ]] && ! validate_instance_id "$INSTANCE_ID"; then
        errors=$((errors + 1))
    fi

    # Validate operation type
    if [[ "${OPERATION}" != "upgrade" && "${OPERATION}" != "rollback" ]]; then
        log "ERROR" "OPERATION must be 'upgrade' or 'rollback'"
        errors=$((errors + 1))
    fi

    # Validate numeric parameters
    if ! validate_numeric_range "$MAX_PARALLEL" 1 100 "MAX_PARALLEL"; then
        errors=$((errors + 1))
    fi

    if ! validate_numeric_range "$TIMEOUT" 60 86400 "TIMEOUT"; then
        errors=$((errors + 1))
    fi

    if ! validate_numeric_range "$POLL_INTERVAL" 5 300 "POLL_INTERVAL"; then
        errors=$((errors + 1))
    fi

    if ! validate_numeric_range "$HEALTH_CHECK_TIMEOUT" 30 3600 "HEALTH_CHECK_TIMEOUT"; then
        errors=$((errors + 1))
    fi

    # Validate stagger delay (float between 0.1 and 60.0)
    if ! [[ "$STAGGER_DELAY" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log "ERROR" "STAGGER_DELAY must be a positive number: $STAGGER_DELAY"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        log "ERROR" "Environment validation failed with ${errors} error(s)"
        return 1
    fi

    return 0
}

# ========================================
# Main Execution
# ========================================

main() {
    log "INFO" "WBI Fleet Upgrader - Version ${APP_VERSION:-unknown}"
    log "INFO" "Starting container entrypoint"

    # Handle special commands
    case "${1:-}" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        bash|sh|/bin/bash|/bin/sh)
            log "INFO" "Starting interactive shell"
            exec "${1}"
            ;;
        upgrade|rollback)
            OPERATION="${1}"
            shift
            ;;
    esac

    # If no arguments, check if we can build from environment
    if [[ $# -eq 0 ]]; then
        if validate_environment; then
            log "INFO" "Building command from environment variables"
            log "INFO" "Project: ${GCP_PROJECT_ID}"
            log "INFO" "Locations: ${LOCATIONS}"
            log "INFO" "Operation: ${OPERATION}"
            log "INFO" "Dry-run: ${DRY_RUN}"

            # Build Python command
            python_args=$(build_python_args)
            log "INFO" "Executing: python3 main.py ${python_args}"

            # Execute
            exec python3 main.py ${python_args}
        else
            log "ERROR" "No command provided and environment validation failed"
            echo ""
            show_help
            exit 1
        fi
    fi

    # Pass through to Python CLI
    log "INFO" "Executing: python3 main.py $*"
    exec python3 main.py "$@"
}

# Run main function
main "$@"
