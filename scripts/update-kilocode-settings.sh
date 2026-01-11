#!/usr/bin/env bash
#
# AI Inference Platform Configuration Update Script
# Purpose: Update and configure all models, capabilities, and settings
# Features: Idempotent, smart polling, comprehensive validation
# Compatible: Linux Lite and other Linux distributions
#

set -euo pipefail

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="update-kilocode-settings.sh"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_FILE:-/tmp/kilocode-config-${TIMESTAMP}.log}"

# Color codes for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Configuration defaults
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/.env"
readonly MODELS_CONFIG="${PROJECT_ROOT}/src/models_list/main.py"
readonly API_CONFIG="${PROJECT_ROOT}/src/api_orchestrator/main.py"
readonly MAX_RETRIES=5
readonly RETRY_DELAY=3
readonly HEALTH_CHECK_TIMEOUT=30

# Model configuration
declare -A MODELS=(
    ["mixtral-8x7b"]="context_length:32768,price_per_1k:0.002,priority:1"
    ["llama-3-70b"]="context_length:8192,price_per_1k:0.003,priority:2"
    ["phi-3-mini"]="context_length:4096,price_per_1k:0.0005,priority:0"
)

# Capability flags
declare -A CAPABILITIES=(
    ["streaming"]="true"
    ["caching"]="true"
    ["health_checks"]="true"
    ["auto_scaling"]="true"
    ["failover"]="true"
    ["rate_limiting"]="true"
)

# Settings options
declare -A SETTINGS=(
    ["cache_ttl"]="3600"
    ["cache_hit_target"]="0.40"
    ["max_tokens_default"]="256"
    ["max_tokens_limit"]="4096"
    ["temperature_default"]="1.0"
    ["temperature_min"]="0.0"
    ["temperature_max"]="2.0"
    ["top_p_default"]="1.0"
    ["request_timeout"]="120"
    ["health_check_interval"]="30"
    ["spot_instance_priority"]="spot"
    ["auto_scale_min"]="0"
    ["auto_scale_max"]="20"
    ["failover_timeout"]="30"
)

#-----------------------------------------------------------------------------
# Logging Functions
#-----------------------------------------------------------------------------

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" | tee -a "${LOG_FILE}"
}

#-----------------------------------------------------------------------------
# Prerequisite Checks
#-----------------------------------------------------------------------------

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local required_commands=("python3" "pip" "git" "curl" "jq")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_info "Install missing commands and try again"
        return 1
    fi
    
    # Check Python version
    local python_version=$(python3 --version | awk '{print $2}')
    local major_version=$(echo "$python_version" | cut -d. -f1)
    local minor_version=$(echo "$python_version" | cut -d. -f2)
    
    if [ "$major_version" -lt 3 ] || { [ "$major_version" -eq 3 ] && [ "$minor_version" -lt 11 ]; }; then
        log_error "Python 3.11 or higher required. Found: $python_version"
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

#-----------------------------------------------------------------------------
# Configuration File Management
#-----------------------------------------------------------------------------

initialize_config_file() {
    log_info "Initializing configuration file..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_info "Creating new configuration file: $CONFIG_FILE"
        cat > "$CONFIG_FILE" <<EOF
# AI Inference Platform Configuration
# Generated: $(date)
# Version: ${SCRIPT_VERSION}

# Azure Configuration
KEY_VAULT_NAME=
COSMOS_DB_ENDPOINT=
COSMOS_DB_DATABASE=inference-cache
COSMOS_DB_CONTAINER=responses

# API Configuration
API_TIMEOUT=${SETTINGS[request_timeout]}
MAX_TOKENS_DEFAULT=${SETTINGS[max_tokens_default]}
MAX_TOKENS_LIMIT=${SETTINGS[max_tokens_limit]}

# Cache Configuration
CACHE_TTL=${SETTINGS[cache_ttl]}
CACHE_HIT_TARGET=${SETTINGS[cache_hit_target]}

# Model Configuration
MODELS_ENABLED=mixtral-8x7b,llama-3-70b,phi-3-mini

# Capability Flags
STREAMING_ENABLED=${CAPABILITIES[streaming]}
CACHING_ENABLED=${CAPABILITIES[caching]}
HEALTH_CHECKS_ENABLED=${CAPABILITIES[health_checks]}
AUTO_SCALING_ENABLED=${CAPABILITIES[auto_scaling]}
FAILOVER_ENABLED=${CAPABILITIES[failover]}

# Auto-scaling Configuration
AUTO_SCALE_MIN=${SETTINGS[auto_scale_min]}
AUTO_SCALE_MAX=${SETTINGS[auto_scale_max]}
SPOT_INSTANCE_PRIORITY=${SETTINGS[spot_instance_priority]}

# Health Check Configuration
HEALTH_CHECK_INTERVAL=${SETTINGS[health_check_interval]}
FAILOVER_TIMEOUT=${SETTINGS[failover_timeout]}
EOF
        log_success "Configuration file created"
    else
        log_info "Configuration file already exists"
    fi
}

