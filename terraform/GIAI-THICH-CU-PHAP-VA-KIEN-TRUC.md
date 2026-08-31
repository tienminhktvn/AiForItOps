# Giải thích cú pháp Terraform & Kiến trúc — AIforITOps

> Đọc file này sau khi đã làm xong Phase 2 (Terraform cơ bản) trong [../LO-TRINH-HOC-AZURE-TERRAFORM.md](../LO-TRINH-HOC-AZURE-TERRAFORM.md). Mục tiêu: hiểu **từng dòng cú pháp** đang dùng trong folder `terraform/` này, và hiểu **bức tranh kiến trúc tổng thể**.
>
> Cập nhật: project đã được tách thành **root module** (`main.tf`, `variables.tf`, `outputs.tf`) gọi 9 **child module** trong `modules/` (mỗi module = 1 module Bicep gốc). Các ví dụ dưới đây trích từ NỘI DUNG bên trong child module — khi tham chiếu từ root/module khác, địa chỉ đầy đủ có thêm tiền tố `module.<tên_module>.`, xem mục 1.10.

---

## Phần 1 — Cú pháp HCL (HashiCorp Configuration Language) cơ bản

Terraform dùng ngôn ngữ HCL. Toàn bộ file `.tf` trong project chỉ dùng 6 loại "block" sau:

| Block | Dùng để | Ví dụ trong project |
|---|---|---|
| `terraform { }` | Khai báo version, provider cần dùng, nơi lưu state | [providers.tf](providers.tf) |
| `provider "x" { }` | Cấu hình cách kết nối tới Azure | [providers.tf](providers.tf) |
| `resource "TYPE" "NAME" { }` | **Tạo** 1 resource thật trên Azure | hầu hết các file |
| `data "TYPE" "NAME" { }` | **Đọc** thông tin có sẵn (không tạo mới) | `data.azurerm_client_config.current` |
| `variable "x" { }` | Khai báo input, có thể override lúc chạy | [variables.tf](variables.tf) |
| `output "x" { }` | In ra giá trị sau khi apply xong | [outputs.tf](outputs.tf) |

