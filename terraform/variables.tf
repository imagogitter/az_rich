# =============================================================================
# VARIABLES
# =============================================================================

variable "project_name" {
  description = "Project name (used for resource naming)"
  type        = string
  default     = "ai-inference"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "vmss_sku" {
  description = "VM SKU for GPU instances (A100 GPUs)"
  type        = string
  default     = "Standard_ND96asr_v4"  # 8x NVIDIA A100 40GB GPUs
  
  validation {
    condition     = can(regex("^Standard_ND.*v4$", var.vmss_sku))
    error_message = "VM SKU must be an ND v4 series for A100 GPUs (e.g., Standard_ND96asr_v4)."
  }
}

variable "vmss_spot_max_price" {
  description = "Maximum price for spot instances (-1 for on-demand price). A100 spot pricing varies by region."
  type        = number
  default     = -1  # -1 means pay up to on-demand price
}

variable "vmss_min_instances" {
  description = "Minimum VMSS instances"
  type        = number
  default     = 0
}

variable "vmss_max_instances" {
  description = "Maximum VMSS instances (each with 8x A100 GPUs)"
  type        = number
  default     = 8
  
  validation {
    condition     = var.vmss_max_instances >= 1 && var.vmss_max_instances <= 100
    error_message = "Maximum instances must be between 1 and 100."
  }
}

variable "admin_email" {
  description = "Admin email for APIM and alerts"
  type        = string
  default     = "admin@example.com"
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection (additional cost)"
  type        = bool
  default     = false
}

variable "enable_weekend_scale_to_zero" {
  description = "Enable automatic scale to 0 on weekends (Saturday/Sunday). Disable for 24/7 production workloads."
  type        = bool
  default     = false
}