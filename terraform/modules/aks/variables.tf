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

variable "sku_tier" {
  type = string
}

variable "node_count" {
  type = number
}

variable "vm_size" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "identity_id" {
  type        = string
  description = "id của user-assigned identity (module identity) - dùng làm cả cluster identity lẫn kubelet identity"
}

variable "identity_client_id" {
  type = string
}

variable "identity_principal_id" {
  type = string
}
