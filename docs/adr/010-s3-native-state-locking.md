# ADR-010: Lock Terraform state with S3 native lockfiles

## Status

Accepted

## Context and Problem Statement

[ADR-002](002-remote-state-in-s3.md) locks Terraform state with a DynamoDB table. This table is a second resource that each environment needs. It must exist before the first `init`, so the team creates it by hand. The CI deploy role needs `dynamodb:GetItem`, `dynamodb:PutItem`, and `dynamodb:DeleteItem` on the table. The `state_lock_table` variable also appears in three modules.

Terraform 1.10 adds native S3 locking. With `use_lockfile = true`, Terraform writes a `.tflock` object next to the state object. S3 conditional writes make the lock atomic. The state bucket then holds both the state and the lock. Terraform 1.11 makes this feature generally available and deprecates the `dynamodb_table` argument.

Before this decision, the pinned Terraform CLI was 1.8.4. That version does not support `use_lockfile`.

## Decision Drivers

- Concurrent-applier safety
- Fewer resources to bootstrap by hand
- Smaller permission set for the CI deploy role
- A supported path when `dynamodb_table` is removed
- Reviewed change to the pinned toolchain ([ADR-008](008-pinned-toolchain-with-renovate.md))

## Considered Options

- S3 native lockfile locking
- Keep DynamoDB locking
- Use both locks during a migration window

## Decision Outcome

Chosen option: "S3 native lockfile locking".

We will set `use_lockfile = true` in each backend and remove the DynamoDB lock table. We will pin the Terraform CLI to 1.11.4, the first minor line where the feature is generally available.

This option removes one resource per environment and keeps the lock in the same bucket as the state. It also follows the direction of Terraform, which deprecates `dynamodb_table`.

### Changes in the repository

1. The Terraform pin moves from 1.8.4 to 1.11.4 in `.terraform-version`, the `Makefile`, the CI workflow, and every `required_version`.
2. Each `backend.hcl.example` sets `use_lockfile = true` and has no `dynamodb_table`.
3. The `state_lock_table` variable and the `TerraformStateLock` policy statement are removed from the baseline module, both environments, and `projects/aws-bedrock`.
4. The README bootstrap has no `aws dynamodb create-table` step.
5. `verify/adr-010-s3-lockfile.sh` checks the pin, the backends, and the deploy policies.

### Migration of an existing backend

An operator does these steps once for each environment that already has state.

1. Add `use_lockfile = true` and keep `dynamodb_table` in `backend.hcl`. Run `terraform init -reconfigure`. Terraform now takes both locks.
2. Run one plan per environment. Confirm that a second run fails while the first run holds the lock.
3. Remove `dynamodb_table` from `backend.hcl`. Run `terraform init -reconfigure` again.
4. Apply the baseline, so that the deploy role loses its DynamoDB actions.
5. Delete the lock table from the account.

## Consequences

- Positive: each environment needs one fewer resource, and the bootstrap needs no `aws dynamodb create-table` step.
- Positive: the deploy role loses the `dynamodb:*` actions. The policy gets smaller.
- Positive: the stack does not depend on a deprecated argument.
- Negative: every contributor and the CI image must install Terraform 1.11.4.
- Negative: a stale `.tflock` object can block a run after a crash. An operator must remove it with `terraform force-unlock` or by deleting the object.
- Neutral: the deploy role needs `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on the `.tflock` object. The existing `TerraformState` statement already grants these actions on the state bucket objects, so the policy needs no new statement.
- Neutral: the lock depends on S3 conditional writes. Bucket versioning stays on, so each lock creates extra object versions. The state bucket lifecycle rule must expire noncurrent versions.

## Pros and Cons of the Options

### S3 native lockfile locking

- Good, because it removes the DynamoDB table and its permissions.
- Good, because the state and the lock share one bucket and one encryption setting.
- Bad, because it needs Terraform 1.10 or later, so the pin must move.
- Bad, because a crash can leave a stale lock object.

### Keep DynamoDB locking

- Good, because it works with the old pinned CLI.
- Good, because the team already runs it.
- Bad, because it keeps a second resource and a manual bootstrap step.
- Bad, because the `dynamodb_table` argument is deprecated and Terraform can remove it.

### Use both locks during a migration window

- Good, because a run takes two locks and a failure of either one stops the run.
- Bad, because it keeps all DynamoDB cost and permissions for the window.
- Neutral: this is a migration step, not an end state. The migration steps above use it.

## References

- [ADR-002](002-remote-state-in-s3.md)
- [ADR-008](008-pinned-toolchain-with-renovate.md)
- `docs/specs/delivery/terraform.md` rules 1 and 4
- `https://developer.hashicorp.com/terraform/language/backend/s3`
