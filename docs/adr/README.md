# Architecture Decision Records

| ADR | Title | Status |
| --- | --- | --- |
| [ADR-001](001-adopt-terraform.md) | Adopt Terraform as the infrastructure substrate | Accepted |
| [ADR-002](002-remote-state-in-s3.md) | Keep Terraform state in S3 with DynamoDB locking | Accepted |
| [ADR-003](003-environment-per-directory.md) | Separate environments by directory | Accepted |
| [ADR-004](004-baseline-module-layout.md) | Structure the baseline as a reusable module | Accepted |
| [ADR-005](005-aws-baseline-scope.md) | Scope the AWS baseline to audit, guardrails and budget | Accepted |
| [ADR-006](006-github-oidc-workload-identity.md) | Authenticate CI with GitHub OIDC | Accepted |
| [ADR-007](007-ci-gates.md) | Gate every change on format, validate, tests and Checkov | Accepted |
| [ADR-008](008-pinned-toolchain-with-renovate.md) | Pin the toolchain and refresh it with Renovate | Accepted |
| [ADR-009](009-prek-for-local-hooks.md) | Use prek for local hooks | Accepted |
