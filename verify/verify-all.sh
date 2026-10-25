#!/usr/bin/env bash
# Run every ADR and BDR verifier under verify/. Exit nonzero if any fails.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPTS="
adr-001-terraform.sh
adr-002-remote-state.sh
adr-003-environments.sh
adr-004-module-layout.sh
adr-005-aws-baseline.sh
adr-006-oidc.sh
adr-007-ci-gates.sh
adr-008-toolchain.sh
adr-009-prek.sh
bdr-contracts.sh
project-aws-bedrock.sh
"

failed=0
total=0
for s in $SCRIPTS; do
	total=$((total + 1))
	bash "$SCRIPT_DIR/$s" || failed=$((failed + 1))
done

echo
if [ "$failed" -eq 0 ]; then
	echo "all $total verifiers passed"
	exit 0
else
	echo "$failed of $total verifiers failed"
	exit 1
fi
