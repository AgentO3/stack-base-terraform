# BDR-003: Audit logging is on in every environment

## Status

Accepted

## Behavior

Every API call in every account this stack manages is recorded to a durable, integrity-validated log that survives the account's own accidental deletion.

## Context

After an incident the first question is what changed and who changed it. Without a trail there is no answer. CloudTrail and AWS Config together provide the who and the what.

## Acceptance Criteria

- The trail is multi-Region and covers global service events.
- Log-file validation is enabled, and the log bucket is versioned and KMS-encrypted.
- AWS Config records all supported resource types and is actively recording.
- Log retention is an explicit number of days, never "never expire".

## Verification

### Scenario: Trail covers a new Region

- **Given** a baseline applied in `us-east-1`
- **When** a resource is created in `us-west-2`
- **Then** the event appears in the trail's S3 prefix

### Scenario: Log integrity is verifiable

- **Given** a trail with log-file validation enabled
- **When** `aws cloudtrail validate-logs` runs against the bucket
- **Then** it reports no invalid digest files
