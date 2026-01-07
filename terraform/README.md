# A100 GPU VMSS Terraform Configuration

This Terraform configuration provisions Azure infrastructure for A100 GPU-based AI inference with the following features:

## Features

✅ **A100 GPU Support**: 8x NVIDIA A100 40GB GPUs per instance (Standard_ND96asr_v4)  
✅ **$0 Idle Cost**: Scales to 0 instances when not in use  
✅ **Fast Spin-up**: Pre-configured GPU images with CUDA and drivers  
✅ **Auto-scaling**: CPU-based autoscaling (scale up > 70%, scale down < 30%)  
✅ **Cost Optimized**: Spot instances with up to 90% discount  
✅ **Idempotent**: Safe to run multiple times  
✅ **Load Balanced**: Azure Load Balancer with health probes  
✅ **Secure**: Managed identity + Key Vault for secrets  

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Azure Load Balancer                     │
│                  (Public IP + Health Probes)                 │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
┌───────▼──────┐ ┌──────▼──────┐ ┌─────▼───────┐
│   VM 0-7     │ │   VM 0-7    │ │   VM 0-7    │
│ 8x A100 GPUs │ │ 8x A100 GPUs│ │ 8x A100 GPUs│
│ Inference    │ │ Inference   │ │ Inference   │
│ Service      │ │ Service     │ │ Service     │
└──────────────┘ └─────────────┘ └─────────────┘
     (Spot Priority - Deallocate on eviction)
              Auto-scales 0-8 instances
```

## VM SKU Details

**Standard_ND96asr_v4**
- **GPUs**: 8x NVIDIA A100 40GB (total 320GB VRAM)
- **CPU**: 96 vCPUs (AMD EPYC 7V12)
- **RAM**: 900 GB
- **Network**: 8x 200 Gbps Mellanox HDR InfiniBand
- **Storage**: Premium SSD
- **Spot Price**: ~$3-5/hour per instance (vs ~$30/hour on-demand)

Alternative: **Standard_ND96amsr_A100_v4** (8x A100 80GB, 1900 GB RAM)

## Prerequisites

1. **Azure CLI**: Authenticated and with contributor access
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. **Terraform**: Version >= 1.5.0
   ```bash
   terraform version
   ```

3. **Quota**: ND-series v4 quota in your region
   ```bash
   # Check current quota
   az vm list-usage --location eastus -o table | grep "ND"
   
   # Request quota increase if needed (via Azure Portal)
   ```

## Quick Start

```bash
# 1. Initialize Terraform
terraform init

# 2. Review the plan
terraform plan

# 3. Deploy infrastructure
terraform apply

# 4. View outputs
terraform output

# 5. Test the deployment
curl http://$(terraform output -raw load_balancer_public_ip)/health
```

## Configuration

### Variables

Create a `terraform.tfvars` file:

```hcl
project_name     = "ai-inference"
environment      = "prod"
location         = "eastus"

# A100 GPU configuration
vmss_sku         = "Standard_ND96asr_v4"  # 8x A100 40GB
vmss_min_instances = 0                     # Scale to 0 for $0 idle cost
vmss_max_instances = 8                     # Max 8 instances (64 GPUs total)

# Spot pricing
vmss_spot_max_price = -1                   # -1 = pay up to on-demand price

# Notifications
admin_email = "admin@example.com"
```

### Alternative A100 SKU (80GB)

For larger models requiring more VRAM:

```hcl
vmss_sku = "Standard_ND96amsr_A100_v4"  # 8x A100 80GB (640GB total)
```

## Autoscaling

The configuration includes two autoscaling profiles:

### 1. Default Profile (Workload-based)
- **Scale OUT**: When CPU > 70% for 5 minutes → Add 1 instance
- **Scale IN**: When CPU < 30% for 10 minutes → Remove 1 instance
- **Cooldown**: 1-5 minutes between scaling actions

### 2. Off-Hours Profile (Schedule-based)
- **When**: Weekends (Saturday & Sunday)
- **Action**: Scale to 0 instances
- **Result**: $0 cost during off-hours

### Manual Scaling

Override autoscaling when needed:

```bash
# Scale to specific number of instances
az vmss scale \
  --name ai-inference-gpu \
  --resource-group ai-inference-prod-rg \
  --new-capacity 4

# Scale to 0 (idle)
az vmss scale \
  --name ai-inference-gpu \
  --resource-group ai-inference-prod-rg \
  --new-capacity 0
```

## Cost Analysis

### Spot Pricing (90% discount)
| Configuration | Idle Cost | Active (1 instance) | Active (8 instances) |
|--------------|-----------|-------------------|---------------------|
| Min=0, Spot  | **$0/mo** | ~$3-5/hour        | ~$24-40/hour       |
| Min=1, Spot  | ~$2,200/mo| ~$3-5/hour        | ~$24-40/hour       |

### On-Demand Pricing (Full price)
| Configuration | Idle Cost | Active (1 instance) | Active (8 instances) |
|--------------|-----------|-------------------|---------------------|
| Min=0        | **$0/mo** | ~$30/hour         | ~$240/hour         |

**Recommendation**: Use Spot + Scale to 0 for maximum savings

## Deployment

### Idempotent Deployment

This configuration is idempotent - safe to run multiple times:

```bash
# First deployment
terraform apply

