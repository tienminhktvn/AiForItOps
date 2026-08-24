variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
  default     = "rg-aiops-workshop"
}

variable "location" {
  type        = string
  description = "Azure region for deployment"
  default     = "eastus"
}