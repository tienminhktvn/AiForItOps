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

variable "aks_identity_principal_id" {
  type        = string
  description = "principal_id của managed identity AKS - được cấp role AcrPull để pull image"
}
