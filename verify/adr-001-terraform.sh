#!/usr/bin/env bash
# Verify ADR-001 — Adopt Terraform as the infrastructure substrate.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

for env in dev prod; do
	root="environments/$env"
	for f in versions.tf main.tf variables.tf outputs.tf; do
		if [ -f "$root/$f" ]; then
			check_pass "$root/$f present"
		else
			check_fail "$root/$f present" "file not found"
		fi
	done

	file_has "$root/versions.tf" 'required_version[[:space:]]*=[[:space:]]*"= [0-9]+\.[0-9]+\.[0-9]+"' \
		"$env pins the Terraform CLI exactly"

	file_has "$root/versions.tf" 'source[[:space:]]*=[[:space:]]*"hashicorp/aws"' \
		"$env declares the AWS provider"

	if [ -f "$root/.terraform.lock.hcl" ]; then
		check_pass "$env lockfile committed"
	else
		check_fail "$env lockfile committed" "missing $root/.terraform.lock.hcl"
	fi
done

stray=""
for f in template.yaml template.yml cdk.json app.py serverless.yml; do
	[ -e "$f" ] && stray="${stray:+$stray, }$f"
done
if [ -z "$stray" ]; then
	check_pass "no competing IaC definition at the stack root"
else
	check_fail "no competing IaC definition at the stack root" "found: $stray"
fi

if have_tools terraform; then
	run_cmd FMT_OUT FMT_ERR FMT_CODE -- terraform fmt -check -recursive .
	check "terraform fmt -check exits 0" "$FMT_CODE" \
		"$(printf '%s%s' "$FMT_OUT" "$FMT_ERR" | head -c 200 | tr '\n' ' ')"
else
	check_skip "terraform fmt -check" "terraform not on PATH"
fi

report_and_exit "ADR-001 — Terraform"
