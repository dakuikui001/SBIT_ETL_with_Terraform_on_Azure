terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117.1"
    }
  }

  backend "azurerm" {
    resource_group_name  = "data_engineering"
    storage_account_name = "dataprojectsforhuilu"
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {} 
}

# --- 1. 基础资源 ---
resource "azurerm_resource_group" "existing_dev" {
  name     = "data_engineering"
  location = "southeastasia"
}

resource "azurerm_log_analytics_workspace" "existing_law" {
  name                = "la-data-engineering"
  location            = "southeastasia"
  resource_group_name = "data_engineering"
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# --- 2. 存储资源 ---
resource "azurerm_storage_account" "existing_storage" {
  name                          = "dataprojectsforhuilu"
  resource_group_name           = "data_engineering"
  location                      = "southeastasia"
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  is_hns_enabled                = true 
  nfsv3_enabled                 = false
  public_network_access_enabled = true
}

# --- 3. 核心大数据组件 ---
resource "azurerm_databricks_workspace" "existing_dbx" {
  name                = "databricks_projects"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  sku                 = "premium"

  lifecycle {
    prevent_destroy = true 
  }
}

resource "azurerm_data_factory" "existing_adf" {
  name                = "sbtidatafactory"
  resource_group_name = "data_engineering"
  location            = "southeastasia"

  identity {
    type = "SystemAssigned"
  }

  github_configuration {
    account_name    = "dakuikui001" 
    repository_name = "SBIT_ETL_with_Terraform_on_Azure"
    branch_name     = "main"
    root_folder     = "/SBIT_ADF_Code" 
  }

  lifecycle {
    prevent_destroy = true 
  }
}
