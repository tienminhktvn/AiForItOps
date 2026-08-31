variable "account_name" {
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

variable "database_name" {
  type = string
}

variable "products_container_name" {
  type = string
}

variable "orders_container_name" {
  type = string
}

variable "free_tier_enabled" {
  type        = bool
  description = "CHỈ 1 account free-tier được phép mỗi subscription."
}

variable "shared_throughput" {
  type = number
}
