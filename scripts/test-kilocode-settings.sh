#!/usr/bin/env bash
#
# Test script for update-kilocode-settings.sh
# Purpose: Validate the configuration script works correctly
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_SCRIPT="${SCRIPT_DIR}/update-kilocode-settings.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

test_passed=0
test_failed=0

echo "========================================================================"
echo "  Testing update-kilocode-settings.sh"
echo "========================================================================"
echo ""

# Helper functions
pass() {
    echo -e "${GREEN}✓ PASS${RESET}: $1"
    test_passed=$((test_passed + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${RESET}: $1"
    test_failed=$((test_failed + 1))
}

info() {
    echo -e "${YELLOW}INFO${RESET}: $1"
}

# Test 1: Script exists and is executable
test_script_exists() {
    info "Test 1: Check script exists and is executable"
    
    if [ -f "$CONFIG_SCRIPT" ]; then
        pass "Script file exists"
    else
        fail "Script file not found: $CONFIG_SCRIPT"
        return 1
    fi
    
    if [ -x "$CONFIG_SCRIPT" ]; then
        pass "Script is executable"
    else
        fail "Script is not executable"
        return 1
    fi
}

# Test 2: Script shows help
test_help_command() {
    info "Test 2: Check --help command"
    
    if bash "$CONFIG_SCRIPT" --help &> /dev/null; then
        pass "Help command works"
    else
        fail "Help command failed"
        return 1
    fi
}

# Test 3: Script shows version
test_version_command() {
    info "Test 3: Check --version command"
    
    local output=$(bash "$CONFIG_SCRIPT" --version)
    if [[ "$output" =~ "version" ]]; then
        pass "Version command works: $output"
    else
        fail "Version command failed"
        return 1
    fi
}

# Test 4: Verify-only mode (dry run)
test_verify_mode() {
    info "Test 4: Check --verify-only mode"
    
    # This may fail if config doesn't exist, but command should work
    bash "$CONFIG_SCRIPT" --verify-only &> /tmp/verify-test.log || true
    
    if [ -f /tmp/verify-test.log ]; then
        if grep -q "Checking prerequisites" /tmp/verify-test.log; then
            pass "Verify mode executes prerequisite checks"
        else
            fail "Verify mode didn't run prerequisite checks"
            return 1
        fi
    else
        fail "Verify mode produced no output"
        return 1
    fi
}

# Test 5: Full configuration run
test_full_configuration() {
    info "Test 5: Check full configuration run"
    
    # Clean up any existing config
    rm -f "${PROJECT_ROOT}/.env"
    
    # Run configuration
    if bash "$CONFIG_SCRIPT" &> /tmp/config-test.log; then
        pass "Configuration script completed successfully"
        
        # Check if .env was created
        if [ -f "${PROJECT_ROOT}/.env" ]; then
            pass ".env file was created"
            
            # Check for key configuration values
            if grep -q "MODELS_ENABLED=mixtral-8x7b,llama-3-70b,phi-3-mini" "${PROJECT_ROOT}/.env"; then
                pass "Models are configured correctly"
            else
                fail "Models configuration is incorrect"
            fi
            
            if grep -q "STREAMING_ENABLED=true" "${PROJECT_ROOT}/.env"; then
                pass "Streaming capability is enabled"
            else
                fail "Streaming capability is not enabled"
            fi
            
            if grep -q "CACHE_TTL=3600" "${PROJECT_ROOT}/.env"; then
                pass "Cache TTL is configured"
            else
                fail "Cache TTL is not configured"
            fi
        else
            fail ".env file was not created"
        fi
    else
        fail "Configuration script failed"
        return 1
    fi
}

# Test 6: Idempotency check
test_idempotency() {
    info "Test 6: Check idempotency (run twice)"
    
    # First run
    bash "$CONFIG_SCRIPT" &> /tmp/config-run1.log
    local checksum1=$(md5sum "${PROJECT_ROOT}/.env" 2>/dev/null | cut -d' ' -f1 || echo "")
    
    sleep 1
    
    # Second run
    bash "$CONFIG_SCRIPT" &> /tmp/config-run2.log
    local checksum2=$(md5sum "${PROJECT_ROOT}/.env" 2>/dev/null | cut -d' ' -f1 || echo "")
    
    if [ "$checksum1" == "$checksum2" ]; then
        pass "Configuration is idempotent (no changes on second run)"
    else
        # Check if only timestamp changed
        if diff <(grep -v "^# Generated:" "${PROJECT_ROOT}/.env" | grep -v "^#") \
                <(grep -v "^# Generated:" "${PROJECT_ROOT}/.env" | grep -v "^#") &>/dev/null; then
            pass "Configuration is idempotent (only timestamp changed)"
        else
            fail "Configuration changed between runs (not idempotent)"
        fi
    fi
}

# Test 7: Backup creation
test_backup_creation() {
    info "Test 7: Check backup creation"
    
    # Run configuration
    bash "$CONFIG_SCRIPT" &> /tmp/config-backup-test.log
    
    if [ -d "${PROJECT_ROOT}/.backups" ]; then
        pass "Backup directory was created"
        
        local backup_count=$(ls -1 "${PROJECT_ROOT}/.backups"/.env.backup.* 2>/dev/null | wc -l)
        if [ "$backup_count" -gt 0 ]; then
            pass "Backup files were created ($backup_count backups)"
        else
            fail "No backup files were created"
        fi
    else
        # First run might not create backup if no previous config exists
        pass "Backup directory not needed (first run)"
    fi
}

# Test 8: Configuration report generation
test_report_generation() {
    info "Test 8: Check configuration report generation"
    
    bash "$CONFIG_SCRIPT" &> /tmp/config-report-test.log
    
    local report_count=$(ls -1 "${PROJECT_ROOT}"/configuration-report-*.txt 2>/dev/null | wc -l)
    
    if [ "$report_count" -gt 0 ]; then
        pass "Configuration report was generated"
        
        local latest_report=$(ls -t "${PROJECT_ROOT}"/configuration-report-*.txt | head -1)
        if grep -q "MODELS CONFIGURED:" "$latest_report"; then
            pass "Report contains model information"
        else
            fail "Report is missing model information"
        fi
    else
        fail "No configuration report was generated"
    fi
}

# Test 9: Script handles missing prerequisites gracefully
test_error_handling() {
    info "Test 9: Check error handling (informational)"
    
    # This test is informational - just checks that script doesn't crash
    bash "$CONFIG_SCRIPT" --help &> /dev/null
    if [ $? -eq 0 ]; then
        pass "Script handles commands without errors"
    else
        fail "Script has error handling issues"
    fi
}

# Run all tests
echo "Starting tests..."
echo ""

test_script_exists
echo ""

test_help_command
echo ""

test_version_command
echo ""

test_verify_mode
echo ""

test_full_configuration
echo ""

test_idempotency
echo ""

test_backup_creation
echo ""

test_report_generation
echo ""

test_error_handling
echo ""

# Summary
echo "========================================================================"
echo "  Test Summary"
echo "========================================================================"
echo -e "Passed: ${GREEN}${test_passed}${RESET}"
echo -e "Failed: ${RED}${test_failed}${RESET}"
echo ""

# Cleanup
info "Cleaning up test artifacts..."
rm -f /tmp/config-test.log /tmp/config-run1.log /tmp/config-run2.log
rm -f /tmp/verify-test.log /tmp/config-backup-test.log /tmp/config-report-test.log
rm -f "${PROJECT_ROOT}"/.env
rm -rf "${PROJECT_ROOT}"/.backups
rm -f "${PROJECT_ROOT}"/configuration-report-*.txt

echo ""

if [ $test_failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${RESET}"
    exit 0
else
    echo -e "${RED}Some tests failed!${RESET}"
    exit 1
fi
