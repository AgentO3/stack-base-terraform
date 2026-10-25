#!/usr/bin/env bash
# Verify ADR-002 — Keep Terraform state in S3 with DynamoDB locking.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

for env in dev prod; do
	root="environments/$env"
	file_has "$root/versions.tf" 'backend[[:space:]]+"s3"[[:space:]]*\{' \
		"$env declares an S3 backend"

	example="$root/backend.hcl.example"
	file_has "$example" '^encrypt[[:space:]]*=[[:space:]]*true' \
		"$env encrypts remote state"
	file_has "$example" '^dynamodb_table[[:space:]]*=' \
		"$env configures a lock table"
	file_has "$example" "^key[[:space:]]*=[[:space:]]*\"base-terraform/$env/" \
		"$env uses its own state key"
done

if grep -qx '\*.tfstate' .gitignore && grep -qx '\*.tfstate.\*' .gitignore; then
	check_pass ".gitignore excludes state files"
else
	check_fail ".gitignore excludes state files" "missing *.tfstate patterns"
fi

state_files="$(find . -name '*.tfstate' -not -path './.terraform/*' 2>/dev/null)"
if [ -z "$state_files" ]; then
	check_pass "no state file in the working tree"
else
	check_fail "no state file in the working tree" "found: $(echo "$state_files" | tr '\n' ' ')"
fi

if [ -f docs/adr/002-remote-state-in-s3.md ]; then
	check_pass "ADR-002 recorded"
else
	check_fail "ADR-002 recorded" "docs/adr/002-remote-state-in-s3.md missing"
fi

report_and_exit "ADR-002 — Remote state"
