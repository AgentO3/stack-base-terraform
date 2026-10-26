#!/usr/bin/env bash
# Verify ADR-010 — Lock Terraform state with S3 native lockfiles.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

# use_lockfile needs Terraform 1.10 or later.
if [ -f .terraform-version ]; then
	pinned="$(tr -d '[:space:]' < .terraform-version)"
	major="${pinned%%.*}"
	rest="${pinned#*.}"
	minor="${rest%%.*}"
	if [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -ge 10 ]; }; then
		check_pass "pinned CLI supports use_lockfile" "$pinned"
	else
		check_fail "pinned CLI supports use_lockfile" "$pinned is below 1.10"
	fi
else
	check_fail "pinned CLI supports use_lockfile" ".terraform-version missing"
fi

for root in environments/dev environments/prod projects/aws-bedrock; do
	example="$root/backend.hcl.example"
	file_has "$example" '^use_lockfile[[:space:]]*=[[:space:]]*true' \
		"$root locks state with an S3 lockfile"
	file_lacks "$example" '^dynamodb_table[[:space:]]*=' \
		"$root has no DynamoDB lock table"
done

for f in modules/baseline/main.tf projects/aws-bedrock/main.tf; do
	file_lacks "$f" 'dynamodb:' "$f deploy policy grants no DynamoDB action"
done

lock_refs="$(grep -rl 'state_lock_table' environments modules projects --include='*.tf' --include='*.hcl' 2>/dev/null)"
if [ -z "$lock_refs" ]; then
	check_pass "no state_lock_table input remains"
else
	check_fail "no state_lock_table input remains" "found in: $(echo "$lock_refs" | tr '\n' ' ')"
fi

file_has docs/adr/010-s3-native-state-locking.md '^Accepted$' "ADR-010 accepted"
file_has docs/adr/002-remote-state-in-s3.md '^Superseded by ADR-010$' "ADR-002 superseded by ADR-010"

report_and_exit "ADR-010 — S3 native state locking"