### 1.1 `resource "TYPE" "NAME"` — cú pháp quan trọng nhất

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
```

- `azurerm_resource_group` — **TYPE**: loại resource, do provider `azurerm` định nghĩa sẵn (không tự đặt tên được). Muốn biết 1 resource type có field gì, tra [Terraform Registry — azurerm docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs).
- `"rg"` — **local name**: tên bạn tự đặt, chỉ dùng để tham chiếu **bên trong code Terraform**, KHÔNG phải tên resource thật trên Azure (tên thật nằm trong field `name = ...`).
- Muốn tham chiếu lại resource này ở file khác, viết `azurerm_resource_group.rg.<field>`, ví dụ `azurerm_resource_group.rg.name`, `azurerm_resource_group.rg.location`, `azurerm_resource_group.rg.id`.

Đây chính là cách các file trong project nối với nhau. Ví dụ trong [modules/acr/main.tf](modules/acr/main.tf) — lưu ý bên trong module này, `azurerm_resource_group.rg` không tồn tại nữa (module không được phép "nhìn" trực tiếp resource của root), thay vào đó nhận qua `var.location`/`var.resource_group_name` do root truyền vào ([main.tf](main.tf)):

```hcl
# modules/acr/main.tf
resource "azurerm_container_registry" "acr" {
  location            = var.location               # <- input do root truyền vào
  resource_group_name = var.resource_group_name    # <- input do root truyền vào
  ...
}
```

```hcl
# main.tf (root) - nơi TRUYỀN giá trị vào 2 var ở trên
module "acr" {
  source               = "./modules/acr"
  location             = azurerm_resource_group.rg.location   # <- tham chiếu resource RG ở root
  resource_group_name  = azurerm_resource_group.rg.name
  ...
}
```

Khi root viết `azurerm_resource_group.rg.location` để truyền vào `module "acr"`, Terraform tự hiểu: **module `acr` phải được apply SAU `rg`** — đây gọi là **implicit dependency** (phụ thuộc ngầm), hoạt động xuyên qua ranh giới module y hệt như giữa 2 resource cùng file. Bạn không cần tự khai báo thứ tự tạo resource, Terraform tự dựng "dependency graph" (xem Phần 3) từ các tham chiếu này.

### 1.2 String interpolation — `"${...}"`

```hcl
name = "${var.acr_name}${random_string.suffix.result}"
```

Bất kỳ chỗ nào có `${ }` bên trong chuỗi `"..."`, Terraform sẽ chạy biểu thức bên trong rồi nối vào chuỗi. Ở đây: lấy giá trị biến `acr_name` (vd "aiforitopsacr") nối với 5 ký tự random (vd "x7k2p") → ra `"aiforitopsacrx7k2p"`. Lý do phải làm vậy: tên ACR/KeyVault/CosmosDB/OpenAI/ServiceBus phải **unique trên toàn Azure**, nếu để tên cố định thì người thứ 2 chạy `terraform apply` với cùng tên sẽ bị lỗi trùng.

### 1.3 `variable` — input có thể thay đổi khi chạy

```hcl
variable "location" {
  type        = string
  description = "Vùng (region) triển khai cho hầu hết resource"
  default     = "japaneast"
}
```

- `type` — kiểu dữ liệu: `string`, `number`, `bool`, `list(string)`, `map(string)`, `object({...})`.
- `default` — giá trị dùng nếu bạn không truyền gì khác. Cách override (theo thứ tự ưu tiên tăng dần):
  1. `default` trong `variable` block (thấp nhất)
  2. file `terraform.tfvars` (tự động đọc nếu tồn tại)
  3. `-var-file=xxx.tfvars` truyền tay
  4. `-var="location=eastus"` truyền tay trên command line (cao nhất)
- Dùng lại ở nơi khác bằng `var.location`.

### 1.4 `data` — đọc thông tin có sẵn, không tạo gì cả

```hcl
data "azurerm_client_config" "current" {}
```

Khác với `resource` (tạo mới), `data` chỉ **đọc**. Ở đây nó đọc thông tin về **danh tính đang chạy `terraform apply`** (chính bạn nếu chạy local, hoặc service principal nếu chạy trong pipeline). Khai báo ở root ([main.tf](main.tf)), vì các `module` không tự gọi được `data` này — phải nhận qua input giống mọi thứ khác:

```hcl
# main.tf (root)
data "azurerm_client_config" "current" {}

module "keyvault" {
  source                      = "./modules/keyvault"
  terraform_caller_object_id = data.azurerm_client_config.current.object_id
  ...
}
```

```hcl
# modules/keyvault/main.tf
resource "azurerm_role_assignment" "terraform_caller_kv_officer" {
  principal_id = var.terraform_caller_object_id
}
```

→ Tự động cấp quyền ghi Key Vault cho **bất kỳ ai/cái gì** đang chạy Terraform, không cần biết trước đó là ai.

### 1.5 `count` — tạo 0 hoặc nhiều resource có điều kiện

```hcl
variable "principal_id" {
  default = ""
}

