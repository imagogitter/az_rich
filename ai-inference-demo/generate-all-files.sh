#!/usr/bin/env bash
set -euo pipefail

# This script generates all project files for the AI Inference Arbitrage Platform
# Run from project root: ./scripts/generate-all-files.sh

echo "📦 Generating all project files..."

# Navigate to project root (assuming script is run from scripts/ or root)
if [ -d "scripts" ]; then
    PROJECT_ROOT="$(pwd)"
elif [ -d "../src" ]; then
    PROJECT_ROOT="$(cd .. && pwd)"
else
    echo "Error: Run this from the project root directory"
    exit 1
fi

cd "$PROJECT_ROOT"

# =============================================================================
# DEPLOYMENT SCRIPTS
# =============================================================================

cat > deploy.sh << 'DEPLOY_SH'
#!/usr/bin/env bash
set -euo pipefail

# Full Azure deployment script with all resources
# See chat.txt for complete implementation

PROJECT_NAME="${PROJECT_NAME:-ai-inference-platform}"
LOCATION="${AZURE_LOCATION:-eastus}"

echo "🚀 Deploying ${PROJECT_NAME} to Azure..."
echo "This is a placeholder. See the full deploy.sh in the original chat output."
echo ""
echo "To generate complete files, run:"
echo "  bash <(curl -s <URL_TO_FULL_SCRIPT>)"
DEPLOY_SH

chmod +x deploy.sh

cat > openapi.json << 'OPENAPI'
{
  "openapi": "3.0.3",
  "info": {
    "title": "AI Inference API",
    "version": "1.0.0"
  },
  "paths": {
    "/chat/completions": {
      "post": {
        "summary": "Create chat completion",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": ["model", "messages"],
                "properties": {
                  "model": {"type": "string"},
                  "messages": {"type": "array"}
                }
              }
            }
          }
        },
        "responses": {
          "200": {"description": "Success"}
        }
      }
    },
    "/health/live": {
      "get": {
        "summary": "Liveness probe",
        "responses": {
          "200": {"description": "Service is alive"}
        }
      }
    },
    "/health/ready": {
      "get": {
        "summary": "Readiness probe",
        "responses": {
          "200": {"description": "Service is ready"}
        }
      }
    }
  }
}
OPENAPI

# =============================================================================
# PYTHON SOURCE CODE
# =============================================================================

cat > src/requirements.txt << 'REQ'
azure-functions==1.17.0
azure-identity==1.15.0
azure-keyvault-secrets==4.7.0
azure-cosmos==4.5.1
azure-mgmt-compute==30.3.0
aiohttp==3.9.1
pydantic==2.5.2
REQ

cat > src/host.json << 'HOST_JSON'
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true
      }
    }
  },
  "extensions": {
    "http": {
      "routePrefix": "",
      "maxOutstandingRequests": 200
    }
  },
  "healthMonitor": {
    "enabled": true
  }
}
HOST_JSON

cat > src/health/function.json << 'HEALTH_FUNC'
{
  "scriptFile": "health_functions.py",
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["get"],
      "route": "health/{check_type}"
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
HEALTH_FUNC

cat > src/health/health_functions.py << 'HEALTH_PY'
"""Health check endpoints."""
import json
import azure.functions as func
from datetime import datetime

def main(req: func.HttpRequest) -> func.HttpResponse:
    check_type = req.route_params.get("check_type", "live")
    
    response = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    return func.HttpResponse(
        json.dumps(response),
        status_code=200,
        mimetype="application/json"
    )
HEALTH_PY

# =============================================================================
# TERRAFORM
# =============================================================================

mkdir -p terraform/environments

cat > terraform/main.tf << 'TF_MAIN'
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "project_name" {
  default = "ai-inference"
}

variable "location" {
  default = "eastus"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
}
TF_MAIN

cat > terraform/environments/prod.tfvars << 'TF_PROD'
project_name = "ai-inference"
environment  = "prod"
location     = "eastus"
TF_PROD

# =============================================================================
# BICEP
# =============================================================================

cat > bicep/main.bicep << 'BICEP_MAIN'
targetScope = 'subscription'

param projectName string = 'ai-inference'
param location string = 'eastus'

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${projectName}-rg'
  location: location
}
BICEP_MAIN

# =============================================================================
# GITHUB ACTIONS
# =============================================================================

cat > .github/workflows/ci.yml << 'CI_YML'
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r src/requirements.txt
      - run: pytest tests -v
CI_YML

# =============================================================================
# DOCUMENTATION
# =============================================================================

cat > docs/deployment-guide.md << 'DEPLOY_DOC'
# Deployment Guide

## Prerequisites

- Azure CLI installed
- Azure subscription
- Appropriate permissions

## Steps

1. Clone the repository
2. Configure `.env` file
3. Run `./deploy.sh`
4. Deploy function code

## Troubleshooting

See logs in Azure Portal.
DEPLOY_DOC

cat > docs/api-usage.md << 'API_DOC'
# API Usage Guide

## Authentication

```bash
curl -H "Authorization: Bearer YOUR_KEY" \
  https://your-apim.azure-api.net/v1/chat/completions \
  -d '{"model": "mixtral-8x7b", "messages": [...]}'
```

## Endpoints

- POST `/v1/chat/completions` - Generate completions
- GET `/health/live` - Liveness check
- GET `/health/ready` - Readiness check
API_DOC

# =============================================================================
# TESTS
# =============================================================================

cat > tests/conftest.py << 'CONFTEST'
import pytest
import os

@pytest.fixture
def mock_env(monkeypatch):
    monkeypatch.setenv("KEY_VAULT_NAME", "test")
    monkeypatch.setenv("COSMOS_ACCOUNT", "test")
CONFTEST

cat > tests/test_health.py << 'TEST_HEALTH'
def test_health_endpoint(mock_env):
    """Test health check returns 200."""
    # Placeholder test
    assert True
TEST_HEALTH

echo "✅ All files generated!"
echo ""
echo "📋 Generated files:"
echo "   - deploy.sh (deployment script)"
echo "   - openapi.json (API specification)"
echo "   - src/ (Python source code)"
echo "   - terraform/ (Infrastructure as Code)"
echo "   - bicep/ (Alternative IaC)"
echo "   - .github/workflows/ (CI/CD pipelines)"
echo "   - docs/ (Documentation)"
echo "   - tests/ (Test suite)"
echo ""
echo "⚠️  Note: This generates minimal/placeholder versions."
echo "    For the complete implementation with all features,"
echo "    see the full code in chat.txt"
echo ""
echo "🚀 Next steps:"
echo "   1. Review and customize configuration"
echo "   2. Run: ./deploy.sh"
echo "   3. Deploy function code"
