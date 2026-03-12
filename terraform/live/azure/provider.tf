# # Configure the Azure Provider
# terraform {
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 3.0"
#     }
#   }
# }

# provider "azurerm" {
#   features {}
# }

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100" 
    }
  }
}

provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion     = true
      # 필요한 경우, 데이터 디스크 삭제 옵션도 추가
      # delete_data_disks_on_deletion = true 
    }
  }
}