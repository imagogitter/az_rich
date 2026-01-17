#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Complete Frontend Setup Script for AI Inference Platform
# =============================================================================
# This script performs a complete frontend setup from scratch, including:
# - Prerequisites check
# - Infrastructure deployment
# - Frontend container build and deployment
# - Admin account creation guidance
# - Security setup
# - Connection testing
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# =============================================================================
# PREREQUISITES CHECK
# =============================================================================

check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing=0
    
    # Check Azure CLI
    if ! command -v az >/dev/null 2>&1; then
        error "Azure CLI not found. Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
        missing=1
    else
        success "✓ Azure CLI found ($(az --version | head -n1))"
    fi
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker not found. Install from: https://docs.docker.com/get-docker/"
        missing=1
    else
        success "✓ Docker found ($(docker --version))"
    fi
    
    # Check Terraform
    if ! command -v terraform >/dev/null 2>&1; then
        error "Terraform not found. Install from: https://www.terraform.io/downloads"
        missing=1
    else
        success "✓ Terraform found ($(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4))"
    fi
    
    # Check Azure login
    log "Checking Azure login status..."
    if ! az account show >/dev/null 2>&1; then
        warn "Not logged in to Azure. Running 'az login'..."
        az login || error "Failed to login to Azure"
    fi
    
    local account_name=$(az account show --query name -o tsv)
    success "✓ Logged in to Azure account: $account_name"
    
    # Check Docker daemon
    if ! docker ps >/dev/null 2>&1; then
        error "Docker daemon not running. Start Docker Desktop or Docker service."
    fi
    success "✓ Docker daemon is running"
    
    if [ $missing -eq 1 ]; then
        error "Please install missing prerequisites and try again."
    fi
    
    success "All prerequisites satisfied!"
    echo ""
}

# =============================================================================
# INFRASTRUCTURE DEPLOYMENT
# =============================================================================

deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."
    echo ""
    
    cd terraform || error "terraform directory not found"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init || error "Terraform init failed"
    
    # Validate configuration
    log "Validating Terraform configuration..."
    terraform validate || error "Terraform validation failed"
    
    # Show plan
    log "Generating Terraform plan..."
    terraform plan -out=tfplan || error "Terraform plan failed"
    
    # Apply
    log "Applying Terraform configuration..."
    echo ""
    warn "This will create Azure resources and may take 5-10 minutes."
    read -p "Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        warn "Deployment cancelled by user"
        exit 0
    fi
    
    terraform apply tfplan || error "Terraform apply failed"
    
    cd ..
    success "Infrastructure deployed successfully!"
    echo ""
}

# =============================================================================
# FRONTEND DEPLOYMENT
# =============================================================================

deploy_frontend() {
    log "Building and deploying frontend container..."
    echo ""
    
    # Get resource names from Terraform
    RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name 2>/dev/null || echo "")
    REGISTRY_NAME=$(cd terraform && terraform output -raw container_registry_name 2>/dev/null || echo "")
    REGISTRY_LOGIN_SERVER=$(cd terraform && terraform output -raw container_registry_login_server 2>/dev/null || echo "")
    FRONTEND_APP_NAME=$(cd terraform && terraform output -raw frontend_app_name 2>/dev/null || echo "")
    
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$REGISTRY_NAME" ]; then
        error "Could not get Terraform outputs. Infrastructure may not be deployed."
    fi
    
    log "Resource Group: $RESOURCE_GROUP"
    log "Registry: $REGISTRY_NAME"
    log "Frontend App: $FRONTEND_APP_NAME"
    echo ""
    
    # Login to ACR
    log "Logging in to Azure Container Registry..."
    az acr login --name "$REGISTRY_NAME" || error "Failed to login to ACR"
    
    # Build Docker image
    log "Building Docker image (this may take 2-3 minutes)..."
    cd frontend || error "frontend directory not found"
    docker build -t open-webui:latest . || error "Failed to build Docker image"
    cd ..
    
    # Tag for ACR
    log "Tagging image for registry..."
    docker tag open-webui:latest "${REGISTRY_LOGIN_SERVER}/open-webui:latest" || error "Failed to tag image"
    
    # Push to ACR
    log "Pushing image to Azure Container Registry..."
    docker push "${REGISTRY_LOGIN_SERVER}/open-webui:latest" || error "Failed to push image"
    
    # Wait for deployment
    log "Waiting for container app to update (30 seconds)..."
    sleep 30
    
    success "Frontend deployed successfully!"
    echo ""
}