resource "azurerm_role_assignment" "user_kv_officer" {
  count = var.principal_id != "" ? 1 : 0
  ...
  principal_id = var.principal_id
}
```

`count` nhận 1 số nguyên: 0 = không tạo resource này, N = tạo N bản sao (đánh số `[0]`, `[1]`...). Ở đây dùng kiểu "if": nếu bạn có set `principal_id` thì tạo 1 role assignment, nếu để trống (`""`) thì bỏ qua. Đây là toán tử 3 ngôi quen thuộc: `điều_kiện ? giá_trị_nếu_đúng : giá_trị_nếu_sai`.

### 1.6 `depends_on` — phụ thuộc tường minh (kể cả xuyên qua output của module)

```hcl
# modules/keyvault/outputs.tf
output "id_ready_for_secrets" {
  value      = azurerm_key_vault.kv.id
  depends_on = [azurerm_role_assignment.terraform_caller_kv_officer]
}
```

Bình thường Terraform tự suy ra thứ tự qua tham chiếu (mục 1.1). Nhưng ở đây, việc "ghi được secret" phụ thuộc vào role assignment đã **có hiệu lực thật sự trên Azure AD** (không chỉ là đã gọi API tạo xong) — một quan hệ mà Terraform không tự nhìn thấy qua tham chiếu field thông thường. `depends_on` ép buộc: chờ role assignment xong hẳn rồi mới trả giá trị `id_ready_for_secrets` ra ngoài.

`output` cũng nhận được `depends_on`, không chỉ `resource` — đây chính là mánh dùng để "xuất khẩu" 1 ràng buộc thời gian ra khỏi module: [main.tf](main.tf) gọi `module "secrets"` với `keyvault_id = module.keyvault.id_ready_for_secrets` (**không phải** `module.keyvault.id` thường) → module `secrets` tự động phải đợi role assignment xong, dù bản thân nó không biết gì về role assignment đó tồn tại. Cùng pattern này được dùng ở [modules/identity/outputs.tf](modules/identity/outputs.tf) để ép mọi module dùng đến identity (acr, keyvault, aks) phải đợi role `Managed Identity Operator` lan truyền xong trong Azure AD (~30s, xem `time_sleep` ở mục dưới).

### 1.7 Nested block vs attribute — 2 cách khai báo khác nhau trong CÙNG 1 resource

```hcl
# modules/aks/main.tf
resource "azurerm_kubernetes_cluster" "aks" {
  name     = var.name              # <- ATTRIBUTE: key = value
  sku_tier = var.sku_tier          # <- ATTRIBUTE

  default_node_pool {              # <- NESTED BLOCK: không có dấu =
    name       = "default"
    node_count = var.node_count
  }

  identity {                       # <- NESTED BLOCK khác
    type         = "UserAssigned"
    identity_ids = [var.identity_id]   # <- var.identity_id = module.identity.id truyền từ root
  }
}
```

Cách phân biệt: **attribute** dùng `key = value` (1 giá trị đơn/list/map). **Nested block** là `tên_block { ... }` không có dấu `=`, dùng khi 1 resource có 1 nhóm cấu hình con phức tạp (ví dụ AKS có `default_node_pool`, `identity`, `network_profile`, `key_vault_secrets_provider` — mỗi cái là 1 "cụm" field riêng). Đây là chỗ dễ gõ sai nhất khi mới học — quên dấu `{}` hoặc thêm nhầm dấu `=` sẽ báo lỗi ngay ở `terraform validate`.

### 1.8 `sensitive` — che giá trị nhạy cảm khỏi log/output

Terraform tự động đánh dấu `sensitive = true` cho một số attribute do chính provider `azurerm` quy định (ví dụ `azurerm_servicebus_namespace.default_primary_connection_string`, `azurerm_cognitive_account.primary_access_key`). Khi bạn chạy `terraform plan`, các giá trị này sẽ hiện `(sensitive value)` thay vì in ra thật — nhưng chúng **vẫn được lưu dạng plain text trong file state** (`.tfstate`). Đây là lý do bắt buộc:
- Không bao giờ commit `.tfstate` lên git (đã chặn ở `.gitignore` gốc).
- Dùng remote backend (Azure Storage) để state được mã hoá at-rest và giới hạn quyền truy cập, thay vì nằm trên máy local.

### 1.9 `module` — gói 1 nhóm resource thành khối tái sử dụng được

```hcl
module "identity" {
  source = "./modules/identity"

