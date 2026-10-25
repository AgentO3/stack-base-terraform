# Verifiers

Bash scripts that check whether the stack conforms to each ADR and whether the BDR records are well formed.

## Layout

- `lib.sh` — shared helpers: colour output, pass/fail/skip recording, file and section assertions, command capture. Source it; do not run it.
- `adr-NNN-<topic>.sh` — one script per ADR. Exit `0` if every assertion passes, `1` if any fails.
- `bdr-contracts.sh` — checks that every BDR has the required sections, an Accepted status and an index entry.
- `verify-all.sh` — runs every verifier in order and exits nonzero if any fails.

## Usage

```bash
bash verify/adr-006-oidc.sh      # one verifier
bash verify/verify-all.sh        # everything
make verify                      # same, through the Makefile
```

## Conventions

- POSIX-portable `bash`; `grep`, `awk` and `find` only.
- Static checks always run. Tool-dependent checks (`terraform fmt`, `terraform validate`) report `SKIP` when the tool is not on `PATH`, so the verifier stays useful in a minimal sandbox.
- `.shellcheckrc` disables `SC1091` for the `lib.sh` source line; every other warning is an error.

## Output

```
== ADR-006 — OIDC workload identity ==
  PASS  GitHub OIDC provider
  PASS  trust checks the subject
  ...
  8/8 passed
```

Exit code matches the gate intent: `0` clean, `1` failure.
