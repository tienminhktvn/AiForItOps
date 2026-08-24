# Lộ trình học Azure qua Lab: Manual → Terraform → Azure DevOps CI/CD

> Dành cho người mới bắt đầu học Azure, học theo hướng "lab trước, lý thuyết sau", muốn dùng **Terraform** thay vì Bicep cho project [AIforITOps](./README.md).

---

## 0. Trả lời thẳng câu hỏi của bạn

> "Nên lao đầu vô Terraform + Azure DevOps pipeline luôn, hay nên tự tay làm step-by-step rồi mới tích hợp?"

**Làm tay trước → Terraform → Pipeline.** Theo đúng thứ tự đó, đừng đảo.

Lý do:

- **Terraform chỉ là công cụ mô tả lại thứ bạn đã hiểu.** Nếu bạn chưa từng tự tay tạo một AKS cluster, một Key Vault, một Managed Identity qua Portal/CLI, thì khi đọc file `.tf` bạn sẽ không biết mình đang đọc cái gì — chỉ đang copy-paste HCL mà không hiểu resource đó dùng để làm gì, vì sao nó cần liên kết với resource khác.
- **Debug Terraform khó hơn debug thao tác tay rất nhiều.** Khi `terraform apply` báo lỗi RBAC hoặc lỗi dependency, nếu bạn không có hình dung "bình thường làm tay thì bước này cần cái gì trước", bạn sẽ không biết lỗi đó là do sai cú pháp Terraform hay do bạn thiếu hiểu biết về Azure.
- **Pipeline (Azure DevOps) là lớp tự động hóa trên cùng.** Nó chỉ có ý nghĩa khi bạn đã tin tưởng vào Terraform code của mình (đã `plan`/`apply` thành công nhiều lần bằng tay ở local). Nhảy thẳng vào pipeline khi Terraform còn chưa chạy ổn ở local sẽ khiến bạn vừa phải debug Terraform vừa phải debug YAML pipeline cùng lúc — rất dễ nản.

Thứ tự đề xuất cụ thể: **Portal/CLI thủ công → Terraform chạy local (`plan`/`apply` bằng tay) → Terraform + remote state → Azure DevOps pipeline tự động hóa**.

---

## 1. Đánh giá độ khó của project này (quan trọng, đọc trước khi bắt đầu)

Kiến trúc của AIforITOps khá "nặng" so với một người mới học Azure hoàn toàn:

| Resource trong project | Bicep module | Độ khó khi mới học |
|---|---|---|
| Resource Group | `main.bicep` | Dễ |
| Managed Identity | [identity.bicep](infra/core/identity.bicep) | Dễ–Trung bình |
| Azure Container Registry (ACR) | [acr.bicep](infra/core/acr.bicep) | Trung bình |
| Azure Kubernetes Service (AKS) | [aks.bicep](infra/core/aks.bicep) | **Khó** (networking, node pools, RBAC, workload identity) |
| Cosmos DB | [cosmosdb.bicep](infra/core/cosmosdb.bicep) | Trung bình |
| Service Bus | [servicebus.bicep](infra/core/servicebus.bicep) | Trung bình |
| Key Vault (+ RBAC + CSI driver trong AKS) | [keyvault.bicep](infra/core/keyvault.bicep), [keyvault-secrets.bicep](infra/core/keyvault-secrets.bicep) | Trung bình–Khó |
| Azure OpenAI | [openai.bicep](infra/core/openai.bicep) | Trung bình (cần quota/region riêng) |

**Khuyến nghị:** đừng cố "Terraform hóa" toàn bộ project này ngay từ lab đầu tiên. Nó có AKS + Key Vault CSI + Workload Identity — đây là combo thuộc dạng khó nhất trong toàn bộ Azure IaC, kể cả với người có kinh nghiệm. Hãy đi qua Phase 0–2 bên dưới bằng các **lab mini độc lập, đơn giản hơn**, rồi mới quay lại "dịch" project thật ở Phase 3.

