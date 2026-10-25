#!/usr/bin/env bash
# Verify ADR-005 — Scope the AWS baseline to audit, guardrails and budget.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

main="modules/baseline/main.tf"

file_has "$main" 'resource "aws_kms_key" "logs"' "dedicated audit KMS key"
file_has "$main" 'enable_key_rotation[[:space:]]*=[[:space:]]*true' "audit key rotation enabled"
file_has "$main" 'resource "aws_s3_bucket" "logs"' "audit log bucket"
file_has "$main" 'resource "aws_s3_bucket_public_access_block" "logs"' "bucket public access block"
file_has "$main" 'resource "aws_s3_account_public_access_block" "main"' "account public access block"
file_has "$main" 'resource "aws_cloudtrail" "main"' "CloudTrail trail"
file_has "$main" 'is_multi_region_trail[[:space:]]*=[[:space:]]*true' "trail is multi-Region"
file_has "$main" 'enable_log_file_validation[[:space:]]*=[[:space:]]*true' "trail validates log files"
file_has "$main" 'resource "aws_cloudwatch_log_group" "trail"' "trail CloudWatch log group"
file_has "$main" 'retention_in_days[[:space:]]*=[[:space:]]*var\.log_retention_days' "log retention is explicit"
file_has "$main" 'resource "aws_config_configuration_recorder" "main"' "AWS Config recorder"
file_has "$main" 'resource "aws_config_configuration_recorder_status" "main"' "AWS Config recording status"
file_has "$main" 'resource "aws_budgets_budget" "monthly"' "monthly cost budget"
file_has "$main" 'notification_type[[:space:]]*=[[:space:]]*"FORECASTED"' "forecasted budget alert"
file_has "$main" 'notification_type[[:space:]]*=[[:space:]]*"ACTUAL"' "actual budget alert"

# Every bucket must have an encryption configuration.
buckets="$(grep -c 'resource "aws_s3_bucket" "' "$main")"
encrypted="$(grep -c 'resource "aws_s3_bucket_server_side_encryption_configuration" "' "$main")"
if [ "$buckets" -gt 0 ] && [ "$buckets" -eq "$encrypted" ]; then
	check_pass "every bucket is encrypted ($buckets/$buckets)"
else
	check_fail "every bucket is encrypted" "buckets=$buckets encrypted=$encrypted"
fi

# The baseline must not create long-lived users or keys.
if grep -Eq 'resource "aws_iam_(user|access_key)"' "$main"; then
	check_fail "no IAM user or access key" "found in $main"
else
	check_pass "no IAM user or access key"
fi

if have_tools terraform; then
	run_cmd VAL_OUT VAL_ERR VAL_CODE -- terraform -chdir=modules/baseline validate
	check "terraform validate (baseline module)" "$VAL_CODE" \
		"$(printf '%s%s' "$VAL_OUT" "$VAL_ERR" | tail -c 200 | tr '\n' ' ')"
else
	check_skip "terraform validate (baseline module)" "terraform not on PATH"
fi

report_and_exit "ADR-005 — AWS baseline"
