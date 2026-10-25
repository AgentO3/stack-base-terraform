# BDR-004: Public S3 access is blocked account-wide

## Status

Accepted

## Behavior

A bucket in a managed account cannot be made public, even by a policy that asks for it.

## Context

Public buckets are the most common cause of AWS data exposure. Account-level Block Public Access closes the failure mode for buckets that do not yet exist and for policies written later.

## Acceptance Criteria

- All four account-level public access block switches are on.
- Every bucket the stack creates also has the four bucket-level switches on.
- A put-bucket-policy that grants public access is rejected.

## Verification

### Scenario: Public policy is rejected

- **Given** the baseline applied
- **When** an operator applies a bucket policy with `Principal: "*"`
- **Then** the request fails with `AccessDenied` because of the account-level block