Bạn đã có sẵn khung `terraform/` (providers.tf, variables.tf, main.tf, identity.tf, network.tf, compute.tf, ai_services.tf) — cứ giữ nguyên, chúng ta sẽ điền dần vào đó ở Phase 3.

---

## 2. Lộ trình tổng quan

| Phase | Nội dung | Thời lượng gợi ý | Mục tiêu đạt được |
|---|---|---|---|
| 0 | Nền tảng Azure (account, Portal, CLI, RBAC, RG, region) | 2–3 buổi | Biết điều hướng Portal, dùng `az` cơ bản |
| 1 | Dựng tay từng resource của project (Portal + `az cli`) | 1–2 tuần | Hiểu vì sao mỗi resource tồn tại và liên kết ra sao |
| 2 | Học Terraform cơ bản bằng lab **độc lập** (không đụng vào project) | 3–5 buổi | Hiểu HCL, provider, state, plan/apply/destroy |
| 3 | Dịch từng module Bicep → Terraform cho chính project này | 1–2 tuần | Có bộ `.tf` chạy được `terraform apply` ra đúng kiến trúc |
| 4 | Azure DevOps Pipeline (CI/CD cho Terraform) | 3–5 buổi | Pipeline tự `plan` khi PR, tự `apply` khi merge |
| 5 | Nâng cao (workspaces, module hóa, security scan, deploy app lên AKS qua pipeline) | Tùy chọn | Vận hành gần với production |

---

## Phase 0 — Nền tảng Azure

Mục tiêu: biết "định vị" trong Azure trước khi gõ bất kỳ dòng code nào.

