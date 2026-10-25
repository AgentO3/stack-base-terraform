#!/usr/bin/env bash
# Regenerate the evidence bundle from the current working tree.
#
# Writes only under evidence/. Every artifact is produced by a command that a
# reviewer can rerun; nothing here is hand-written except the README.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/evidence"
mkdir -p "$OUT"
cd "$ROOT" || exit 2

CHECKOV_SPEC="checkov==3.2.520"

# --- 1. Provenance (captured before this script writes anything) ----------

worktree_before="$(git status --porcelain -- . ':(exclude)evidence' | wc -l | tr -d ' ')"
{
	echo "generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "branch: $(git branch --show-current)"
	echo "source_commit: $(git rev-parse HEAD)"
	echo "source_commit_subject: $(git log -1 --pretty=%s)"
	echo "remote: $(git remote get-url origin 2>/dev/null || echo none)"
	echo "changed_paths_before_generation: ${worktree_before}"
} >"$OUT/provenance.txt"

{
	echo "generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "terraform: $(terraform version -json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["terraform_version"])' 2>/dev/null || echo unknown)"
	echo "checkov_spec: ${CHECKOV_SPEC}"
	echo "uvx: $(uvx --version 2>/dev/null | head -1 || echo unknown)"
	echo "gh: $(gh --version 2>/dev/null | head -1 || echo unknown)"
	echo "os: $(uname -srm)"
} >"$OUT/tooling.txt"

# --- 2. Local gates --------------------------------------------------------

results=()

run_gate() {
	local name="$1"
	local log="$2"
	shift 2
	"$@" >"$OUT/$log" 2>&1
	local code=$?
	if [ "$code" -eq 0 ]; then
		results+=("PASS  $name")
	else
		results+=("FAIL  $name (exit $code)")
	fi
	return 0
}

run_gate "make check" "make-check.log" make check

for dir in modules/baseline projects/aws-bedrock; do
	run_gate "terraform test $dir" "terraform-test-$(echo "$dir" | tr '/' '-').log" \
		terraform -chdir="$dir" test -no-color
done

run_gate "verify-all" "verify-all.log" bash verify/verify-all.sh

# --- 3. Policy scan, pinned to the CI version ------------------------------

rm -rf "$OUT/checkov" "$OUT/checkov.json"
uvx --from "$CHECKOV_SPEC" checkov -d . --framework terraform --compact --quiet \
	--output json --output-file-path "$OUT/checkov" >"$OUT/checkov.stdout.log" 2>&1
checkov_code=$?

raw_json="$(find "$OUT/checkov" -name '*.json' 2>/dev/null | head -1)"
if [ -n "$raw_json" ]; then
	python3 - "$raw_json" "$OUT/checkov-results.json" <<'PY'
import sys

source, destination = sys.argv[1], sys.argv[2]
with open(source, "rb") as fh:
    data = fh.read()
if not data.endswith(b"\n"):
    data += b"\n"
with open(destination, "wb") as fh:
    fh.write(data)
PY
fi
rm -rf "$OUT/checkov"

python3 - "$OUT/checkov-results.json" >"$OUT/checkov-summary.txt" <<'PY'
import json
import sys

try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
except (OSError, ValueError) as exc:
    print(f"could not read Checkov JSON: {exc}")
    raise SystemExit(0)

summary = data.get("summary", {})
results = data.get("results", {})
passed = summary.get("passed", len(results.get("passed_checks", [])))
failed = summary.get("failed", len(results.get("failed_checks", [])))
skipped = summary.get("skipped", len(results.get("skipped_checks", [])))
version = summary.get("checkov_version") or data.get("checkov_version") or "unknown"

print(f"checkov_version: {version}")
print(f"passed: {passed}")
print(f"failed: {failed}")
print(f"skipped: {skipped}")
print(f"resources_scanned: {summary.get('resource_count', 'unknown')}")
for check in results.get("failed_checks", []):
    print(f"FAILED {check.get('check_id')} {check.get('check_name')} {check.get('resource')}")
PY

if [ "$checkov_code" -eq 0 ]; then
	results+=("PASS  checkov ($CHECKOV_SPEC)")
else
	results+=("FAIL  checkov ($CHECKOV_SPEC, exit $checkov_code)")
fi

# --- 4. CI evidence for the source commit ---------------------------------

if command -v gh >/dev/null 2>&1; then
	run_json="$(gh run list --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" \
		--commit "$(git rev-parse HEAD)" --limit 1 --json databaseId,conclusion,status,headSha,url 2>/dev/null)"
	if [ -n "$run_json" ] && [ "$run_json" != "[]" ]; then
		printf '%s\n' "$run_json" | python3 -m json.tool >"$OUT/ci-run.json"
		conclusion="$(printf '%s' "$run_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["conclusion"])' 2>/dev/null)"
		if [ "$conclusion" = "success" ]; then
			results+=("PASS  CI run for source commit")
		else
			results+=("FAIL  CI run for source commit ($conclusion)")
		fi
	else
		echo "no CI run found for $(git rev-parse HEAD)" >"$OUT/ci-run.json"
		results+=("SKIP  CI run for source commit (not found)")
	fi
else
	echo "gh not installed" >"$OUT/ci-run.json"
	results+=("SKIP  CI run (gh not on PATH)")
fi

# --- 5. Inventory and manifest --------------------------------------------

{
	echo "tracked_files: $(git ls-files | grep -vc '^evidence/')"
	echo "adrs: $(find docs/adr -name '[0-9][0-9][0-9]-*.md' ! -name '000-template.md' | wc -l | tr -d ' ')"
	echo "bdrs: $(find docs/bdr -name '[0-9][0-9][0-9]-*.md' ! -name '000-template.md' | wc -l | tr -d ' ')"
	echo "specs: $(find docs/specs -name '*.md' | wc -l | tr -d ' ')"
	echo "verifiers: $(find verify -name 'adr-*.sh' -o -name 'bdr-*.sh' -o -name 'project-*.sh' | wc -l | tr -d ' ')"
	echo "terraform_roots: $(find . -name versions.tf -not -path './.terraform/*' -not -path '*/.terraform/*' | wc -l | tr -d ' ')"
	echo "test_runs: $(cat modules/baseline/tests/*.hcl projects/*/tests/*.hcl 2>/dev/null | grep -c 'run \"')"
} >"$OUT/inventory.txt"

if command -v sha256sum >/dev/null 2>&1; then
	hash_cmd=(sha256sum)
else
	hash_cmd=(shasum -a 256)
fi

git ls-files | grep -v '^evidence/' | while IFS= read -r file; do
	[ -f "$file" ] && "${hash_cmd[@]}" "$file"
done >"$OUT/manifest.sha256"

# --- 6. Verdict ------------------------------------------------------------

{
	echo "Evidence for source commit $(git rev-parse HEAD)"
	echo
	for line in "${results[@]}"; do
		echo "$line"
	done
	echo
	if printf '%s\n' "${results[@]}" | grep -q '^FAIL'; then
		echo "verdict: INCOMPLETE"
		exit_code=1
	else
		echo "verdict: COMPLETE"
		exit_code=0
	fi
	echo
	echo "Artifacts:"
	for artifact in "$OUT"/*; do
		name="$(basename "$artifact")"
		[ "$name" = "generate.sh" ] && continue
		echo "  $name"
	done
} >"$OUT/status.txt"

cat "$OUT/status.txt"
exit "$exit_code"
