#!/usr/bin/env bash
# Verify ADR-008 — Pin the toolchain and refresh it with Renovate.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f .terraform-version ]; then
	pinned="$(tr -d '[:space:]' < .terraform-version)"
	check_pass ".terraform-version present" "$pinned"
	for env in dev prod; do
		file_has "environments/$env/versions.tf" "required_version[[:space:]]*=[[:space:]]*\"= $pinned\"" \
			"$env required_version matches .terraform-version"
	done
else
	check_fail ".terraform-version present" "file not found"
fi

for env in dev prod; do
	file_has "environments/$env/versions.tf" 'version[[:space:]]*=[[:space:]]*"~> [0-9]+\.[0-9]+\.[0-9]+"' \
		"$env provider uses a pessimistic constraint"
done

file_has modules/baseline/versions.tf 'version[[:space:]]*=[[:space:]]*"~> [0-9]+\.[0-9]+\.[0-9]+"' \
	"module provider uses a pessimistic constraint"

for env in dev prod; do
	if grep -q 'provider "registry.terraform.io/hashicorp/aws"' "environments/$env/.terraform.lock.hcl" 2>/dev/null; then
		check_pass "$env lockfile pins the AWS provider"
	else
		check_fail "$env lockfile pins the AWS provider" "no aws entry"
	fi
done

if [ -f renovate.json ]; then
	check_pass "renovate.json committed"
else
	check_fail "renovate.json committed" "file missing"
fi

# shellcheck disable=SC2016 # renovate.json contains a literal $schema key
file_has renovate.json '"\$schema"' "Renovate schema pinned"
file_has renovate.json '"timezone"' "Renovate timezone set"
file_has renovate.json '"schedule"' "Renovate schedule set"
file_has renovate.json '"prConcurrentLimit"' "Renovate concurrent PR limit set"
file_has renovate.json '"prHourlyLimit"' "Renovate hourly PR limit set"
file_has renovate.json '"dependencyDashboard"[[:space:]]*:[[:space:]]*true' "Renovate dashboard enabled"
file_has renovate.json '"vulnerabilityAlerts"' "Renovate vulnerability alerts enabled"

report_and_exit "ADR-008 — Pinned toolchain"
