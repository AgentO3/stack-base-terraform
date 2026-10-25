---
id: prek
layer: quality
extends: []
---

# prek

## Purpose

prek is a Rust-implemented, drop-in replacement for pre-commit that runs git-hook-driven linters, formatters, and scanners — and like the original, it is only as useful as its configuration is locked down. Hook repos pinned to `rev: main` (or `rev: master`) silently absorb whatever the upstream pushed today, which is how supply-chain payloads have ridden into a `pre-commit autoupdate` PR. Hooks installed locally but never run in CI become advisory; CI runs that don't mirror local hook semantics produce "works for me, fails on main" loops. `git commit --no-verify` to land a change converts the gate into theatre. Without baseline file-hygiene hooks, junk files accumulate; without a secret scanner, credentials end up in `git log`. Two competing hook frameworks (prek next to husky next to trunk) duplicate work, fight over hook ownership, and confuse contributors. This spec pins the configuration file, the hook-version pinning rule, the baseline hook set (file hygiene + per-language linters/formatters + secret detection), the CI mirror, the auto-update workflow, the local + CI cache discipline, and the prohibition on bypass and on stacking parallel runners — so a green prek run is a real statement that the change is shippable.

## References

- **spec** `trunk-code-quality` — sibling quality-layer spec for an alternative hook runner; pick one
- **spec** `conventional-commits` — practices-layer spec whose `commit-msg` enforcement runs as a prek hook
- **external** `https://prek.j178.dev/` — prek documentation
- **external** `https://prek.j178.dev/configuration/` — prek configuration reference
- **external** `https://github.com/j178/prek` — prek source
- **external** `https://pre-commit.com/` — upstream pre-commit (compatible config format)
- **external** `https://github.com/pre-commit/pre-commit-hooks` — Baseline file-hygiene hooks
- **external** `https://github.com/gitleaks/gitleaks` — gitleaks secret scanner

## Rules

1. Configure prek via a single `prek.toml` (TOML, recommended) or `.pre-commit-config.yaml` (YAML, pre-commit-compatible) at the repository root; do not split hook configuration across multiple files.
2. Pin the prek CLI version installed on developer machines and CI agents (project package manager, devbox, mise, or a pinned binary release); do not rely on an ambient `prek` install.
3. Pin every remote repo entry's `rev:` to a tagged release or a commit SHA; do not pin a remote `rev:` to a branch name (`main`, `master`, `HEAD`).
4. Run `prek install` once per repository and document it in the project's onboarding step (README, `make setup`, justfile target) so every contributor's local hooks are installed automatically.
5. Configure at least one formatter and/or linter hook for every language present in the repository (`ruff`, `prettier`, `eslint`, `gofmt`, `golangci-lint`, `shellcheck`, `hadolint`, etc.).
6. Configure a secret-detection hook (`gitleaks`, `trufflehog`, or equivalent); do not commit to a repository whose hooks do not scan for credentials.
7. Configure baseline file-hygiene hooks from `pre-commit/pre-commit-hooks` — at minimum `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-json`, `check-merge-conflict`, `check-added-large-files`.
8. Define language-native hooks under `repo: local` (or as `language: <lang>` entries) when the project's lockfile already pins the tool's version, so a single source of truth controls the version; do not pin the same tool in both prek's `rev:` and the project lockfile.
9. Scope each hook with `files:` / `exclude:` patterns matching only the files it should cover; do not let an expensive hook run on every file in a large monorepo by default.
10. Set `stages:` explicitly on each hook (`pre-commit`, `pre-push`, `commit-msg`, `manual`); do not rely on the implicit `pre-commit` default for a hook that is meaningful only at push or in CI.
11. Mirror the same prek configuration in CI by running `prek run --all-files --show-diff-on-failure` (or a changed-files run via `--from-ref` / `--to-ref`) and treat any hook failure as a build failure.
12. Run `prek auto-update --check` on a scheduled cadence (weekly or monthly) and open a PR with the resulting hook upgrades; do not let `rev:` pins drift unmaintained for months.
13. Cache prek's hook environments in CI keyed on the configuration file (`prek.toml` or `.pre-commit-config.yaml`); do not rebuild every hook environment on every CI job.
14. Do not bypass prek with `git commit --no-verify` or `git push --no-verify` to land work; fix the finding or update the configuration deliberately and commit the config change in the same PR.
15. Suppress individual findings inline at the violation site (e.g. `# noqa: <rule>`, `// eslint-disable-next-line <rule>`) with a short reason; do not add broad `exclude:` patterns that mask problems that should be fixed.
16. Use a single hook runner per repository — choose prek (or upstream pre-commit, or Trunk Code Quality) and remove the others; do not run two competing hook frameworks against the same set of tools. (refs: trunk-code-quality)
17. Implement Conventional Commits enforcement (`commitlint` or equivalent) as a `commit-msg` stage hook under prek; do not run commitlint via a parallel husky/lefthook installation alongside prek. (refs: conventional-commits)
