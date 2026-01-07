# Quick Start Guide: A100 GPU Deployment

This guide will help you deploy the A100 GPU infrastructure in under 15 minutes.

## Prerequisites Checklist

- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Terraform >= 1.5.0 installed
- [ ] Azure subscription with contributor access
- [ ] ND-series v4 quota approved (96 vCPUs per instance)
- [ ] Preferred region: eastus, westus2, or southcentralus

## Step-by-Step Deployment

### 1. Check Prerequisites

```bash
# Verify Azure CLI
az account show

# Check current quota (you need 96+ vCPUs for ND-series v4)
az vm list-usage --location eastus -o table | grep "ND"

# Verify Terraform
terraform version
```

### 2. Configure Variables

```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your preferences
vim terraform.tfvars
```

**Key settings:**
```hcl
vmss_min_instances = 0    # Scale to 0 for $0 idle
vmss_max_instances = 8    # Max 8 instances (64 A100 GPUs)
vmss_sku = "Standard_ND96asr_v4"  # 8x A100 40GB
admin_email = "your-email@example.com"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes ~5-10 minutes)
terraform apply

# Save outputs
terraform output > ../deployment-info.txt
```

### 4. Verify Deployment

```bash
# Get load balancer IP
LB_IP=$(terraform output -raw load_balancer_public_ip)

# Wait for first instance to spin up (if min > 0)
# Or manually scale up:
az vmss scale \
  --name $(terraform output -raw vmss_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --new-capacity 1

# Wait ~3-5 minutes for instance to initialize

# Test health endpoint
curl http://$LB_IP/health

# Expected response:
# {
#   "status": "healthy",
#   "gpu_available": true,
#   "gpu_count": 8,
#   "gpu_names": ["NVIDIA A100-SXM4-40GB", ...]
# }
```

### 5. Test Inference

```bash
# Send test request
curl -X POST http://$LB_IP/inference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "What is machine learning?",
    "max_tokens": 100
  }'
```

## Common Issues

### Issue: Quota Exceeded

**Error:** `QuotaExceeded: Operation could not be completed`

**Fix:**
1. Go to Azure Portal → Subscriptions → Usage + quotas
2. Search for "Standard NDASv4 Family vCPUs"
3. Request increase to 96+ vCPUs
4. Wait for approval (usually 1-2 business days)

### Issue: Spot Capacity Not Available

**Error:** `AllocationFailed: Allocation failed due to Spot capacity constraints`

**Fix:**
1. Try different region in `terraform.tfvars`:
   ```hcl
   location = "westus2"  # Better A100 availability
   ```
2. Or use on-demand (more expensive):
   ```hcl
   # In vmss.tf, change:
   priority = "Regular"
   ```

### Issue: Terraform State Locked

**Error:** `Error acquiring the state lock`

**Fix:**
```bash
# If you're sure no other operation is running:
terraform force-unlock <LOCK_ID>
```

## Cost Management

### Minimize Costs

```bash
# Scale to 0 when not in use
az vmss scale \
  --name <vmss-name> \
  --resource-group <rg-name> \
  --new-capacity 0

# Result: $0/hour compute cost
```

### Monitor Costs

```bash
# View current month costs
az consumption usage list \
  --start-date $(date -d "1 month ago" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[?contains(instanceName, 'ai-inference')]"
```

### Set Cost Alerts

1. Go to Azure Portal → Cost Management
2. Create budget alert
3. Set threshold: e.g., $500/month
4. Add email notification

## Scaling Operations

### Manual Scale

```bash
# Scale to N instances
az vmss scale --name <vmss-name> --resource-group <rg-name> --new-capacity N

# Examples:
# - Small workload: 1 instance (8 A100 GPUs)
# - Medium workload: 4 instances (32 A100 GPUs)
# - Full scale: 8 instances (64 A100 GPUs)
```

### View Current Scale

```bash
az vmss show \
  --name <vmss-name> \
  --resource-group <rg-name> \
  --query sku.capacity
```

### Autoscaling Status

```bash
# View autoscale settings
az monitor autoscale show \
  --name <vmss-name>-vmss-autoscale \
  --resource-group <rg-name>

# View scaling history
az monitor activity-log list \
  --resource-group <rg-name> \
  --max-events 20 \
  --query "[?contains(operationName.value, 'Autoscale')]"
```

## Monitoring

### GPU Status

```bash
# Get SSH key
az keyvault secret show \
  --vault-name <key-vault-name> \
  --name vmss-ssh-private-key \
  --query value -o tsv > ~/.ssh/vmss_key.pem
chmod 600 ~/.ssh/vmss_key.pem

# Get instance IP
az vmss list-instance-connection-info \
  --name <vmss-name> \
  --resource-group <rg-name>

# SSH to instance
ssh -i ~/.ssh/vmss_key.pem azureuser@<instance-ip>

# Check GPU status
nvidia-smi

# View setup logs
tail -f /var/log/gpu-setup.log

# Check inference service
systemctl status inference.service
```

### Metrics

```bash
# CPU usage
az monitor metrics list \
  --resource <vmss-id> \
  --metric "Percentage CPU" \
  --interval PT1M

# Network
az monitor metrics list \
  --resource <vmss-id> \
  --metric "Network In Total" \
  --interval PT5M
```

## Cleanup

### Destroy Infrastructure

```bash
cd terraform

# Preview what will be deleted
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type 'yes' to confirm
```

**Cost:** ~$0 after destruction (only minimal storage costs if any)

## Production Checklist

Before going to production:

- [ ] Set up remote Terraform state (Azure Storage)
- [ ] Configure custom domain + SSL certificate
- [ ] Enable DDoS protection (`enable_ddos_protection = true`)
- [ ] Set up Azure Monitor dashboards
- [ ] Configure log analytics workspace
- [ ] Create backup/disaster recovery plan
- [ ] Set up cost alerts and budgets
- [ ] Document runbooks for common operations
- [ ] Test spot eviction handling
- [ ] Configure CI/CD pipeline (GitHub Actions)
- [ ] Set up secrets in GitHub (ARM_CLIENT_ID, etc.)

## Next Steps

1. **Load Models**: SSH to instances and download your AI models
2. **Custom Image**: Create custom VM image with pre-loaded models
3. **API Gateway**: Configure APIM with rate limiting and auth
4. **Monitoring**: Set up Application Insights for inference tracking
5. **Scaling Policy**: Tune autoscaling thresholds for your workload

## Support Resources

- **Azure Docs**: https://learn.microsoft.com/azure/
- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/azurerm/
- **NVIDIA Docs**: https://docs.nvidia.com/cuda/
- **This Repo**: Check `terraform/README.md` for detailed documentation

## Estimated Timings

- Prerequisites check: 5 minutes
- Terraform deployment: 5-10 minutes
- First instance boot: 3-5 minutes
- GPU setup complete: 3-5 minutes
- **Total**: ~15-30 minutes

## Cost Estimates

### Spot Pricing (Recommended)
- **Idle**: $0/month (scaled to 0)
- **1 instance active**: ~$2,160/month (~$3/hour * 720 hours)
- **8 instances active**: ~$17,280/month (~$24/hour * 720 hours)

### On-Demand Pricing
- **1 instance**: ~$21,600/month (~$30/hour * 720 hours)
- **8 instances**: ~$172,800/month (~$240/hour * 720 hours)

**Recommendation**: Use spot + scale to 0 for 95%+ cost savings