  resource_group_name = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  tags                 = var.tags
}
```

- `source` — đường dẫn tới thư mục chứa module (ở đây là thư mục local `modules/identity/`; module cũng có thể trỏ tới 1 Git repo hoặc Terraform Registry, nhưng project này chỉ dùng local module).
- Các dòng còn lại (`resource_group_name`, `location`, `tags`) là **giá trị truyền vào các `variable` khai báo bên trong `modules/identity/variables.tf`** — y hệt cách bạn gọi hàm và truyền tham số.
- Muốn lấy giá trị **ra khỏi** module, dùng `output` bên trong module + tham chiếu `module.<tên>.<tên_output>` từ bên ngoài, ví dụ [main.tf](main.tf):
  ```hcl
  module "acr" {
    source                     = "./modules/acr"
    aks_identity_principal_id = module.identity.principal_id   # <- lấy output từ module identity
  }
  ```
- **Ranh giới quan trọng**: code BÊN TRONG 1 module chỉ nhìn thấy `var.*` (input của chính nó) và resource nó tự tạo — KHÔNG nhìn thấy resource của module khác hay của root, dù chúng nằm cùng 1 lần `terraform apply`. Đây là lý do `modules/acr/main.tf` phải nhận `var.aks_identity_principal_id` thay vì tự viết `azurerm_user_assigned_identity.aks_identity.principal_id` như hồi còn là 1 file phẳng.
- **Địa chỉ resource đổi khi vào module**: `azurerm_container_registry.acr` (khi còn ở root) trở thành `module.acr.azurerm_container_registry.acr` trong state — chạy `terraform state list` sẽ thấy tiền tố `module.<tên>.` cho mọi resource nằm trong module.

### 1.10 Tóm tắt vòng đời lệnh

| Lệnh | Làm gì | Có động tới Azure thật không |
|---|---|---|
| `terraform init` | Tải provider, cấu hình backend | Không |
| `terraform validate` | Kiểm tra cú pháp/kiểu dữ liệu | Không |
| `terraform fmt` | Format lại code cho đẹp | Không |
| `terraform plan` | Tính toán sẽ tạo/sửa/xoá gì (so với state) | Chỉ đọc (read-only API calls) |
| `terraform apply` | Thực thi đúng như plan | **Có** — tạo/sửa/xoá resource thật |
| `terraform destroy` | Xoá toàn bộ resource đang quản lý trong state | **Có** — xoá thật |

---

## Phần 2 — Kiến trúc tổng thể

```mermaid
flowchart TB
    subgraph RG["Resource Group: aiforitops-rg (root main.tf)"]
        subgraph VNET["VNet 10.0.0.0/16 (module.network)"]
            SUBAKS["Subnet aks-subnet\n10.0.1.0/24"]
            SUBPE["Subnet pe-subnet\n10.0.2.0/24"]
        end

        ID["User-Assigned Identity\nid-aks-keyvault\n(module.identity)"]

        subgraph AKSC["AKS Cluster (module.aks)"]
            NODE["Node pool 'default'\n2 node Standard_D2s_v3\nCNI Overlay"]
            CSI["Key Vault CSI Driver\n(secret rotation 2m)"]
        end

        ACR["Container Registry\n(module.acr)"]
        KV["Key Vault - RBAC mode\n(module.keyvault)"]
        COSMOS["CosmosDB account\nfree tier, 2 container\n(module.cosmosdb)"]
        SB["Service Bus namespace\nBasic + 1 queue\n(module.servicebus)"]
        OAI["Azure OpenAI\npublic network: OFF\n(module.openai)"]
        PE["Private Endpoint\npe-openai"]
        DNS["Private DNS Zone\nprivatelink.openai.azure.com"]

        NODE -. vnet_subnet_id .-> SUBAKS
        PE -. subnet_id .-> SUBPE
        PE --> DNS
        PE -.-> OAI

        AKSC -- kubelet_identity --> ID
        ID -- role: AcrPull --> ACR
        ID -- role: Key Vault Secrets User --> KV
        CSI -- đọc secret qua CSI --> KV

        KV -- secret: cosmosdb-connectionstring --> COSMOS
        KV -- secret: servicebus-connectionstring --> SB
        KV -- secret: openai-endpoint/key/deployment --> OAI
    end

    YOU["Bạn (terraform apply)\nhoặc Azure DevOps pipeline"]
    YOU -- role: Key Vault Secrets Officer --> KV
    YOU -.provision toàn bộ.-> RG