# Update configuration
vim terraform.tfvars

# Re-apply (only changes applied)
terraform apply

# No changes? No problem
terraform apply  # Shows "No changes"
```

### Backend Configuration

For production, use remote state:

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate<unique>"
    container_name       = "tfstate"
    key                  = "ai-inference-a100.tfstate"
  }
}
```

Then initialize:

```bash
terraform init -backend-config="backend.tfvars"
```

## Accessing Instances

### SSH Access

```bash
# 1. Get SSH private key from Key Vault
az keyvault secret show \
  --vault-name $(terraform output -raw key_vault_name) \
  --name vmss-ssh-private-key \
  --query value -o tsv > ~/.ssh/vmss_key.pem

chmod 600 ~/.ssh/vmss_key.pem

# 2. Get instance IP
az vmss list-instance-connection-info \
  --name $(terraform output -raw vmss_name) \
  --resource-group $(terraform output -raw resource_group_name)

# 3. SSH to instance
ssh -i ~/.ssh/vmss_key.pem azureuser@<instance-ip>
```

### View GPU Status

```bash
# Once connected via SSH
nvidia-smi

# Check inference service
systemctl status inference.service

# View logs
tail -f /var/log/gpu-setup.log
```

## Monitoring

### View Current Scale

```bash
az vmss show \
  --name $(terraform output -raw vmss_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query sku.capacity
```

### Autoscale Settings

```bash
az monitor autoscale show \
  --name ai-inference-gpu-vmss-autoscale \
  --resource-group $(terraform output -raw resource_group_name)
```

### Autoscale History

```bash
az monitor autoscale list \
  --resource-group $(terraform output -raw resource_group_name)
```

### Metrics

```bash
# View CPU metrics
az monitor metrics list \
  --resource $(terraform output -raw vmss_id) \
  --metric "Percentage CPU" \
  --interval PT1M

# View scaling events
az monitor activity-log list \
  --resource-group $(terraform output -raw resource_group_name) \
  --max-events 50
```

## Testing

### Health Check

```bash
# Get load balancer IP
LB_IP=$(terraform output -raw load_balancer_public_ip)

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

### Inference Test

```bash
curl -X POST http://$LB_IP/inference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Explain quantum computing",
    "max_tokens": 100
  }'
```

## Troubleshooting

### Issue: Quota Exceeded

**Error**: `QuotaExceeded: Operation could not be completed as it results in exceeding quota`

**Solution**: Request quota increase for ND-series v4 VMs
1. Go to Azure Portal → Subscriptions → Usage + quotas
2. Search for "Standard NDASv4 Family vCPUs"
3. Request increase (typically need 96 vCPUs per instance)

### Issue: Spot Capacity Not Available

**Error**: `AllocationFailed: Allocation failed due to Spot capacity constraints`

**Solution**:
1. Try different region: `location = "westus2"` (better A100 availability)
2. Use on-demand instead of spot: `priority = "Regular"` in vmss.tf
3. Lower max bid price: `vmss_spot_max_price = 10.0`

### Issue: Instances Not Scaling

**Check**:
```bash
# View autoscale settings
az monitor autoscale show \
  --name ai-inference-gpu-vmss-autoscale \
  --resource-group $(terraform output -raw resource_group_name)

# Check CPU metrics
az monitor metrics list \
  --resource $(terraform output -raw vmss_id) \
  --metric "Percentage CPU"

# Force scale
az vmss scale \
  --name $(terraform output -raw vmss_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --new-capacity 1
```

### Issue: GPU Drivers Not Loaded

**SSH to instance and check**:
```bash
# Check driver status
nvidia-smi

# View setup log
tail -100 /var/log/gpu-setup.log

# Check inference service
systemctl status inference.service
```

## Cleanup

### Destroy All Resources

```bash
# Preview what will be deleted
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm with: yes
```

### Destroy Specific Resource

```bash
# Example: Remove autoscaling but keep VMSS
terraform state rm azurerm_monitor_autoscale_setting.vmss
terraform apply
```

## Security Considerations

✅ **Managed Identity**: No credentials stored in VMs  
✅ **Key Vault**: All secrets stored securely  
✅ **Network Security**: NSG restricts inbound traffic  
✅ **Spot VMs**: Automatically deallocated (not deleted) on eviction  
✅ **RBAC**: Minimal permissions for VMSS identity  

## Performance Optimization

### Fast Spin-up

Current spin-up time: ~3-5 minutes (OS boot + GPU setup)

**Optimization Options**:

1. **Custom Image** (Recommended)
   - Pre-install NVIDIA drivers and CUDA
   - Pre-load ML models
   - Reduces spin-up to ~30 seconds
   ```hcl
   source_image_id = "/subscriptions/.../images/a100-inference-v1"
   ```

2. **Managed Image Gallery**
   - Share images across regions
   - Version control for images

3. **Container-based Inference**
   - Pre-built Docker images with models
   - Even faster startup (~10 seconds)

## Support

For issues or questions:
- Azure Support: https://azure.microsoft.com/support/
- Terraform Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- NVIDIA Docs: https://docs.nvidia.com/cuda/

## License

This configuration is provided as-is under the MIT license.
