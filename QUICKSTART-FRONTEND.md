# 🚀 Frontend Quick Start

Get the AI Inference Platform frontend up and running in 4 steps!

## Prerequisites

- ✅ Azure CLI installed and logged in (`az login`)
- ✅ Docker installed and running
- ✅ Terraform installed

## Step 1: Deploy Infrastructure ⚙️

```bash
cd terraform
terraform init
terraform apply -auto-approve
cd ..
```

**Time**: ~5-10 minutes

## Step 2: Deploy Frontend 🐳

```bash
./deploy-frontend.sh
```

**Time**: ~2-3 minutes

## Step 3: Create Admin Account 👤

```bash
# Get your frontend URL
cd terraform && terraform output frontend_url
```

1. Open the URL in your browser
2. Click **"Sign Up"**
3. Fill in:
   - Username (e.g., "admin")
   - Name (e.g., "Admin User")
   - Password (use a strong password!)
4. Click **"Create Account"**

**⚠️ Important**: The first user becomes the admin!

## Step 4: Secure the Frontend 🔒

```bash
# After creating your admin account
./setup-frontend-auth.sh
```

Follow the prompts to disable public signup.

**Time**: ~1 minute

## ✅ Done!

Your frontend is ready! Visit the URL and start chatting with AI models.

---

## Quick Tips

### Select a Model
- **Llama-3-70B**: Best quality, 8K context
- **Mixtral 8x7B**: Fast, 32K context  
- **Phi-3-mini**: Lightweight, 4K context

### Adjust Settings
Click the ⚙️ icon to change:
- Temperature (creativity)
- Max tokens (response length)
- Top P (diversity)

### Use System Prompts
Set the AI's behavior with system prompts like:
- "You are a helpful coding assistant"
- "Respond in a friendly, casual tone"
- "You are an expert in Python"

---

## Need Help?

- 📖 [Full Deployment Guide](docs/frontend-deployment.md)
- 📚 [Usage Guide](docs/frontend-usage.md)
- 🏗️ [Implementation Details](docs/FRONTEND-IMPLEMENTATION.md)
- 🐛 Check logs: `az containerapp logs show --name ai-inference-platform-frontend --resource-group <resource-group>`

## Common Issues

### "terraform: command not found"
Install Terraform: https://www.terraform.io/downloads

### "docker: command not found"  
Install Docker: https://docs.docker.com/get-docker/

### "az: command not found"
Install Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli

### Cannot access frontend URL
Wait 1-2 minutes after deployment for DNS propagation

### Backend connection error
Ensure Azure Functions are deployed and running

---

## What's Next?

- 🎨 Customize the interface name in `terraform/container_app.tf`
- 👥 Add more users (temporarily enable signup)
- 🔧 Adjust auto-scaling settings
- 📊 Monitor usage in Azure Portal
- 💾 Configure persistent storage for chat history

**Enjoy your AI Inference Platform! 🎉**
