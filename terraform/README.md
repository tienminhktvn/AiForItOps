# Terraform — AIforITOps (bản Free-tier / Azure for Students)

Bản Terraform này mô tả lại đúng kiến trúc của [infra/](../infra) (bản Bicep gốc),
điều chỉnh cho phù hợp với subscription free-tier/Student: 1 node pool AKS duy nhất,
AKS control plane tier "Free", CosmosDB free tier, Service Bus Basic, model OpenAI
`gpt-5-mini`. Xem giải thích từng bước ở [../LO-TRINH-HOC-AZURE-TERRAFORM.md](../LO-TRINH-HOC-AZURE-TERRAFORM.md).

## Cấu trúc

Root module (`main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`) chỉ đứng ra
**gọi** các child module trong `modules/` và nối output module này thành input
module kia — không tự tạo resource nghiệp vụ nào ngoài `azurerm_resource_group`
và `random_string.suffix`. Mỗi module map 1-1 với 1 module Bicep gốc:

| Module (`modules/…`) | Tạo resource gì | Tương đương Bicep |
|---|---|---|
| `network/` | VNet, 2 subnet (AKS, Private Endpoint), Private DNS Zone cho OpenAI | — (mở rộng thêm, bản Bicep gốc dùng network mặc định) |
| `identity/` | User-assigned Managed Identity dùng chung cho AKS + role tự cấp cho chính nó | `core/identity.bicep` |
| `acr/` | Azure Container Registry + role AcrPull cho AKS | `core/acr.bicep` |
| `keyvault/` | Key Vault (RBAC mode) + role assignment cho AKS/user/terraform caller | `core/keyvault.bicep` |
| `aks/` | AKS cluster (1 node pool, OIDC + Workload Identity, CNI Overlay) | `core/aks.bicep` |
| `cosmosdb/` | CosmosDB account (free tier) + database + 2 container | `core/cosmosdb.bicep` |
| `servicebus/` | Service Bus namespace (Basic) + 1 queue | `core/servicebus.bicep` |
| `openai/` | Azure OpenAI (private, không public network) + deployment + private endpoint | `core/openai.bicep` |
| `secrets/` | 5 secret (Cosmos, ServiceBus, OpenAI endpoint/key/deployment) ghi vào Key Vault | `core/keyvault-secrets.bicep` |

Ở root:

| File | Vai trò |
|---|---|
| `providers.tf` | Khai báo provider `azurerm`/`random`/`time`, backend remote state |
| `variables.tf` | Toàn bộ input, đồng bộ với [../scripts/env.conf](../scripts/env.conf) |
| `main.tf` | Resource Group + `random_string` suffix + gọi 9 module trên, truyền output module này làm input module kia |
| `outputs.tf` | Gom output từ các module lại (tương đương `main.bicep` outputs) |
| `pipelines/azure-pipelines.yml` | Pipeline Azure DevOps: Validate → Plan → Apply (có approval) |

**Thứ tự phụ thuộc giữa các module** (Terraform tự suy ra qua tham chiếu output,
không cần khai báo tay): `network` và `identity` chạy trước tiên (độc lập) → `acr`,
`keyvault`, `openai` cần output của `identity`/`network` → `aks` cần cả `identity`
lẫn `network` → `secrets` cần output của `keyvault`, `cosmosdb`, `servicebus`, `openai`
(chạy sau cùng). Xem sơ đồ chi tiết ở [GIAI-THICH-CU-PHAP-VA-KIEN-TRUC.md](GIAI-THICH-CU-PHAP-VA-KIEN-TRUC.md).

## Chạy ở local (Phase 3 trong lộ trình)

```bash
cp terraform.tfvars.example terraform.tfvars
# sửa principal_id = kết quả của: az ad signed-in-user show --query id -o tsv

# Lần đầu chưa có remote backend, có thể init tạm với state local:
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Dọn dẹp khi học xong (tránh tốn credit free-tier):

```bash
terraform destroy -var-file=terraform.tfvars
```

## Chuyển sang remote state (Phase 2.5 / trước khi dùng pipeline)

```bash
az group create -n rg-tfstate -l japaneast
az storage account create -g rg-tfstate -n <TEN_STORAGE_UNIQUE> --sku Standard_LRS
az storage container create --account-name <TEN_STORAGE_UNIQUE> -n tfstate

cp backend.hcl.example backend.hcl   # rồi điền TEN_STORAGE_UNIQUE thật
terraform init -backend-config="backend.hcl" -migrate-state
```

## Dùng với Azure DevOps (Phase 4)

1. Tạo Service Connection "Azure Resource Manager" (nên dùng Workload Identity federation).
2. Tạo Environment `aiforitops-prod` trong Pipelines → Environments, thêm check "Approvals".
3. Sửa 4 biến `serviceConnection`/`backend*` đầu file [pipelines/azure-pipelines.yml](pipelines/azure-pipelines.yml).
4. Tạo pipeline trỏ vào file này. PR sẽ tự chạy Validate + Plan; merge vào `main` sẽ dừng ở Apply chờ bạn Approve.

## Lưu ý chi phí (Azure for Students / free-tier)

- AKS control plane: `sku_tier = "Free"` — không tính phí control plane, chỉ tính phí node VM.
- CosmosDB: `free_tier_enabled = true` — 1000 RU/s + 25GB miễn phí trọn đời. **Chỉ 1 account/subscription** được bật flag này (kiểm tra `az cosmosdb list --query "[?enableFreeTier]"` nếu tạo lỗi do đã dùng hết).
- Service Bus: dùng SKU `Basic` (rẻ hơn `Standard`, đủ dùng vì chỉ có 1 queue, không cần topic/session).
- OpenAI: `sku.capacity = 1` (1000 TPM) để không vượt quota mặc định của subscription Student. Nếu gặp lỗi `InsufficientQuota` dù quota còn trống, kiểm tra `az cognitiveservices account list-deleted` — resource cũ bị soft-delete vẫn giữ chỗ quota `OpenAI.S0.AccountCount`, cần `az cognitiveservices account purge` để giải phóng.
- Sau mỗi buổi lab, chạy `terraform destroy` hoặc ít nhất `az aks stop -g <rg> -n <aks_name>` để ngừng tính phí node.