```

**Đọc sơ đồ này như thế nào:**
- Đường nét liền có nhãn "role: ..." = một `azurerm_role_assignment` (RBAC) — quyền, không phải kết nối mạng.
- Đường nét đứt `-.->` = quan hệ hạ tầng mạng (subnet, private endpoint, DNS).
- 3 mũi tên "secret: ..." từ KV ra Cosmos/ServiceBus/OpenAI thực ra đi **ngược chiều dữ liệu**: Terraform đọc connection string/key từ Cosmos/ServiceBus/OpenAI rồi **ghi vào** Key Vault ([modules/secrets/main.tf](modules/secrets/main.tf)) — vẽ theo chiều "KV chứa thông tin của" cho dễ hình dung.
- Ứng dụng (AdminSite/StoreFront/ProductWorker chạy trong pod AKS, xem [../k8s/](../k8s/)) sẽ đọc secret ngược lại từ KV qua CSI Driver, không tự gọi trực tiếp Cosmos/ServiceBus bằng key hard-code.

---

## Phần 3 — Thứ tự Terraform thực sự tạo resource (dependency graph)

Đây là thứ tự Terraform tự suy ra được từ các tham chiếu (mục 1.1), **không phải thứ tự các file `.tf` hay các `module` block bạn viết** — Terraform đọc TẤT CẢ file `.tf` (kể cả bên trong mọi module) cùng lúc rồi tự dựng graph, thứ tự khai báo không quan trọng. Tên đầy đủ mỗi resource trong graph dưới đây khớp với những gì `terraform state list` in ra.

```mermaid
flowchart LR
    RG["azurerm_resource_group.rg (root)"] --> VNET["module.network.azurerm_virtual_network.vnet"]
    VNET --> SUBAKS["module.network...subnet.aks_subnet"]
    VNET --> SUBPE["module.network...subnet.pe_subnet"]
    RG --> DNS["module.network...private_dns_zone.openai_dns"]
    VNET --> DNSLINK["module.network...vnet_link"]
    DNS --> DNSLINK

    RG --> ID["module.identity...user_assigned_identity.aks_identity"]
    ID --> IDROLE["module.identity...role_assignment.aks_identity_operator"]
    IDROLE --> IDSLEEP["module.identity.time_sleep.wait_for_identity_rbac"]
    RG --> RAND["random_string.suffix (root)"]

    RG --> ACR["module.acr...container_registry.acr"]
    IDSLEEP --> ACRROLE["module.acr...role_assignment.aks_acr_pull"]
    ACR --> ACRROLE

    RG --> KV["module.keyvault.azurerm_key_vault.kv"]
    RAND --> KV
    IDSLEEP --> KVROLE1["module.keyvault...role_assignment.aks_kv_reader"]
    KV --> KVROLE1
    KV --> KVROLE2["module.keyvault...role_assignment.terraform_caller_kv_officer"]

    SUBAKS --> AKS["module.aks.azurerm_kubernetes_cluster.aks"]
    IDSLEEP --> AKS

    RG --> COSMOS["module.cosmosdb...cosmosdb_account.cosmos"]
    RAND --> COSMOS
    COSMOS --> DB["module.cosmosdb...sql_database.db"]
    DB --> C1["module.cosmosdb...sql_container.products"]
    DB --> C2["module.cosmosdb...sql_container.orders"]

    RG --> SB["module.servicebus...servicebus_namespace.sb"]
    RAND --> SB
    SB --> QUEUE["module.servicebus...servicebus_queue.queue"]

    RAND --> OAI["module.openai...cognitive_account.openai"]
    OAI --> DEPLOY["module.openai...cognitive_deployment.openai_model"]
    DEPLOY --> OAISLEEP["module.openai.time_sleep.wait_for_openai"]
    OAISLEEP --> PE["module.openai...private_endpoint.openai_pe"]
    SUBPE --> PE
    DNS --> PE

    COSMOS --> SECRET1["module.secrets...key_vault_secret.cosmosdb_connectionstring"]
    KVROLE2 --> SECRET1
    SB --> SECRET2["module.secrets...key_vault_secret.servicebus_connectionstring"]
    KVROLE2 --> SECRET2
    OAI --> SECRET3["module.secrets...key_vault_secret.openai_endpoint/openai_key"]
    DEPLOY --> SECRET4["module.secrets...key_vault_secret.openai_deployment"]
    KVROLE2 --> SECRET3
    KVROLE2 --> SECRET4
