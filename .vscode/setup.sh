#!/usr/bin/env bash
set -euo pipefail

# Azure AI Inference Platform - Kilocode Setup Script
# This script helps configure VSCode for Kilocode extension

echo "==========================================="
echo "Azure AI Inference - Kilocode Setup"
echo "==========================================="
echo ""

# Check if in correct directory
if [ ! -f "../terraform/outputs.tf" ]; then
    echo "Error: Run this script from the .vscode directory"
    exit 1
fi

# Get APIM information
echo "Step 1: Getting Azure credentials..."
cd ../terraform

if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -f "terraform.tfstate" ]; then
    echo "Warning: Terraform state not found. Have you deployed the infrastructure?"
    echo "Run: terraform apply"
    exit 1
fi

APIM_NAME=$(terraform output -raw apim_name 2>/dev/null || echo "")
APIM_URL=$(terraform output -raw apim_gateway_url 2>/dev/null || echo "")

if [ -z "$APIM_NAME" ]; then
    echo "Error: Could not get APIM name from terraform output"
    exit 1
fi

echo "✓ APIM Name: $APIM_NAME"
echo "✓ APIM URL: $APIM_URL"
echo ""

# Create settings.json from template
echo "Step 2: Creating settings.json..."
cd ../.vscode

if [ -f "settings.json" ]; then
    echo "Warning: settings.json already exists"
    read -p "Overwrite? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping settings.json creation"
        exit 0
    fi
fi

cp settings.json.example settings.json
sed -i "s|YOUR-APIM-NAME|$APIM_NAME|g" settings.json

echo "✓ Created settings.json with APIM name"
echo ""

# Check for API key
echo "Step 3: Checking API key..."
if [ -z "${AZURE_AI_API_KEY:-}" ]; then
    echo "⚠ Environment variable AZURE_AI_API_KEY not set"
    echo ""
    echo "Get your API key from Azure Portal:"
    echo "  1. Go to: https://portal.azure.com"
    echo "  2. Navigate to API Management: $APIM_NAME"
    echo "  3. Click 'Subscriptions'"
    echo "  4. Copy the primary key"
    echo ""
    echo "Then set the environment variable:"
    echo "  export AZURE_AI_API_KEY=\"your-key-here\""
    echo ""
    echo "Or get it via CLI:"
    echo "  az apim subscription list --service-name $APIM_NAME --resource-group \$(terraform output -raw resource_group_name)"
else
    echo "✓ AZURE_AI_API_KEY is set"
    
    # Test connection
    echo ""
    echo "Step 4: Testing connection..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Ocp-Apim-Subscription-Key: $AZURE_AI_API_KEY" \
        "$APIM_URL/inference/health" || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✓ Connection successful!"
    else
        echo "⚠ Connection failed (HTTP $HTTP_CODE)"
        echo "  Check your API key and ensure infrastructure is deployed"
    fi
fi

echo ""
echo "==========================================="
echo "Setup complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Open VSCode in this workspace"
echo "  2. Install Kilocode extension"
echo "  3. Reload VSCode to apply settings"
echo ""
echo "Settings location: .vscode/settings.json"
echo "Documentation: KILOCODE_INTEGRATION.md"
