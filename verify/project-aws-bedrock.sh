#!/usr/bin/env bash
# Verify the aws-bedrock project keeps the projects/ contract.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

project="projects/aws-bedrock"

for f in README.md versions.tf main.tf variables.tf outputs.tf backend.hcl.example; do
	if [ -f "$project/$f" ]; then
		check_pass "$project/$f present"
	else
		check_fail "$project/$f present" "file not found"
	fi
done

file_has "$project/versions.tf" 'required_version[[:space:]]*=[[:space:]]*"= 1\.11\.4"' \
	"project pins the Terraform CLI exactly"
file_has "$project/backend.hcl.example" '^key[[:space:]]*=[[:space:]]*"base-terraform/projects/aws-bedrock/' \
	"project uses its own state key"

# The project must not re-create the baseline floor.
if grep -Eq 'resource "aws_(cloudtrail|config_configuration_recorder|budgets_budget|s3_account_public_access_block)"' "$project/main.tf" 2>/dev/null; then
	check_fail "project does not re-create baseline resources" "baseline resource found"
else
	check_pass "project does not re-create baseline resources"
fi

file_has "$project/main.tf" 'resource "aws_bedrock_guardrail" "main"' "guardrail defined"
file_has "$project/main.tf" 'resource "aws_bedrock_guardrail_version" "main"' "guardrail version published"
file_has "$project/main.tf" 'PROMPT_ATTACK' "prompt-attack filter configured"
file_has "$project/main.tf" 'US_SOCIAL_SECURITY_NUMBER' "SSN blocked"
file_has "$project/main.tf" 'resource "aws_bedrock_model_invocation_logging_configuration" "main"' "prompt logging configured"
file_has "$project/main.tf" 'resource "aws_cloudwatch_metric_alarm" "model"' "per-model alarms defined"
# shellcheck disable=SC2016 # HCL interpolation, not shell expansion
file_has "$project/main.tf" 'foundation-model/\$\{model\}' "invoke policy targets foundation-model ARNs"
file_has "$project/main.tf" 'AssumeRoleWithWebIdentity' "deploy role uses OIDC"
# shellcheck disable=SC2016 # HCL interpolation, not shell expansion
file_has "$project/main.tf" 'repo:\$\{var\.github_repository\}:ref:refs/heads/\$\{var\.github_branch\}' \
	"deploy role is scoped to repository and branch"

file_has "$project/README.md" 'BDR-001' "README names the BDRs it must preserve"
file_has "$project/README.md" 'terraform.tfstate' "README documents the state key"

if [ -f "$project/tests/bedrock.tftest.hcl" ]; then
	check_pass "project has Terraform contract tests"
else
	check_fail "project has Terraform contract tests" "tests/bedrock.tftest.hcl missing"
fi

file_has projects/README.md '\[aws-bedrock\]' "project is listed in the projects index"

if have_tools terraform; then
	run_cmd VAL_OUT VAL_ERR VAL_CODE -- terraform -chdir="$project" validate
	check "terraform validate ($project)" "$VAL_CODE" \
		"$(printf '%s%s' "$VAL_OUT" "$VAL_ERR" | tail -c 200 | tr '\n' ' ')"
else
	check_skip "terraform validate ($project)" "terraform not on PATH"
fi

report_and_exit "Project — aws-bedrock"
