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
  description = "VM SKU for GPU instances"
  type        = string
  default     = "Standard_NC4as_T4_v3"
}

variable "vmss_spot_max_price" {
  description = "Maximum price for spot instances (-1 for on-demand price)"
  type        = number
  default     = 0.15
}

variable "vmss_min_instances" {
  description = "Minimum VMSS instances"
  type        = number
  default     = 0
}

variable "vmss_max_instances" {
  description = "Maximum VMSS instances"
  type        = number
  default     = 20
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