### Lab 0.1 — Setup
1. Tạo tài khoản Azure Free Trial (nếu chưa có): https://aka.ms/azure-free-account
2. Cài `az` CLI, `kubectl`, `terraform`, `git` (project này đã liệt kê ở [README Prerequisites](README.md#prerequisites)).
3. `az login`, sau đó chạy:
   ```bash
   az account show
   az account list --output table
   ```
4. Hiểu 3 khái niệm: **Tenant** (Azure AD/Entra ID), **Subscription** (đơn vị billing), **Resource Group** (đơn vị gom nhóm resource theo vòng đời).

### Lab 0.2 — Resource Group bằng tay
```bash
az group create --name rg-lab-hoctap --location japaneast
az group list --output table
az group delete --name rg-lab-hoctap --yes --no-wait
```
Làm cả hai cách: qua Portal (Create a resource group) và qua CLI, để so sánh.

### Lab 0.3 — Đọc song song Workshop có sẵn
Project đã có sẵn 5 bài lý thuyết ngắn rất phù hợp làm nền — đọc xen kẽ trong lúc làm Phase 0–1:
- [Workshop/1-Identity.md](Workshop/1-Identity.md)
- [Workshop/2-Networking.md](Workshop/2-Networking.md)
- [Workshop/3-Monitoring.md](Workshop/3-Monitoring.md)
- [Workshop/4-Governance.md](Workshop/4-Governance.md)
- [Workshop/5-CostManagement.md](Workshop/5-CostManagement.md)

> Đúng tinh thần "lab trước lý thuyết sau" của bạn: làm Lab 0.1–0.2 trước, đọc các bài trên sau khi đã sờ tay vào Portal rồi thì sẽ dễ ngấm hơn.

**Checklist Phase 0:** biết tạo/xóa resource group, phân biệt được Tenant/Subscription/RG, hiểu region là gì và vì sao OpenAI trong project này lại deploy ở region khác (`westus`) so với các resource còn lại (`main.bicep` dòng 13).

---

## Phase 1 — Dựng tay từng resource (KHÔNG dùng azd, KHÔNG dùng Terraform)

Mục tiêu: tự tay trải qua đúng những gì `main.bicep` làm hộ bạn, để sau này đọc Terraform mới biết mình đang mô tả lại cái gì. Làm resource nào, hiểu resource đó, rồi **xóa luôn** (dùng `az group delete`) để tránh phát sinh phí trước khi qua resource tiếp theo — trừ các bước có phụ thuộc lẫn nhau thì giữ lại trong 1 resource group tạm.

Gợi ý tạo 1 resource group riêng cho cả Phase 1: `rg-lab-manual`.

### Lab 1.1 — Managed Identity
```bash
az group create -n rg-lab-manual -l japaneast
az identity create -g rg-lab-manual -n id-lab --location japaneast
az identity show -g rg-lab-manual -n id-lab --query principalId -o tsv
```
So sánh với [identity.bicep](infra/core/identity.bicep). Hiểu: vì sao AKS cần 1 identity riêng thay vì dùng tài khoản cá nhân của bạn.

### Lab 1.2 — Azure Container Registry (ACR)
```bash
az acr create -g rg-lab-manual -n acrlab$RANDOM --sku Basic
```
So sánh với [acr.bicep](infra/core/acr.bicep) — chú ý phần gán role `AcrPull` cho managed identity (`principalId` param). Đây là ví dụ đầu tiên về **RBAC giữa 2 resource** — rất quan trọng để hiểu trước khi học Terraform.

### Lab 1.3 — Key Vault + RBAC
```bash
az keyvault create -g rg-lab-manual -n kvlab$RANDOM --enable-rbac-authorization true
```
Thử gán quyền `Key Vault Secrets Officer` cho chính bạn qua `az role assignment create`, rồi thử `az keyvault secret set`. So sánh [keyvault.bicep](infra/core/keyvault.bicep).

### Lab 1.4 — Cosmos DB
```bash
az cosmosdb create -g rg-lab-manual -n cosmoslab$RANDOM --kind GlobalDocumentDB
```
Tạo 1 database + 1 container bằng tay (`az cosmosdb sql database create`, `az cosmosdb sql container create`). So sánh [cosmosdb.bicep](infra/core/cosmosdb.bicep) — chú ý `productsContainerName` và `ordersContainerName`, mỗi container có partition key khác nhau, đọc kỹ vì sao.

### Lab 1.5 — Service Bus
```bash
az servicebus namespace create -g rg-lab-manual -n sblab$RANDOM --sku Basic
az servicebus queue create -g rg-lab-manual --namespace-name sblab$RANDOM -n productsqueue
```
So sánh [servicebus.bicep](infra/core/servicebus.bicep).

### Lab 1.6 — Azure OpenAI (cần approved access + quota)
```bash
az cognitiveservices account create -g rg-lab-manual -n oailab$RANDOM \
  --kind OpenAI --sku S0 --location japaneast
```
Nếu subscription chưa có quyền OpenAI, đọc kỹ phần Prerequisites/Quota trong [README.md](README.md) và [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — đây là điểm nghẽn phổ biến nhất khi lab.

### Lab 1.7 — AKS (khó nhất, để cuối, và **xóa ngay sau khi xong** vì rất tốn phí)
```bash
az aks create -g rg-lab-manual -n akslab \
  --node-count 2 --enable-managed-identity \
  --assign-identity <id của Lab 1.1> \
  --generate-ssh-keys
az aks get-credentials -g rg-lab-manual -n akslab
kubectl get nodes
az aks delete -g rg-lab-manual -n akslab --yes --no-wait
```
So sánh [aks.bicep](infra/core/aks.bicep) — chú ý `systemNodeCount` vs `userNodeCount` (2 node pool riêng biệt), và `managedIdentityId` được truyền vào từ Lab 1.1.

### Lab 1.8 — Kết nối các resource lại với nhau
Đây là phần quan trọng nhất của Phase 1: tự tay set 1 secret Cosmos DB connection string vào Key Vault, gán RBAC cho AKS identity đọc được Key Vault đó (đúng như [keyvault-secrets.bicep](infra/core/keyvault-secrets.bicep) làm). Mục tiêu: hiểu **luồng dữ liệu bí mật** (Cosmos → Key Vault → AKS pod qua CSI driver, xem [k8s/keyvault-cosmosdb-spc.yaml](k8s/keyvault-cosmosdb-spc.yaml)) trước khi mô tả nó bằng Terraform.

Sau đó dọn dẹp: `az group delete -n rg-lab-manual --yes`.

**Checklist Phase 1:** bạn có thể vẽ lại trên giấy sơ đồ 7 resource này và giải thích bằng lời vì sao mỗi mũi tên (dependency) tồn tại — không cần nhìn code.

---

## Phase 2 — Học Terraform bằng lab độc lập (chưa đụng vào project)

Mục tiêu: học cú pháp và tư duy Terraform trên ví dụ nhỏ, KHÔNG mang theo độ phức tạp của AKS/OpenAI.

### Lab 2.1 — Terraform "Hello World"
Tạo 1 folder riêng (ví dụ `~/tf-lab`, tách biệt khỏi `terraform/` của project), thử:
```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
  }
}
provider "azurerm" { features {} }

resource "azurerm_resource_group" "rg" {
  name     = "rg-tf-lab"
  location = "japaneast"
}
```
```bash
terraform init
terraform plan
terraform apply
terraform destroy
```
Hiểu rõ 4 lệnh này trước khi đi tiếp — đây là toàn bộ vòng đời Terraform.

### Lab 2.2 — State file
Sau `apply`, mở file `terraform.tfstate` bằng text editor. Hiểu: Terraform không "hỏi" Azure mỗi lần, nó tin vào state file. Thử sửa tay resource group đó trên Portal (đổi tag), rồi `terraform plan` lại → thấy Terraform phát hiện "drift".

### Lab 2.3 — Variables, outputs, so sánh với `main.parameters.json` của Bicep
```hcl
variable "location" {
  default = "japaneast"
}
output "rg_id" {
  value = azurerm_resource_group.rg.id
}
```
So sánh tư duy này với cách Bicep dùng `param` và `output` trong [main.bicep](infra/main.bicep) — Terraform và Bicep giải quyết cùng vấn đề, khác cú pháp.

### Lab 2.4 — Một resource có dependency (giống RBAC ở Lab 1.2)
Tạo `azurerm_user_assigned_identity` + `azurerm_role_assignment` gán quyền lên 1 storage account, để cảm nhận cách Terraform tự suy ra thứ tự tạo resource qua tham chiếu (implicit dependency), khác với cách bạn phải tự chạy tay từng lệnh CLI theo đúng thứ tự ở Phase 1.

### Lab 2.5 — Remote backend (state lưu trên Azure Storage thay vì local)
```bash
az group create -n rg-tfstate -l japaneast
az storage account create -g rg-tfstate -n tfstatelab$RANDOM --sku Standard_LRS
az storage container create --account-name <tên account> -n tfstate
```
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "<tên account>"
    container_name        = "tfstate"
    key                    = "lab.tfstate"
  }
}
```
Đây là bước bắt buộc phải hiểu trước khi làm CI/CD ở Phase 4 (pipeline không có local state, phải dùng remote backend).

**Checklist Phase 2:** hiểu init/plan/apply/destroy, hiểu state là gì và vì sao cần remote backend, hiểu resource reference tạo implicit dependency.

---

## Phase 3 — Dịch project thật: Bicep → Terraform

Giờ mới quay lại folder [terraform/](terraform/) đã có sẵn trong project. Làm **từng resource một, theo đúng thứ tự Phase 1**, apply thử, kiểm tra trên Portal khớp với bản Bicep, rồi mới sang resource kế tiếp.

Gợi ý cấu trúc file (đã có sẵn khung, chỉ cần điền dần):

| File có sẵn | Điền nội dung tương ứng | Bicep gốc |
|---|---|---|
| [terraform/providers.tf](terraform/providers.tf) | provider `azurerm`, `random` | — |
| [terraform/variables.tf](terraform/variables.tf) | các biến giống `main.bicep` param | main.bicep dòng 1–74 |
| [terraform/main.tf](terraform/main.tf) | resource group + random suffix (đã có) | main.bicep dòng 86–90 |
| [terraform/identity.tf](terraform/identity.tf) | `azurerm_user_assigned_identity` | identity.bicep |
| — (tạo mới `acr.tf`) | `azurerm_container_registry` + role assignment `AcrPull` | acr.bicep |
| [terraform/compute.tf](terraform/compute.tf) | `azurerm_kubernetes_cluster` (system + user node pool) | aks.bicep |
| — (tạo mới `data.tf` hoặc gộp vào từng file) | `azurerm_cosmosdb_account` + sql database + 2 container | cosmosdb.bicep |
| — (tạo mới `messaging.tf`) | `azurerm_servicebus_namespace` + queue | servicebus.bicep |
| — (tạo mới `keyvault.tf`) | `azurerm_key_vault` (RBAC mode) + secrets | keyvault.bicep, keyvault-secrets.bicep |
| [terraform/ai_services.tf](terraform/ai_services.tf) | `azurerm_cognitive_account` (kind = OpenAI) + deployment | openai.bicep |
| [terraform/network.tf](terraform/network.tf) | (nếu muốn custom VNet cho AKS thay vì default) | — (project hiện dùng network mặc định của AKS) |

Nguyên tắc khi dịch:
1. Mở file `.bicep` gốc, liệt kê param → output.
2. Viết `.tf` tương ứng, dùng đúng tên biến tiếng Anh giống Bicep để dễ đối chiếu (bạn đang viết comment tiếng Việt trong `main.tf`, vậy cứ giữ style đó, không sao).
3. `terraform plan` sau MỖI resource thêm vào — đừng viết hết 8 resource rồi mới plan lần đầu, sẽ rất khó debug.
4. Dùng `azd` bản Bicep hiện có làm "đáp án" — deploy thử bằng azd trước (đọc [AZD-SETUP.md](AZD-SETUP.md)), so sánh resource được tạo ra trên Portal với resource Terraform của bạn tạo ra, để tự chấm điểm.

**Checklist Phase 3:** `terraform apply` từ folder `terraform/` tạo ra đầy đủ 7 resource, các bí mật (connection string, OpenAI key) nằm đúng trong Key Vault, AKS identity có quyền đọc Key Vault.

---

## Phase 4 — Azure DevOps Pipeline

Chỉ bắt đầu phase này khi Terraform ở Phase 3 đã `apply` thành công ổn định nhiều lần bằng tay.

### Lab 4.1 — Setup Azure DevOps
1. Tạo tổ chức + project tại https://dev.azure.com.
2. Push code (repo này hoặc 1 fork riêng cho terraform) lên Azure Repos hoặc kết nối GitHub repo.

### Lab 4.2 — Service Connection
Tạo Service Connection kiểu "Azure Resource Manager", dùng **Workload Identity federation (OIDC)** nếu có thể (an toàn hơn service principal + secret truyền thống). Đây tương đương với việc bạn tự `az login` khi làm tay ở Phase 1–3, giờ pipeline cần "login" thay bạn.

### Lab 4.3 — Pipeline YAML tối thiểu: chỉ `plan`
Tạo `azure-pipelines.yml`:
```yaml
trigger:
  branches: { include: [ main ] }
pr:
  branches: { include: [ main ] }

pool:
  vmImage: ubuntu-latest

steps:
  - task: TerraformInstaller@1
    inputs:
      terraformVersion: 'latest'
  - task: TerraformTaskV4@4
    inputs:
      provider: 'azurerm'
      command: 'init'
      backendServiceArm: '<tên service connection>'
      backendAzureRmResourceGroupName: 'rg-tfstate'
      backendAzureRmStorageAccountName: '<storage từ Lab 2.5>'
      backendAzureRmContainerName: 'tfstate'
      backendAzureRmKey: 'project.tfstate'
  - task: TerraformTaskV4@4
    inputs:
      provider: 'azurerm'
      command: 'plan'
      environmentServiceNameAzureRM: '<tên service connection>'
```
Chạy pipeline với 1 PR test, chỉ xem `plan` output trong log — **chưa cho apply**.

### Lab 4.4 — Thêm stage `apply` có approval
Tách thành 2 stage: `Plan` (chạy trên mọi PR) và `Apply` (chỉ chạy khi merge vào `main`, và gắn 1 **Environment** trong Azure DevOps có "Approvals and checks" — bắt buộc bạn tự bấm Approve trước khi apply chạy thật). Đây là thói quen production quan trọng: không bao giờ để pipeline tự `apply` vào hạ tầng thật mà không có người duyệt.

### Lab 4.5 — Biến nhạy cảm
Dùng **Variable Group** liên kết với Key Vault (Library → Variable groups → Link secrets from an Azure Key Vault) thay vì hard-code secret trong YAML.

**Checklist Phase 4:** mở PR → pipeline tự chạy `terraform plan` và hiện log; merge vào `main` → pipeline dừng ở bước approval; bấm Approve → `terraform apply` chạy, hạ tầng thật được cập nhật.

---

## Phase 5 — Nâng cao (làm khi đã vững Phase 0–4)

- **Terraform modules**: tách mỗi resource (`acr`, `aks`, `cosmosdb`...) thành module riêng trong `terraform/modules/`, gọi lại từ `main.tf` — giống cách `main.bicep` gọi các file trong `infra/core/`.
- **Nhiều môi trường (dev/staging/prod)**: dùng `terraform workspace` hoặc tách `.tfvars` riêng từng env, kết hợp Azure DevOps Environments.
- **Security scan trong pipeline**: thêm bước `tfsec` hoặc `checkov` scan trước khi cho `plan`.
- **CD ứng dụng lên AKS**: sau khi hạ tầng ổn, thêm stage build image → push ACR → `kubectl apply` các manifest có sẵn trong [k8s/](k8s/) (project đã có sẵn deployment/service YAML cho AdminSite, StoreFront, ProductWorker).
- **Cost & Governance**: áp dụng lại nội dung [Workshop/5-CostManagement.md](Workshop/5-CostManagement.md) và [Workshop/4-Governance.md](Workshop/4-Governance.md) lên hạ tầng Terraform của bạn (budget alert, policy).

---

## Bảng tự kiểm tra tổng (dùng để biết mình đang ở đâu)

- [ ] Phase 0: tự tạo/xóa resource group bằng cả Portal và CLI
- [ ] Phase 1: tự tay dựng đủ 7 resource + nối chúng lại (Key Vault ↔ AKS RBAC) rồi xóa sạch
- [ ] Phase 2: hiểu init/plan/apply/destroy, state, remote backend trên 1 project Terraform nhỏ tách biệt
- [ ] Phase 3: `terraform apply` folder `terraform/` của project ra đúng kiến trúc như bản Bicep
- [ ] Phase 4: pipeline Azure DevOps tự `plan` trên PR, `apply` sau approval trên `main`
- [ ] Phase 5 (tùy chọn): module hóa, multi-env, security scan, CD app lên AKS

---

## Tài liệu tham khảo

- Microsoft Learn — [Terraform on Azure](https://learn.microsoft.com/azure/developer/terraform/)
- Terraform Registry — [azurerm provider docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- Microsoft Learn path — [AZ-104 fundamentals](https://learn.microsoft.com/training/paths/az-104-administrator-prerequisites/) (đọc song song, không cần học hết trước khi lab)
- [AZD-SETUP.md](AZD-SETUP.md) và [PS-SETUP.md](PS-SETUP.md) trong repo này — "đáp án" để đối chiếu khi bạn tự dựng bằng Terraform
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — các lỗi quota/region thường gặp, đặc biệt với AKS và OpenAI
