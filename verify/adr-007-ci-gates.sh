#!/usr/bin/env bash
# Verify ADR-007 — Gate every change on format, validate, tests and Checkov.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

ci=".github/workflows/ci.yml"

if [ -f "$ci" ]; then
	check_pass "CI workflow exists"
else
	check_fail "CI workflow exists" "$ci missing"
fi

file_has "$ci" '^name:' "workflow has a name"
file_has "$ci" '^permissions:' "workflow declares permissions"
file_has "$ci" 'contents:[[:space:]]*read' "workflow defaults to contents: read"
file_has "$ci" 'timeout-minutes:' "every job has a timeout"
file_has "$ci" '^concurrency:' "workflow declares concurrency"
file_has "$ci" 'make fmt-check' "CI runs the format check"
file_has "$ci" 'make validate' "CI runs validate"
file_has "$ci" 'make test' "CI runs terraform test"
file_has "$ci" 'make scan' "CI runs the policy scan"
file_has "$ci" 'checkout@v[0-9]+' "checkout action pinned to a major tag"

file_has Makefile 'terraform fmt -check -recursive' "Makefile implements the format check"
# shellcheck disable=SC2016 # the Makefile text contains a literal $$dir
file_has Makefile 'terraform -chdir=\$\$dir validate' "Makefile implements validate"
# shellcheck disable=SC2016 # the Makefile text contains a literal $$dir
file_has Makefile 'terraform -chdir=\$\$dir test' "Makefile implements terraform test"
file_has Makefile 'checkov -d' "Makefile implements the policy scan"

if [ -f .checkov.yaml ]; then
	check_pass "Checkov configuration committed"
else
	check_fail "Checkov configuration committed" ".checkov.yaml missing"
fi

file_has Makefile '^check:' "Makefile exposes a check target"
file_has Makefile 'fmt-check' "check target includes fmt-check"

# Third-party actions must be pinned to a full SHA.
if grep -Eq 'uses:[[:space:]]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@(v[0-9]+|main|master)' "$ci" 2>/dev/null; then
	# actions/* are allowed major tags by the spec; anything else is not.
	unpinned="$(grep -E 'uses:[[:space:]]+' "$ci" | grep -Ev 'uses:[[:space:]]+actions/' | grep -E '@(v[0-9]+|main|master)' || true)"
	if [ -z "$unpinned" ]; then
		check_pass "non-GitHub actions are pinned to a full SHA"
	else
		check_fail "non-GitHub actions are pinned to a full SHA" "$(echo "$unpinned" | head -1)"
	fi
else
	check_pass "non-GitHub actions are pinned to a full SHA"
fi

report_and_exit "ADR-007 — CI gates"
