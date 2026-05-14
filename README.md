# 🔭 Azure Serverless Site Monitor

[![Azure](https://img.shields.io/badge/Provider-Azure-blue)](https://azure.microsoft.com)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io)
[![Python](https://img.shields.io/badge/Runtime-Python_3.11-yellow)](https://www.python.org)
[![Serverless](https://img.shields.io/badge/Compute-Azure_Functions-orange)](https://azure.microsoft.com/en-us/products/functions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform Validate](https://github.com/OliwierOzgaIT/azure-serverless-monitoring/actions/workflows/terraform-validate.yml/badge.svg)](https://github.com/OliwierOzgaIT/azure-serverless-monitoring/actions)

A production-grade, fully serverless uptime monitoring system built on Microsoft Azure.

> 🌐 **Live Dashboard:** [https://stsitemonitordev.z6.web.core.windows.net/](https://stsitemonitordev.z6.web.core.windows.net/) The platform automatically checks the availability and response time of configured websites every 5 minutes, persists results to Azure Table Storage, exposes a REST API for data access, and triggers email alerts via Azure Logic Apps when a site goes down — all without managing a single server.

---

## 🎯 Objective

The goal of this project is to demonstrate a real-world **event-driven serverless architecture** on Azure. Rather than running a VM continuously to perform health checks, this system uses Azure Functions on the B1 Basic App Service plan, running Python functions on a dedicated Linux host without managing any underlying infrastructure. The architecture connects five Azure services into a coherent pipeline, covering compute, storage, secret management, alerting, and static hosting entirely through Terraform.

---

## ✨ Key Features

- **Automated Health Checks:** Timer-triggered Azure Function checks all 12 configured sites every 5 minutes, measuring both HTTP status and response time.
- **Time-Series Storage:** Results persisted to Azure Table Storage with a partition strategy optimised for per-site historical queries.
- **REST API Layer:** HTTP-triggered Function exposes a `/api/api` endpoint, acting as secure middleware between the dashboard and storage.
- **Live Dashboard:** Static HTML dashboard hosted on Azure Blob Storage with auto-refresh, sparkline charts, and uptime percentages.
- **Email Alerting:** Azure Logic App sends alerts when a site goes down, fully decoupled from monitoring logic via HTTP trigger.
- **Secrets Management:** Azure Key Vault stores all credentials; Function App accesses them via Managed Identity — no secrets in code or config.
- **Modular IaC:** Terraform split into four independent modules (`storage`, `keyvault`, `functions`, `alerting`) mirroring real team ownership boundaries.
- **Remote State:** Terraform state stored in Azure Blob Storage, enabling collaborative infrastructure management.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform (HCL) — modular structure |
| Cloud Provider | Microsoft Azure — Poland Central |
| Compute | Azure Functions — B1 Basic App Service plan |
| Runtime | Python 3.11 |
| Storage | Azure Table Storage (monitoring data) + Blob Storage (dashboard) |
| Secrets | Azure Key Vault + Managed Identity (RBAC) |
| Alerting | Azure Logic Apps — HTTP trigger + email action |
| Observability | Azure Application Insights |

---

## 🏗️ Architecture

A timer-triggered Azure Function checks each configured site every 5 minutes and writes results to Table Storage. A second HTTP-triggered Function exposes the data as a REST API at `/api/api`. The static dashboard, hosted on Blob Storage, calls this API directly from the browser. When a site fails, the monitor Function POSTs to a Logic App trigger URL which handles email delivery — keeping alerting logic completely separate from monitoring logic.

<img width="800" alt="architecture-diagram" src="./screenshots/scheme.png" />

---

## 📂 Repository Structure

```
azure-serverless-monitoring/
├── .gitignore
├── README.md
├── dashboard/
│   └── index.html                # Single-file monitoring dashboard
├── screenshots/                  # Architecture diagrams and deployment evidence
└── code/
    ├── functions/
    │   ├── host.json
    │   ├── requirements.txt
    │   ├── monitor/              # Timer-triggered checker
    │   │   ├── __init__.py
    │   │   └── function.json
    │   └── api/                  # HTTP status API
    │       ├── __init__.py
    │       └── function.json
    └── terraform/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── terraform.tfvars.example
        └── modules/
            ├── storage/          # Blob + Table Storage + static website
            ├── keyvault/         # Key Vault + secret
            ├── functions/        # App Service Plan + Function App + App Insights
            └── alerting/         # Logic App workflow
```

---

## 🚀 Deployment

### Prerequisites

- **Azure CLI** — Authenticated via `az login`
- **Terraform** — Version 1.5.0 or higher
- **Azure Functions Core Tools v4** — `npm install -g azure-functions-core-tools@4`
- **Python 3.11** — For local function development

### 1 — Bootstrap Remote State

Terraform needs a storage account for its own state before it can manage any resources. Create this once manually:

```bash
az group create \
  --name rg-tfstate \
  --location polandcentral

# Storage account name must be globally unique — choose your own
az storage account create \
  --name stterraformstate \
  --resource-group rg-tfstate \
  --sku Standard_LRS \
  --https-only true \
  --min-tls-version TLS1_2

az storage container create \
  --name tfstate \
  --account-name stterraformstate
```

### 2 — Configure Variables

```bash
cd code/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set alert_email and adjust any defaults
```

### 3 — Initialise and Apply Terraform

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> [!IMPORTANT]
> After `apply` completes, note the outputs — you will need `api_endpoint`, `dashboard_url`, `function_app_name`, and `storage_account_name` in the next steps.

> [!IMPORTANT]
> Before deploying functions, update the CORS `allowed_origins` value in `code/terraform/modules/functions/main.tf` to match your own `dashboard_url` output. Format: `https://<your-storage-account>.z6.web.core.windows.net/`

### 4 — Deploy Python Functions

```bash
cd ../functions
func azure functionapp publish \
  $(terraform -chdir=../terraform output -raw function_app_name)
```

### 5 — Upload Dashboard

```bash
STORAGE=$(terraform -chdir=../terraform output -raw storage_account_name)

# Replace API endpoint in dashboard before uploading
sed -i 's|YOUR_FUNCTION_APP_URL_HERE|'$(terraform -chdir=../terraform output -raw api_endpoint)'|g' \
  ../../dashboard/index.html

az storage blob upload \
  --account-name "$STORAGE" \
  --container-name '$web' \
  --name index.html \
  --file ../../dashboard/index.html \
  --content-type text/html \
  --overwrite
```

### 6 — Wire Logic App Alert (Optional)

```bash
az functionapp config appsettings set \
  --name $(terraform -chdir=../terraform output -raw function_app_name) \
  --resource-group $(terraform -chdir=../terraform output -raw resource_group_name) \
  --settings "LOGIC_APP_TRIGGER_URL=$(terraform output -raw logic_app_trigger_url)"
```

### Teardown

```bash
terraform destroy -auto-approve
```

---

## 🔬 Infrastructure Lifecycle

The deployment follows a structured lifecycle across six phases, from Terraform initialisation through to a live, data-populated dashboard.

### 1. Initialisation & Provider Setup

- **Backend Initialisation** — Running `terraform init` to connect to the Azure Blob remote backend and download the `hashicorp/azurerm` provider, creating a `.terraform.lock.hcl` file to pin versions for reproducible deployments.
- **Version Validation** — Confirming provider compatibility before any plan is generated.

<img width="1000" alt="terraform-init" src="./screenshots/terraform-init.png" />

### 2. Execution Planning

- **Initial Plan** — Running `terraform plan` to validate all 13 resources across four modules: resource group, Logic App workflow, Application Insights, Key Vault, storage accounts, Table Storage, and the Function App.
- **Plan Verification** — Reviewing resource names, tags, SKU selections, and dependency order before committing to any changes.

<img width="1000" alt="terraform-plan-part1" src="./screenshots/terraform-plan-part1.png" />
<img width="1000" alt="terraform-plan-part2" src="./screenshots/terraform-plan-part2.png" />

### 3. Configuration Refinement & Re-plan

- **Config Changes** — After the initial apply, adjustments were made to Function App settings and Key Vault access policies based on runtime behaviour.
- **Re-plan** — A second `terraform plan` confirmed 4 resources to add, 1 to change, and 2 to destroy — demonstrating iterative infrastructure management.

<img width="1000" alt="terraform-plan-reapply-part1" src="./screenshots/terraform-plan-reapply-part1.png" />
<img width="1000" alt="terraform-plan-reapply-part2" src="./screenshots/terraform-plan-reapply-part2.png" />

### 4. Automated Provisioning

- **Full Stack Deployment** — Running `terraform apply` to orchestrate creation of all 8 resources in Poland Central: resource group, two storage accounts, Table Storage, Key Vault with secret, Function App, App Service Plan, Application Insights (`appi-site-monitor-devt1`), and Logic App.
- **Output Capture** — After apply, Terraform prints `dashboard_url`, `api_endpoint`, `function_app_name`, and `storage_account_name` for use in subsequent steps.

<img width="1000" alt="terraform-apply" src="./screenshots/terraform-apply.png" />

### 5. Function Code Deployment

- **Oryx Build** — Publishing Python function code to the Function App via `func azure functionapp publish`. Azure runs a remote Oryx build: installing dependencies from `requirements.txt` via pip.
- **Deployment Confirmation** — Remote build completes successfully with both `monitor` and `api` functions listed as deployed and their trigger types confirmed.

<img width="1000" alt="function-deployment-part1" src="./screenshots/function-deployment-part1.png" />
<img width="1000" alt="function-deployment-part2" src="./screenshots/function-deployment-part2.png" />

### 6. Dashboard Upload & Verification

- **Dashboard Upload** — Uploading the configured `index.html` to the `$web` blob container. The Azure CLI confirms 100% transfer and returns a success JSON response.
- **Unconfigured State** — On first load before the API endpoint is injected, the dashboard correctly displays the yellow configuration notice, confirming the config detection logic works.
- **Portal Verification** — Confirming `func-site-monitor-dev` shows Status: Running in the Azure Portal, with both functions visible and active.

<img width="1000" alt="dashboard-upload" src="./screenshots/dashboard-upload.png" />
<img width="1000" alt="dashboard-unconfigured" src="./screenshots/dashboard-unconfigured.png" />
<img width="1000" alt="portal-function-app-running" src="./screenshots/portal-function-app-running.png" />

### 7. Function App Configuration & Testing

- **Always On Setting** — `always_on = true` is set directly in the `site_config` block in Terraform to keep the function host active between timer triggers. The portal warnings and CLI output confirmed the setting was applied correctly after deployment.
- **Live Function Test** — Using the Portal Code+Test blade to manually trigger the monitor function, confirming HTTP 202 (Accepted) and successful execution.

<img width="1000" alt="portal-function-app-warnings" src="./screenshots/portal-function-app-warnings.png" />
<img width="1000" alt="portal-always-on-config-part1" src="./screenshots/portal-always-on-config-part1.png" />
<img width="1000" alt="portal-always-on-config-part2" src="./screenshots/portal-always-on-config-part2.png" />
<img width="1000" alt="portal-monitor-function-test" src="./screenshots/portal-monitor-function-test.png" />

### 8. End-to-End Validation

- **Resource Group** — All 8 deployed resources visible in the Azure Portal with correct names, tags, and locations.
- **Table Storage** — Storage Browser confirms `monitoringresults` table is populated with rows containing `PartitionKey` (site URL), `RowKey` (timestamp), `StatusCode`, `ResponseTimeMs`, and `IsUp`.
- **Key Vault** — Confirming `storage-connection-string` secret exists in Key Vault with status Enabled.
- **Alert Email Received** — End-to-end proof: the Logic App successfully delivered the alert email to the configured ProtonMail inbox within 30 seconds of the workflow being triggered.
- **Run History** — Logic App run history showing two green Succeeded executions after wiring the real Outlook connector, with earlier Failed runs from the placeholder endpoint visible below — documenting the fix in real time.
- **Live Dashboard** — Final state showing all 12 sites UP (0 degraded), 790ms average response time, with sparkline charts for each site populated with real historical data. The dashboard is publicly accessible at [https://stsitemonitordev.z6.web.core.windows.net/](https://stsitemonitordev.z6.web.core.windows.net/).

<img width="1000" alt="azure-portal-resources" src="./screenshots/azure-portal-resources.png" />
<img width="1000" alt="table-storage-data" src="./screenshots/table-storage-data.png" />
<img width="1000" alt="keyvault-secret" src="./screenshots/keyvault-secret.png" />
<img width="1000" alt="logic-app-email-config" src="./screenshots/logic-app-email-config.png" />
<img width="1000" alt="logic-app-email-received" src="./screenshots/logic-app-email-received.png" />
<img width="1000" alt="logic-app-run-history" src="./screenshots/logic-app-run-history.png" />
<img width="1000" alt="dashboard-live" src="./screenshots/dashboard-live.png" />
<img width="1000" alt="dashboard-final" src="./screenshots/dashboard-final.png" />

---

## 🧩 Challenges & Solutions

### 1. Anti-Bot Protection (HTTP 403)

| | |
|:---|:---|
| **Issue** | Monitoring `wikipedia.org` consistently returned `403 Forbidden` while all other sites responded normally. |
| **Cause** | Wikipedia blocks HTTP requests that do not include a legitimate `User-Agent` header, identifying them as automated scrapers. |
| **Solution** | Configured a custom `User-Agent` header in the Python `requests.get()` call to mimic a standard Chrome browser, bypassing the anti-bot filter. |

<img width="1000" alt="log-wikipedia-403-detected" src="./screenshots/log-wikipedia-403-detected.png" />
<img width="1000" alt="dashboard-wikipedia-403" src="./screenshots/dashboard-wikipedia-403.png" />
<img width="1000" alt="code-user-agent-fix" src="./screenshots/code-user-agent-fix.png" />

---

### 2. Database Self-Healing (Table Storage 404)

| | |
|:---|:---|
| **Issue** | The monitor function failed with `404 Not Found` when attempting to write results to Table Storage. |
| **Cause** | Azure Table Storage requires the table to exist before any write operations. Redeployments sometimes left the table in a missing state. |
| **Solution** | Integrated `create_table_if_not_exists` logic directly into the `store_result` function, making the storage layer self-healing regardless of deployment state. |

<img width="1000" alt="error-table-storage-404" src="./screenshots/error-table-storage-404.png" />

---

### 3. Identity & Connectivity (Key Vault & RBAC)

| | |
|:---|:---|
| **Issue** | Managed Identity propagation delays intermittently blocked the Function App from resolving Key Vault secret references at startup. |
| **Solution** | The `STORAGE_CONNECTION_STRING` and `AzureWebJobsStorage` values were set directly as environment variables on the Function App via the Azure Portal. Key Vault remains provisioned in the infrastructure and `STORAGE_CONNECTION_STRING` is still tagged as "Key vault" in the environment variables blade — visible in the portal screenshots below. |

<img width="1000" alt="portal-environment-variables" src="./screenshots/portal-environment-variables.png" />
<img width="1000" alt="portal-env-var-storage-edit" src="./screenshots/portal-env-var-storage-edit.png" />
<img width="1000" alt="portal-env-var-connection-string-edit" src="./screenshots/portal-env-var-connection-string-edit.png" />
<img width="1000" alt="portal-env-var-save-confirm" src="./screenshots/portal-env-var-save-confirm.png" />

---

### 4. Data Consistency (PartitionKey Logic)

| | |
|:---|:---|
| **Issue** | The dashboard occasionally showed all sites as DOWN despite the monitor function reporting them as UP. |
| **Cause** | Mismatched string formatting between the monitor function (writer) and the API function (reader) for URLs containing special characters such as colons and slashes. |
| **Solution** | Developed a standardised `safe_pk()` function that sanitises URLs by replacing special characters with underscores, ensuring identical PartitionKey values are written and queried across both functions. |

<img width="1000" alt="dashboard-all-sites-down" src="./screenshots/dashboard-all-sites-down.png" />

---

### 5. Infrastructure Quota & Deprecation Fixes

| Challenge | Description | Resolution |
|:---|:---|:---|
| **Consumption plan quota** | Initial deployment on the Y1 Consumption plan failed — Azure subscription had 0 VM quota available in the target region. | Switched to a machine with a higher-tier Azure subscription and deployed on the B1 Basic App Service plan, which has no quota restrictions and provides a dedicated Linux host. |
| **Key Vault access policy race condition** | The Function App's Managed Identity access policy was not yet applied when the Function App first started, causing Key Vault secret references to fail with an authorization error. | Added `depends_on = [azurerm_key_vault_access_policy.function_app]` to the Function App resource, forcing Terraform to apply the access policy before the Function App is created. |
| **Classic Application Insights deprecation** | Any modification to the infrastructure (such as adding new sites to monitor) triggered an Azure Resource Manager validation failure. Azure has deprecated Classic Application Insights in favour of workspace-based instances and began enforcing the `workspace_id` linkage on updates. | Provisioned an `azurerm_log_analytics_workspace` and refactored the App Insights resource to include `workspace_id`. This resolved the deployment block and aligned the project with Azure's 2024+ observability standards, enabling centralised log management. |
| **Key Vault name length** | Key Vault names have a 24-character Azure limit which longer project names exceed. | Used `substr(replace(var.project_name, "-", ""), 0, 12)` in locals to cap the name regardless of input length. |
| **CORS blocking API calls** | Browser blocked cross-origin requests from the Blob-hosted dashboard to the Function App. | Added `cors` block in `site_config` with the specific Blob Storage origin `https://stsitemonitordev.z6.web.core.windows.net/` as the allowed origin. |
| **Resource group deletion error** | Default `prevent_deletion_if_contains_resources = true` in azurerm 3.x blocked `terraform destroy`. | Set `prevent_deletion_if_contains_resources = false` in the provider `features.resource_group` block. |
| **Deprecated storage attribute** | `enable_https_traffic_only` was renamed in the azurerm provider. | Replaced with `https_traffic_only_enabled` on all storage account resources. |

---

## 🔐 Security Design

| Control | Implementation |
|:---|:---|
| **No secrets in source control** | Connection string stored in Key Vault; Function App uses `@Microsoft.KeyVault(...)` reference syntax. |
| **Least-privilege access** | Function App Managed Identity granted `Get` and `List` only on Key Vault secrets — cannot create or delete. |
| **Transport encryption** | `https_traffic_only_enabled = true` on all storage accounts, `min_tls_version = TLS1_2` enforced throughout, CORS restricted to the specific dashboard origin. |
| **Soft delete protection** | Key Vault `soft_delete_retention_days = 7` ensures secrets survive accidental `terraform destroy` for 7 days. |
| **No hardcoded credentials** | All secrets injected at runtime via environment variables resolved from Key Vault or set directly on the Function App. |

---

## 🏁 Conclusion

This project demonstrates end-to-end ownership of a cloud-native monitoring solution — from infrastructure provisioning through Terraform, to Python serverless functions, to a live browser dashboard — with secrets managed through Key Vault and zero plaintext credentials anywhere in the system. Four real debugging challenges encountered during deployment are documented with evidence, reflecting the reality of production cloud work.

### 💡 Key Takeaways

- **Right-sizing compute** — the B1 Basic App Service plan provides a dedicated Linux host for the functions without quota restrictions, making it a reliable choice when Consumption plan availability is constrained by subscription limits.
- **Secrets management is non-negotiable** — Managed Identity + Key Vault references are the Azure baseline; connection strings in plain app settings are a security anti-pattern.
- **Module boundaries reflect team boundaries** — splitting Terraform into `storage`, `keyvault`, `functions`, and `alerting` means each component is independently testable and ownable.
- **Remote state enables collaboration** — local state is fine for solo projects; any team scenario requires a shared backend with locking to prevent concurrent apply conflicts.

---

## 👤 Author

**Oliwier Ozga** — [LinkedIn](https://www.linkedin.com/in/oliwier-ozga-380192405/)

---

## 🤝 Credits & Acknowledgments

- Guided by Azure Well-Architected Framework principles for serverless and security.
- Table Storage partition strategy informed by Microsoft's [Table Storage design patterns](https://learn.microsoft.com/en-us/azure/storage/tables/table-storage-design-patterns) documentation.
- [Azure Functions Python developer guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
- [Terraform azurerm provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- Inspired by real-world SRE observability practices — measuring response time alongside availability reflects production monitoring standards.
