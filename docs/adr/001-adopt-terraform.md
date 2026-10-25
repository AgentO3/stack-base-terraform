# ADR-001: Adopt Terraform as the infrastructure substrate

## Status

Accepted

## Context and Problem Statement

The baseline must be reproducible across several AWS accounts, reviewable before it changes, and reversible when it is wrong. Console changes satisfy none of the three: they leave no diff, no review trail, and no way to recreate an account. The team already has AWS experience but no existing IaC investment, so the choice is open.

## Decision Drivers

- Reproducible account bootstrap
- Reviewable diffs on every change
- A provider ecosystem that covers every baseline service
- Local execution without a vendor-specific runtime

## Considered Options

- Terraform
- OpenTofu
- AWS CDK
- CloudFormation

## Decision Outcome

We will declare the baseline in Terraform, versioned in this repository, and apply it only through CI.

Terraform has the widest provider coverage, works locally and in CI without an account-side control plane, and the `delivery/terraform` spec already pins the conventions this stack needs. OpenTofu is the closest alternative and is a drop-in replacement if licensing becomes a constraint.

## Consequences

- Positive: every change is a diff, and the plan is the review artifact.
- Positive: the same configuration bootstraps any account.
- Negative: state becomes a critical asset, which forces ADR-002.
- Negative: the team must learn HCL and the provider's resource model.
- Neutral: switching to OpenTofu later is a toolchain change, not a rewrite.

## References

- `docs/specs/delivery/terraform.md`
- `https://developer.hashicorp.com/terraform`
