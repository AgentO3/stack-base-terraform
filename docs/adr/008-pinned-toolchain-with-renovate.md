# ADR-008: Pin the toolchain and refresh it with Renovate

## Status

Accepted

## Context and Problem Statement

Terraform CLI and provider versions change resource schemas. A range in `required_version` or an unpinned provider lets two runs on the same commit produce different plans, and lets a provider major version land without review. Pinning alone is not enough: a pin nobody updates becomes a security debt.

## Decision Drivers

- Identical plans for identical commits
- A reviewed path for upgrades
- Security patches that arrive without waiting for a human to notice
- One place to see what is out of date

## Considered Options

- Pin exactly and update through Renovate
- Allow ranges and upgrade opportunistically
- Pin exactly with manual upgrades
- Track the latest provider always

## Decision Outcome

We will pin the CLI exactly (`= 1.8.4`), constrain providers pessimistically (`~> 6.70.0`), commit the lockfile, and let Renovate open grouped routine PRs weekly and ungrouped security PRs immediately.

The lockfile is the reproducibility boundary; the constraint is the review boundary; Renovate is the maintenance boundary.

## Consequences

- Positive: `terraform init -lockfile=readonly` proves the lockfile matches the constraints.
- Positive: a provider major bump is a reviewed PR with a failing gate if anything breaks.
- Negative: exact CLI pinning means every contributor and CI image must install 1.8.4.
- Negative: Renovate configuration is another file to own, and a broken config blocks upgrades silently.
- Neutral: the `.terraform-version` file and the `required_version` value are checked for agreement by the ADR-008 verifier.

## References

- `docs/specs/delivery/terraform.md` rules 1-3
- `docs/specs/security/renovate.md`
- `renovate.json`
