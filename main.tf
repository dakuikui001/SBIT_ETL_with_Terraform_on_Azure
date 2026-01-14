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
    key                  = "terraform.tfstate"
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

# 🌟 必须改为 resource，确保删掉后能重建
resource "azurerm_application_insights" "ai_bmp" {
  name                = "SBIT-bmp-azure-function"
  location            = "southeastasia"
  resource_group_name = "data_engineering"
  application_type    = "web"
}

resource "azurerm_application_insights" "ai_user" {
  name                = "SBIT-user-info-azure-function"
  location            = "southeastasia"
  resource_group_name = "data_engineering"
  application_type    = "web"
}

resource "azurerm_application_insights" "ai_workout" {
  name                = "SBIT-workout-azure-function"
  location            = "southeastasia"
  resource_group_name = "data_engineering"
  application_type    = "web"
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

# --- 2. 局部变量 ---
locals {
  common_app_settings = {
    "AzureWebJobsFeatureFlags"      = "EnableWorkerIndexing"
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "FUNCTIONS_EXTENSION_VERSION"    = "~4"
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
    # 移除 AzureWebJobsSecretStorageType = "files" 以避免挂载失败
    "AzureWebJobsStorage"            = azurerm_storage_account.existing_storage.primary_connection_string
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.existing_storage.primary_connection_string
    
    # Kafka 与 Storage 业务变量
    "KafkaConnString"            = "pkc-921jm.us-east-2.aws.confluent.cloud:9092"
    "KafkaPassword"              = "cflttFmb380V3TiQCvtXPmKEWoLkUDBoZn2ZUsdrpoAWV9ynKNUvtD+iExYLFHMQ"
    "KafkaUsername"              = "GGJPHA2CIM2YFWVA"
    "STORAGE_ACCOUNT_CONNECTION" = azurerm_storage_account.existing_storage.primary_connection_string
    "STORAGE_ACCOUNT_KEY"        = azurerm_storage_account.existing_storage.primary_access_key
    "STORAGE_ACCOUNT_NAME"       = "dataprojectsforhuilu"
  }
}

# --- 3. Function Apps ---

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
}