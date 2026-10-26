# aws-bedrock

A foundation-model application baseline: guardrails, prompt logging, per-model alarms, and two narrowly scoped roles — one for application invocation, one for CI.

This project sits on top of the stack baseline. It assumes an account where `modules/baseline` has already applied the KMS, audit, Config and budget floor, and it does not re-create any of them.

## What it creates

| Concern | Resource | Guarantee |
| --- | --- | --- |
| Prompt encryption | `aws_kms_key.prompts` | Rotation on, 30-day deletion window |
| Prompt logging | `aws_bedrock_model_invocation_logging_configuration.main` | Text delivery on, CloudWatch target |
| Log retention | `aws_cloudwatch_log_group.prompts` | Explicit `retention_in_days` |
| Content safety | `aws_bedrock_guardrail.main` | Hate, insults, sexual, violence, misconduct and prompt-attack filters at HIGH |
| Privacy | guardrail PII policy | Email and phone anonymised; SSN blocked |
| Topic control | guardrail topic policy | Investment advice denied |
| Version pinning | `aws_bedrock_guardrail_version.main` | Callers reference a published version, never `DRAFT` |
| Application access | `aws_iam_role.invoke` | `InvokeModel` scoped to the approved model ARNs only |
| CI access | `aws_iam_role.deploy` | OIDC trust scoped to one repository and branch, permissions scoped to this project |
| Operability | `aws_cloudwatch_metric_alarm.model` | Five alarms per monitored model: throttles, server errors, latency, input tokens, output tokens |

## Prerequisites

1. The stack baseline applied in the target account.
2. **Model access enabled** for each `model_ids` entry, in every Region you call. AWS grants this per account and per Region, and Terraform cannot manage it.
3. The GitHub OIDC provider that the baseline creates.
4. A `backend.hcl` from `backend.hcl.example`, with the shared state bucket and `use_lockfile = true`.

## State

```
key = "base-terraform/projects/aws-bedrock/terraform.tfstate"
```

## Inputs worth knowing

| Input | Default | Note |
| --- | --- | --- |
| `model_ids` | `["amazon.nova-lite-v1:0"]` | Models the application role may invoke |
| `alarm_model_ids` | same | Each model creates five alarms; keep this list short |
| `alarm_sns_topic_arn` | `""` | Pass the baseline budget topic to wire alarms to on-call |
| `create_deploy_role` | `true` | Set false when CI uses a centrally managed role |
| `log_retention_days` | `365` | 90 to 3653 |

## Outputs

`guardrail_id`, `guardrail_arn`, `guardrail_version`, `invoke_role_arn`, `prompt_log_group_name`, `deploy_role_arn`, `alarm_names`.

Callers must pass `guardrail_id` and the published `guardrail_version`; a `DRAFT` reference is not a contract.

## BDRs this project must preserve

- [BDR-001](../../docs/bdr/001-changes-go-through-a-reviewed-plan.md) — changes reach the account through a reviewed plan.
- [BDR-002](../../docs/bdr/002-state-is-encrypted-and-locked.md) — the project uses the shared encrypted, locked state.
- [BDR-006](../../docs/bdr/006-ci-holds-no-stored-credential.md) — CI assumes the project role through OIDC; no static keys.
- [BDR-003](../../docs/bdr/003-audit-logging-is-always-on.md) — prompt logging is additional audit, not a replacement for the trail and Config.

## Deliberately out of scope

- **Knowledge bases and vector stores.** A RAG store is a data-architecture decision (OpenSearch Serverless, Aurora pgvector, Neptune, S3 Vectors) with its own cost and residency profile. Add it as a separate project.
- **Provisioned Throughput.** Only justified by measured sustained load.
- **Custom and imported models.** Fine-tuning and distillation belong in a training project.
- **Cross-Region inference profiles.** A residency decision, not a default.
- **Model access and guardrail policy authorship.** The guardrail is a starting policy; the application owner owns its topics and filters.

## Verify

```bash
terraform -chdir=projects/aws-bedrock init -backend=false
terraform -chdir=projects/aws-bedrock validate
terraform -chdir=projects/aws-bedrock test
```

`make check` at the stack root covers all three, plus Checkov and the verifiers.
