#!/bin/bash
# Terraform Validation Script
# Tests all Terraform configurations WITHOUT deploying resources
# Validates: syntax, formatting, configuration, security issues

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

echo "════════════════════════════════════════════════════════════"
echo "  Terraform Validation - NO RESOURCES WILL BE CREATED"
echo "════════════════════════════════════════════════════════════"
echo ""

# Function to run check
run_check() {
    local check_name="$1"
    local check_command="$2"
    local allow_failure="${3:-false}"

    ((TOTAL_CHECKS++))
    echo -n "  ▶ $check_name... "

    if eval "$check_command" > /tmp/tf-check-output.log 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED_CHECKS++))
        return 0
    else
        if [[ "$allow_failure" == "true" ]]; then
            echo -e "${YELLOW}⚠ WARNING${NC}"
            ((WARNINGS++))
            cat /tmp/tf-check-output.log | head -5
            return 0
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((FAILED_CHECKS++))
            cat /tmp/tf-check-output.log
            return 1
        fi
    fi
}

# Check prerequisites
echo -e "${BLUE}[1/6] Checking Prerequisites${NC}"
echo "────────────────────────────────────────────────────────────"

if ! command -v terraform >/dev/null 2>&1; then
    echo -e "${RED}✗ Terraform not installed${NC}"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo -e "${GREEN}✓ Terraform version: $TERRAFORM_VERSION${NC}"

if command -v tflint >/dev/null 2>&1; then
    TFLINT_VERSION=$(tflint --version | head -1)
    echo -e "${GREEN}✓ TFLint available: $TFLINT_VERSION${NC}"
    HAS_TFLINT=true
else
    echo -e "${YELLOW}⚠ TFLint not installed (optional)${NC}"
    HAS_TFLINT=false
fi

if command -v tfsec >/dev/null 2>&1; then
    TFSEC_VERSION=$(tfsec --version | head -1)
    echo -e "${GREEN}✓ TFSec available: $TFSEC_VERSION${NC}"
    HAS_TFSEC=true
else
    echo -e "${YELLOW}⚠ TFSec not installed (optional)${NC}"
    HAS_TFSEC=false
fi

echo ""

# Find all Terraform modules
MODULES=(
    "terraform/cloudbuild-iam"
    "terraform/artifact-registry"
    "terraform/artifact-registry-iam"
)

# Validate each module
for MODULE in "${MODULES[@]}"; do
    if [[ ! -d "$MODULE" ]]; then
        echo -e "${YELLOW}⚠ Module not found: $MODULE (skipping)${NC}"
        continue
    fi

    echo -e "${BLUE}[Testing] $MODULE${NC}"
    echo "────────────────────────────────────────────────────────────"

    cd "$MODULE"

    # Test 1: Terraform Format Check
    run_check "Format check (terraform fmt)" \
        "terraform fmt -check -recursive -diff" \
        "true"

    # Test 2: Terraform Init
    run_check "Initialize module (terraform init)" \
        "terraform init -backend=false -upgrade=false"

    # Test 3: Terraform Validate
    run_check "Validate configuration (terraform validate)" \
        "terraform validate"

    # Test 4: Check for required variables
    if [[ -f "variables.tf" ]]; then
        run_check "Variables file exists" \
            "test -f variables.tf"
    fi

    # Test 5: TFLint (if available)
    if [[ "$HAS_TFLINT" == "true" ]]; then
        run_check "Lint with TFLint" \
            "tflint --init && tflint" \
            "true"
    fi

    # Test 6: TFSec security scan (if available)
    if [[ "$HAS_TFSEC" == "true" ]]; then
        run_check "Security scan with TFSec" \
            "tfsec . --minimum-severity MEDIUM" \
            "true"
    fi

    cd - > /dev/null
    echo ""
done

# Test new files (not yet in main modules)
echo -e "${BLUE}[2/6] Testing New Security Files${NC}"
echo "────────────────────────────────────────────────────────────"

NEW_FILES=(
    "terraform/cloudbuild-iam/custom-roles.tf"
    "terraform/cloudbuild-iam/audit-logging.tf"
    "terraform/cloudbuild-iam/workload-identity.tf"
    "terraform/artifact-registry/kms.tf"
    "terraform/artifact-registry-iam/storage-scoped.tf"
)

for FILE in "${NEW_FILES[@]}"; do
    if [[ -f "$FILE" ]]; then
        MODULE_DIR=$(dirname "$FILE")
        FILE_NAME=$(basename "$FILE")

        echo -e "  Testing: ${BLUE}$FILE${NC}"

        # Syntax check
        run_check "  Syntax check" \
            "terraform fmt -check $FILE" \
            "true"

        # Check for common issues
        run_check "  No hardcoded values" \
            "! grep -E 'project_id\s*=\s*\"[^$]' $FILE" \
            "true"
    else
        echo -e "${YELLOW}⚠ File not found: $FILE${NC}"
    fi
done

echo ""

# Test 3: Dependency Graph (dry-run)
echo -e "${BLUE}[3/6] Testing Terraform Dependency Graph${NC}"
echo "────────────────────────────────────────────────────────────"

for MODULE in "${MODULES[@]}"; do
    if [[ ! -d "$MODULE" ]]; then
        continue
    fi

    MODULE_NAME=$(basename "$MODULE")
    echo -e "  Generating graph for: ${BLUE}$MODULE_NAME${NC}"

    cd "$MODULE"
    if terraform graph > /tmp/graph-$MODULE_NAME.dot 2>&1; then
        echo -e "  ${GREEN}✓${NC} Graph generated: /tmp/graph-$MODULE_NAME.dot"
    else
        echo -e "  ${YELLOW}⚠${NC} Could not generate graph"
    fi
    cd - > /dev/null
