#!/bin/bash
# Setup script for WBI Fleet Upgrade & Rollback Tool
#
# This script automates the initial setup process including:
# - Python environment verification
# - Dependency installation
# - Google Cloud authentication check
# - API enablement
# - Basic configuration validation
#
# Usage:
#   ./setup.sh
#   ./setup.sh --with-terraform    # Also setup IAM with Terraform
#   ./setup.sh --dev               # Install development dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
	echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
	echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
	echo -e "${RED}✗${NC} $1"
}

log_section() {
	echo ""
	echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${BLUE}  $1${NC}"
	echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo ""
}

# Check if running as root (not recommended)
if [[ $EUID -eq 0 ]]; then
	log_warning "Running as root is not recommended. Consider running as a regular user."
fi

# Parse command line arguments
WITH_TERRAFORM=false
DEV_MODE=false

while [[ $# -gt 0 ]]; do
	case $1 in
	--with-terraform)
		WITH_TERRAFORM=true
		shift
		;;
	--dev)
		DEV_MODE=true
		shift
		;;
	--help)
		echo "WBI Fleet Upgrade & Rollback Setup Script"
		echo ""
		echo "Usage: ./setup.sh [OPTIONS]"
		echo ""
		echo "Options:"
		echo "  --with-terraform    Setup IAM using Terraform"
		echo "  --dev              Install development dependencies"
		echo "  --help             Show this help message"
		echo ""
		exit 0
		;;
	*)
		log_error "Unknown option: $1"
		echo "Use --help for usage information"
		exit 1
		;;
	esac
done

log_section "WBI Fleet Upgrade & Rollback - Setup"

log_info "This script will set up your environment for WBI operations."
echo ""

# Step 1: Check Python version
log_section "Step 1: Python Environment"

if ! command -v python3 &>/dev/null; then
	log_error "Python 3 is not installed. Please install Python 3.11 or newer."
	exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
log_success "Python $PYTHON_VERSION found"

# Check if Python version is 3.11+
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 11 ]]; then
	log_warning "Python 3.11+ is recommended (you have $PYTHON_VERSION)"
	read -p "Continue anyway? (y/N): " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 1
	fi
fi

# Step 2: Install Python dependencies
log_section "Step 2: Python Dependencies"

if [[ ! -f "requirements.txt" ]]; then
	log_error "requirements.txt not found. Are you in the correct directory?"
	exit 1
fi

log_info "Installing Python dependencies..."

# Check if pip is available
if ! command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
	log_error "pip is not installed. Please install pip first."
	exit 1
fi

# Use pip3 if available, otherwise pip
PIP_CMD="pip3"
if ! command -v pip3 &>/dev/null; then
	PIP_CMD="pip"
fi

# Install dependencies
if $PIP_CMD install -r requirements.txt; then
	log_success "Runtime dependencies installed"
else
	log_error "Failed to install dependencies"
	exit 1
fi

# Install dev dependencies if requested
if $DEV_MODE; then
	log_info "Installing development dependencies..."
	if [[ -f "requirements-dev.txt" ]]; then
		if $PIP_CMD install -r requirements-dev.txt; then
			log_success "Development dependencies installed"
		else
			log_warning "Failed to install some development dependencies"
		fi
	else
		log_warning "requirements-dev.txt not found"
	fi
fi

# Step 3: Check Google Cloud SDK
log_section "Step 3: Google Cloud SDK"

if ! command -v gcloud &>/dev/null; then
	log_error "Google Cloud SDK (gcloud) is not installed."
	log_info "Install it from: https://cloud.google.com/sdk/docs/install"
	exit 1
fi

GCLOUD_VERSION=$(gcloud version --format="value(version)" 2>/dev/null || echo "unknown")
log_success "Google Cloud SDK $GCLOUD_VERSION found"

# Step 4: Check authentication
log_section "Step 4: Google Cloud Authentication"

log_info "Checking authentication status..."

if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
	ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
	log_success "Authenticated as: $ACTIVE_ACCOUNT"
else
	log_warning "Not authenticated with Google Cloud"
	read -p "Would you like to authenticate now? (y/N): " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		gcloud auth application-default login
		log_success "Authentication complete"
	else
		log_warning "Skipping authentication. You'll need to authenticate before using the tool."
	fi
fi

# Step 5: Check project configuration
log_section "Step 5: Project Configuration"

CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

if [[ -z "$CURRENT_PROJECT" ]]; then
	log_warning "No default project configured"
	read -r -p "Enter your GCP project ID (or press Enter to skip): " PROJECT_ID
	if [[ -n "$PROJECT_ID" ]]; then
		gcloud config set project "$PROJECT_ID"
		log_success "Project set to: $PROJECT_ID"
		CURRENT_PROJECT="$PROJECT_ID"
	fi
else
	log_success "Current project: $CURRENT_PROJECT"
fi

