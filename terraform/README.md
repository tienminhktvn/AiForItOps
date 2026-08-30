# Terraform — AIforITOps (bản Free-tier / Azure for Students)

Bản Terraform này mô tả lại đúng kiến trúc của [infra/](../infra) (bản Bicep gốc),
điều chỉnh cho phù hợp với subscription free-tier/Student: 1 node pool AKS duy nhất,
AKS control plane tier "Free", CosmosDB free tier, Service Bus Basic, model OpenAI
`gpt-5-mini`. Xem giải thích từng bước ở [../LO-TRINH-HOC-AZURE-TERRAFORM.md](../LO-TRINH-HOC-AZURE-TERRAFORM.md).

## Cấu trúc file (map 1-1 với module Bicep)

| File | Tạo resource gì | Tương đương Bicep |
|---|---|---|
| `providers.tf` | Khai báo provider `azurerm`/`random`, backend remote state | — |
| `variables.tf` | Toàn bộ input, đồng bộ với [../scripts/env.conf](../scripts/env.conf) | `main.bicep` params |
| `main.tf` | Resource Group + suffix random cho tên unique | `main.bicep` |
| `network.tf` | VNet, 2 subnet (AKS, Private Endpoint), Private DNS Zone cho OpenAI | — (mở rộng thêm, bản Bicep gốc dùng network mặc định) |
| `identity.tf` | User-assigned Managed Identity dùng chung cho AKS | `core/identity.bicep` |
| `acr.tf` | Azure Container Registry + role AcrPull cho AKS | `core/acr.bicep` |
| `compute.tf` | AKS cluster (1 node pool, OIDC + Workload Identity, CNI Overlay) | `core/aks.bicep` |
| `cosmosdb.tf` | CosmosDB account (free tier) + database + 2 container | `core/cosmosdb.bicep` |
| `servicebus.tf` | Service Bus namespace (Basic) + 1 queue | `core/servicebus.bicep` |
| `keyvault.tf` | Key Vault (RBAC mode) + role assignment cho AKS/user/terraform caller | `core/keyvault.bicep` |
| `keyvault-secrets.tf` | 5 secret (Cosmos, ServiceBus, OpenAI endpoint/key/deployment) | `core/keyvault-secrets.bicep` |
| `ai_services.tf` | Azure OpenAI (private, không public network) + deployment + private endpoint | `core/openai.bicep` |
| `outputs.tf` | Output tương đương `main.bicep` outputs | `main.bicep` outputs |
| `pipelines/azure-pipelines.yml` | Pipeline Azure DevOps: Validate → Plan → Apply (có approval) | — |

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
- CosmosDB: `enable_free_tier = true` — 1000 RU/s + 25GB miễn phí trọn đời. **Chỉ 1 account/subscription** được bật flag này.
- Service Bus: dùng SKU `Basic` (rẻ hơn `Standard`, đủ dùng vì chỉ có 1 queue, không cần topic/session).
- OpenAI: `scale.capacity = 1` (1000 TPM) để không vượt quota mặc định của subscription Student.
- Sau mỗi buổi lab, chạy `terraform destroy` hoặc ít nhất `az aks stop -g <rg> -n <aks_name>` để ngừng tính phí node.