# =============================================================================
# GET CONNECTION DETAILS
# =============================================================================

show_connection_details() {
    log "Retrieving connection details..."
    echo ""
    
    cd terraform || error "terraform directory not found"
    
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
    KEY_VAULT_NAME=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    
    cd ..
    
    # Get the function app hostname (backend API)
    BACKEND_URL=$(az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv 2>/dev/null || echo "")
    
    if [ -n "$BACKEND_URL" ]; then
        BACKEND_API="https://${BACKEND_URL}/api/v1"
    else
        BACKEND_API="<Function App not deployed yet>"
    fi
    
    # Get the API key
    API_KEY=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "frontend-openai-api-key" --query value -o tsv 2>/dev/null || echo "<Not available>")
    
    echo "========================================================================="
    echo "                    CONNECTION DETAILS                                  "
    echo "========================================================================="
    echo ""
    echo "Frontend URL:      $FRONTEND_URL"
    echo "Backend API URL:   $BACKEND_API"
    echo "API Key:           $API_KEY"
    echo ""
    echo "Available Models:"
    echo "  - mixtral-8x7b   (32K context, fast)"
    echo "  - llama-3-70b    (8K context, high quality)"
    echo "  - phi-3-mini     (4K context, lightweight)"
    echo ""
    echo "Resources:"
    echo "  Resource Group:  $RESOURCE_GROUP"
    echo "  Key Vault:       $KEY_VAULT_NAME"
    echo "  Function App:    $FUNCTION_APP_NAME"
    echo ""
    echo "========================================================================="
    echo ""
    
    # Save to file
    cat > connection-details.txt <<EOF
AI Inference Platform - Connection Details
Generated: $(date)

Frontend URL:      $FRONTEND_URL
Backend API URL:   $BACKEND_API
API Key:           $API_KEY

Available Models:
  - mixtral-8x7b   (32K context, fast)
  - llama-3-70b    (8K context, high quality)
  - phi-3-mini     (4K context, lightweight)

Resources:
  Resource Group:  $RESOURCE_GROUP
  Key Vault:       $KEY_VAULT_NAME
  Function App:    $FUNCTION_APP_NAME

API Endpoints:
  - POST   $BACKEND_API/chat/completions
  - GET    $BACKEND_API/models
  - GET    $BACKEND_API/health
  - GET    $BACKEND_API/health/live
  - GET    $BACKEND_API/health/ready

cURL Example:
curl -X POST $BACKEND_API/chat/completions \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer $API_KEY" \\
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7,
    "max_tokens": 256
  }'

OpenAI Python SDK Example:
from openai import OpenAI

client = OpenAI(
    api_key="$API_KEY",
    base_url="$BACKEND_API"
)

response = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[{"role": "user", "content": "Hello!"}],
    temperature=0.7,
    max_tokens=256
)

print(response.choices[0].message.content)
EOF
    
    success "Connection details saved to connection-details.txt"
    echo ""
}

# =============================================================================
# ADMIN ACCOUNT SETUP
# =============================================================================

