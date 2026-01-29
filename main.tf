terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117.1"
    }
  }

  # --- 远程状态存储配置 ---
  backend "azurerm" {
    resource_group_name  = "data_engineering_001"
    storage_account_name = "tfstatehuilu001"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  # 新账号信息
  subscription_id = "537b908d-4bec-4202-ba63-8e6564154525"
  tenant_id       = "e95910d1-062c-4288-9af6-33419337cea1"
}

# --- 1. 基础资源 ---
resource "azurerm_resource_group" "existing_dev" {
  name     = "data_engineering_001"
  location = "southeastasia"
}

resource "azurerm_log_analytics_workspace" "existing_law" {
  name                = "la-data-engineering"
  location            = azurerm_resource_group.existing_dev.location
  resource_group_name = azurerm_resource_group.existing_dev.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# --- 2. 存储资源 (业务数据存储) ---
resource "azurerm_storage_account" "existing_storage" {
  name                          = "dataprojectsforhuilu001" # 确保新账号下唯一
  resource_group_name           = azurerm_resource_group.existing_dev.name
  location                      = azurerm_resource_group.existing_dev.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  is_hns_enabled                = true 
  nfsv3_enabled                 = false
  public_network_access_enabled = true
}

# --- 3. 核心大数据组件 ---
resource "azurerm_databricks_workspace" "existing_dbx" {
  name                = "databricks_projects"
  resource_group_name = azurerm_resource_group.existing_dev.name
  location            = azurerm_resource_group.existing_dev.location
  sku                 = "premium"

  lifecycle {
    prevent_destroy = true 
  }
}

resource "azurerm_data_factory" "existing_adf" {
  name                = "sbitdatafactoryhuilu001"
  resource_group_name = azurerm_resource_group.existing_dev.name
  location            = azurerm_resource_group.existing_dev.location

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
