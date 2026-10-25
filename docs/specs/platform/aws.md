---
id: aws
layer: platform
extends: []
---

# Amazon Web Services (AWS)

## Purpose

AWS is a multi-tenant cloud platform whose default settings optimize for "anything is possible" rather than "the right thing is easy" — a fresh account can spin up a public S3 bucket, an unencrypted RDS instance, an `0.0.0.0/0` security group, and a long-lived `AKIA…` access key in under a minute, and every one of those defaults has been a real-world breach. Without an opinionated baseline, teams reinvent the same controls badly: console-applied changes drift from IaC, IAM users with hard-coded keys leak through `git push`, dev workloads share an account with prod and trip across each other, log retention defaults to "Never expire" while the budget defaults to "Never alert," and the root user becomes the daily driver. This spec pins the cross-service AWS baseline — multi-account organization, IaC-managed provisioning, federated human access, workload IAM via OIDC/instance roles, region allowlisting, KMS-by-default, S3 public-access blocks, baseline tagging, log retention, automated cross-region backups, and budget alerts — so individual service specs (RDS, Lambda, ECS, etc.) can refine on top of a known floor instead of redefining it.

## References

- **external** `https://aws.amazon.com/` — AWS home
- **external** `https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html` — AWS Well-Architected Framework
- **external** `https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html` — IAM best practices
- **external** `https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html` — AWS Organizations
- **external** `https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html` — IAM Identity Center (SSO)
- **external** `https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html` — CloudTrail
- **external** `https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-fsbp.html` — AWS Foundational Security Best Practices
- **external** `https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html` — S3 Block Public Access
- **external** `https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html` — Secrets Manager
- **external** `https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html` — AWS Backup
- **external** `https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html` — AWS Budgets

## Rules

1. Manage production AWS resources via Infrastructure as Code (OpenTofu, Terraform, AWS CDK, or CloudFormation); do not provision production resources through the AWS Console. (refs: opentofu)
2. Use AWS Organizations with separate accounts for production, staging, development, and shared services; do not run production and non-production workloads in the same AWS account.
3. Federate human access through AWS IAM Identity Center backed by the organization's identity provider; do not create long-lived IAM users for human operators.
4. Authenticate workloads via IAM roles assumed through OIDC, workload-identity federation, or EC2/ECS/EKS/Lambda execution roles; do not embed long-lived access keys (`AKIA…`) in source, config, container images, or CI secret stores.
5. Pin each workload's deployment regions explicitly and enforce the allowlist via an organization SCP; do not deploy resources to a region the team has not approved.
6. Enable CloudTrail management-event logging in every account with logs centralized to a dedicated, write-protected logging account; do not operate an account without CloudTrail enabled.
7. Enable AWS Config plus the AWS Foundational Security Best Practices conformance pack (or AWS Security Hub) in every account; do not silence Config or Security Hub findings without a documented, time-bounded exception.
8. Encrypt data at rest with KMS for every storage service (S3, EBS, RDS, Aurora, DynamoDB, EFS, Redshift); do not create unencrypted buckets, volumes, or databases.
9. Enable S3 Block Public Access at the account level with all four switches on (`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`); do not create publicly readable S3 buckets without a documented, reviewed exception.
10. Lock the AWS account root user with MFA and a break-glass-vaulted credential, and use root only for the tasks AWS documents as root-only; do not perform routine operations as root.
11. Do not configure security groups that allow `0.0.0.0/0` (or `::/0`) ingress on application ports; route public traffic through an ALB, NLB, API Gateway, or CloudFront distribution.
12. Store secrets in AWS Secrets Manager or SSM Parameter Store (SecureString) and retrieve them at runtime via the workload's IAM role; do not place secrets in Lambda environment variables, ECS task-definition plaintext environment fields, or `.env` files baked into container images.
13. Apply the team's baseline tag set (e.g. `Environment`, `Owner`, `CostCenter`, `Application`) to every taggable resource at create time; do not deploy resources to production missing the baseline tag set.
14. Set an explicit retention period on every CloudWatch Logs log group and a lifecycle policy on every log/data S3 bucket; do not let log retention default to "Never expire."
15. Enable automated backups with cross-region copy for production stateful resources (RDS automated backups + cross-region snapshot copy, DynamoDB PITR or global tables, EBS snapshot lifecycle, S3 cross-region replication for irreplaceable data); do not rely on a single-region copy as the sole backup.
16. Configure AWS Budgets with at least one alert per account wired to an on-call channel; do not run a production account without a budget alert.
17. Scope IAM policies to specific resources and actions following least privilege; do not attach `AdministratorAccess` (or `Action: "*"` + `Resource: "*"` policies) to roles that are not designated break-glass.