setup_admin_account() {
    log "Admin Account Setup"
    echo ""
    
    cd terraform || error "terraform directory not found"
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    cd ..
    
    warn "IMPORTANT: You need to create an admin account through the web interface!"
    echo ""
    echo "Steps:"
    echo "  1. Open: $FRONTEND_URL"
    echo "  2. Click 'Sign Up'"
    echo "  3. Enter your admin credentials:"
    echo "     - Username (e.g., 'admin')"
    echo "     - Full Name (e.g., 'Admin User')"
    echo "     - Password (use a strong password!)"
    echo "  4. Click 'Create Account'"
    echo ""
    echo "The first user to sign up becomes the admin!"
    echo ""
    
    read -p "Press Enter when you've created your admin account..." -r
    echo ""
}

# =============================================================================
# SECURE FRONTEND
# =============================================================================

secure_frontend() {
    log "Securing frontend by disabling public signup..."
    echo ""
    
    cd terraform || error "terraform directory not found"
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    FRONTEND_APP_NAME=$(terraform output -raw frontend_app_name 2>/dev/null || echo "")
    cd ..
    
    log "Disabling public signup..."
    az containerapp update \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --set-env-vars "ENABLE_SIGNUP=false" \
        || error "Failed to disable signup"
    
    log "Waiting for update to apply (10 seconds)..."
    sleep 10
    
    log "Restarting container app..."
    az containerapp revision restart \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        || warn "Failed to restart (will restart automatically)"
    
    success "Frontend secured! Public signup is now disabled."
    echo ""
}

# =============================================================================
# TEST CONNECTION
# =============================================================================

test_connection() {
    log "Testing frontend and backend connectivity..."
    echo ""
    
    cd terraform || error "terraform directory not found"
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    cd ..
    
    # Test frontend
    log "Testing frontend URL: $FRONTEND_URL"
    if curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" | grep -q "200\|301\|302"; then
        success "✓ Frontend is accessible"
    else
        warn "⚠ Frontend may not be ready yet. Wait 1-2 minutes and try accessing it manually."
    fi
    
    # Test backend (if deployed)
    if [ -n "$FUNCTION_APP_NAME" ]; then
        BACKEND_URL=$(az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv 2>/dev/null || echo "")
        if [ -n "$BACKEND_URL" ]; then
            log "Testing backend URL: https://${BACKEND_URL}/api/v1/health"
            if curl -s "https://${BACKEND_URL}/api/v1/health" | grep -q "ok\|healthy"; then
                success "✓ Backend is accessible"
            else
                warn "⚠ Backend may not be deployed yet. Deploy with ./deploy.sh"
            fi
        fi
    fi
    
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo "========================================================================="
    echo "     AI Inference Platform - Complete Frontend Setup                    "
    echo "========================================================================="
    echo ""
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Deploy infrastructure
    log "Step 1/6: Infrastructure Deployment"
    deploy_infrastructure
    
    # Step 3: Deploy frontend
    log "Step 2/6: Frontend Deployment"
    deploy_frontend
    
    # Step 4: Show connection details
    log "Step 3/6: Connection Details"
    show_connection_details
    
    # Step 5: Admin setup
    log "Step 4/6: Admin Account Setup"
    setup_admin_account
    
    # Step 6: Secure frontend
    log "Step 5/6: Security Setup"
    secure_frontend
    
    # Step 7: Test
    log "Step 6/6: Connectivity Testing"
    
    # Test
    test_connection
    
    # Final summary
    echo ""
    echo "========================================================================="
    echo "                    SETUP COMPLETE!                                     "
    echo "========================================================================="
    echo ""
    success "✅ Infrastructure deployed"
    success "✅ Frontend deployed and secured"
    success "✅ Connection details saved to connection-details.txt"
    echo ""
    cd terraform
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    cd ..
    echo "🚀 Access your platform at: $FRONTEND_URL"
    echo ""
    echo "Next steps:"
    echo "  - Deploy backend with: ./deploy.sh"
    echo "  - Review connection details: cat connection-details.txt"
    echo "  - Check frontend logs: az containerapp logs show --name <app-name> --resource-group <rg>"
    echo ""
    echo "For detailed usage information, see: docs/frontend-usage.md"
    echo "========================================================================="
    echo ""
}

main "$@"
