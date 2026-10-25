# ADR-007: Gate every change on format, validate, tests and Checkov

## Status

Accepted

## Context and Problem Statement

Terraform fails late: an unformatted file is a review distraction, an invalid reference is a failed apply, an insecure default is a production incident. Each failure is cheaper to catch earlier. The repository needs a single gate whose result means the change is safe to plan.

## Decision Drivers

- Deterministic local and CI results
- No cloud credentials needed for the gate
- Security findings that block rather than advise
- A gate fast enough to run on every pull request

## Considered Options

- Format, validate, `terraform test` and Checkov in CI, mirrored by prek
- Plan-only review
- Checkov in audit mode only
- A commercial policy engine

## Decision Outcome

We will run `terraform fmt -check -recursive`, `terraform validate` in every root and the module, `terraform test` with mock providers, and Checkov with a repository `.checkov.yaml`, and treat any failure as a build failure.

`terraform test` uses `mock_provider`, so the contract tests run with no credentials and no network calls to AWS. Checkov reports 124 passing checks and zero findings; three S3 hardening checks are waived in `.checkov.yaml` with a written reason because they conflict with the purpose of an audit-log bucket.

The waiver list is deliberately short and each entry carries its rationale. Anything else that fails is a build failure.

## Consequences

- Positive: the whole gate runs offline and identically on a laptop and in CI.
- Positive: a plan artifact is still produced and reviewed before apply.
- Negative: mock providers cannot catch provider-side validation, so a real plan is still required before apply.
- Negative: Checkov's rules lag new resource types, so the configuration will need review as the stack grows.
- Neutral: `make check` is the single entry point.

## References

- `docs/specs/delivery/terraform.md` rules 7-10
- `docs/specs/delivery/github-actions.md`
- `.checkov.yaml`
