# ADR-004: Structure the baseline as a reusable module

## Status

Accepted

## Context and Problem Statement

The baseline has to run in every account, but each environment differs in budget, retention and state location. Copying the resource definitions into each root would fork them immediately: a fix in `dev` would not reach `prod`, and the two would drift until a security control exists in one account and not the other.

## Decision Drivers

- One definition of the baseline
- Per-environment inputs without conditionals
- Bounded, typed inputs
- A module other stacks can compose

## Considered Options

- A local module under `modules/baseline`
- Copy the resources into every root module
- A published registry module
- A Terragrunt-style generator

## Decision Outcome

We will define the baseline once in `modules/baseline`, with `main.tf`, `variables.tf`, `outputs.tf` and `versions.tf` at its root, and call it from each environment with explicit inputs.

Every input is typed and validated where the domain is bounded, so a bad value fails at plan time in the caller's context rather than inside the module.

## Consequences

- Positive: a control added once reaches every environment at its next apply.
- Positive: the module is small enough to test with mock providers.
- Negative: outputs must be curated; the module cannot expose resources it does not name.
- Neutral: a registry module would add supply-chain surface this stack does not need.

## References

- `docs/specs/delivery/terraform.md` rules 13-14
