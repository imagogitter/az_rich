#!/bin/bash
# =============================================================================
# GPU Instance Initialization Script
# =============================================================================
# This script is executed on each VMSS instance startup to configure
# NVIDIA drivers, CUDA, and the inference service.

set -euo pipefail

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/gpu-setup.log
}

log "Starting GPU setup..."

# Update system packages
log "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Install required packages
log "Installing required packages..."
apt-get install -y -qq \
    build-essential \
    "linux-headers-$(uname -r)" \
    dkms \
    curl \
    wget \
    git \
    python3-pip \
    python3-dev \
    jq

# Install Azure CLI (if not present)
if ! command -v az &> /dev/null; then
    log "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
fi

# Verify NVIDIA GPU is present
log "Checking for NVIDIA GPU..."
if ! lspci | grep -i nvidia &> /dev/null; then
    log "WARNING: No NVIDIA GPU detected!"
else
    log "NVIDIA GPU detected"
    lspci | grep -i nvidia | tee -a /var/log/gpu-setup.log
fi

# Install NVIDIA drivers (if not already installed)
if ! command -v nvidia-smi &> /dev/null; then
    log "Installing NVIDIA drivers..."
    
    # Add NVIDIA package repositories
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb
    dpkg -i cuda-keyring_1.0-1_all.deb
    apt-get update -qq
    
    # Install NVIDIA driver and CUDA toolkit
    apt-get install -y -qq cuda-drivers
    apt-get install -y -qq cuda-toolkit-12-2
    
    # Add CUDA to PATH
    echo 'export PATH=/usr/local/cuda/bin:'"$PATH" >> /etc/profile.d/cuda.sh
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:'"$LD_LIBRARY_PATH" >> /etc/profile.d/cuda.sh
    
    log "NVIDIA drivers installed"
else
    log "NVIDIA drivers already installed"
fi

# Source CUDA environment
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Verify NVIDIA driver installation
if command -v nvidia-smi &> /dev/null; then
    log "NVIDIA driver verification:"
    nvidia-smi | tee -a /var/log/gpu-setup.log
else
    log "WARNING: nvidia-smi not available after installation"
fi

# Install Docker (for containerized inference)
if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker azureuser
    
    # Install NVIDIA Container Toolkit
    log "Installing NVIDIA Container Toolkit..."
    # shellcheck disable=SC1091
    distribution=$(. /etc/os-release; echo "$ID$VERSION_ID")
    curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | apt-key add -
    curl -s -L "https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list" | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update -qq
    apt-get install -y -qq nvidia-container-toolkit
    systemctl restart docker
    
    log "Docker and NVIDIA Container Toolkit installed"
else
    log "Docker already installed"
fi

# Install Python dependencies
log "Installing Python dependencies..."
pip3 install --upgrade pip
pip3 install \
    torch \
    transformers \
    accelerate \
    fastapi \
    uvicorn \
    azure-identity \
    azure-keyvault-secrets

# Get Key Vault name from template parameter
# Note: key_vault_name is provided by Terraform templatefile function
# shellcheck disable=SC2154
KEY_VAULT_NAME="${key_vault_name}"

# Authenticate to Azure using managed identity
log "Authenticating to Azure with managed identity..."
log "Key Vault configured: $KEY_VAULT_NAME"
# Wait for managed identity to be available
sleep 30

# Create inference service directory
log "Setting up inference service..."
mkdir -p /opt/inference
cat > /opt/inference/server.py << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
Simple GPU inference server
"""
import os
import torch
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="GPU Inference Service")

class InferenceRequest(BaseModel):
    prompt: str
    max_tokens: int = 100

@app.get("/health")
async def health():
    """Health check endpoint"""
    gpu_available = torch.cuda.is_available()
    gpu_count = torch.cuda.device_count() if gpu_available else 0
    
    return {
        "status": "healthy",
        "gpu_available": gpu_available,
        "gpu_count": gpu_count,
        "gpu_names": [torch.cuda.get_device_name(i) for i in range(gpu_count)] if gpu_available else []
    }

@app.post("/inference")
async def inference(request: InferenceRequest):
    """Run inference"""
    if not torch.cuda.is_available():
        raise HTTPException(status_code=503, detail="GPU not available")
    
    # Placeholder for actual model inference
    return {
        "result": f"Processed: {request.prompt[:50]}...",
        "tokens": request.max_tokens,
        "gpu_used": torch.cuda.get_device_name(0)
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
PYTHON_EOF

chmod +x /opt/inference/server.py

# Create systemd service for inference
log "Creating systemd service..."
cat > /etc/systemd/system/inference.service << 'SERVICE_EOF'
[Unit]
Description=GPU Inference Service
After=network.target

[Service]
Type=simple
User=azureuser
WorkingDirectory=/opt/inference
ExecStart=/usr/bin/python3 /opt/inference/server.py
Restart=always
RestartSec=10
Environment="CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7"

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable and start the inference service
log "Starting inference service..."
systemctl daemon-reload
systemctl enable inference.service
systemctl start inference.service

log "GPU setup complete!"

# Final verification
log "Final system verification:"
nvidia-smi | tee -a /var/log/gpu-setup.log || log "WARNING: nvidia-smi failed"
systemctl status inference.service --no-pager | tee -a /var/log/gpu-setup.log

log "Setup finished. Check /var/log/gpu-setup.log for details"
