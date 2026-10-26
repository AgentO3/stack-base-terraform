# Projects

Projects that consume the baseline. `modules/baseline` prepares an account — encryption, audit, guardrails, budget and a deploy role. A project puts a workload inside that prepared account.

The baseline is the floor, not the building. A project must not re-create the floor.

## What belongs here

One directory per project, kebab-case:

```
projects/<project-name>/
  README.md          # purpose, target environment, resources, BDRs it must preserve
  versions.tf        # only when the project has its own state
  main.tf
  variables.tf
  outputs.tf
```

A project without its own state can be documentation-only until it needs to apply.

## Rules

- **Do not re-create baseline resources.** The KMS key, audit bucket, trail, Config recorder, account public access block and budget belong to `modules/baseline`. Read them through module outputs or data sources.
- **Own state, own key.** A project with a Terraform root uses the same state bucket and S3 lockfile locking, with `key = "base-terraform/projects/<name>/terraform.tfstate"`.
- **Same gates.** Every project root passes `terraform fmt -check`, `terraform validate`, `terraform test` and Checkov before it merges.
- **Extend the deploy role deliberately.** The CI role is scoped to the baseline's services. A project that needs more must add the permissions as a reviewed change, not widen `Resource = "*"`.
- **Name the BDRs it must keep true** in its README, so a change that breaks one is visible in review.

## Projects

| Project | Environment | State key | Status |
| --- | --- | --- | --- |
| [aws-bedrock](aws-bedrock/README.md) | dev | `base-terraform/projects/aws-bedrock/terraform.tfstate` | Accepted |

Add a row when a project directory is created.
