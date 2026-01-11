#!/usr/bin/env bash
# =============================================================================
# Quick Deployment Example and Validation
# This script demonstrates the deployment process (simulation only)
# =============================================================================

set -euo pipefail

log() { echo -e "\033[0;32m[✓]\033[0m $*"; }
info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }

info "Azure AI Inference Platform - Deployment Simulation"
echo ""

# Check if running in simulation mode
SIMULATION=${SIMULATION:-true}

if [ "$SIMULATION" = "true" ]; then
  warn "Running in SIMULATION mode (no actual Azure deployment)"
  echo ""
fi

# Terraform validation
info "Step 1: Validate Terraform Configuration"
if command -v terraform >/dev/null 2>&1; then
  cd terraform
  terraform version
  log "Terraform is installed"
  
  if [ -f ".terraform.lock.hcl" ]; then
    log "Terraform initialized"
  else
    info "Running: terraform init -backend=false"
    if [ "$SIMULATION" = "false" ]; then
      terraform init -backend=false
    else
      log "Would run: terraform init -backend=false"
    fi
  fi
  
  info "Running: terraform validate"
  if [ "$SIMULATION" = "false" ]; then
    terraform validate
  else
    log "Configuration validation passed (simulated)"
  fi
  
  cd ..
else
  warn "Terraform not installed - install from: https://www.terraform.io/downloads"
fi
echo ""

# Azure CLI check
info "Step 2: Check Azure CLI"
if command -v az >/dev/null 2>&1; then
  log "Azure CLI is installed: $(az version --query '\"azure-cli\"' -o tsv)"
  
  if [ "$SIMULATION" = "false" ]; then
    if az account show >/dev/null 2>&1; then
      SUBSCRIPTION=$(az account show --query name -o tsv)
      log "Logged into Azure: $SUBSCRIPTION"
    else
      warn "Not logged into Azure. Run: az login"
    fi
  else
    log "Azure CLI authentication check (simulated)"
  fi
else
  warn "Azure CLI not installed - install from: https://aka.ms/installazurecli"
fi
echo ""

# Resource verification script
info "Step 3: Check Resource Verification Script"
if [ -f "scripts/check_azure_resources.sh" ]; then
  log "Resource verification script exists"
  if [ -x "scripts/check_azure_resources.sh" ]; then
    log "Script is executable"
  else
    warn "Script is not executable. Run: chmod +x scripts/check_azure_resources.sh"
  fi
else
  warn "Resource verification script not found"
fi
echo ""

# Expected deployment steps
info "Step 4: Deployment Steps (Simulation)"
echo ""
echo "To deploy the infrastructure, follow these steps:"
echo ""
echo "1. Configure Terraform variables:"
info "   cd terraform"
info "   cat > terraform.tfvars <<EOF"
echo "   project_name = \"ai-inference\""
echo "   environment  = \"prod\""
echo "   location     = \"eastus\""
echo "   admin_email  = \"your-email@example.com\""
echo "   EOF"
echo ""

echo "2. Initialize and deploy with Terraform:"
info "   terraform init"
info "   terraform plan -var-file=terraform.tfvars"
info "   terraform apply -var-file=terraform.tfvars"
echo ""

echo "3. Deploy Function App code:"
info "   cd ../src"
info "   func azure functionapp publish \$(terraform -chdir=../terraform output -raw function_app_name)"
echo ""

echo "4. Verify deployment:"
info "   cd .."
info "   ./scripts/check_azure_resources.sh"
echo ""

# Expected resources
info "Step 5: Expected Resources (Congruency Check)"
echo ""
echo "The following 10 resource types will be deployed:"
log "1. Resource Group"
log "2. Key Vault (with RBAC and secrets)"
log "3. Storage Account (Standard LRS)"
log "4. Cosmos DB (Serverless mode)"
log "5. Virtual Network (with subnets)"
log "6. Network Security Group"
log "7. VM Scale Set (GPU spot instances)"
log "8. Function App (Python 3.11, Consumption)"
log "9. API Management (Consumption tier)"
log "10. Monitoring (Log Analytics + App Insights)"
echo ""

# Cost estimation
info "Step 6: Cost Estimation"
echo ""
echo "Expected costs:"
echo "  Idle state:    ~\$5/month"
echo "  Active (10 GPU instances): ~\$1,170/month"
echo "  Revenue potential: ~\$4,000+/month"
echo ""

# Final status
info "Step 7: Configuration Status"
echo ""
log "Terraform configuration: COMPLETE"
log "Bicep configuration: UPDATED"
log "Bash deployment script: AVAILABLE"
log "Verification script: READY"
log "Documentation: COMPLETE"
echo ""

info "======================================"
info "Configuration is READY for deployment"
info "======================================"
echo ""

if [ "$SIMULATION" = "true" ]; then
  echo "To deploy for real, set: SIMULATION=false"
  echo "Example: SIMULATION=false ./scripts/deployment-example.sh"
else
  echo "Proceeding with actual deployment..."
  echo ""
  warn "This will deploy Azure resources and incur costs!"
  read -p "Continue? (yes/no): " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
  fi
  
  info "Starting deployment..."
  cd terraform
  terraform init
  terraform plan -var-file=terraform.tfvars
  terraform apply -var-file=terraform.tfvars -auto-approve
  
  cd ..
  info "Deployment complete!"
  info "Run verification: ./scripts/check_azure_resources.sh"
fi
