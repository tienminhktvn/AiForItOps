# Toàn bộ default value bên dưới được đồng bộ với scripts/env.conf (bản PowerShell)
# để 2 cách deploy (PowerShell thủ công vs Terraform) tạo ra hạ tầng tương đương.

# ---------- Chung ----------

variable "resource_group_name" {
  type        = string
  description = "Tên resource group"
  default     = "aiforitops-rg"
}

variable "location" {
  type        = string
  description = "Vùng (region) triển khai cho hầu hết resource"
  default     = "japaneast"
}

variable "principal_id" {
  type        = string
  description = "Object ID của user hiện tại, dùng để cấp role Key Vault Secrets Officer. Lấy bằng: az ad signed-in-user show --query id -o tsv"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tag áp dụng cho mọi resource"
  default = {
    project    = "ai-for-itops"
    managed-by = "terraform"
  }
}

# ---------- Azure Container Registry ----------

variable "acr_name" {
  type        = string
  description = "Prefix tên ACR (sẽ được nối thêm suffix random cho unique, ACR chỉ nhận chữ thường/số)"
  default     = "aiforitopsacr"
}

# ---------- AKS ----------
# Lưu ý free-tier / Azure for Students: chỉ dùng 1 node pool duy nhất (không tách
# system/user pool như bản Bicep gốc) để tiết kiệm quota vCPU, và sku_tier = Free
# để không mất phí control plane (~73 USD/tháng nếu để Standard).

variable "aks_name" {
  type        = string
  description = "Tên cụm AKS"
  default     = "aiforitops-aks"
}

variable "aks_vm_size" {
  type        = string
  description = "VM size cho node pool. Standard_D2s_v3 thường nằm trong quota mặc định của subscription Free/Student."
  default     = "Standard_D2s_v3"
}

variable "aks_node_count" {
  type        = number
  description = "Số node trong node pool duy nhất"
  default     = 2
}

variable "aks_sku_tier" {
  type        = string
  description = "Free (mặc định, miễn phí control plane, phù hợp lab) hoặc Standard (có SLA, tính phí)"
  default     = "Free"
}

# ---------- CosmosDB ----------

variable "cosmosdb_account_name" {
  type        = string
  description = "Prefix tên CosmosDB account (nối thêm suffix cho unique)"
  default     = "aiforitops-cosmos"
}

variable "cosmosdb_database_name" {
  type    = string
  default = "productsdb"
}

variable "cosmosdb_products_container_name" {
  type    = string
  default = "productscontainer"
}

variable "cosmosdb_orders_container_name" {
  type    = string
  default = "orderscontainer"
}

variable "cosmosdb_free_tier_enabled" {
  type        = bool
  description = "Bật free tier CosmosDB (1000 RU/s + 25GB miễn phí). CHỈ 1 account free-tier được phép mỗi subscription."
  default     = true
}

variable "cosmosdb_shared_throughput" {
  type        = number
  description = "RU/s dùng chung cho cả database (2 container xài chung), giữ trong hạn mức free tier (1000 RU/s)"
  default     = 800
}

# ---------- Service Bus ----------

variable "servicebus_namespace_name" {
  type        = string
  description = "Prefix tên Service Bus namespace (nối thêm suffix cho unique)"
  default     = "aiforitops-sb"
}

variable "servicebus_queue_name" {
  type    = string
  default = "productsqueue"
}

variable "servicebus_sku" {
  type        = string
  description = "Basic đủ dùng vì project chỉ dùng 1 queue đơn giản (không cần topic/session của Standard) -> rẻ hơn"
  default     = "Basic"
}

# ---------- Key Vault ----------

variable "keyvault_name" {
  type        = string
  description = "Prefix tên Key Vault (nối thêm suffix cho unique, tối đa 24 ký tự)"
  default     = "kv-aiops"
}

# ---------- Azure OpenAI ----------

variable "openai_resource_name" {
  type        = string
  description = "Prefix tên resource Azure OpenAI (nối thêm suffix cho unique)"
  default     = "aiforitops-openai"
}

variable "openai_location" {
  type        = string
  description = "Region riêng cho OpenAI (có thể khác location chính nếu vùng đó chưa có quota/model bạn cần)"
  default     = "japaneast"
}

variable "openai_deployment_name" {
  type    = string
  default = "gpt-5-mini"
}

variable "openai_model_name" {
  type    = string
  default = "gpt-5-mini"
}

variable "openai_model_version" {
  type    = string
  default = "2025-08-07"
}

variable "openai_sku_capacity" {
  type        = number
  description = "Capacity (nghìn TPM) cho deployment, để 1 cho free/student subscription tránh vượt quota"
  default     = 1
}
