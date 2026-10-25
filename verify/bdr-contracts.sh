#!/usr/bin/env bash
# Verify the BDR contract: every record has the required sections and is indexed.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

index="docs/bdr/README.md"

if [ -f "$index" ]; then
	check_pass "BDR index present"
else
	check_fail "BDR index present" "$index missing"
fi

found=0
for file in docs/bdr/[0-9][0-9][0-9]-*.md; do
	[ -e "$file" ] || continue
	base="$(basename "$file" .md)"
	case "$base" in
	000-template) continue ;;
	esac
	found=$((found + 1))
	number="${base%%-*}"

	file_has "$file" "^# BDR-${number}: " "BDR-$number heading matches its file name"
	file_has_section "$file" "Status" "BDR-$number has Status"
	file_has_section "$file" "Behavior" "BDR-$number has Behavior"
	file_has_section "$file" "Context" "BDR-$number has Context"
	file_has_section "$file" "Acceptance Criteria" "BDR-$number has Acceptance Criteria"
	file_has_section "$file" "Verification" "BDR-$number has Verification"

	status="$(awk '/^## Status$/{f=1;next} f&&NF{print;exit}' "$file" 2>/dev/null)"
	if [ "$status" = "Accepted" ]; then
		check_pass "BDR-$number status is Accepted"
	else
		check_fail "BDR-$number status is Accepted" "actual: ${status:-<missing>}"
	fi
	file_has "$index" "\[BDR-$number\]" "BDR-$number is listed in the index"
done

if [ "$found" -ge 1 ]; then
	check_pass "BDR records present" "$found records"
else
	check_fail "BDR records present" "none found"
fi

report_and_exit "BDR contracts"
