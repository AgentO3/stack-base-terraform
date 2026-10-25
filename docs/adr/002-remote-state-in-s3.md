# ADR-002: Keep Terraform state in S3 with DynamoDB locking

## Status

Accepted

## Context and Problem Statement

Terraform state maps declarations to real resources. If two applies run against the same state, one silently overwrites the other's view of the account. If the state lives on a laptop, losing the laptop loses the mapping between code and infrastructure. The state also contains every attribute Terraform has read, including values that must not leak.

## Decision Drivers

- Concurrent-applier safety
- Encryption at rest
- Durability independent of any one machine
- Minimal new infrastructure before the first apply

## Considered Options

- S3 with DynamoDB locking
- HCP Terraform remote runs
- S3 with native lockfile locking
- Local state committed or copied

## Decision Outcome

We will store each environment's state in a versioned, KMS-encrypted S3 bucket and lock it with a DynamoDB table named by the environment.

S3 is already in every account, DynamoDB gives a hard lock, and both are managed by AWS without a third-party control plane. HCP Terraform is a reasonable alternative but adds a vendor and a second source of truth for runs.

## Consequences

- Positive: an apply takes a lock and fails fast if another run holds it.
- Positive: state survives any developer machine.
- Negative: the bucket and table must exist before the first `init`, so they are created once by hand and documented in the README.
- Negative: DynamoDB locking requires Terraform 1.8; native S3 lockfiles need 1.10 and are a later option.
- Neutral: state is still a single point of failure, mitigated by versioning and lifecycle rules.

## Pros and Cons of the Options

### S3 with DynamoDB locking

- Good, because it needs no vendor and no new account.
- Bad, because the bootstrap is manual.

### HCP Terraform remote runs

- Good, because runs are recorded and access is managed centrally.
- Bad, because it adds a third-party dependency and a second place to look for state.

### S3 with native lockfile locking

- Good, because it removes DynamoDB.
- Bad, because it requires Terraform 1.10+, above the pinned CLI.

### Local state

- Good, because it needs no setup.
- Bad, because it cannot support more than one operator safely.

## References

- `docs/specs/delivery/terraform.md` rules 4-5
- `https://developer.hashicorp.com/terraform/language/state/remote`
