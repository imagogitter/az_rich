#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Frontend Launch & Test Script
# =============================================================================
# This script helps launch and test the frontend after deployment
# - Checks deployment status
# - Opens frontend in browser
# - Tests API connectivity
# - Provides troubleshooting information
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${CYAN}=== $* ===${NC}\n"; }

# =============================================================================
# CHECK DEPLOYMENT STATUS
# =============================================================================

check_status() {
    section "Checking Deployment Status"
    
    # Check Terraform outputs
    if [ ! -d "terraform" ]; then
        error "terraform directory not found. Are you in the project root?"
        exit 1
    fi
    
    cd terraform
    
    # Get resource names
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    FRONTEND_APP_NAME=$(terraform output -raw frontend_app_name 2>/dev/null || echo "")
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    
    cd ..
    
    if [ -z "$RESOURCE_GROUP" ] || [ -z "$FRONTEND_APP_NAME" ]; then
        error "Could not get Terraform outputs. Has infrastructure been deployed?"
        echo ""
        echo "Run: cd terraform && terraform apply"
        exit 1
    fi
    
    log "Resource Group: $RESOURCE_GROUP"
    log "Frontend App: $FRONTEND_APP_NAME"
    log "Frontend URL: $FRONTEND_URL"
    echo ""
    
    # Check container app status
    log "Checking container app status..."
    STATUS=$(az containerapp show \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.provisioningState" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$STATUS" ]; then
        error "Container app not found. Has it been deployed?"
        exit 1
    fi
    
    if [ "$STATUS" = "Succeeded" ]; then
        success "✓ Container app is running"
    else
        warn "Container app status: $STATUS"
    fi
    
    # Check replica count
    REPLICAS=$(az containerapp replica list \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "length(@)" -o tsv 2>/dev/null || echo "0")
    
    log "Active replicas: $REPLICAS"
    
    if [ "$REPLICAS" -eq 0 ]; then
        warn "No active replicas. Container may be scaling from zero."
        log "Waiting 30 seconds for scale-up..."
        sleep 30
    fi
    
    echo ""
}

# =============================================================================
# TEST CONNECTIVITY
# =============================================================================