# Step 6: Enable required APIs
if [[ -n "$CURRENT_PROJECT" ]]; then
	log_section "Step 6: Enable Required APIs"

	log_info "Checking if Notebooks API is enabled..."

	if gcloud services list --enabled --filter="name:notebooks.googleapis.com" --format="value(name)" 2>/dev/null | grep -q notebooks; then
		log_success "Notebooks API is already enabled"
	else
		log_warning "Notebooks API is not enabled"
		read -p "Would you like to enable it now? (y/N): " -n 1 -r
		echo
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			if gcloud services enable notebooks.googleapis.com; then
				log_success "Notebooks API enabled"
			else
				log_error "Failed to enable Notebooks API"
				log_info "You can enable it manually with: gcloud services enable notebooks.googleapis.com"
			fi
		else
			log_warning "Notebooks API not enabled. You'll need to enable it before using the tool."
		fi
	fi
else
	log_section "Step 6: Enable Required APIs"
	log_warning "Skipping API enablement (no project configured)"
fi

# Step 7: Terraform setup (optional)
if $WITH_TERRAFORM; then
	log_section "Step 7: Terraform IAM Setup"

	if ! command -v terraform &>/dev/null; then
		log_error "Terraform is not installed."
		log_info "Install it from: https://www.terraform.io/downloads"
	else
		TERRAFORM_VERSION=$(terraform version -json | grep terraform_version | cut -d'"' -f4 || echo "unknown")
		log_success "Terraform $TERRAFORM_VERSION found"

		if [[ -d "terraform/cloudbuild-iam" ]]; then
			log_info "Terraform configuration found in terraform/cloudbuild-iam/"
			log_warning "Review the configuration before applying!"

			read -p "Would you like to apply Terraform configuration now? (y/N): " -n 1 -r
			echo
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				cd terraform/cloudbuild-iam

				if [[ -z "$CURRENT_PROJECT" ]]; then
					read -r -p "Enter your GCP project ID: " PROJECT_ID
				else
					PROJECT_ID="$CURRENT_PROJECT"
				fi

				PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)' 2>/dev/null || echo "")

				if [[ -z "$PROJECT_NUMBER" ]]; then
					log_error "Could not get project number for $PROJECT_ID"
				else
					log_info "Initializing Terraform..."
					terraform init

					log_info "Planning Terraform changes..."
					terraform plan \
						-var="project_id=$PROJECT_ID" \
						-var="project_number=$PROJECT_NUMBER"

					read -p "Apply these changes? (y/N): " -n 1 -r
					echo
					if [[ $REPLY =~ ^[Yy]$ ]]; then
						terraform apply \
							-var="project_id=$PROJECT_ID" \
							-var="project_number=$PROJECT_NUMBER"
						log_success "Terraform configuration applied"
					else
						log_info "Terraform apply skipped"
					fi
				fi

				cd ../..
			fi
		else
			log_warning "Terraform configuration not found in terraform/cloudbuild-iam/"
		fi
	fi
fi

# Step 8: Verify installation
log_section "Step 8: Verification"

log_info "Verifying installation..."

# Test Python imports
if python3 -c "import google.auth; from google.auth.transport.requests import AuthorizedSession" 2>/dev/null; then
	log_success "Python dependencies verified"
else
	log_error "Python dependency verification failed"
fi

# Test CLI
if python3 main.py --help >/dev/null 2>&1; then
	log_success "CLI tool verified"
else
	log_error "CLI tool verification failed"
fi

# Run tests if in dev mode
if $DEV_MODE; then
	log_info "Running tests..."
	if command -v pytest &>/dev/null; then
		if pytest tests/ -v --tb=short 2>&1 | tail -20; then
			log_success "Tests passed"
		else
			log_warning "Some tests failed (see output above)"
		fi
	else
		log_warning "pytest not found, skipping tests"
	fi
fi

# Final summary
log_section "Setup Complete!"

echo ""
log_success "Environment setup completed successfully!"
echo ""
log_info "Next steps:"
echo ""
echo "  1. Read the Quickstart Guide:"
echo "     cat QUICKSTART.md"
echo ""
echo "  2. Try a dry-run:"
if [[ -n "$CURRENT_PROJECT" ]]; then
	echo "     python3 main.py --project $CURRENT_PROJECT --locations ZONE --dry-run"
else
	echo "     python3 main.py --project YOUR_PROJECT_ID --locations ZONE --dry-run"
fi
echo ""
echo "  3. Review the Operations Guide:"
echo "     cat OPERATIONS.md"
echo ""
echo "  4. Set up Cloud Build (optional):"
echo "     cat docs/cloud-build.md"
echo ""

log_info "Documentation:"
echo "  - Quickstart: QUICKSTART.md"
echo "  - Operations: OPERATIONS.md"
echo "  - Cloud Build: docs/cloud-build.md"
echo "  - Contributing: CONTRIBUTING.md"
echo ""

log_success "You're all set! Trigger upgrades via Cloud Build when ready. 🚀"
echo ""
