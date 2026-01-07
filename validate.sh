#!/usr/bin/env bash
# =============================================================================
# Terraform Validation and Testing Script
# =============================================================================
# This script validates the Terraform configuration without deploying to Azure
# Run this before committing changes to ensure configuration is valid

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if Terraform is installed
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        log_info "Install from: https://developer.hashicorp.com/terraform/downloads"
        exit 1
    fi
    
    log_info "Terraform version: $(terraform version | head -n1)"
}

# Validate Terraform configuration
validate_terraform() {
    log_info "Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Format check
    log_info "Checking Terraform formatting..."
    if terraform fmt -check -recursive; then
        log_info "✅ Terraform files are properly formatted"
    else
        log_warn "⚠️  Terraform files need formatting. Run: terraform fmt -recursive"
        return 1
    fi
    
    # Initialize (without backend)
    log_info "Initializing Terraform..."
    if terraform init -backend=false > /dev/null 2>&1; then
        log_info "✅ Terraform initialized successfully"
    else
        log_error "❌ Terraform initialization failed"
        terraform init -backend=false
        return 1
    fi
    
    # Validate
    log_info "Validating Terraform configuration..."
    if terraform validate; then
        log_info "✅ Terraform configuration is valid"
    else
        log_error "❌ Terraform validation failed"
        return 1
    fi
    
    cd - > /dev/null
}

# Check shell scripts
check_shell_scripts() {
    log_info "Checking shell scripts with shellcheck..."
    
    if ! command -v shellcheck &> /dev/null; then
        log_warn "shellcheck not installed, skipping shell script checks"
        log_info "Install from: https://github.com/koalaman/shellcheck"
        return 0
    fi
    
    # Dynamically find shell scripts
    local scripts=()
    while IFS= read -r -d '' script; do
        scripts+=("$script")
    done < <(find "$SCRIPT_DIR" -type f \( -name "*.sh" -o -executable \) -not -path "*/.*" -not -path "*/node_modules/*" -not -path "*/venv/*" -print0)
    
    if [ ${#scripts[@]} -eq 0 ]; then
        log_warn "No shell scripts found to check"
        return 0
    fi
    
    local failed=0
    for script in "${scripts[@]}"; do
        # Skip if not a shell script
        if ! head -1 "$script" 2>/dev/null | grep -q "^#!.*sh"; then
            continue
        fi
        
        local rel_path="${script#"$SCRIPT_DIR"/}"
        log_info "Checking $rel_path..."
        if shellcheck "$script"; then
            log_info "✅ $rel_path passed shellcheck"
        else
            log_error "❌ $rel_path has shellcheck issues"
            failed=1
        fi
    done
    
    return $failed
}

# Validate variable constraints
check_variables() {
    log_info "Checking variable constraints..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if example file exists
    if [ -f "terraform.tfvars.example" ]; then
        log_info "✅ Example variables file exists"
    else
        log_warn "⚠️  terraform.tfvars.example not found"
    fi
    
    # Check critical variables
    log_info "Validating variable definitions..."
    
    local required_vars=(
        "vmss_sku"
        "vmss_min_instances"
        "vmss_max_instances"
        "vmss_spot_max_price"
    )
    
    for var in "${required_vars[@]}"; do
        if grep -q "variable \"$var\"" variables.tf; then
            log_info "✅ Variable '$var' defined"
        else
            log_error "❌ Variable '$var' not found in variables.tf"
            return 1
        fi
    done
    
    cd - > /dev/null
}

# Check documentation
check_documentation() {
    log_info "Checking documentation..."
    
    local docs=(
        "README.md"
        "terraform/README.md"
    )
    
    for doc in "${docs[@]}"; do
        if [ -f "$SCRIPT_DIR/$doc" ]; then
            log_info "✅ $doc exists"
        else
            log_warn "⚠️  $doc not found"
        fi
    done
}

# Summary
print_summary() {
    echo ""
    echo "=========================================="
    log_info "Validation Summary"
    echo "=========================================="
    echo ""
    log_info "All checks passed! ✅"
    echo ""
    log_info "Next steps:"
    echo "  1. Commit your changes: git add . && git commit -m 'description'"
    echo "  2. Push to trigger CI: git push"
    echo "  3. Deploy with Terraform: cd terraform && terraform apply"
    echo ""
}

# Main execution
main() {
    log_info "Starting validation..."
    echo ""
    
    local exit_code=0
    
    check_terraform || exit_code=$?
    echo ""
    
    validate_terraform || exit_code=$?
    echo ""
    
    check_shell_scripts || exit_code=$?
    echo ""
    
    check_variables || exit_code=$?
    echo ""
    
    check_documentation || exit_code=$?
    echo ""
    
    if [ $exit_code -eq 0 ]; then
        print_summary
    else
        log_error "Validation failed with errors. Please fix the issues above."
        exit $exit_code
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
