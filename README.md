# stack-base-terraform

A base stack for AWS accounts: the audit, guardrail and budget floor that every other stack on the account can assume. Terraform owns the resources, GitHub Actions owns the plan/apply gate, and OIDC replaces long-lived keys.

This stack is the composition of the specs under [`docs/specs/`](docs/specs/). It does not restate them; it implements them.

## Spec set

| Layer | Spec | Question it answers |
| --- | --- | --- |
| `delivery` | `terraform` | How infrastructure is declared, versioned and applied |
| `delivery` | `github-actions` | Where plan and apply gates run |
| `platform` | `aws` | What the AWS baseline must guarantee |
| `practices` | `git` | How history is written and protected |
| `practices` | `trunk-based-development` | How work reaches `main` |
| `practices` | `conventional-commits` | How commits are formatted |
| `practices` | `adr` | How decisions are recorded |
| `practices` | `bdr` | How observable behaviour is recorded |
| `quality` | `prek` | Which local gates run before a commit |
| `security` | `dependency-management` | How provider and module versions are governed |
| `security` | `renovate` | How those versions are updated |
| `security` | `vulnerability-scanning` | How CVE signal reaches the update stream |

## Architecture contract

```
GitHub Actions ──OIDC──▶ IAM role ──assume──▶ AWS account
      │                                         │
      └── terraform plan/apply ──▶ S3 state + S3 lockfile
```

### 1. Layout

```
environments/dev/     root module, own state key, own budget and retention
environments/prod/    root module, own state key, own budget and retention
modules/baseline/     the reusable floor: audit, guardrails, budget, deploy role
projects/             workloads layered on the baseline (see projects/README.md)
verify/               one verifier per ADR, plus the BDR contract check
```

Environments are directories, never `count` or `for_each` switches. Each root module declares its own backend and its own `name_prefix`, so a plan for `dev` cannot address a `prod` resource.

### 2. What the baseline creates

| Concern | Resource | Guarantee |
| --- | --- | --- |
| Encryption | `aws_kms_key.logs` + alias | Rotation on, 30-day deletion window |
| Audit storage | `aws_s3_bucket.logs` | Versioned, KMS-encrypted, public access blocked, lifecycle-bound |
| Trail | `aws_cloudtrail.main` | Multi-Region, log-file validation, CloudWatch + SNS delivery |
| Log retention | `aws_cloudwatch_log_group.trail` | Explicit `retention_in_days` |
| Configuration history | `aws_config_configuration_recorder.main` | All supported resource types, delivery channel enabled |
| Account guardrail | `aws_s3_account_public_access_block.main` | All four switches on |
| Spend | `aws_budgets_budget.monthly` + SNS | Forecasted 80% and actual 100% alerts |
| Workload identity | `aws_iam_role.deploy` | GitHub OIDC trust scoped to repository and branch |
| CI permissions | `aws_iam_role_policy.deploy` | Per-service, resource-scoped actions; no `Action: "*"` |

### 3. State bootstrap

The state bucket must exist before the first `init`, so it is created once by hand. This is the only console/CLI step, and it is recorded in [ADR-002](docs/adr/002-remote-state-in-s3.md). Terraform locks state with a `.tflock` object in the same bucket (`use_lockfile = true`), so no lock table is needed ([ADR-010](docs/adr/010-s3-native-state-locking.md)).

```bash
aws s3api create-bucket --bucket <state-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <state-bucket> --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket <state-bucket> \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
```

Then copy `environments/<env>/backend.hcl.example` to `backend.hcl`, fill it in, and run `terraform init -backend-config=backend.hcl`.

### 4. Deploy flow

1. A pull request runs `fmt -check`, `validate`, `terraform test`, and Checkov.
2. The same job produces a `plan` artifact and posts it to the PR.
3. Merging to `main` reruns the plan and applies that saved plan through the OIDC role.
4. `prod` is gated by a GitHub `environment:` with required reviewers.

The `plan` and `apply` jobs stay skipped until the repository variable `AWS_ROLE_ARN` is set and a `backend.hcl` exists for the target environment. The offline gate runs on every push and pull request regardless.

### 5. Invariants

- Terraform CLI is pinned exactly (`= 1.11.4`); providers use pessimistic constraints.
- The lockfile is committed in every root and in the module.
- No credential material in the repository; CI authenticates through OIDC only.
- Every taggable resource receives `Owner`, `CostCenter`, `Application`, `Environment`, `ManagedBy`, `Stack`.
- Log retention is always explicit; nothing defaults to "never expire".

## Commands

```bash
make init        # init every root and the module with -backend=false
make fmt         # rewrite HCL to canonical format
make fmt-check   # fail on unformatted HCL
make validate    # terraform validate in every root and the module
make test        # terraform test (mock providers, no credentials)
make scan        # Checkov, configured in .checkov.yaml
make verify      # every ADR and BDR verifier
make check       # fmt-check + validate + test + scan + verify
```

Install the local hooks once after cloning:

```bash
pipx install prek==0.5.7
make prek-install   # prek install --prepare-hooks && prek install --hook-type commit-msg
```

## Decisions

[`docs/adr/`](docs/adr/README.md) holds the architecture decisions. [`docs/bdr/`](docs/bdr/README.md) holds the observable behaviour contracts. Read ADR-001 first; it explains why Terraform, and the rest follow from it.

## Gaps

- The deploy role's permissions are resource-scoped but still broad across the services the baseline owns. Narrow it per environment before adding workloads.
- `aws_config_configuration_recorder` does not attach the AWS Foundational Security Best Practices conformance pack; that belongs to a security stack layered on this one.
- Cross-Region backup (rule 15 of the AWS spec) applies to stateful workloads, not to this baseline. The stack that owns stateful resources must implement it.
