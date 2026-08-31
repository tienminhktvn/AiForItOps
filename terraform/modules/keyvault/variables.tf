variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "tenant_id" {
  type = string
}

variable "terraform_caller_object_id" {
  type        = string
  description = "object_id của danh tính đang chạy terraform apply (user local hoặc service principal pipeline) - bắt buộc để ghi được secret"
}

variable "principal_id" {
  type        = string
  description = "Tùy chọn: object_id của 1 user khác cần cấp quyền Key Vault Secrets Officer"
  default     = ""
}

variable "aks_identity_principal_id" {
  type        = string
  description = "principal_id của managed identity AKS - được cấp Key Vault Secrets User để CSI driver đọc secret"
}
