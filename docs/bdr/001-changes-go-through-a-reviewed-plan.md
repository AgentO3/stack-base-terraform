# BDR-001: Infrastructure changes reach AWS only through a reviewed plan

## Status

Accepted

## Behavior

An infrastructure change cannot be applied to a shared environment until a human has reviewed the plan that produced it.

## Context

A plan is the only artifact that shows what will change before it changes. Applying a speculative plan from a laptop bypasses review and cannot be audited.

## Acceptance Criteria

- A pull request that changes HCL produces a plan artifact and a failed or pending check until a reviewer approves.
- Applying the same commit twice produces an empty plan the second time.
- No apply step exists outside the CI workflow.

## Verification

### Scenario: Unreviewed change is blocked

- **Given** a branch that changes `modules/baseline/main.tf`
- **When** the pull request is opened
- **Then** CI posts a plan and the merge button is blocked until approval

### Scenario: Approved change applies the reviewed plan

- **Given** an approved pull request
- **When** it merges to `main`
- **Then** CI applies the saved plan artifact and no other plan