```

**Ý nghĩa thực tế:** khi bạn chạy `terraform apply`, các nhánh KHÔNG phụ thuộc nhau (vd `module.acr`, `module.keyvault`, `module.cosmosdb`, `module.servicebus`, `module.openai` đều chỉ phụ thuộc `RG`) sẽ được Terraform **tạo song song** để nhanh hơn — module hóa KHÔNG làm mất khả năng chạy song song này, vì Terraform vẫn dựng graph ở cấp resource thật bên trong, "module" chỉ là cách tổ chức code chứ không tạo ra 1 lớp hàng đợi tuần tự. Đây là lý do dùng IaC nhanh hơn hẳn so với chạy tuần tự từng lệnh `az cli` bằng tay như ở Phase 1 của lộ trình học.

---

## Phần 4 — Luồng Azure DevOps Pipeline

```mermaid
sequenceDiagram
    participant Dev as Bạn (Pull Request)
    participant ADO as Azure DevOps Pipeline
    participant TFC as Terraform (state trên Azure Storage)
    participant AZ as Azure (API)
    participant Human as Người duyệt (Approver)

    Dev->>ADO: Mở PR vào nhánh main
    ADO->>TFC: terraform init (đọc backend)
    ADO->>ADO: terraform fmt -check, terraform validate
    ADO->>AZ: terraform plan (chỉ đọc, so sánh với state)
    ADO-->>Dev: Hiện kết quả plan trong log PR

    Dev->>ADO: Merge PR vào main
    ADO->>AZ: terraform plan lại, lưu thành artifact "tfplan"
    ADO->>Human: Dừng ở stage Apply, chờ Approval (Environment aiforitops-prod)
    Human-->>ADO: Approve
    ADO->>AZ: terraform apply "tfplan" (đúng plan đã duyệt, không plan lại)
    AZ-->>TFC: Ghi kết quả mới vào state
    ADO-->>Dev: Pipeline hoàn tất
```

Điểm quan trọng: **stage Apply dùng đúng file `tfplan` đã tạo ở stage Plan** (`terraform apply tfplan`, không phải `terraform apply` chay) — đảm bảo những gì người duyệt nhìn thấy lúc Approve chính xác là những gì sẽ được thực thi, không có khoảng trống để hạ tầng đổi khác giữa lúc plan và lúc apply.

---

## Câu hỏi tự kiểm tra (đừng đọc đáp án trước)

1. Nếu ở `main.tf` (root), dòng `location = azurerm_resource_group.rg.location` trong `module "acr"` bị đổi thành `location = "japaneast"` (hard-code), Terraform còn biết phải tạo `rg` trước `module.acr` không? Vì sao?
2. `count = var.principal_id != "" ? 1 : 0` trong `modules/keyvault/main.tf` — nếu `principal_id` có giá trị, muốn tham chiếu resource đó **từ root** (ngoài module) phải viết địa chỉ đầy đủ thế nào?
3. Trong sơ đồ Phần 3, vì sao `module.secrets...key_vault_secret.cosmosdb_connectionstring` phải phụ thuộc cả `COSMOS` lẫn `KVROLE2`, thiếu 1 trong 2 thì `terraform apply` sẽ lỗi ở bước nào?
4. Nếu bạn sửa `modules/aks/main.tf` để nó tự viết thẳng `azurerm_user_assigned_identity.aks_identity.id` thay vì dùng `var.identity_id`, `terraform validate` sẽ báo lỗi gì?

<details>
<summary>Gợi ý đáp án</summary>

1. Vẫn biết — vì `resource_group_name = azurerm_resource_group.rg.name` ở dòng khác trong cùng `module` block vẫn còn tham chiếu, chỉ cần 1 tham chiếu là đủ để Terraform dựng dependency giữa root và module. Nhưng đây là lý do KHÔNG nên hard-code bất kỳ field nào có thể tham chiếu được — mất tham chiếu ở tất cả field mới thực sự mất dependency.
2. `module.keyvault.azurerm_role_assignment.user_kv_officer[0]` — cộng tiền tố `module.keyvault.` vì resource nằm trong module, và vẫn giữ `[0]` vì có `count`.
3. Thiếu `COSMOS` → lỗi vì chưa có connection string để đọc (giá trị chưa tồn tại). Thiếu `KVROLE2` → lỗi 403 Forbidden vì danh tính chạy Terraform chưa có quyền ghi secret vào Key Vault (đây là lý do `main.tf` phải truyền `module.keyvault.id_ready_for_secrets`, không phải `module.keyvault.id`, vào `module "secrets"`).
4. Lỗi "Reference to undeclared resource" — bên trong 1 module chỉ được tham chiếu resource/data do chính module đó khai báo, không được "nhìn xuyên" sang resource của root hay module khác. Đây là ranh giới cố ý của Terraform để module dùng lại được ở nhiều nơi khác nhau mà không phụ thuộc ngầm vào tên resource cụ thể ở nơi gọi nó.

</details>
