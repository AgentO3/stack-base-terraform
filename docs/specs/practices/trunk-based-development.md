---
id: trunk-based-development
layer: practices
extends: []
---

# Trunk-Based Development

## Purpose

Trunk-based development is the simplest branching model that supports continuous integration: one long-lived branch, every developer integrating to it daily, every commit on it releasable, incomplete work hidden behind feature flags rather than parked on a side branch. Without that discipline, teams default to GitFlow-shaped patterns whose costs they pay even when they don't say "GitFlow" out loud — long-running `develop` or `staging` branches that drift from `main`, week-long feature branches that hit merge hell on day five, release branches that accumulate fixes never back-ported to the trunk, "temporary" feature flags that outlive the engineer who introduced them, and a red trunk that nobody fixes because the next person can stack on top. Each of those breaks the property TBD exists to preserve: that `main` is shippable right now, by anyone, without a multi-day integration phase. This spec pins the trunk model — single trunk, daily integration, short-lived branches, releasable-by-default trunk, fix-forward via cherry-pick, feature-flagged incomplete work, branch protection, no force-push, small PRs, and a stop-the-line response to a broken build — so "merged to main" actually means "ready to ship."

## References

- **spec** `conventional-commits` — practices-layer commit-message format that pairs with TBD's squash-merge flow
- **spec** `tdd` — practices-layer testing discipline that underwrites "every trunk commit is releasable"
- **external** `https://trunkbaseddevelopment.com/` — Trunk-Based Development reference site (Paul Hammant)
- **external** `https://trunkbaseddevelopment.com/short-lived-feature-branches/` — Short-lived feature branches
- **external** `https://trunkbaseddevelopment.com/release-from-trunk/` — Release from trunk
- **external** `https://trunkbaseddevelopment.com/branch-by-abstraction/` — Branch by abstraction
- **external** `https://martinfowler.com/articles/branching-patterns.html` — Patterns for managing source code branches (Fowler)
- **external** `https://martinfowler.com/articles/feature-toggles.html` — Feature toggles (Fowler / Pete Hodgson)

## Rules

1. Maintain a single long-lived branch (typically `main`) as the trunk; do not maintain parallel long-lived `develop`, `integration`, `staging`, or `qa` branches.
2. Keep every commit on the trunk releasable — full CI passing (build, tests, lint, security scans) and deployable without further integration work.
3. Integrate every developer's work into the trunk at least once per working day; do not let a feature branch live longer than ~24 working hours without a merge back to the trunk.
4. Keep feature branches short-lived, single-author, and single-purpose (target lifetime under 1 day, hard cap 2–3 days); do not create multi-developer feature branches that diverge for a sprint.
5. Hide user-visible incomplete work behind feature flags (default-off) so it can land on the trunk without affecting production behavior; do not park half-finished features on a side branch.
6. Track every feature flag with an owner and an expected removal date (in a registry, flag-service metadata, or a project-wide code-comment standard); remove the flag and the dead code path once the feature has fully shipped or has been abandoned.
7. Land merges via squash-merge (or rebase-and-merge with cleaned messages) so the trunk holds one Conventional Commit per change; do not merge a series of WIP commits onto the trunk. (refs: conventional-commits)
8. Release from the trunk by default; cut a release branch only just-in-time when a customer or environment must pin a specific version, and cut it from the trunk (never from another release branch).
9. Apply hotfixes by committing the fix to the trunk first, then cherry-pick to the affected release branch; do not patch a release branch with a fix that has not landed on the trunk.
10. Delete release branches once their version is no longer supported; do not let abandoned release branches accumulate.
11. Protect the trunk with branch-protection rules requiring passing CI, at least one approving review, and (where practical) signed commits; do not allow direct pushes to the trunk from developer machines.
12. Forbid force-pushes and history rewrites to the trunk; do not let a merged commit's SHA change after the fact.
13. Disable the "merge commit" strategy on the trunk in repository settings; configure squash-merge or rebase-merge as the only available option.
14. Keep pull requests small enough to review in one sitting (target under ~400 lines of diff excluding lockfiles and generated files); do not merge large branches that have accumulated unrelated work.
15. Run the full pre-integration build (or a draft-PR CI run) before opening a merge request; do not push speculative commits expecting CI to "tell me what failed."
16. Treat a red trunk build as the team's top priority — stop further merges until it is green and revert the offending commit if a forward fix is not imminent; do not stack additional commits on top of a broken trunk.
17. Pull and rebase from the trunk at the start of every working session so feature-branch divergence stays small; do not let a local branch drift days behind the trunk before merging.
