#!/bin/bash
# Container Image Signature Verification Script
# Verifies Cosign signatures and SBOM attestations

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if image URI provided
if [[ $# -lt 1 ]]; then
	echo "Usage: $0 <image-uri>"
	echo "Example: $0 europe-west2-docker.pkg.dev/project-id/repo/image:tag"
	exit 1
fi

IMAGE_URI=$1
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-europe-west2}"
KMS_KEYRING="wbi-fleet-upgrader-keyring"
KMS_KEY="cosign-signing-key"
KMS_KEY_PATH="gcpkms://projects/${PROJECT_ID}/locations/${REGION}/keyRings/${KMS_KEYRING}/cryptoKeys/${KMS_KEY}"

echo "🔍 Verifying Container Image Security"
echo "======================================"
echo ""
echo "Image: $IMAGE_URI"
echo "KMS Key: $KMS_KEY_PATH"
echo ""

# Check prerequisites
if ! command -v cosign >/dev/null 2>&1; then
	echo -e "${RED}❌ cosign not found${NC}"
	echo "Install: https://docs.sigstore.dev/cosign/installation/"
	exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
	echo -e "${RED}❌ gcloud not found${NC}"
	exit 1
fi

# Authenticate to Artifact Registry
echo "🔐 Authenticating to Artifact Registry..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Step 1: Verify signature
echo ""
echo "📝 Step 1: Verifying image signature..."
if cosign verify --key "${KMS_KEY_PATH}" "${IMAGE_URI}" 2>/dev/null; then
	echo -e "${GREEN}✅ Image signature verified${NC}"
else
	echo -e "${RED}❌ Image signature verification FAILED${NC}"
	echo ""
	echo "Possible causes:"
	echo "1. Image not signed"
	echo "2. Signature tampered with"
	echo "3. Wrong KMS key"
	echo ""
	exit 1
fi

# Step 2: Verify SBOM attestation
echo ""
echo "📋 Step 2: Verifying SBOM attestation..."
if cosign verify-attestation --key "${KMS_KEY_PATH}" "${IMAGE_URI}" 2>/dev/null; then
	echo -e "${GREEN}✅ SBOM attestation verified${NC}"
else
	echo -e "${YELLOW}⚠️  SBOM attestation not found or invalid${NC}"
	echo "This is not critical but recommended for supply chain security."
fi

# Step 3: Display SBOM
echo ""
echo "📦 Step 3: Extracting SBOM..."
if cosign download sbom "${IMAGE_URI}" >/tmp/sbom.json 2>/dev/null; then
	echo -e "${GREEN}✅ SBOM extracted${NC}"

	# Count dependencies
	DEPS=$(jq -r '.components | length' /tmp/sbom.json 2>/dev/null || echo "unknown")
	echo "   Dependencies: $DEPS"

	# Show top-level packages
	echo ""
	echo "   Top-level packages:"
	jq -r '.components[:5] | .[] | "   - \(.name)@\(.version)"' /tmp/sbom.json 2>/dev/null || echo "   (unable to parse)"

	echo ""
	echo "   Full SBOM saved to: /tmp/sbom.json"
else
	echo -e "${YELLOW}⚠️  Could not extract SBOM${NC}"
fi

# Step 4: Check image provenance
echo ""
echo "🏭 Step 4: Checking build provenance..."
if gcloud artifacts docker images describe "${IMAGE_URI}" --show-provenance --format=json >/tmp/provenance.json 2>/dev/null; then
	echo -e "${GREEN}✅ Provenance found${NC}"

	BUILD_ID=$(jq -r '.provenance.buildId' /tmp/provenance.json 2>/dev/null || echo "unknown")
	BUILD_TIME=$(jq -r '.provenance.createTime' /tmp/provenance.json 2>/dev/null || echo "unknown")

	echo "   Build ID: $BUILD_ID"
	echo "   Build Time: $BUILD_TIME"
else
	echo -e "${YELLOW}⚠️  Provenance not found${NC}"
fi

# Step 5: Security scan results
echo ""
echo "🛡️  Step 5: Checking vulnerability scan results..."
if gcloud artifacts docker images describe "${IMAGE_URI}" --format=json | jq -e '.vulnerability' >/dev/null 2>&1; then
	CRITICAL=$(gcloud artifacts docker images describe "${IMAGE_URI}" --format="value(vulnerability.summary.criticalCount)" 2>/dev/null || echo "0")
	HIGH=$(gcloud artifacts docker images describe "${IMAGE_URI}" --format="value(vulnerability.summary.highCount)" 2>/dev/null || echo "0")
	MEDIUM=$(gcloud artifacts docker images describe "${IMAGE_URI}" --format="value(vulnerability.summary.mediumCount)" 2>/dev/null || echo "0")

	echo "   Vulnerabilities:"
	if [[ "$CRITICAL" != "0" ]]; then
		echo -e "   ${RED}Critical: $CRITICAL${NC}"
	else
		echo -e "   ${GREEN}Critical: $CRITICAL${NC}"
	fi

	if [[ "$HIGH" != "0" ]]; then
		echo -e "   ${YELLOW}High: $HIGH${NC}"
	else
		echo -e "   ${GREEN}High: $HIGH${NC}"
	fi

	echo "   Medium: $MEDIUM"

	if [[ "$CRITICAL" != "0" ]]; then
		echo ""
		echo -e "${RED}⚠️  WARNING: Critical vulnerabilities found!${NC}"
		echo "   Review and remediate before deploying to production."
	fi
else
	echo -e "${YELLOW}⚠️  No scan results available${NC}"
	echo "   Scan may still be in progress."
fi

# Step 6: Binary Authorization
echo ""
echo "🔐 Step 6: Checking Binary Authorization..."
if gcloud container binauthz policy export --format=json 2>/dev/null | jq -e '.defaultAdmissionRule.evaluationMode == "REQUIRE_ATTESTATION"' >/dev/null 2>&1; then
	echo -e "${GREEN}✅ Binary Authorization enabled${NC}"

	# Check if attestation exists for this image
	ATTESTOR="wbi-build-attestor"
	if gcloud beta container binauthz attestations list \
		--artifact-url="${IMAGE_URI}" \
		--attestor="${ATTESTOR}" \
		--attestor-project="${PROJECT_ID}" \
		--format=json 2>/dev/null | jq -e 'length > 0' >/dev/null; then
		echo -e "   ${GREEN}✅ Attestation found${NC}"
	else
		echo -e "   ${YELLOW}⚠️  No attestation found${NC}"
		echo "   Image may be blocked by Binary Authorization policy."
	fi
else
	echo -e "${YELLOW}⚠️  Binary Authorization not enforcing attestations${NC}"
	echo "   Configure: gcloud container binauthz policy import"
fi

# Summary
echo ""
echo "======================================"
echo "📊 VERIFICATION SUMMARY"
echo "======================================"
echo ""

CHECKS=0
PASSED=0

# Count checks
((CHECKS++)) && [[ -n "$(cosign verify --key "${KMS_KEY_PATH}" "${IMAGE_URI}" 2>/dev/null || echo '')" ]] && ((PASSED++))
((CHECKS++)) && [[ -f "/tmp/sbom.json" ]] && ((PASSED++))
((CHECKS++)) && [[ -f "/tmp/provenance.json" ]] && ((PASSED++))
((CHECKS++)) && [[ "${CRITICAL:-0}" == "0" ]] && ((PASSED++))

echo -e "Checks Passed: ${GREEN}$PASSED${NC} / $CHECKS"
echo ""

if [[ $PASSED -eq $CHECKS ]]; then
	echo -e "${GREEN}✅ Image verification: PASS${NC}"
	echo -e "${GREEN}✅ Deployment recommendation: APPROVED${NC}"
	echo ""
	echo "This image meets security requirements and can be deployed."
	exit 0
elif [[ $PASSED -ge 3 ]]; then
	echo -e "${YELLOW}⚠️  Image verification: PARTIAL${NC}"
	echo -e "${YELLOW}⚠️  Deployment recommendation: REVIEW REQUIRED${NC}"
	echo ""
	echo "Review warnings above before deploying."
	exit 1
else
	echo -e "${RED}❌ Image verification: FAIL${NC}"
	echo -e "${RED}❌ Deployment recommendation: BLOCKED${NC}"
	echo ""
	echo "DO NOT deploy this image. Fix security issues first."
	exit 1
fi
