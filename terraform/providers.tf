terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state trên Azure Storage (Phase 2.5 trong lộ trình học).
  # Không đặt giá trị trực tiếp ở đây vì backend block không cho phép dùng variable.
  # Tạo trước 1 Storage Account + Container (xem terraform/README.md), sau đó chạy:
  #   terraform init -backend-config="backend.hcl"
  # (copy backend.hcl.example -> backend.hcl và điền tên storage account thật của bạn,
  #  backend.hcl đã được .gitignore vì có thể chứa thông tin riêng của bạn)
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      # Cho phép `terraform destroy` xóa cả khi RG còn sót resource ngoài ý muốn
      # (hữu ích khi bạn đang học và hay phải destroy/apply lại nhiều lần).
      prevent_deletion_if_contains_resources = false
    }
  }
}
