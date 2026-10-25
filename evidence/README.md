# Evidence bundle

Machine-generated proof that the stack and the `aws-bedrock` project are in a complete, verified state.

Every file here except this README is written by [`generate.sh`](generate.sh) and can be reproduced with `make evidence`. Nothing is hand-edited; if a check fails, `status.txt` says `INCOMPLETE` and the run exits nonzero.

## What this evidence covers

The state recorded in [`provenance.txt`](provenance.txt): the branch, the source commit, and the remote. `manifest.sha256` hashes the working tree at generation time, so it describes exactly the content that was committed alongside this bundle.

## Completeness claims

| # | Claim | Evidence |
| --- | --- | --- |
| C1 | Every declared artifact exists: 4 Terraform roots, 9 ADRs, 6 BDRs, 12 specs, 11 verifiers | [`inventory.txt`](inventory.txt), [`manifest.sha256`](manifest.sha256) |
| C2 | HCL is canonically formatted and valid in every root | [`make-check.log`](make-check.log) — `fmt-check` and `validate` |
| C3 | 22 contract tests pass with mock providers and no AWS credentials | [`terraform-test-modules-baseline.log`](terraform-test-modules-baseline.log), [`terraform-test-projects-aws-bedrock.log`](terraform-test-projects-aws-bedrock.log) |
| C4 | The policy gate reports zero findings on the CI-pinned Checkov version | [`checkov-summary.txt`](checkov-summary.txt), [`checkov-results.json`](checkov-results.json) |
| C5 | Every ADR, BDR and project-contract verifier passes | [`verify-all.log`](verify-all.log) |
| C6 | GitHub CI passed the same gates on the same commit | [`ci-run.json`](ci-run.json) |
| C7 | No secrets, keys or state files entered the tree | `make-check.log` and `verify-all.log` — ADR-002 and ADR-006 checks |
| C8 | Decisions and observable behaviours are documented and indexed | [`inventory.txt`](inventory.txt) counts, `docs/adr/`, `docs/bdr/` |

The verdict is the last line of [`status.txt`](status.txt).

## What "complete" does not claim

- **Nothing has been applied to AWS.** There is no account in this evidence. `plan` and `apply` are skipped in CI until `AWS_ROLE_ARN` is configured and `backend.hcl` exists.
- **Model access is manual.** AWS grants Bedrock model access per account and per Region; Terraform cannot manage it.
- **Knowledge bases, Provisioned Throughput and cross-Region inference are out of scope**, by [the project's own README](../projects/aws-bedrock/README.md#deliberately-out-of-scope).
- **Three S3 hardening checks are waived**, with reasons in `.checkov.yaml`. `checkov-summary.txt` records the exact pass/fail/skip counts so the waiver is visible rather than hidden.

## Regenerate

```bash
make evidence
```

Requires `terraform` 1.8.4, `uvx`, `python3` and an authenticated `gh`. Checkov is pinned to the CI version (`checkov==3.2.520`) so the local result matches GitHub.

## Verify the manifest independently

```bash
cd .. && sha256sum -c evidence/manifest.sha256
# macOS: shasum -a 256 -c evidence/manifest.sha256
```

The manifest covers tracked files excluding `evidence/`, because evidence files cannot hash themselves.

## Reading the files

| File | Meaning |
| --- | --- |
| `status.txt` | PASS/FAIL per gate and the overall verdict |
| `provenance.txt` | Branch, source commit, remote, dirty-path count |
| `tooling.txt` | Exact tool versions used |
| `inventory.txt` | Counts of artefacts |
| `manifest.sha256` | SHA-256 of every tracked source file |
| `make-check.log` | Full output of `make check` |
| `verify-all.log` | Full output of all 11 verifiers |
| `checkov-results.json` | Raw Checkov results at the CI version |
| `ci-run.json` | GitHub run metadata for the source commit |
