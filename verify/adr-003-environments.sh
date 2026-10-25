#!/usr/bin/env bash
# Verify ADR-003 — Separate environments by directory.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

for env in dev prod; do
	if [ -d "environments/$env" ]; then
		check_pass "environments/$env is a root module"
	else
		check_fail "environments/$env is a root module" "directory missing"
	fi

	file_has "environments/$env/main.tf" "name_prefix[[:space:]]*=[[:space:]]*\"base-$env\"" \
		"$env has its own resource prefix"
	file_has "environments/$env/main.tf" 'source[[:space:]]*=[[:space:]]*"\.\./\.\./modules/baseline"' \
		"$env calls the shared baseline module"
done

# Environment switching through count/for_each in a root is forbidden.
if grep -REq 'module[[:space:]]+"baseline"[[:space:]]*\{[^}]*count[[:space:]]*=' environments/ 2>/dev/null; then
	check_fail "no count/for_each environment switch" "module baseline uses count"
else
	check_pass "no count/for_each environment switch"
fi

# The two roots must not share a state key.
key_dev="$(grep -E '^key' environments/dev/backend.hcl.example 2>/dev/null)"
key_prod="$(grep -E '^key' environments/prod/backend.hcl.example 2>/dev/null)"
if [ -n "$key_dev" ] && [ -n "$key_prod" ] && [ "$key_dev" != "$key_prod" ]; then
	check_pass "dev and prod use different state keys"
else
	check_fail "dev and prod use different state keys" "keys are equal or missing"
fi

file_has README.md 'environments/dev/' "README documents the environment layout"

report_and_exit "ADR-003 — Environments"
