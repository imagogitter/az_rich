# Frontend Deployment Guide

This guide explains how to deploy the Open WebUI frontend for the AI Inference Platform.

## Overview

The frontend is deployed as an Azure Container App running Open WebUI, which provides:

- Built-in user authentication (username/password)
- OpenAI-compatible API integration
- Full model selection and configuration
- Modern, responsive web interface
- Chat history and conversation management

## Prerequisites

- Azure CLI (`az`) installed
- Docker installed
- Terraform deployed infrastructure (run `terraform apply` first)
- Azure subscription with permissions to create Container Apps

## Deployment Steps

### 1. Deploy Infrastructure

First, deploy the base infrastructure using Terraform:

```bash
cd terraform
terraform init
terraform apply
```

This creates:
- Azure Container Registry
- Azure Container App Environment
- Azure Container App (with placeholder image)
- Key Vault secrets for API authentication

### 2. Build and Deploy Frontend

Run the frontend deployment script:

```bash
./deploy-frontend.sh
```

This script will:
1. Login to Azure Container Registry
2. Build the Open WebUI Docker image
3. Push the image to ACR
4. Trigger a Container App revision restart

### 3. Get Frontend URL

After deployment, get the frontend URL:

```bash
cd terraform
terraform output frontend_url
```

Example output:
```
https://ai-inference-platform-frontend.happygrass-12345678.eastus.azurecontainerapps.io
```

### 4. Initial Setup

1. Navigate to the frontend URL in your browser
2. You'll be prompted to sign up for the first time
3. Create an admin account (first user becomes admin)
4. After creating the admin account, disable signup to prevent unauthorized access

## Configuration

### Environment Variables

The Container App is configured with the following environment variables:

- `OPENAI_API_BASE_URL`: Backend API endpoint (Azure Functions)
- `OPENAI_API_KEY`: API key for backend authentication (stored in Key Vault)
- `WEBUI_AUTH`: Enable authentication (default: true)
- `ENABLE_SIGNUP`: Allow new user registration (default: false)
- `WEBUI_NAME`: Name displayed in UI (default: "AI Inference Platform")
- `DEFAULT_USER_ROLE`: Default role for new users (default: "user")

## Usage

### Model Selection

Open WebUI automatically discovers available models from the backend API. Users can select from:

- **Llama-3-70B**: High-quality responses, 8K context
- **Mixtral 8x7B**: Fast and efficient, 32K context
- **Phi-3-mini**: Lightweight, 4K context

### Features

- **Chat Interface**: Multi-turn conversations with context
- **System Prompts**: Set custom system instructions
- **Parameters**: Adjust temperature, top_p, max_tokens
- **History**: Save and manage conversation history
- **Export**: Export conversations to various formats
- **Models**: Switch between available models

## Troubleshooting

### Container App Not Starting

Check the logs:

```bash
az containerapp logs show \
  --name ai-inference-platform-frontend \
  --resource-group $(cd terraform && terraform output -raw resource_group_name) \
  --tail 100
```

### Authentication Issues

1. Verify the OpenAI API key is correctly set
2. Check backend API is accessible

### Image Not Updating

Force a new revision:

```bash
az containerapp revision restart \
  --name ai-inference-platform-frontend \
  --resource-group $(cd terraform && terraform output -raw resource_group_name)
```

## Cost Optimization

The Container App is configured with:

- **Min replicas**: 0 (scales to zero when idle)
- **Max replicas**: 3 (scales up under load)
- **CPU**: 0.5 cores per instance
- **Memory**: 1Gi per instance

Expected costs:
- **Idle**: $0-2/month (scales to zero)
- **Active**: $5-20/month depending on usage

## Security

### Authentication

- **Required**: All users must authenticate before accessing the UI
- **Signup**: Disabled by default after admin creation
- **Roles**: Admin can manage users and settings

### API Security

- Backend API key is stored as a Container App secret
- Key is never exposed in logs or UI
- HTTPS only for all connections
