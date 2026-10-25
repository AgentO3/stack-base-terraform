#!/usr/bin/env bash
# Verify ADR-009 — Use prek for local hooks.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f prek.toml ]; then
	check_pass "prek.toml present"
else
	check_fail "prek.toml present" "file missing"
fi

if [ -f .pre-commit-config.yaml ]; then
	check_fail "single hook runner" ".pre-commit-config.yaml competes with prek.toml"
else
	check_pass "single hook runner"
fi

file_has prek.toml 'gitleaks' "secret detection hook configured"
file_has prek.toml 'trailing-whitespace' "trailing-whitespace hook configured"
file_has prek.toml 'end-of-file-fixer' "end-of-file-fixer hook configured"
file_has prek.toml 'check-yaml' "check-yaml hook configured"
file_has prek.toml 'check-merge-conflict' "check-merge-conflict hook configured"
file_has prek.toml 'check-added-large-files' "check-added-large-files hook configured"
file_has prek.toml 'terraform_fmt' "terraform fmt hook configured"
file_has prek.toml 'terraform_validate' "terraform validate hook configured"
file_has prek.toml 'commit-msg' "commit-msg stage configured"

# Remote hooks must not track a branch.
if grep -Eq 'rev[[:space:]]*=[[:space:]]*"(main|master|HEAD)"' prek.toml 2>/dev/null; then
	check_fail "remote hooks pin a tag or SHA" "a rev points at a branch"
else
	check_pass "remote hooks pin a tag or SHA"
fi

file_has README.md 'prek install' "README documents prek install"

report_and_exit "ADR-009 — prek"
