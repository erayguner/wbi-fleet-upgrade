#!/bin/bash
# Terraform Plan Script - See what WOULD be created (no actual deployment)
# Generates plan files for review before applying

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  Terraform Plan Generation - DRY RUN"
echo "  NO RESOURCES WILL BE CREATED"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check if required variables are set
REQUIRED_VARS=(
	"PROJECT_ID"
	"REGION"
)

MISSING_VARS=()
for VAR in "${REQUIRED_VARS[@]}"; do
	if [[ -z "${!VAR:-}" ]]; then
		MISSING_VARS+=("$VAR")
	fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
	echo -e "${YELLOW}⚠ Missing required environment variables:${NC}"
	for VAR in "${MISSING_VARS[@]}"; do
		echo "  - $VAR"
	done
	echo ""
	echo "Example:"
	echo "  export PROJECT_ID=your-project-id"
	echo "  export REGION=europe-west2"
	echo ""
	echo "Using placeholder values for validation..."
	export PROJECT_ID="${PROJECT_ID:-placeholder-project}"
	export REGION="${REGION:-europe-west2}"
	export PROJECT_NUMBER="${PROJECT_NUMBER:-123456789}"
fi

echo "Configuration:"
echo "  PROJECT_ID:     $PROJECT_ID"
echo "  REGION:         $REGION"
echo "  PROJECT_NUMBER: ${PROJECT_NUMBER:-unknown}"
echo ""

# Terraform modules
MODULES=(
	"terraform/cloudbuild-iam"
	"terraform/artifact-registry"
	"terraform/artifact-registry-iam"
)

# Create plans directory
PLANS_DIR="terraform-plans"
mkdir -p "$PLANS_DIR"

echo "Plans will be saved to: $PLANS_DIR/"
echo ""

# Generate plan for each module
for MODULE in "${MODULES[@]}"; do
	if [[ ! -d "$MODULE" ]]; then
		echo -e "${YELLOW}⚠ Module not found: $MODULE (skipping)${NC}"
		continue
	fi

	MODULE_NAME=$(basename "$MODULE")
	PLAN_FILE="$PLANS_DIR/${MODULE_NAME}.tfplan"
	PLAN_JSON="$PLANS_DIR/${MODULE_NAME}.json"
	PLAN_TEXT="$PLANS_DIR/${MODULE_NAME}.txt"

	echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
	echo -e "${BLUE}Planning: $MODULE${NC}"
	echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

	cd "$MODULE"

	# Create tfvars file with placeholder values
	cat >terraform.tfvars <<EOF
project_id     = "$PROJECT_ID"
region         = "$REGION"
project_number = "${PROJECT_NUMBER:-123456789}"
EOF

	# Initialize
	echo "  → Initializing..."
	if ! terraform init -backend=false >/tmp/tf-init.log 2>&1; then
		echo -e "${YELLOW}⚠ Init failed, see: /tmp/tf-init.log${NC}"
		cd - >/dev/null
		continue
	fi

	# Generate plan
	echo "  → Generating plan..."
	if terraform plan \
		-input=false \
		-out="../$PLAN_FILE" \
		-var-file=terraform.tfvars \
		>"../$PLAN_TEXT" 2>&1; then

		echo -e "  ${GREEN}✓${NC} Plan generated successfully"

		# Convert to JSON for analysis
		terraform show -json "../$PLAN_FILE" >"../$PLAN_JSON" 2>/dev/null || true

		# Count changes
		TO_ADD=$(grep -c "will be created" "../$PLAN_TEXT" || echo "0")
		TO_CHANGE=$(grep -c "will be updated" "../$PLAN_TEXT" || echo "0")
		TO_DESTROY=$(grep -c "will be destroyed" "../$PLAN_TEXT" || echo "0")

		echo ""
		echo "  Changes Summary:"
		echo "    • Resources to ADD:     $TO_ADD"
		echo "    • Resources to CHANGE:  $TO_CHANGE"
		echo "    • Resources to DESTROY: $TO_DESTROY"
		echo ""

		# Show resource types
		echo "  Resource Types:"
		grep "^  # " "../$PLAN_TEXT" | sed 's/^  # /    • /' | head -10

		if [[ $(grep -c "^  # " "../$PLAN_TEXT") -gt 10 ]]; then
			echo "    ... and more"
		fi

	else
		echo -e "  ${YELLOW}⚠${NC} Plan generation had issues"
		echo "  See: $PLAN_TEXT"
	fi

	# Cleanup
	rm -f terraform.tfvars

	cd - >/dev/null
	echo ""
done

# Summary
echo "════════════════════════════════════════════════════════════"
echo "  PLAN GENERATION COMPLETE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Generated files:"
for MODULE in "${MODULES[@]}"; do
	MODULE_NAME=$(basename "$MODULE")
	if [[ -f "$PLANS_DIR/${MODULE_NAME}.tfplan" ]]; then
		echo -e "  ${GREEN}✓${NC} $PLANS_DIR/${MODULE_NAME}.tfplan"
		echo "    └─ Human-readable: $PLANS_DIR/${MODULE_NAME}.txt"
		echo "    └─ JSON format:    $PLANS_DIR/${MODULE_NAME}.json"
	fi
done

echo ""
echo "Review plans:"
echo "  1. Read text files:  cat $PLANS_DIR/*.txt"
echo "  2. Analyze JSON:     jq . $PLANS_DIR/*.json"
echo ""
echo "To apply (ONLY after review):"
echo "  cd terraform/MODULE_NAME"
echo "  terraform apply ../$PLANS_DIR/MODULE_NAME.tfplan"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT: Review all plans before applying!${NC}"
