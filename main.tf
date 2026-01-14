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

# --- 2. 监控资源 ---
resource "azurerm_application_insights" "ai_bmp" {
  name                = "SBIT-bmp-azure-function"
  location            = "southeastasia"
  resource_group_name = "data_engineering"
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.existing_law.id
}

resource "azurerm_application_insights" "ai_user" {
  name                = "SBIT-user-info-azure-function"
  location            = "southeastasia"
  resource_group_name = "data_engineering"
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.existing_law.id
}

resource "azurerm_application_insights" "ai_workout" {
  name                = "SBIT-workout-azure-function"
  location            = "southeastasia"
  resource_group_name = "data_engineering"
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.existing_law.id
}

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

# --- 4. 局部变量 ---
locals {
  common_app_settings = {
    "AzureWebJobsFeatureFlags"      = "EnableWorkerIndexing"
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "FUNCTIONS_EXTENSION_VERSION"    = "~4"
    # 🌟 移除 WEBSITE_RUN_FROM_PACKAGE = "1"，由 GitHub Action 的 az CLI 动态管理
    "AzureWebJobsStorage"            = azurerm_storage_account.existing_storage.primary_connection_string
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.existing_storage.primary_connection_string
    "KafkaConnString"            = "pkc-921jm.us-east-2.aws.confluent.cloud:9092"
    "KafkaPassword"              = "cflttFmb380V3TiQCvtXPmKEWoLkUDBoZn2ZUsdrpoAWV9ynKNUvtD+iExYLFHMQ"
    "KafkaUsername"              = "GGJPHA2CIM2YFWVA"
    "STORAGE_ACCOUNT_CONNECTION" = azurerm_storage_account.existing_storage.primary_connection_string
    "STORAGE_ACCOUNT_KEY"        = azurerm_storage_account.existing_storage.primary_access_key
    "STORAGE_ACCOUNT_NAME"       = "dataprojectsforhuilu"
  }
}

# --- 5. Function Apps ---

# BMP Function
resource "azurerm_service_plan" "plan_bmp" {
  name                = "ASP-dataengineering-aaa1"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func_bmp" {
  name                        = "SBIT-bmp-azure-function"
  resource_group_name         = "data_engineering"
  location                    = "southeastasia"
  service_plan_id             = azurerm_service_plan.plan_bmp.id
  storage_account_name        = azurerm_storage_account.existing_storage.name
  storage_account_access_key  = azurerm_storage_account.existing_storage.primary_access_key

  app_settings = merge(local.common_app_settings, {
    "WEBSITE_CONTENTSHARE"                  = "sbit-bmp-share"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.ai_bmp.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai_bmp.connection_string
  })

  site_config {
    application_stack { python_version = "3.11" }
    ftps_state = "FtpsOnly"
  }

  # 🌟 关键：防止 Terraform 强制重置部署变量
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["WEBSITE_ENABLE_SYNC_UPDATE_SITE"]
    ]
  }
}

# User Info Function
resource "azurerm_service_plan" "plan_user_info" {
  name                = "ASP-dataengineering-9d2d"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func_user_info" {
  name                        = "SBIT-user-info-azure-function"
  resource_group_name         = "data_engineering"
  location                    = "southeastasia"
  service_plan_id             = azurerm_service_plan.plan_user_info.id
  storage_account_name        = azurerm_storage_account.existing_storage.name
  storage_account_access_key  = azurerm_storage_account.existing_storage.primary_access_key

  app_settings = merge(local.common_app_settings, {
    "WEBSITE_CONTENTSHARE"                  = "sbit-user-info-share"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.ai_user.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai_user.connection_string
  })

  site_config {
    application_stack { python_version = "3.11" }
    ftps_state = "FtpsOnly"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["WEBSITE_ENABLE_SYNC_UPDATE_SITE"]
    ]
  }
}

# Workout Function
resource "azurerm_service_plan" "plan_workout" {
  name                = "ASP-dataengineering-a71e"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func_workout" {
  name                        = "SBIT-workout-azure-function"
  resource_group_name         = "data_engineering"
  location                    = "southeastasia"
  service_plan_id             = azurerm_service_plan.plan_workout.id
  storage_account_name        = azurerm_storage_account.existing_storage.name
  storage_account_access_key  = azurerm_storage_account.existing_storage.primary_access_key

  app_settings = merge(local.common_app_settings, {
    "WEBSITE_CONTENTSHARE"                  = "sbit-workout-share"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.ai_workout.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.ai_workout.connection_string
  })

  site_config {
    application_stack { python_version = "3.11" }
    ftps_state = "FtpsOnly"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["WEBSITE_ENABLE_SYNC_UPDATE_SITE"]
    ]
  }
}