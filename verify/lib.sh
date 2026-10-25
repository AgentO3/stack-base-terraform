#!/usr/bin/env bash
# Shared helpers for verify/*.sh. Source from other scripts; do not run directly.

if [ -z "${STACK_ROOT-}" ]; then
	STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
	export STACK_ROOT
fi

if [ -t 1 ]; then
	RED=$'\033[31m'
	GREEN=$'\033[32m'
	YELLOW=$'\033[33m'
	DIM=$'\033[2m'
	RESET=$'\033[0m'
else
	RED=""
	GREEN=""
	YELLOW=""
	DIM=""
	RESET=""
fi

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_SKIPPED=0
CHECKS_RESULTS=()

have_tools() {
	local t
	for t in "$@"; do
		command -v "$t" >/dev/null 2>&1 || return 1
	done
	return 0
}

_record() {
	local status="$1"
	local name="$2"
	local detail="${3-}"
	local mark
	case "$status" in
	pass)
		mark="${GREEN}PASS${RESET}"
		CHECKS_PASSED=$((CHECKS_PASSED + 1))
		;;
	fail)
		mark="${RED}FAIL${RESET}"
		CHECKS_FAILED=$((CHECKS_FAILED + 1))
		;;
	skip)
		mark="${YELLOW}SKIP${RESET}"
		CHECKS_SKIPPED=$((CHECKS_SKIPPED + 1))
		;;
	esac
	if [ -n "$detail" ]; then
		CHECKS_RESULTS[${#CHECKS_RESULTS[@]}]="${mark}  ${name} ${DIM}— ${detail}${RESET}"
	else
		CHECKS_RESULTS[${#CHECKS_RESULTS[@]}]="${mark}  ${name}"
	fi
}

check_pass() { _record "pass" "$1" "${2-}"; }
check_fail() { _record "fail" "$1" "${2-}"; }
check_skip() { _record "skip" "$1" "${2-}"; }

# check NAME STATUS [DETAIL] — STATUS 0 is pass, nonzero is fail.
check() {
	if [ "$2" -eq 0 ]; then
		_record "pass" "$1" "${3-}"
	else
		_record "fail" "$1" "${3-}"
	fi
}

# file_has FILE PATTERN [NAME] — pass when PATTERN appears in FILE.
file_has() {
	local file="$1"
	local pattern="$2"
	local name="${3:-$pattern in $file}"
	if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then
		check_pass "$name"
	else
		check_fail "$name" "missing in ${file}"
	fi
}

# file_lacks FILE PATTERN [NAME] — pass when PATTERN does not appear.
file_lacks() {
	local file="$1"
	local pattern="$2"
	local name="${3:-no $pattern in $file}"
	if [ ! -f "$file" ] || ! grep -Eq "$pattern" "$file"; then
		check_pass "$name"
	else
		check_fail "$name" "found in ${file}"
	fi
}

# file_has_section FILE HEADING [NAME] — pass when a markdown heading exists.
file_has_section() {
	local file="$1"
	local heading="$2"
	local name="${3:-$heading section}"
	if [ -f "$file" ] && grep -Fqx "## ${heading}" "$file"; then
		check_pass "$name"
	else
		check_fail "$name" "missing in ${file}"
	fi
}

run_cmd() {
	local out_var="$1"
	local err_var="$2"
	local code_var="$3"
	shift 3
	[ "$1" = "--" ] && shift
	local tmp_out tmp_err code
	tmp_out="$(mktemp)"
	tmp_err="$(mktemp)"
	"$@" >"$tmp_out" 2>"$tmp_err"
	code=$?
	eval "$out_var=\$(cat \"\$tmp_out\")"
	eval "$err_var=\$(cat \"\$tmp_err\")"
	eval "$code_var=$code"
	rm -f "$tmp_out" "$tmp_err"
}

report_and_exit() {
	local title="$1"
	echo
	echo "== ${title} =="
	local i=0
	local n=${#CHECKS_RESULTS[@]}
	while [ "$i" -lt "$n" ]; do
		echo "  ${CHECKS_RESULTS[$i]}"
		i=$((i + 1))
	done
	local total=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_SKIPPED))
	if [ "$CHECKS_FAILED" -eq 0 ]; then
		echo "${GREEN}${CHECKS_PASSED}/${total} passed${RESET}"
		exit 0
	else
		echo "${RED}${CHECKS_FAILED} of ${total} checks failed${RESET}"
		exit 1
	fi
}
