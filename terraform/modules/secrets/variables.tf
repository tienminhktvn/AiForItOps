variable "keyvault_id" {
  type        = string
  description = "Nên truyền output keyvault.id_ready_for_secrets (đã depends_on role assignment) chứ không phải keyvault.id thường"
}

variable "cosmosdb_connection_string" {
  type      = string
  sensitive = true
}

variable "servicebus_connection_string" {
  type      = string
  sensitive = true
}

variable "openai_endpoint" {
  type = string
}

variable "openai_key" {
  type      = string
  sensitive = true
}

variable "openai_deployment_name" {
  type = string
}
