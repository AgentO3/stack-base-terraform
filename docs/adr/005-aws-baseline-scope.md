# ADR-005: Scope the AWS baseline to audit, guardrails and budget

## Status

Accepted

## Context and Problem Statement

"Baseline" can mean anything from a landing zone to every service an application will ever need. A stack that tries to own identity, networking and workloads becomes an internal platform with its own release cadence, and the application stacks that should extend it cannot. The `platform/aws` spec lists seventeen rules; this stack must decide which of them belong to the floor and which belong to the workload.

## Decision Drivers

- Every account needs the same controls before any workload lands
- Workload stacks must be able to extend without forking the baseline
- Controls must be testable without credentials
- Scope creep makes the base stack undeliverable

## Considered Options

- Audit, account guardrails and budget only
- The full landing zone, including Organizations, SCPs and networking
- A thin tagging convention with no resources

## Decision Outcome

We will own the controls that are identical in every account and independent of workload: a rotated KMS key, an encrypted and versioned audit bucket, a multi-Region CloudTrail with log-file validation and CloudWatch/SNS delivery, an AWS Config recorder, the account-level S3 public access block, a monthly budget with SNS alerts, and the OIDC deploy role.

Organisations, SCPs, IAM Identity Center, VPC design and workload resources stay outside. They are either account-founding decisions made once by a different process or application concerns.

## Consequences

- Positive: the module is small enough to test entirely with mock providers.
- Positive: a workload stack can be dropped into any environment this baseline has prepared.
- Negative: region allowlisting is enforced only by variable validation, not by an SCP, because SCPs belong to the organization layer.
- Negative: the Foundational Security Best Practices conformance pack is not attached; a security stack must add it.
- Neutral: the boundary is documented in the README's gap list, so the next stack knows what to add.

## Pros and Cons of the Options

### Audit, guardrails and budget only

- Good, because it is identical in every account and testable offline.
- Bad, because it does not stop a workload from deploying to an unapproved Region.

### Full landing zone

- Good, because it enforces every rule in one place.
- Bad, because it needs organization-level access and a separate release cadence.

### Tagging convention only

- Good, because it is trivial to adopt.
- Bad, because it provides no audit trail and no spend guardrail.

## References

- `docs/specs/platform/aws.md`
- `README.md` (gap list)
