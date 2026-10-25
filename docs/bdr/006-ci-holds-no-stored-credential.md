# BDR-006: CI authenticates without a stored credential

## Status

Accepted

## Behavior

The CI workflow obtains AWS credentials only by exchanging a short-lived GitHub identity token, and only for the repository and branch named in the trust policy.

## Context

A static access key in repository secrets is valid everywhere, forever, and for anyone who can read the secret. OIDC replaces it with a credential that expires with the job and is bound to its origin.

## Acceptance Criteria

- No access key is stored in the repository, its secrets or its workflow files.
- The deploy role trusts `token.actions.githubusercontent.com` with an `aud` and `sub` condition.
- A run from another repository or branch cannot assume the role.
- Credentials expire when the job ends.

## Verification

### Scenario: Authorised branch assumes the role

- **Given** a workflow on `main` in the configured repository
- **When** it requests credentials with `permissions: id-token: write`
- **Then** it receives temporary credentials for the deploy role

### Scenario: Another branch is rejected

- **Given** a workflow on a feature branch
- **When** it requests the same role
- **Then** `sts:AssumeRoleWithWebIdentity` is denied
