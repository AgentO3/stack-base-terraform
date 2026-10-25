---
id: terraform
layer: delivery
extends: []
---

# Terraform

## Purpose

Terraform is the substrate that decides what infrastructure exists, what version of each provider provisions it, and what state file claims authority over it — so a sloppy Terraform configuration is a production-outage, blast-radius, and credential-leak liability rolled into one. Unpinned Terraform CLI or provider versions silently change resource schemas between runs, local state files turn the developer's laptop into the source of truth, hardcoded credentials and committed `.tfvars` leak secrets into git history, `count`-based environment switching produces destroy-and-recreate events on the wrong account, and missing `terraform fmt` / `validate` / static-analysis gates let drift accumulate until an apply blows up. This spec pins how configurations are versioned, how state is stored and locked, how modules are structured and sourced, how secrets are handled, and how plan / apply gates run in CI so an `apply` is a deliberate, reviewed, reproducible action rather than a roll of the dice.

## References

- **spec** `github-actions` — sibling delivery-layer spec for the CI workflow that runs Terraform
- **external** `https://developer.hashicorp.com/terraform` — Terraform documentation home
- **external** `https://developer.hashicorp.com/terraform/language` — Terraform language reference
- **external** `https://developer.hashicorp.com/terraform/language/style` — Terraform style guide
- **external** `https://developer.hashicorp.com/terraform/language/state/remote` — Remote state backends
- **external** `https://developer.hashicorp.com/terraform/cloud-docs/run/remote-operations` — Terraform Cloud / HCP Terraform remote runs
- **external** `https://github.com/terraform-linters/tflint` — TFLint
- **external** `https://www.checkov.io/` — Checkov policy-as-code scanner

## Rules

1. Pin the Terraform CLI version with `terraform { required_version = "= <X.Y.Z>" }` in every root module; do not allow open-ended ranges in committed configurations.
2. Pin every provider with `required_providers` in `terraform {}` to an exact version or a pessimistic constraint (`~> X.Y.Z`); do not omit a provider version.
3. Commit the `.terraform.lock.hcl` lockfile to the repo and require CI to run `terraform init -lockfile=readonly`.
4. Configure a remote state backend with locking (HCP Terraform, S3 + DynamoDB, GCS, Azure Storage with leases, or equivalent); do not keep `terraform.tfstate` on a developer machine for any shared environment.
5. Encrypt remote state at rest and in transit; do not configure a backend that stores state unencrypted.
6. Do not commit `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `*.tfvars` containing secrets, or crash logs — list them in `.gitignore`.
7. Run `terraform fmt -check -recursive` in CI and fail on unformatted files.
8. Run `terraform validate` in CI for every root module on every PR.
9. Run a static-analysis scanner (TFLint plus Checkov, tfsec, or Trivy) in CI and treat findings at the configured severity as build failures.
10. Produce a `terraform plan` artifact in CI for every PR, post the plan output to the PR, and require human review before any apply runs against a shared environment.
11. Run `terraform apply` only via the same CI / orchestration system that ran the reviewed plan, using the saved plan file; do not apply ad-hoc speculative plans from a developer machine against shared environments.
12. Separate environments by directory (`environments/<env>/`) or by HCP Terraform / Terraform Cloud workspaces; do not switch environments via `count`/`for_each` toggles in a single root module.
13. Structure every reusable module with `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf` at the module root.
14. Type every input variable explicitly with `type = ...` and constrain it with `validation` blocks where the domain is bounded; do not declare untyped variables.
15. Mark sensitive inputs and outputs with `sensitive = true`; do not log or `terraform output` secrets in plain text.
16. Source secrets from a secret manager via data sources (`aws_secretsmanager_secret_version`, `vault_generic_secret`, etc.) at apply time; do not store credentials in `*.tfvars`, environment variables committed to the repo, or `locals`.
17. Pin every external module source to an exact ref — git tag (`?ref=v1.2.3`), commit SHA, or registry version constraint with `~>`; do not depend on `main`, `master`, or an unpinned branch.
18. Apply a consistent tag / label set (owner, environment, cost-center, repo) to every taggable resource via a shared `default_tags` provider configuration or module convention.
19. Refactor resource addresses with `moved` blocks (or `import` blocks for adoption) committed alongside the change; do not run `terraform state mv` / `terraform state rm` manually against shared state.
20. Do not use `local-exec` or `null_resource` to drive primary infrastructure control flow; reserve them for narrow shims that document why the provider is insufficient.