test_connectivity() {
    section "Testing Connectivity"
    
    cd terraform
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    KEY_VAULT_NAME=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
    cd ..
    
    # Test frontend
    log "Testing frontend URL..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" -L --max-time 30 || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        success "✓ Frontend is accessible (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        success "✓ Frontend is accessible (redirecting)"
    elif [ "$HTTP_CODE" = "000" ]; then
        error "✗ Frontend is not responding (timeout)"
        warn "The frontend may still be starting up. Wait 1-2 minutes and try again."
    else
        warn "⚠ Frontend returned HTTP $HTTP_CODE"
    fi
    echo ""
    
    # Test backend if available
    if [ -n "$FUNCTION_APP_NAME" ]; then
        BACKEND_URL=$(az functionapp show \
            --name "$FUNCTION_APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --query defaultHostName -o tsv 2>/dev/null || echo "")
        
        if [ -n "$BACKEND_URL" ]; then
            log "Testing backend API..."
            HEALTH_URL="https://${BACKEND_URL}/api/v1/health"
            
            # Check HTTP status code first
            HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" --max-time 10 || echo "000")
            
            if [ "$HEALTH_CODE" = "200" ]; then
                # Now check content
                BACKEND_STATUS=$(curl -s "$HEALTH_URL" --max-time 10 || echo "")
                if echo "$BACKEND_STATUS" | grep -q "ok\|healthy\|live"; then
                    success "✓ Backend API is responding"
                else
                    warn "⚠ Backend API responded but with unexpected content"
                fi
            else
                warn "⚠ Backend API is not responding (HTTP $HEALTH_CODE) or not deployed"
                log "Deploy backend with: ./deploy.sh"
            fi
        else
            warn "Backend function app not found or not deployed"
        fi
    fi
    
    echo ""
}

# =============================================================================
# SHOW CONNECTION INFO
# =============================================================================

show_info() {
    section "Connection Information"
    
    cd terraform
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    KEY_VAULT_NAME=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
    cd ..
    
    # Get backend URL
    BACKEND_URL=$(az functionapp show \
        --name "$FUNCTION_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query defaultHostName -o tsv 2>/dev/null || echo "")
    
    if [ -n "$BACKEND_URL" ]; then
        BACKEND_API="https://${BACKEND_URL}/api/v1"
    else
        BACKEND_API="<not deployed>"
    fi
    
    # Get API key
    API_KEY=$(az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "frontend-openai-api-key" \
        --query value -o tsv 2>/dev/null || echo "<not available>")
    
    echo "Frontend URL:     $FRONTEND_URL"
    echo "Backend API:      $BACKEND_API"
    echo "API Key:          ${API_KEY:0:20}..."
    echo ""
    echo "Available Models:"
    echo "  • mixtral-8x7b   (32K context)"
    echo "  • llama-3-70b    (8K context)"
    echo "  • phi-3-mini     (4K context)"
    echo ""
    echo "Quick Test Command:"
    echo "  curl $BACKEND_API/models"
    echo ""
}

# =============================================================================
# OPEN BROWSER
# =============================================================================

open_browser() {
    section "Opening Frontend"
    
    cd terraform
    FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "")
    cd ..
    
    log "Opening $FRONTEND_URL in browser..."
    
    # Try to open browser based on OS
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$FRONTEND_URL" 2>/dev/null &
    elif command -v open >/dev/null 2>&1; then
        open "$FRONTEND_URL" 2>/dev/null &
    elif command -v start >/dev/null 2>&1; then
        start "$FRONTEND_URL" 2>/dev/null &
    else
        warn "Could not auto-open browser. Please visit manually:"
        echo ""
        echo "  $FRONTEND_URL"
        echo ""
    fi
    
    success "Frontend should open in your browser"
    echo ""
}

# =============================================================================
# VIEW LOGS
# =============================================================================

view_logs() {
    section "Recent Logs"
    
    cd terraform
    FRONTEND_APP_NAME=$(terraform output -raw frontend_app_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    cd ..
    
    log "Fetching last 20 log entries..."
    echo ""
    
    az containerapp logs show \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --tail 20 \
        --follow false 2>/dev/null || warn "Could not fetch logs"
    
    echo ""
    log "To follow logs in real-time:"
    echo "  az containerapp logs show --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP --tail 100 --follow"
    echo ""
}

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

show_troubleshooting() {
    section "Troubleshooting"
    
    echo "Common Issues:"
    echo ""
    echo "1. Frontend not loading:"
    echo "   • Wait 1-2 minutes for DNS propagation"
    echo "   • Check status: az containerapp show --name <app> --resource-group <rg>"
    echo "   • View logs: az containerapp logs show --name <app> --resource-group <rg>"
    echo ""
    echo "2. Cannot connect to backend:"
    echo "   • Deploy backend: ./deploy.sh"
    echo "   • Check API URL in container app env vars"
    echo "   • Test backend: curl https://<function-app>.azurewebsites.net/api/v1/health"
    echo ""
    echo "3. Authentication issues:"
    echo "   • Clear browser cookies"
    echo "   • Ensure WEBUI_AUTH=true in env vars"
    echo "   • Create admin account if first time"
    echo ""
    echo "4. Slow responses:"
    echo "   • Check backend GPU instances are running"
    echo "   • Try a lighter model (phi-3-mini)"
    echo "   • Check cache is working"
    echo ""
    echo "For more help, see: docs/frontend-usage.md"
    echo ""
}

# =============================================================================
# MENU
# =============================================================================

show_menu() {
    echo ""
    echo "Options:"
    echo "  1) Check status"
    echo "  2) Test connectivity"
    echo "  3) Show connection info"
    echo "  4) Open in browser"
    echo "  5) View logs"
    echo "  6) Troubleshooting"
    echo "  7) Run all checks"
    echo "  q) Quit"
    echo ""
    read -p "Select option: " -r choice
    
    case $choice in
        1) check_status ;;
        2) test_connectivity ;;
        3) show_info ;;
        4) open_browser ;;
        5) view_logs ;;
        6) show_troubleshooting ;;
        7) check_status; test_connectivity; show_info; open_browser ;;
        q|Q) exit 0 ;;
        *) warn "Invalid option"; show_menu ;;
    esac
    
    show_menu
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo "========================================================================="
    echo "              AI Inference Platform - Frontend Launch                   "
    echo "========================================================================="
    
    # Check if running with arguments
    if [ $# -gt 0 ]; then
        case "$1" in
            --status) check_status ;;
            --test) test_connectivity ;;
            --info) show_info ;;
            --open) open_browser ;;
            --logs) view_logs ;;
            --help)
                echo ""
                echo "Usage: $0 [option]"
                echo ""
                echo "Options:"
                echo "  --status    Check deployment status"
                echo "  --test      Test connectivity"
                echo "  --info      Show connection information"
                echo "  --open      Open frontend in browser"
                echo "  --logs      View recent logs"
                echo "  --all       Run all checks and open browser"
                echo "  --help      Show this help"
                echo ""
                exit 0
                ;;
            --all)
                check_status
                test_connectivity
                show_info
                open_browser
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    else
        # Interactive mode
        check_status
        test_connectivity
        show_info
        open_browser
        show_menu
    fi
}

main "$@"
