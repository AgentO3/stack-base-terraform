# ADR-003: Separate environments by directory

## Status

Accepted

## Context and Problem Statement

Development and production need different budgets, log retention and accounts. The tempting shortcuts are a single root module with a `count` or `for_each` switch, or one state file with per-environment resource names. Both let a mistyped variable address production while the operator believes they are in development.

## Decision Drivers

- A plan for one environment cannot touch another
- Different retention and budget per environment
- Readable review diffs
- No duplicated module code

## Considered Options

- One directory per environment, each a root module
- One root module with `count`/`for_each` environment switches
- Terraform workspaces
- HCP Terraform workspaces

## Decision Outcome

We will keep one directory per environment under `environments/`, each with its own backend configuration and its own `name_prefix`, both calling the shared `modules/baseline`.

A directory boundary is visible in the filesystem, in the plan path and in the state key, so an operator cannot be confused about which environment they are about to change.

## Consequences

- Positive: `terraform plan` in `environments/prod` can only address production.
- Positive: budgets and retention diverge without conditionals in the module.
- Negative: provider and CLI versions are declared in each root, so they must be updated together; Renovate and the verifier enforce that.
- Neutral: adding an environment means a new directory, not a new branch of logic.

## References

- `docs/specs/delivery/terraform.md` rule 12
