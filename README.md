# Production-Ready GKE with Terraform & Policy Enforcement

> A hands-on, production-oriented guide to **provision, secure, and govern** a **Google Kubernetes Engine (GKE)** cluster using **Terraform**, with **Policy as Code** (OPA/Conftest), **security scanning** (tfsec), and **GitHub Actions** CI/CD. Includes Windows-friendly setup via Chocolatey and safe cleanup.

---

## Table of Contents
1. [What You’ll Build](#what-youll-build)  
2. [Architecture at a Glance](#architecture-at-a-glance)  
3. [Repository Structure](#repository-structure)  
4. [Technology Stack](#technology-stack)  
5. [End-to-End Flow](#end-to-end-flow)  
6. [Prerequisites](#prerequisites)  
7. [Quickstart (TL;DR)](#quickstart-tldr)  
8. [Step-by-Step Setup](#step-by-step-setup)  
   - [1) Workstation Setup (Windows 11 via Chocolatey)](#1-workstation-setup-windows-11-via-chocolatey)  
   - [2) Google Cloud: Project & APIs](#2-google-cloud-project--apis)  
   - [3) IAM for Terraform + Remote State](#3-iam-for-terraform--remote-state)  
   - [4) Configure the Dev Environment](#4-configure-the-dev-environment)  
   - [5) Plan & Apply (Create GKE)](#5-plan--apply-create-gke)  
   - [6) Policy as Code (OPA/Rego + Conftest)](#6-policy-as-code-oparego--conftest)  
   - [7) Security Scanning (tfsec)](#7-security-scanning-tfsec)  
   - [8) GitHub Actions CI/CD](#8-github-actions-cicd)  
   - [9) Verify Access & Basics](#9-verify-access--basics)  
9. [Windows Notes](#windows-notes)  
10. [Security & Policy Ideas](#security--policy-ideas)  
11. [Troubleshooting](#troubleshooting)  
12. [Cost Notes](#cost-notes)  
13. [Cleanup](#cleanup)  
14. [License](#license)

---

## What You’ll Build
A **Terraform-managed** GKE environment that is:
- **Version-controlled** and reviewable (IaC).
- **Team-safe** with **remote state** in GCS.
- **Guard-railed** by **OPA/Rego** policies (e.g., enforce `e2-small` in dev, max 1 node).
- **Scanned** by **tfsec** for misconfigurations.
- **Automated** with **GitHub Actions** for fmt/validate/plan, tfsec, and Conftest checks on every pull request.

---

## Architecture at a Glance
```
Developer ──git push──► GitHub
                         │
                         │  GitHub Actions:
                         │  - terraform fmt / validate / plan
                         │  - tfsec scan
                         │  - conftest (OPA/Rego)
                         │
                         └────────► Google Cloud (GCP)
                                      ├─ GCS (Terraform remote state)
                                      └─ GKE (cluster + node pool)

Local (optional):
terraform plan/apply ──► uses Service Account key (JSON) for auth
```

---

## Repository Structure
```
.
├─ modules/
│  └─ gke_cluster/              # Reusable Terraform module for GKE + node pool
├─ envs/
│  └─ dev/                      # Environment-specific root module
│     ├─ main.tf
│     ├─ variables.tf
│     ├─ outputs.tf
│     └─ terraform.tfvars       # Local inputs (no secrets committed)
├─ policy.rego                  # OPA/Rego policies (Conftest)
├─ .github/
│  └─ workflows/
│     └─ terraform.yml          # CI pipeline: fmt/validate/plan + tfsec + conftest
└─ README.md
```

---

## Technology Stack
- **Terraform** (IaC) + **GCS backend** (remote state & locking)  
- **GKE** (standard mode with release channel)  
- **Open Policy Agent (OPA)** / **Rego** + **Conftest** (Policy as Code)  
- **tfsec** (Terraform static security scanning)  
- **GitHub Actions** (CI/CD for infra)

---

## End-to-End Flow
1. You propose a change (PR).  
2. CI runs: **terraform fmt → validate → plan**, **tfsec** scan, and **Conftest** policy checks.  
3. Only **policy-compliant and secure** changes can be merged.  
4. You apply from CI or locally to provision/update the GKE cluster.  
5. When done, **destroy** to avoid costs.

---

## Prerequisites
- A **GCP project** with billing enabled.
- **Windows 11** (scripted install via **Chocolatey**), or equivalent tooling on macOS/Linux.
- Ability to create a **Service Account** and a **GCS bucket** for Terraform state.
- **GitHub repository** connected to this codebase.

---

## Quickstart (TL;DR)
> For a quick dev spin-up on Windows PowerShell (Administrator):

```powershell
# 0) Install tools (Chocolatey + core CLIs)
Set-ExecutionPolicy Bypass -Scope Process -Force; `
  [System.Net.ServicePointManager]::SecurityProtocol = `
  [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install terraform gcloudsdk git tfsec conftest -y

# 1) gcloud login + set project
gcloud init
gcloud config set project YOUR_PROJECT_ID

# 2) Enable APIs required by Terraform/GKE
gcloud services enable `
  cloudresourcemanager.googleapis.com `
  iam.googleapis.com `
  storage.googleapis.com `
  container.googleapis.com `
  artifactregistry.googleapis.com `
  secretmanager.googleapis.com

# 3) Create Terraform SA + GCS state bucket + key (store securely!)
gcloud iam service-accounts create terraform --display-name="Terraform Service Account"
$saEmail = (gcloud iam service-accounts list --filter="displayName:Terraform Service Account" --format="value(email)")
$bucketName = "YOUR_PROJECT_ID-tf-state-$((Get-Date).ToString('yyyyMMddHHmmss'))"
gsutil mb -p YOUR_PROJECT_ID gs://$bucketName
gsutil iam ch "serviceAccount:$saEmail:objectAdmin" gs://$bucketName
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID --member="serviceAccount:$saEmail" --role="roles/editor"
gcloud iam service-accounts keys create terraform-key.json --iam-account=$saEmail

# 4) Configure dev env & apply
cd envs/dev
$env:GOOGLE_APPLICATION_CREDENTIALS="../../terraform-key.json"
terraform init
terraform plan
terraform apply

# 5) (Optional) Run policy & security checks locally
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
conftest test --policy ../../policy.rego tfplan.json
tfsec .
```

> **Security reminder:** Treat `terraform-key.json` like a password. **Never commit** keys to Git.

---

## Step-by-Step Setup

### 1) Workstation Setup (Windows 11 via Chocolatey)
```powershell
# PowerShell (Admin):
Set-ExecutionPolicy Bypass -Scope Process -Force; `
  [System.Net.ServicePointManager]::SecurityProtocol = `
  [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install terraform gcloudsdk git tfsec conftest -y
```

### 2) Google Cloud: Project & APIs
```powershell
gcloud init
gcloud config set project YOUR_PROJECT_ID

gcloud services enable `
  cloudresourcemanager.googleapis.com `
  iam.googleapis.com `
  storage.googleapis.com `
  container.googleapis.com `
  artifactregistry.googleapis.com `
  secretmanager.googleapis.com
```

### 3) IAM for Terraform + Remote State
Create a **Service Account** for Terraform and a **GCS** bucket for remote state:

```powershell
gcloud iam service-accounts create terraform --display-name="Terraform Service Account"
$saEmail = (gcloud iam service-accounts list --filter="displayName:Terraform Service Account" --format="value(email)")

# Globally-unique bucket for state
$bucketName = "YOUR_PROJECT_ID-tf-state-$((Get-Date).ToString('yyyyMMddHHmmss'))"
gsutil mb -p YOUR_PROJECT_ID gs://$bucketName

# Minimal perms for demo (tighten in production)
gsutil iam ch "serviceAccount:$saEmail:objectAdmin" gs://$bucketName
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID --member="serviceAccount:$saEmail" --role="roles/editor"

# SA key for local runs (prefer keyless/WIF in CI)
gcloud iam service-accounts keys create terraform-key.json --iam-account=$saEmail
```

> **Recommended:** Enable **Object Versioning** on the bucket for state recovery. Consider storing the bucket name in backend config.

### 4) Configure the Dev Environment
From `envs/dev/`, set your inputs in `terraform.tfvars`:

```hcl
gcp_project_id = "YOUR_PROJECT_ID"
region         = "us-central1"
cluster_name   = "dev-gke-cluster"
node_count     = 1
machine_type   = "e2-small"
```

> The **policy** in `policy.rego` enforces `e2-small` and `node_count <= 1` in **dev**.

If you use a backend, your `backend` (e.g., in `main.tf` or `backend.tf`) will look similar to:
```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_PROJECT_ID-tf-state-YYYYMMDDHHMMSS"
    prefix = "envs/dev"
  }
}
```

### 5) Plan & Apply (Create GKE)
```powershell
cd envs/dev
$env:GOOGLE_APPLICATION_CREDENTIALS = "../../terraform-key.json"

terraform init
terraform plan
terraform apply
```

### 6) Policy as Code (OPA/Rego + Conftest)
The **Rego** policies in `policy.rego` enforce dev guardrails:
- **Cost Control:** use `e2-small` machine type in `dev`.
- **Resource Limit:** at most **1 node** in `dev`.

Test locally against your plan:
```powershell
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
conftest test --policy ../../policy.rego tfplan.json
```

A failure indicates a policy violation—adjust inputs or module config before merging/applying.

### 7) Security Scanning (tfsec)
Run a static security scan of Terraform code:
```powershell
tfsec .
```
Fix any HIGH/CRITICAL findings before merging.

### 8) GitHub Actions CI/CD
The workflow at `.github/workflows/terraform.yml` runs on PRs:
1. `terraform fmt -check`  
2. `terraform init` + `terraform validate` + `terraform plan`  
3. `tfsec` scan  
4. `conftest test` with `policy.rego`  

**Auth:**  
- **Simple:** store `GCP_SA_KEY` (Service Account JSON) as a GitHub secret.  
- **Preferred:** use **Workload Identity Federation (WIF)** to avoid long-lived keys.

**Typical secrets/vars:**
- `GCP_PROJECT_ID`
- `GCP_SA_EMAIL` (or WIF provider IDs)
- `GCP_SA_KEY` (if not using WIF)
- `TF_STATE_BUCKET`
- Any `TF_VAR_*` required by your module

### 9) Verify Access & Basics
Once applied, you can interact with the cluster using `gcloud`/`kubectl` (if your module outputs cluster details). Example:
```powershell
# If using standard GKE & have cluster name/region
gcloud container clusters get-credentials dev-gke-cluster --region us-central1
kubectl get nodes
```

---

## Windows Notes
- Use **forward slashes (`/`)** in `.tf` files even on Windows.
- Normalize line endings to avoid diffs:
  ```powershell
  git config --global core.autocrlf false
  ```
- PowerShell env var export:
  ```powershell
  $env:GOOGLE_APPLICATION_CREDENTIALS = "path/to/terraform-key.json"
  ```

---

## Security & Policy Ideas
Extend `policy.rego` to enforce:
- **Required labels/tags** (cost center, owner, env)
- **Allowed regions/zones** only
- **Private control plane** / **NetworkPolicy** required
- **Min/max Kubernetes versions** or **release channel** restrictions
- **Budget guardrails** (e.g., allowed machine families)
- **No public IPs** on nodes / restrict LB usage in non-prod

---

## Troubleshooting
- **`terraform init` fails**: Check backend bucket name, permissions (`objectAdmin` on bucket), and project ID.  
- **Policy failures**: Reproduce locally with `terraform show -json tfplan.binary > tfplan.json` then `conftest test ...` to see which rule fired.  
- **tfsec failures**: Read rule output and remediate (often missing encryption, version pinning, or permissive IAM).  
- **Auth issues**: Ensure `GOOGLE_APPLICATION_CREDENTIALS` points to the correct JSON and that the SA has required roles.

---

## Cost Notes
- **Clusters**, **node pools**, **load balancers**, and **egress** incur costs.  
- Keep **dev** small (`e2-small`, `node_count=1`).  
- Destroy inactive environments and enable autoscaling where appropriate.

---

## Cleanup
When you’re finished, **destroy** to avoid charges:
```powershell
cd envs/dev
$env:GOOGLE_APPLICATION_CREDENTIALS = "../../terraform-key.json"
terraform destroy
```
> Review the plan and confirm. Consider deleting the state bucket **only after** all resources are destroyed and you no longer need history.

---
