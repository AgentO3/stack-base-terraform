# ADR-009: Use prek for local hooks

## Status

Accepted

## Context and Problem Statement

The CI gate is only useful if the same failures are caught before a pull request exists. A hook runner gives contributors that feedback, but two runners in one repository fight over `.git/hooks`, duplicate configuration and produce different results.

## Decision Drivers

- One hook runner per repository
- The same tool versions locally and in CI
- Secret detection before a commit, not after a push
- Configuration that is reviewed like code

## Considered Options

- prek with `prek.toml`
- Trunk Code Quality
- Upstream pre-commit
- Husky with ad-hoc scripts

## Decision Outcome

We will use prek, configured in a single `prek.toml`, with file-hygiene hooks, gitleaks, shellcheck, `terraform fmt`, `terraform validate`, Checkov, and Conventional Commits enforcement at the `commit-msg` stage.

Hook revisions are pinned to tags or commit SHAs. Trunk Code Quality is the mutually exclusive alternative; choosing it would mean deleting `prek.toml`, not running both.

## Consequences

- Positive: a contributor sees format, security and commit-message failures before the commit exists.
- Positive: the CI job runs the same `prek` command, so local and CI semantics match.
- Negative: hook environments must be cached in CI; rebuilding them on every run is slow.
- Negative: terraform and checkov hooks require those binaries on the developer machine.
- Neutral: `prek auto-update --check` keeps the pinned revisions current.

## References

- `docs/specs/quality/prek.md`
- `prek.toml`
