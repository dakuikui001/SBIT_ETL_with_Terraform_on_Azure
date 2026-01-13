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
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {} 
}

resource "azurerm_resource_group" "existing_dev" {

  name     = "data_engineering"
  location = "southeastasia"
}

resource "azurerm_storage_account" "existing_storage" {
  name                     = "dataprojectsforhuilu"
  resource_group_name      = "data_engineering"
  location                 = "southeastasia"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # 必须添加下面这两行来匹配云端现状
  is_hns_enabled           = true 
  nfsv3_enabled            = false # 默认通常为 false，但写上更稳
  
  # 还有 plan 中提到的其他差异也可以补上
  public_network_access_enabled = true
}

resource "azurerm_databricks_workspace" "existing_dbx" {
  name                = "databricks_projects"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  sku                 = "premium"
  
  # 加上这一行
  public_network_access_enabled = true
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
}


# --- Function 1: BMP ---
resource "azurerm_service_plan" "plan_bmp" {
  name                = "ASP-dataengineering-aaa1"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func_bmp" {
  name                       = "SBIT-bmp-azure-function"
  resource_group_name        = "data_engineering"
  location                   = "southeastasia"
  service_plan_id            = azurerm_service_plan.plan_bmp.id
  storage_account_name       = azurerm_storage_account.existing_storage.name
  storage_account_access_key = azurerm_storage_account.existing_storage.primary_access_key

  # 补全环境变量，防止 Kafka 链接和密钥被删
  app_settings = {
    "AzureWebJobsSecretStorageType" = "files"
    "KafkaConnString"               = "pkc-921jm.us-east-2.aws.confluent.cloud:9092"
    "KafkaPassword"                 = "cflttFmb380V3TiQCvtXPmKEWoLkUDBoZn2ZUsdrpoAWV9ynKNUvtD+iExYLFHMQ"
    "KafkaUsername"                 = "GGJPHA2CIM2YFWVA"
    "STORAGE_ACCOUNT_CONNECTION"    = "DefaultEndpointsProtocol=https;AccountName=dataprojectsforhuilu;AccountKey=${azurerm_storage_account.existing_storage.primary_access_key};EndpointSuffix=core.windows.net"
    "STORAGE_ACCOUNT_KEY"           = azurerm_storage_account.existing_storage.primary_access_key
    "STORAGE_ACCOUNT_NAME"          = "dataprojectsforhuilu"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    ftps_state = "FtpsOnly" # 保持云端默认的安全设置
  }
}

# --- Function 2: User Info ---
resource "azurerm_service_plan" "plan_user_info" {
  name                = "ASP-dataengineering-9d2d"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func_user_info" {
  name                       = "SBIT-user-info-azure-function"
  resource_group_name        = "data_engineering"
  location                   = "southeastasia"
  service_plan_id            = azurerm_service_plan.plan_user_info.id
  storage_account_name       = azurerm_storage_account.existing_storage.name
  storage_account_access_key = azurerm_storage_account.existing_storage.primary_access_key

  app_settings = {
    "AzureWebJobsSecretStorageType" = "files"
    "KafkaConnString"               = "pkc-921jm.us-east-2.aws.confluent.cloud:9092"
    "KafkaPassword"                 = "cflttFmb380V3TiQCvtXPmKEWoLkUDBoZn2ZUsdrpoAWV9ynKNUvtD+iExYLFHMQ"
    "KafkaUsername"                 = "GGJPHA2CIM2YFWVA"
    "STORAGE_ACCOUNT_CONNECTION"    = "DefaultEndpointsProtocol=https;AccountName=dataprojectsforhuilu;AccountKey=${azurerm_storage_account.existing_storage.primary_access_key};EndpointSuffix=core.windows.net"
    "STORAGE_ACCOUNT_KEY"           = azurerm_storage_account.existing_storage.primary_access_key
    "STORAGE_ACCOUNT_NAME"          = "dataprojectsforhuilu"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    ftps_state = "FtpsOnly"
  }
}

# --- Function 3: Workout ---
resource "azurerm_service_plan" "plan_workout" {
  name                = "ASP-dataengineering-a71e"
  resource_group_name = "data_engineering"
  location            = "southeastasia"
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func_workout" {
  name                       = "SBIT-workout-azure-function"
  resource_group_name        = "data_engineering"
  location                   = "southeastasia"
  service_plan_id            = azurerm_service_plan.plan_workout.id
  storage_account_name       = azurerm_storage_account.existing_storage.name
  storage_account_access_key = azurerm_storage_account.existing_storage.primary_access_key

  app_settings = {
    "AzureWebJobsSecretStorageType" = "files"
    "KafkaConnString"               = "pkc-921jm.us-east-2.aws.confluent.cloud:9092"
    "KafkaPassword"                 = "cflttFmb380V3TiQCvtXPmKEWoLkUDBoZn2ZUsdrpoAWV9ynKNUvtD+iExYLFHMQ"
    "KafkaUsername"                 = "GGJPHA2CIM2YFWVA"
    "STORAGE_ACCOUNT_CONNECTION"    = "DefaultEndpointsProtocol=https;AccountName=dataprojectsforhuilu;AccountKey=${azurerm_storage_account.existing_storage.primary_access_key};EndpointSuffix=core.windows.net"
    "STORAGE_ACCOUNT_KEY"           = azurerm_storage_account.existing_storage.primary_access_key
    "STORAGE_ACCOUNT_NAME"          = "dataprojectsforhuilu"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    ftps_state = "FtpsOnly"
  }
}