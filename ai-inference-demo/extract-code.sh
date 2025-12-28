#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# EXTRACT COMPLETE CODE FROM CHAT.TXT
# =============================================================================
# This script helps extract the full production-ready code from chat.txt
# =============================================================================

CHAT_FILE="../chat.txt"

if [ ! -f "$CHAT_FILE" ]; then
    echo "❌ Error: chat.txt not found in parent directory"
    echo "Expected location: $(cd .. && pwd)/chat.txt"
    exit 1
fi

echo "📄 Code Extraction Helper"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The chat.txt file contains the complete production-ready code."
echo "This helper provides examples of how to extract specific files."
echo ""

# Function to show extraction options
show_menu() {
    echo "Available extractions:"
    echo ""
    echo "  1) Show code structure overview"
    echo "  2) Extract deploy.sh (full version)"
    echo "  3) Extract health_functions.py"
    echo "  4) Extract api_orchestrator/main.py"
    echo "  5) Extract Terraform main.tf"
    echo "  6) Extract all Terraform files"
    echo "  7) Extract all Bicep files"
    echo "  8) Extract GitHub Actions workflows"
    echo "  9) List all code blocks in chat.txt"
    echo "  0) Exit"
    echo ""
}

# Function to find code blocks
list_code_blocks() {
    echo "📦 Code blocks found in chat.txt:"
    echo ""
    grep -n "cat >" "$CHAT_FILE" | head -50 || echo "No code blocks found"
    echo ""
    echo "Total code blocks: $(grep -c "cat >" "$CHAT_FILE" 2>/dev/null || echo "0")"
}

# Function to show structure
show_structure() {
    echo "📂 Full Project Structure (from chat.txt):"
    echo ""
    cat << 'STRUCTURE'
ai-inference-platform/
├── deploy.sh                          # Complete deployment script (500+ lines)
├── openapi.json                       # Full OpenAPI 3.0 specification
├── .env.example
├── .gitignore
│
├── src/                               # Azure Functions
│   ├── requirements.txt               # Python dependencies
│   ├── host.json                      # Function app configuration
│   ├── local.settings.json.example
│   │
│   ├── health/                        # Health check endpoints
│   │   ├── __init__.py
│   │   ├── function.json
│   │   └── health_functions.py        # Complete with K8s-style probes
│   │
│   ├── api_orchestrator/              # Main API logic
│   │   ├── __init__.py
│   │   ├── function.json
│   │   └── main.py                    # Full routing, caching, error handling
│   │
│   ├── models_list/                   # Model listing endpoint
│   │   ├── function.json
│   │   └── main.py
│   │
│   └── shared/                        # Shared utilities
│       └── (utilities)
│
├── terraform/                         # Complete Terraform IaC
│   ├── main.tf                        # Root module
│   ├── variables.tf                   # All variables with validation
│   ├── outputs.tf                     # Comprehensive outputs
│   ├── resource_group.tf
│   ├── keyvault.tf                    # With RBAC and secrets
│   ├── monitoring.tf                  # Log Analytics + App Insights
│   ├── storage.tf                     # Storage accounts
│   ├── cosmos.tf                      # Cosmos DB serverless
│   ├── network.tf                     # VNet, subnets, NSGs
│   ├── functions.tf                   # Function app with managed identity
│   ├── vmss.tf                        # GPU instances with spot pricing
│   ├── apim.tf                        # API Management
│   ├── terraform.tfvars.example
│   └── environments/
│       ├── dev.tfvars
│       ├── staging.tfvars
│       └── prod.tfvars
│
├── bicep/                             # Alternative IaC with Bicep
│   ├── main.bicep                     # Main deployment
│   └── modules/
│       ├── resources.bicep
│       ├── keyvault.bicep
│       ├── monitoring.bicep
│       ├── cosmos.bicep
│       ├── network.bicep
│       ├── functions.bicep
│       ├── vmss.bicep
│       └── apim.bicep
│
├── .github/workflows/                 # Full CI/CD
│   ├── ci.yml                         # Lint, test, validate
│   ├── deploy-functions.yml           # Function app deployment
│   ├── deploy-infrastructure.yml      # IaC deployment
│   ├── security-scan.yml              # Security scanning
│   └── health-monitor.yml             # Automated health checks
│
├── docs/                              # Complete documentation
│   ├── deployment-guide.md            # Step-by-step deployment
│   ├── api-usage.md                   # API documentation with examples
│   ├── architecture.md                # Architecture diagrams
│   └── runbook.md                     # Operations runbook
│
└── tests/                             # Test suite
    ├── __init__.py
    ├── conftest.py                    # Pytest fixtures
    ├── test_health.py                 # Health endpoint tests
    └── test_api_orchestrator.py       # API logic tests

TOTAL LINES: ~3000+ lines of production-ready code
STRUCTURE
}

# Function to extract a specific file
extract_file() {
    local filename="$1"
    local output_file="$2"
    
    echo "Extracting: $filename -> $output_file"
    
    # This is a simplified example - actual extraction would need more sophisticated parsing
    echo "⚠️  Manual extraction recommended:"
    echo "   1. Open chat.txt in a text editor"
    echo "   2. Search for: cat > $filename"
    echo "   3. Copy the content between heredoc markers"
    echo "   4. Save to: $output_file"
    echo ""
}

# Main menu loop
while true; do
    show_menu
    read -p "Select an option (0-9): " choice
    
    case $choice in
        1)
            show_structure
            echo ""
            read -p "Press Enter to continue..."
            ;;
        2)
            echo ""
            echo "To extract the FULL deploy.sh:"
            echo "1. Open: $CHAT_FILE"
            echo "2. Search for: 'cat > deploy.sh << .HEREDOC.'"
            echo "3. Copy everything until the next HEREDOC marker"
            echo "4. Save as: deploy-full.sh"
            echo ""
            read -p "Press Enter to continue..."
            ;;
        3)
            extract_file "src/health/health_functions.py" "src/health/health_functions.py"
            read -p "Press Enter to continue..."
            ;;
        9)
            list_code_blocks
            read -p "Press Enter to continue..."
            ;;
        0)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done
