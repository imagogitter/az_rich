#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# TRIGGER FULL AZURE DEPLOYMENT
# =============================================================================
# This script helps trigger the Full Azure Deployment GitHub Actions workflow
# which deploys all infrastructure and generates comprehensive deployment details.
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Repository push access
#
# Usage:
#   ./scripts/trigger-deployment.sh [environment]
#
# Example:
#   ./scripts/trigger-deployment.sh prod
#   ./scripts/trigger-deployment.sh staging
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header() { echo -e "${BLUE}===========================================================${NC}"; echo -e "${BLUE}$*${NC}"; echo -e "${BLUE}===========================================================${NC}"; }

# Check prerequisites
check_prereqs() {
  if ! command -v gh >/dev/null 2>&1; then
    error "GitHub CLI (gh) not found."
    echo ""
    echo "Install GitHub CLI:"
    echo "  https://cli.github.com/manual/installation"
    echo ""
    echo "Or trigger manually:"
    echo "  1. Go to: https://github.com/imagogitter/az_rich/actions/workflows/full-deployment.yml"
    echo "  2. Click 'Run workflow'"
    echo "  3. Select branch and environment"
    echo "  4. Click 'Run workflow' button"
    exit 1
  fi
  
  # Check if authenticated
  if ! gh auth status >/dev/null 2>&1; then
    error "GitHub CLI not authenticated."
    echo ""
    echo "Authenticate with:"
    echo "  gh auth login"
    echo ""
    echo "Or trigger manually via web interface (see above)"
    exit 1
  fi
}

# Parse arguments
ENVIRONMENT="${1:-prod}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment: $ENVIRONMENT"
  echo "Valid environments: dev, staging, prod"
  exit 1
fi

# Main execution
main() {
  header "TRIGGER FULL AZURE DEPLOYMENT"
  echo ""
  
  check_prereqs
  
  log "Repository: imagogitter/az_rich"
  log "Workflow: full-deployment.yml"
  log "Environment: $ENVIRONMENT"
  log "Branch: $(git branch --show-current)"
  echo ""
  
  read -p "Do you want to trigger the deployment? (y/N): " -n 1 -r
  echo ""
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Deployment cancelled"
    exit 0
  fi
  
  log "Triggering workflow..."
  
  if gh workflow run full-deployment.yml \
    --ref "$(git branch --show-current)" \
    -f environment="$ENVIRONMENT" \
    -f deploy_infrastructure=true \
    -f deploy_functions=true \
    -f deploy_frontend=true; then
    
    echo ""
    log "✅ Workflow triggered successfully!"
    echo ""
    log "Monitor the workflow run:"
    echo "  gh run list --workflow=full-deployment.yml"
    echo "  gh run watch"
    echo ""
    log "Or visit:"
    echo "  https://github.com/imagogitter/az_rich/actions/workflows/full-deployment.yml"
    echo ""
    log "The workflow will:"
    echo "  1. ✅ Validate Terraform configuration"
    echo "  2. ✅ Lint and test code"
    echo "  3. ✅ Deploy Azure infrastructure"
    echo "  4. ✅ Deploy Azure Functions"
    echo "  5. ✅ Deploy Frontend container"
    echo "  6. ✅ Generate comprehensive deployment details"
    echo "  7. ✅ Verify all resources"
    echo ""
    log "When complete, download artifacts for:"
    echo "  • Complete deployment details"
    echo "  • API endpoints and keys"
    echo "  • Usage examples"
    echo "  • Troubleshooting guides"
    
  else
    error "Failed to trigger workflow"
    echo ""
    echo "Alternative methods:"
    echo ""
    echo "1. Via GitHub web interface:"
    echo "   https://github.com/imagogitter/az_rich/actions/workflows/full-deployment.yml"
    echo ""
    echo "2. Via gh CLI (if auth issues):"
    echo "   gh auth login"
    echo "   gh workflow run full-deployment.yml"
    echo ""
    echo "3. Via git push (triggers on main branch):"
    echo "   git push origin main"
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
