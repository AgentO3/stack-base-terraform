#!/usr/bin/env bash
# Verify ADR-004 — Structure the baseline as a reusable module.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

for f in main.tf variables.tf outputs.tf versions.tf; do
	if [ -f "modules/baseline/$f" ]; then
		check_pass "modules/baseline/$f present"
	else
		check_fail "modules/baseline/$f present" "file not found"
	fi
done

# Count variables and type declarations; each variable must declare a type.
vars="$(grep -c '^variable "' modules/baseline/variables.tf 2>/dev/null)"
types="$(grep -c '^[[:space:]]*type[[:space:]]*=' modules/baseline/variables.tf 2>/dev/null)"
if [ "$vars" -gt 0 ] && [ "$vars" -eq "$types" ]; then
	check_pass "every module variable is typed ($vars/$vars)"
else
	check_fail "every module variable is typed" "variables=$vars types=$types"
fi

validations="$(grep -c 'validation[[:space:]]*{' modules/baseline/variables.tf 2>/dev/null)"
if [ "$validations" -ge 3 ]; then
	check_pass "bounded inputs carry validation blocks" "$validations validations"
else
	check_fail "bounded inputs carry validation blocks" "found $validations"
fi

outputs="$(grep -c '^output "' modules/baseline/outputs.tf 2>/dev/null)"
described="$(grep -c '^[[:space:]]*description[[:space:]]*=' modules/baseline/outputs.tf 2>/dev/null)"
if [ "$outputs" -gt 0 ] && [ "$outputs" -eq "$described" ]; then
	check_pass "every output has a description ($outputs/$outputs)"
else
	check_fail "every output has a description" "outputs=$outputs described=$described"
fi

if [ -f modules/baseline/tests/baseline.tftest.hcl ]; then
	check_pass "module has Terraform contract tests"
else
	check_fail "module has Terraform contract tests" "tests/baseline.tftest.hcl missing"
fi

report_and_exit "ADR-004 — Module layout"
