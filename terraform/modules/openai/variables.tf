variable "resource_name" {
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

variable "deployment_name" {
  type = string
}

variable "model_name" {
  type = string
}

variable "model_version" {
  type = string
}

variable "sku_capacity" {
  type = number
}

variable "pe_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  type = string
}