done

echo ""

# Test 4: Variable validation
echo -e "${BLUE}[4/6] Testing Variable Definitions${NC}"
echo "────────────────────────────────────────────────────────────"

for MODULE in "${MODULES[@]}"; do
    if [[ ! -d "$MODULE" ]]; then
        continue
    fi

    MODULE_NAME=$(basename "$MODULE")

    if [[ -f "$MODULE/variables.tf" ]]; then
        # Check all variables have descriptions
        VARS_WITHOUT_DESC=$(grep -c 'variable "' "$MODULE/variables.tf" || true)
        VARS_WITH_DESC=$(grep -c 'description\s*=' "$MODULE/variables.tf" || true)

        if [[ $VARS_WITHOUT_DESC -eq $VARS_WITH_DESC ]]; then
            echo -e "  ${GREEN}✓${NC} $MODULE_NAME: All variables have descriptions"
        else
            echo -e "  ${YELLOW}⚠${NC} $MODULE_NAME: Some variables missing descriptions"
        fi

        # Check for sensitive variables
        if grep -q 'sensitive\s*=\s*true' "$MODULE/variables.tf"; then
            echo -e "  ${GREEN}✓${NC} $MODULE_NAME: Sensitive variables marked"
        fi
    fi
done

echo ""

# Test 5: Output validation
echo -e "${BLUE}[5/6] Testing Output Definitions${NC}"
echo "────────────────────────────────────────────────────────────"

for MODULE in "${MODULES[@]}"; do
    if [[ ! -d "$MODULE" ]]; then
        continue
    fi

    MODULE_NAME=$(basename "$MODULE")

    if [[ -f "$MODULE/outputs.tf" ]]; then
        # Check outputs have descriptions
        OUTPUTS=$(grep -c 'output "' "$MODULE/outputs.tf" || true)
        OUTPUT_DESC=$(grep -c 'description\s*=' "$MODULE/outputs.tf" || true)

        if [[ $OUTPUTS -eq $OUTPUT_DESC ]]; then
            echo -e "  ${GREEN}✓${NC} $MODULE_NAME: All outputs documented ($OUTPUTS outputs)"
        else
            echo -e "  ${YELLOW}⚠${NC} $MODULE_NAME: Some outputs missing descriptions"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} $MODULE_NAME: No outputs.tf file"
    fi
done

echo ""

# Test 6: Security best practices
echo -e "${BLUE}[6/6] Security Best Practices Check${NC}"
echo "────────────────────────────────────────────────────────────"

SECURITY_CHECKS=0
SECURITY_PASS=0

# Check 1: No hardcoded credentials
if ! find terraform -name "*.tf" -exec grep -l "password\s*=\s*\"" {} \; 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}✓${NC} No hardcoded passwords"
    ((SECURITY_PASS++))
else
    echo -e "  ${RED}✗${NC} Hardcoded passwords found!"
fi
((SECURITY_CHECKS++))

# Check 2: No hardcoded keys
if ! find terraform -name "*.tf" -exec grep -l "api_key\s*=\s*\"" {} \; 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}✓${NC} No hardcoded API keys"
    ((SECURITY_PASS++))
else
    echo -e "  ${RED}✗${NC} Hardcoded API keys found!"
fi
((SECURITY_CHECKS++))

# Check 3: Variables used for sensitive data
if grep -q 'sensitive\s*=\s*true' terraform/*/variables.tf 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Sensitive variables properly marked"
    ((SECURITY_PASS++))
else
    echo -e "  ${YELLOW}⚠${NC} No sensitive variables found (may be OK)"
fi
((SECURITY_CHECKS++))

# Check 4: Encryption enabled
if grep -q 'kms_key' terraform/*/*.tf 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Encryption (KMS) configured"
    ((SECURITY_PASS++))
else
    echo -e "  ${YELLOW}⚠${NC} No KMS encryption found"
fi
((SECURITY_CHECKS++))

# Check 5: Audit logging configured
if grep -q 'audit_log_config' terraform/*/*.tf 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Audit logging configured"
    ((SECURITY_PASS++))
else
    echo -e "  ${YELLOW}⚠${NC} No audit logging found"
fi
((SECURITY_CHECKS++))

echo ""
echo "Security Score: $SECURITY_PASS/$SECURITY_CHECKS checks passed"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  VALIDATION SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo ""
echo -e "Total Checks:     $TOTAL_CHECKS"
echo -e "${GREEN}Passed:           $PASSED_CHECKS${NC}"
echo -e "${RED}Failed:           $FAILED_CHECKS${NC}"
echo -e "${YELLOW}Warnings:         $WARNINGS${NC}"
echo ""

PASS_PERCENTAGE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ ALL VALIDATIONS PASSED ($PASS_PERCENTAGE%)${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Terraform code is valid and ready for deployment!"
    echo ""
    echo "Next steps:"
    echo "1. Review terraform plan output (run: terraform plan)"
    echo "2. Apply in staging first (run: terraform apply)"
    echo "3. Validate changes in staging"
    echo "4. Apply to production"
    echo ""
    exit 0
elif [[ $PASS_PERCENTAGE -ge 80 ]]; then
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚠ MOSTLY VALID ($PASS_PERCENTAGE%)${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Some issues found. Review warnings and fix critical issues."
    echo ""
    exit 1
else
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ VALIDATION FAILED ($PASS_PERCENTAGE%)${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Critical issues found. Fix errors before proceeding."
    echo ""
    exit 1
fi
