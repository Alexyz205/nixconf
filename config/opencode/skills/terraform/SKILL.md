---
name: terraform
description: Terraform and OpenTofu standards - remote state, modules, workspaces, drift detection, security scanning
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: iac
---

## Purpose

Production IaC standards. Reproducible state, reusable modules, secure and reviewable plans.

## State

- Remote state with locking (S3 + DynamoDB, GCS, or TFC) — never local, never committed
- Pin versions in `versions.tf`:
  ```hcl
  terraform {
    required_version = ">= 1.6"
    required_providers {
      aws = { source = "hashicorp/aws", version = "~> 5.0" }
    }
  }
  ```

## Modules & Structure

- Small, reusable modules with a single responsibility
- `variables.tf` / `outputs.tf` / `main.tf` / `versions.tf` per module
- Typed, validated variables; `locals` for DRY, not duplication
- Environment separation: directories or workspaces, never shared state
- Use `count`/`for_each` over copy-paste

## Lifecycle & Safety

- `create_before_destroy` on stateful resources
- `prevent_destroy` on critical data (DBs, buckets)
- `lifecycle { ignore_changes }` where drift is expected
- Never commit `.tfstate` or `*.tfvars` with secrets

## Secrets

- Never hardcode — use variables marked `sensitive`, or sops/age/KMS/vault
- Outputs marked `sensitive` where they expose secrets
- `.terraform.lock.hcl` committed; `.terraform/` ignored

## Validation & Testing

```bash
terraform fmt -recursive -check
terraform validate
terraform plan -out=plan.out   # review before apply
tfsec .                        # static security scan
```

- `check` blocks / `terraform test` for assertions
- `terratest` for integration tests of modules
- Drift: `terraform plan` in CI on a schedule; alert on non-empty

## Workflow

1. `plan` → review diff (resources added/changed/destroyed)
1. Gate on CI: `fmt` + `validate` + `tfsec` + `plan`
1. `apply` from reviewed `plan.out` only
1. Tag everything; enforce naming conventions

## When to Use

- Writing/refactoring modules or stacks
- Reviewing a plan for safety
- Setting up remote state or CI for IaC