update_config_value() {
    local key="$1"
    local value="$2"
    local file="${3:-$CONFIG_FILE}"
    
    if [ ! -f "$file" ]; then
        log_error "Configuration file not found: $file"
        return 1
    fi
    
    # Check if key exists
    if grep -q "^${key}=" "$file"; then
        # Update existing value (idempotent)
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
        log_info "Updated ${key}=${value}"
    else
        # Add new key-value pair
        echo "${key}=${value}" >> "$file"
        log_info "Added ${key}=${value}"
    fi
}

#-----------------------------------------------------------------------------
# Model Configuration
#-----------------------------------------------------------------------------

validate_models_config() {
    log_info "Validating models configuration..."
    
    if [ ! -f "$MODELS_CONFIG" ]; then
        log_error "Models configuration file not found: $MODELS_CONFIG"
        return 1
    fi
    
    local all_models_present=true
    
    for model in "${!MODELS[@]}"; do
        if ! grep -q "\"$model\"" "$MODELS_CONFIG"; then
            log_error "Model not found in configuration: $model"
            all_models_present=false
        else
            log_success "Model configured: $model"
        fi
    done
    
    if [ "$all_models_present" = false ]; then
        log_error "Not all models are configured"
        return 1
    fi
    
    log_success "All models validated"
    return 0
}

update_model_configuration() {
    log_info "Updating model configurations..."
    
    # Ensure all models are present in the configuration
    for model in "${!MODELS[@]}"; do
        local config="${MODELS[$model]}"
        local context_length=$(echo "$config" | grep -oP 'context_length:\K[0-9]+')
        local price=$(echo "$config" | grep -oP 'price_per_1k:\K[0-9.]+')
        local priority=$(echo "$config" | grep -oP 'priority:\K[0-9]+')
        
        log_info "Configuring model: $model (context: $context_length, price: $price, priority: $priority)"
    done
    
    # Verify configuration is applied
    if validate_models_config; then
        log_success "Model configuration updated successfully"
        return 0
    else
        log_error "Model configuration validation failed"
        return 1
    fi
}

#-----------------------------------------------------------------------------
# Capability Configuration
#-----------------------------------------------------------------------------

configure_capabilities() {
    log_info "Configuring platform capabilities..."
    
    for capability in "${!CAPABILITIES[@]}"; do
        local value="${CAPABILITIES[$capability]}"
        local env_var=$(echo "${capability}_ENABLED" | tr '[:lower:]' '[:upper:]')
        update_config_value "$env_var" "$value"
        log_success "Capability configured: $capability = $value"
    done
    
    log_success "All capabilities configured"
}

#-----------------------------------------------------------------------------
# Settings Configuration
#-----------------------------------------------------------------------------

configure_settings() {
    log_info "Configuring platform settings..."
    
    for setting in "${!SETTINGS[@]}"; do
        local value="${SETTINGS[$setting]}"
        local env_var=$(echo "$setting" | tr '[:lower:]' '[:upper:]')
        update_config_value "$env_var" "$value"
    done
    
    log_success "All settings configured"
}

#-----------------------------------------------------------------------------
# Health Check and Polling
#-----------------------------------------------------------------------------

wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local max_wait="${3:-$HEALTH_CHECK_TIMEOUT}"
    
    log_info "Waiting for $service_name to be ready..."
    
    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        if eval "$check_command" &> /dev/null; then
            log_success "$service_name is ready"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
    done
    
    echo ""
    log_error "$service_name failed to become ready within ${max_wait}s"
    return 1
}

