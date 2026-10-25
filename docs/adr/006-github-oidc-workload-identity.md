# ADR-006: Authenticate CI with GitHub OIDC

## Status

Accepted

## Context and Problem Statement

CI must create and change AWS resources. The easy path is an IAM user with an access key stored as a repository secret. That key is long-lived, works from anywhere, is copied into every fork and backup, and cannot be tied to a repository, a branch or a workflow run.

## Decision Drivers

- No long-lived credential in the repository or its secrets
- Permissions tied to a repository and branch
- Credentials that expire with the job
- A trust policy a reviewer can read

## Considered Options

- GitHub OIDC with a scoped IAM role
- An IAM user with an access key in repository secrets
- A self-hosted runner with an instance role
- A third-party secret broker

## Decision Outcome

We will create an IAM OIDC provider for `token.actions.githubusercontent.com` and a deploy role whose trust policy requires `aud = sts.amazonaws.com` and a `sub` matching `repo:<owner>/<name>:ref:refs/heads/<branch>`.

The role's permission policy is resource-scoped per service, so a compromised workflow cannot reach buckets or keys outside the stack's prefix.

## Consequences

- Positive: no static credential exists, so there is nothing to rotate or leak.
- Positive: a fork or another branch cannot assume the role.
- Negative: `pull_request` runs from forks cannot assume the role, so plans from forks do not run against AWS.
- Negative: the account's first OIDC provider is account-global; the module accepts an existing ARN to avoid a duplicate-provider error.
- Neutral: rotating the provider thumbprint is a Terraform change, not an outage.

## References

- `docs/specs/platform/aws.md` rules 3-4
- `docs/specs/delivery/github-actions.md` rule 10
- `https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect`
