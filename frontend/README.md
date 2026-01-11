# AI Inference Platform - Frontend

This directory contains the Open WebUI frontend configuration for the AI Inference Platform.

## Overview

The frontend uses [Open WebUI](https://github.com/open-webui/open-webui), a feature-rich, self-hosted web interface for LLMs with:

- ✅ Built-in user authentication (username/password)
- ✅ OpenAI-compatible API integration
- ✅ Model selection and configuration
- ✅ Chat history and conversations
- ✅ Modern, responsive UI
- ✅ Multiple chat modes and settings

## Deployment

The frontend is deployed as an Azure Container App that connects to the existing Azure Functions backend.

### Environment Variables

- `OPENAI_API_BASE_URL`: Backend API URL (Azure Functions endpoint)
- `OPENAI_API_KEY`: API key for backend authentication
- `WEBUI_AUTH`: Enable authentication (default: true)
- `ENABLE_SIGNUP`: Allow new user registration (default: false)
- `DEFAULT_USER_ROLE`: Default role for users (default: user)

### Initial Admin User

The first user to register will be the admin. To create the admin user:

1. Navigate to the frontend URL
2. Click "Sign Up"
3. Create the admin account
4. Disable signup after creating admin (via environment variable)

## Local Development

```bash
docker build -t ai-inference-frontend .
docker run -p 8080:8080 \
  -e OPENAI_API_BASE_URL=https://your-function-app.azurewebsites.net/api/v1 \
  -e OPENAI_API_KEY=your-api-key \
  ai-inference-frontend
```

## Azure Deployment

The frontend is automatically deployed via Terraform. See `terraform/container_app.tf` for configuration.