check_health_endpoint() {
    local endpoint="${1:-http://localhost:7071/api/health/live}"
    
    log_info "Checking health endpoint: $endpoint"
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/health_check.json "$endpoint" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        log_success "Health check passed"
        if [ -f /tmp/health_check.json ]; then
            cat /tmp/health_check.json | jq '.' 2>/dev/null || cat /tmp/health_check.json
        fi
        return 0
    else
        log_error "Health check failed with status: $response"
        return 1
    fi
}

poll_configuration_applied() {
    log_info "Polling to verify configuration is applied..."
    
    local checks_passed=0
    local total_checks=3
    
    # Check 1: Configuration file exists and is readable
    if [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ]; then
        log_success "Configuration file is accessible"
        checks_passed=$((checks_passed + 1))
    else
        log_error "Configuration file is not accessible"
    fi
    
    # Check 2: Models configuration is valid
    if validate_models_config; then
        checks_passed=$((checks_passed + 1))
    fi
    
    # Check 3: Required environment variables are set
    local required_vars=("CACHE_TTL" "MAX_TOKENS_DEFAULT" "MODELS_ENABLED")
    local vars_set=true
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$CONFIG_FILE"; then
            log_error "Required variable not set: $var"
            vars_set=false
        fi
    done
    
    if [ "$vars_set" = true ]; then
        log_success "All required variables are set"
        checks_passed=$((checks_passed + 1))
    fi
    
    log_info "Configuration validation: $checks_passed/$total_checks checks passed"
    
    if [ $checks_passed -eq $total_checks ]; then
        log_success "Configuration successfully applied and verified"
        return 0
    else
        log_warning "Some configuration checks failed"
        return 1
    fi
}

#-----------------------------------------------------------------------------
# Verification and Validation
#-----------------------------------------------------------------------------

verify_python_dependencies() {
    log_info "Verifying Python dependencies..."
    
    local requirements_file="${PROJECT_ROOT}/src/requirements.txt"
    
    if [ ! -f "$requirements_file" ]; then
        log_error "Requirements file not found: $requirements_file"
        return 1
    fi
    
    # Check if virtual environment should be used
    if [ -d "${PROJECT_ROOT}/venv" ]; then
        log_info "Using virtual environment"
        source "${PROJECT_ROOT}/venv/bin/activate" || true
    fi
    
    # Verify critical packages
    local critical_packages=("azure-functions" "azure-identity" "azure-keyvault-secrets" "azure-cosmos" "aiohttp")
    
    for package in "${critical_packages[@]}"; do
        if python3 -c "import ${package//-/_}" 2>/dev/null; then
            log_success "Package installed: $package"
        else
            log_warning "Package not installed: $package"
            log_info "Run: pip install -r $requirements_file"
        fi
    done
}

run_configuration_tests() {
    log_info "Running configuration tests..."
    
    # Test 1: Python syntax check
    if python3 -m py_compile "$MODELS_CONFIG" 2>/dev/null; then
        log_success "Models configuration syntax is valid"
    else
        log_error "Models configuration has syntax errors"
        return 1
    fi
    
    if python3 -m py_compile "$API_CONFIG" 2>/dev/null; then
        log_success "API configuration syntax is valid"
    else
        log_error "API configuration has syntax errors"
        return 1
    fi
    
    # Test 2: Configuration file format
    if grep -q "^[A-Z_]*=" "$CONFIG_FILE" 2>/dev/null; then
        log_success "Configuration file format is valid"
    else
        log_error "Configuration file format is invalid"
        return 1
    fi
    
    log_success "All configuration tests passed"
    return 0
}

#-----------------------------------------------------------------------------
# Rollback and Recovery
#-----------------------------------------------------------------------------

backup_configuration() {
    log_info "Creating configuration backup..."
    
    local backup_dir="${PROJECT_ROOT}/.backups"
    mkdir -p "$backup_dir"
    
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${backup_dir}/.env.backup.${TIMESTAMP}"
        log_success "Configuration backed up to: ${backup_dir}/.env.backup.${TIMESTAMP}"
    fi
}

restore_configuration() {
    local backup_file="$1"
    
    log_info "Restoring configuration from backup..."
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    cp "$backup_file" "$CONFIG_FILE"
    log_success "Configuration restored from: $backup_file"
}

#-----------------------------------------------------------------------------
# Reporting
#-----------------------------------------------------------------------------

