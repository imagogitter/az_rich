# Complete Setup Checklist

This checklist helps you set up and validate the AI Inference Platform frontend and LLM connections.

## ✅ Prerequisites

- [ ] Azure CLI installed (`az --version`)
- [ ] Docker installed and running (`docker ps`)
- [ ] Terraform installed (`terraform version`)
- [ ] Logged into Azure (`az login`)
- [ ] Python 3.7+ (for examples) (`python3 --version`)
- [ ] jq installed (for cURL examples) (`jq --version`)

## 📋 Setup Options

### Option A: Automated Setup (Recommended)

- [ ] Run `./setup-frontend-complete.sh`
  - [ ] Infrastructure deployed
  - [ ] Frontend container built and deployed
  - [ ] Admin account created via web UI
  - [ ] Frontend secured (signup disabled)
  - [ ] Connection details saved to `connection-details.txt`

**Time**: ~15-20 minutes

### Option B: Manual Step-by-Step

- [ ] Deploy infrastructure: `cd terraform && terraform init && terraform apply && cd ..`
- [ ] Deploy frontend: `./deploy-frontend.sh`
- [ ] Get URL: `cd terraform && terraform output frontend_url && cd ..`
- [ ] Create admin account via web UI
- [ ] Secure frontend: `./setup-frontend-auth.sh`
- [ ] Save connection details manually

**Time**: ~15-20 minutes

## 🚀 Launch & Validation

- [ ] Launch frontend: `./launch-frontend.sh --all`
  - [ ] Status check passed
  - [ ] Connectivity test passed
  - [ ] Frontend opens in browser
  - [ ] Can login with admin account

## 🔌 LLM Connection Setup

### Get Connection Details

- [ ] API Key retrieved: `cat connection-details.txt | grep "API Key"`
- [ ] Backend URL retrieved: `cat connection-details.txt | grep "Backend API URL"`
- [ ] Frontend URL retrieved: `cat connection-details.txt | grep "Frontend URL"`

### Set Environment Variables

```bash
export OPENAI_API_KEY='<your-api-key>'
export OPENAI_API_BASE='<your-backend-url>'
```

- [ ] Environment variables set
- [ ] Variables persist in shell

### Optional: Create .env File

```bash
cat > .env << EOF
OPENAI_API_KEY=<your-api-key>
OPENAI_API_BASE=<your-backend-url>
DEFAULT_MODEL=mixtral-8x7b
EOF
```

- [ ] .env file created
- [ ] .env file in .gitignore

## 🧪 Test LLM Connections

### Backend Health Check

```bash
curl https://<your-app>.azurewebsites.net/api/v1/health
```

- [ ] Health endpoint returns `{"status": "healthy"}`

### List Models

```bash
curl https://<your-app>.azurewebsites.net/api/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

- [ ] Returns list of 3 models (mixtral-8x7b, llama-3-70b, phi-3-mini)

### Test Chat Completion (cURL)

```bash
curl -X POST https://<your-app>.azurewebsites.net/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

- [ ] Returns chat completion response

### Test Python Example

```bash
pip install openai
python3 examples/python-openai-sdk.py
```

- [ ] All Python examples run successfully

### Test cURL Examples

```bash
./examples/curl-examples.sh
```

- [ ] All cURL examples run successfully

## 📚 Documentation Review

- [ ] Read [FRONTEND-COMMANDS.md](FRONTEND-COMMANDS.md) - Command reference
- [ ] Read [docs/LLM-CONNECTION-GUIDE.md](docs/LLM-CONNECTION-GUIDE.md) - API guide
- [ ] Read [docs/frontend-usage.md](docs/frontend-usage.md) - Web UI guide
- [ ] Read [examples/README.md](examples/README.md) - Integration examples

## 🔒 Security Checklist

- [ ] Admin account created with strong password
- [ ] Public signup disabled (`ENABLE_SIGNUP=false`)
- [ ] API key stored securely (not committed to git)
- [ ] Key Vault access properly configured
- [ ] HTTPS enforced for all connections

## 💰 Cost Optimization

- [ ] Frontend scales to zero when idle
- [ ] Backend functions scale based on demand
- [ ] Appropriate models selected for tasks
- [ ] Token limits set reasonably
- [ ] Azure budget alerts configured

## 🔧 Troubleshooting

If any step fails, check:

### Infrastructure Issues

```bash
cd terraform
terraform plan  # Check for errors
terraform output  # Verify outputs
cd ..
```

### Frontend Issues

```bash
az containerapp logs show \
  --name <app-name> \
  --resource-group <rg-name> \
  --tail 100
```

### Backend Issues

```bash
az functionapp log tail \
  --name <function-app-name> \
  --resource-group <rg-name>
```

### Connection Issues

```bash
# Test frontend
curl -I https://<frontend-url>

# Test backend health
curl https://<backend-url>/api/v1/health

# Verify API key
echo $OPENAI_API_KEY
```

## 📊 Monitoring Setup

- [ ] Azure Portal dashboard configured
- [ ] Log Analytics workspace reviewed
- [ ] Cost analysis reviewed
- [ ] Alerts configured for:
  - [ ] High cost threshold
  - [ ] Error rate
  - [ ] Response time

## 🎯 Next Steps

After completing this checklist:

1. **Integrate with Your Application**
   - Use Python examples as templates
   - Implement error handling
   - Add retry logic
   - Monitor token usage

2. **Optimize Performance**
   - Review cache hit rates
   - Adjust model selection
   - Fine-tune parameters
   - Scale resources as needed

3. **Enhance Security**
   - Rotate API keys regularly
   - Review access logs
   - Implement rate limiting
   - Add custom authentication

4. **Deploy Backend** (if not done yet)
   ```bash
   ./deploy.sh
   ```

## 📝 Resources

### Scripts
- `./setup-frontend-complete.sh` - Complete automated setup
- `./launch-frontend.sh` - Launch and test frontend
- `./deploy-frontend.sh` - Deploy frontend container
- `./setup-frontend-auth.sh` - Secure frontend
- `./deploy.sh` - Deploy backend

### Documentation
- `FRONTEND-COMMANDS.md` - All commands
- `docs/LLM-CONNECTION-GUIDE.md` - Complete API reference
- `docs/frontend-usage.md` - Web UI guide
- `examples/README.md` - Integration patterns

### Examples
- `examples/python-openai-sdk.py` - Python examples
- `examples/curl-examples.sh` - cURL examples

### Configuration Files
- `connection-details.txt` - Auto-generated connection info
- `.env` - Environment variables (create manually)
- `terraform/outputs.tf` - Infrastructure outputs

## ✨ Success Criteria

You've successfully completed the setup when:

✅ Frontend is accessible and secured  
✅ Admin account created and can login  
✅ Backend API responds to health checks  
✅ Models endpoint returns available models  
✅ Chat completion works via cURL  
✅ Python examples run successfully  
✅ Connection details saved and accessible  
✅ Environment variables configured  

## 🎉 Congratulations!

Your AI Inference Platform is now fully set up and ready to use!

**Frontend URL**: Check `connection-details.txt`  
**Backend API**: Check `connection-details.txt`  
**API Key**: Check `connection-details.txt`

Start integrating the LLM API into your applications using the examples provided!

---

**Questions or Issues?**

1. Review troubleshooting section above
2. Check logs: `az containerapp logs show --name <app> --resource-group <rg>`
3. Review documentation in `docs/` directory
4. Test with examples in `examples/` directory

---

**Last Updated**: 2024-01-17
