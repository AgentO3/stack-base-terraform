#!/usr/bin/env bash
# Verify ADR-006 — Authenticate CI with GitHub OIDC.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

main="modules/baseline/main.tf"

file_has "$main" 'resource "aws_iam_openid_connect_provider" "github"' "GitHub OIDC provider"
file_has "$main" 'token\.actions\.githubusercontent\.com' "GitHub OIDC issuer referenced"
file_has "$main" '"sts:AssumeRoleWithWebIdentity"' "trust uses AssumeRoleWithWebIdentity"
file_has "$main" 'token\.actions\.githubusercontent\.com:aud' "trust checks the audience"
file_has "$main" 'token\.actions\.githubusercontent\.com:sub' "trust checks the subject"
file_has "$main" 'repo:\$\{var\.github_repository\}:ref:refs/heads/\$\{var\.github_branch\}' \
	"trust is scoped to repository and branch"

# No long-lived AWS credentials anywhere in the stack.
keys="$(grep -REl 'AKIA[0-9A-Z]{16}' --exclude-dir=.terraform --exclude-dir=.git . 2>/dev/null)"
if [ -z "$keys" ]; then
	check_pass "no AWS access key id in the tree"
else
	check_fail "no AWS access key id in the tree" "found in: $(echo "$keys" | tr '\n' ' ')"
fi

if grep -Eq 'resource "aws_iam_(user|access_key)"' "$main"; then
	check_fail "no IAM user or access key resource" "found in $main"
else
	check_pass "no IAM user or access key resource"
fi

report_and_exit "ADR-006 — OIDC workload identity"