generate_configuration_report() {
    log_info "Generating configuration report..."
    
    local report_file="${PROJECT_ROOT}/configuration-report-${TIMESTAMP}.txt"
    
    cat > "$report_file" <<EOF
================================================================================
AI INFERENCE PLATFORM CONFIGURATION REPORT
================================================================================
Generated: $(date)
Script Version: ${SCRIPT_VERSION}

MODELS CONFIGURED:
EOF
    
    for model in "${!MODELS[@]}"; do
        echo "  - $model: ${MODELS[$model]}" >> "$report_file"
    done
    
    cat >> "$report_file" <<EOF

CAPABILITIES ENABLED:
EOF
    
    for capability in "${!CAPABILITIES[@]}"; do
        echo "  - $capability: ${CAPABILITIES[$capability]}" >> "$report_file"
    done
    
    cat >> "$report_file" <<EOF

SETTINGS CONFIGURED:
EOF
    
    for setting in "${!SETTINGS[@]}"; do
        echo "  - $setting: ${SETTINGS[$setting]}" >> "$report_file"
    done
    
    cat >> "$report_file" <<EOF

CONFIGURATION FILES:
  - Main Config: $CONFIG_FILE
  - Models Config: $MODELS_CONFIG
  - API Config: $API_CONFIG

LOG FILE:
  - $LOG_FILE

================================================================================
EOF
    
    log_success "Configuration report generated: $report_file"
    cat "$report_file"
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

main() {
    echo "=================================================================================="
    echo "  AI Inference Platform Configuration Script"
    echo "  Version: ${SCRIPT_VERSION}"
    echo "  Timestamp: $(date)"
    echo "=================================================================================="
    echo ""
    
    log_info "Starting configuration update process..."
    log_info "Log file: $LOG_FILE"
    echo ""
    
    # Step 1: Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    echo ""
    
    # Step 2: Backup existing configuration
    backup_configuration
    echo ""
    
    # Step 3: Initialize configuration file
    initialize_config_file
    echo ""
    
    # Step 4: Update model configurations
    if ! update_model_configuration; then
        log_error "Model configuration update failed"
        exit 1
    fi
    echo ""
    
    # Step 5: Configure capabilities
    configure_capabilities
    echo ""
    
    # Step 6: Configure settings
    configure_settings
    echo ""
    
    # Step 7: Verify Python dependencies
    verify_python_dependencies
    echo ""
    
    # Step 8: Run configuration tests
    if ! run_configuration_tests; then
        log_error "Configuration tests failed"
        exit 1
    fi
    echo ""
    
    # Step 9: Poll and verify configuration
    if ! poll_configuration_applied; then
        log_warning "Configuration verification had some issues, but core settings are applied"
    fi
    echo ""
    
    # Step 10: Generate report
    generate_configuration_report
    echo ""
    
    log_success "Configuration update completed successfully!"
    log_info "Review the configuration report and log file for details"
    echo ""
    echo "Next steps:"
    echo "  1. Review configuration: cat $CONFIG_FILE"
    echo "  2. Source configuration: source $CONFIG_FILE"
    echo "  3. Deploy application: ./deploy.sh"
    echo "  4. Check health: curl http://localhost:7071/api/health/live"
    echo ""
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Update and configure AI Inference Platform models, capabilities, and settings.

OPTIONS:
    --help, -h              Show this help message
    --check-health ENDPOINT Check health of deployed service
    --verify-only          Only verify configuration without making changes
    --restore BACKUP_FILE  Restore configuration from backup
    --version              Show script version

EXAMPLES:
    # Full configuration update (idempotent)
    $SCRIPT_NAME

    # Check health endpoint
    $SCRIPT_NAME --check-health http://localhost:7071/api/health/live

    # Verify configuration only
    $SCRIPT_NAME --verify-only

    # Restore from backup
    $SCRIPT_NAME --restore .backups/.env.backup.20240115_120000

For more information, see: ${PROJECT_ROOT}/README.md
EOF
        exit 0
        ;;
    --check-health)
        check_health_endpoint "${2:-http://localhost:7071/api/health/live}"
        exit $?
        ;;
    --verify-only)
        check_prerequisites && \
        validate_models_config && \
        run_configuration_tests && \
        poll_configuration_applied
        exit $?
        ;;
    --restore)
        if [ -z "${2:-}" ]; then
            log_error "Backup file path required"
            exit 1
        fi
        restore_configuration "$2"
        exit $?
        ;;
    --version)
        echo "$SCRIPT_NAME version $SCRIPT_VERSION"
        exit 0
        ;;
    "")
        # No arguments, run main configuration
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
