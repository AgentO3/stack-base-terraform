# BDR-002: Remote state is encrypted and locked during a run

## Status

Accepted

## Behavior

A Terraform run against a shared environment holds an exclusive lock on that environment's state, and the state is unreadable without the account's KMS key.

## Context

Two concurrent applies can each believe they own the resource graph and the later write silently discards the earlier. State also records every attribute Terraform has read, some of which is sensitive.

## Acceptance Criteria

- A second `apply` against the same environment fails while the first holds the lock.
- The state object in S3 is encrypted with a customer-managed KMS key.
- No state file is present in the repository working tree.

## Verification

### Scenario: Concurrent apply is rejected

- **Given** one apply is in progress for `dev`
- **When** a second apply starts for `dev`
- **Then** it exits with a state-lock error and changes nothing

### Scenario: State is encrypted at rest

- **Given** the state bucket
- **When** an operator without `kms:Decrypt` reads the object
- **Then** access is denied
