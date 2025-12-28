# =============================================================================
# AI Inference Arbitrage Platform - Terraform Configuration
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  backend "azurerm" {
    # Configure in backend.tfvars or via CLI
    # storage_account_name = "tfstate..."
    # container_name       = "tfstate"
    # key                  = "ai-inference.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# =============================================================================
# RANDOM SUFFIXES
# =============================================================================

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  name_suffix = random_string.suffix.result
  
  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    cost_center = "ai-inference"
  }
  
  # Resource names
  resource_group_name    = "${var.project_name}-${var.environment}-rg"
  key_vault_name         = "${var.project_name}-kv-${local.name_suffix}"
  storage_account_name   = "${replace(var.project_name, "-", "")}st${local.name_suffix}"
  cosmos_account_name    = "${var.project_name}-cosmos-${local.name_suffix}"
  function_app_name      = "${var.project_name}-func-${local.name_suffix}"
  app_insights_name      = "${var.project_name}-insights"
  log_analytics_name     = "${var.project_name}-logs"
  apim_name              = "${var.project_name}-apim"
  vnet_name              = "${var.project_name}-vnet"
  vmss_name              = "${var.project_name}-gpu"
}