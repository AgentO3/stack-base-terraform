---
id: renovate
layer: security
extends:
  - dependency-management
---

# Renovate

## Purpose

Renovate is the automation that operationalizes the `dependency-management` policy: it watches the lockfile, opens pull requests as new versions are published, integrates vulnerability feeds, and keeps the dependency graph current without humans having to remember. The same engine, mis-configured, becomes the loudest source of churn in the repo: a default config opens unbatched PRs for every transitive bump every hour, an unscoped `automerge: true` lands a malicious patch release before any human sees it, missing schedules ping reviewers at 3am, an unpinned `extends: ["config:base"]` shifts behavior whenever the upstream preset changes, vulnerability alerts arrive on the same SLA as routine bumps, and a stale dependency dashboard hides whichever update is actually critical. This spec pins where Renovate's configuration lives, how it is validated, the schedule and PR concurrency limits that keep noise bounded, the grouping rules that separate routine bumps from security patches, the auto-merge policy that distinguishes safe ecosystem-tested updates from changes that must be reviewed, the integration with vulnerability feeds, and the self-hosted-vs-cloud operating model — so Renovate enforces the dependency-management policy rather than drowning it in noise.

## References

- **spec** `dependency-management` — policy this spec operationalizes
- **spec** `vulnerability-scanning` — provider of CVE / KEV signals Renovate must honor
- **external** `https://docs.renovatebot.com/` — Renovate documentation
- **external** `https://docs.renovatebot.com/configuration-options/` — Configuration reference
- **external** `https://docs.renovatebot.com/presets/` — Preset reference (`config:*`, `security:*`, `helpers:*`, `npm:*`, …)
- **external** `https://docs.renovatebot.com/key-concepts/automerge/` — Automerge behavior and safety
- **external** `https://docs.renovatebot.com/configuration-options/#schedule` — Scheduling syntax
- **external** `https://docs.renovatebot.com/configuration-options/#vulnerabilityalerts` — Vulnerability alerts
- **external** `https://docs.renovatebot.com/getting-started/running/` — Self-hosted vs cloud
- **external** `https://github.com/renovatebot/renovate` — Renovate source repository
- **external** `https://osv.dev/` — Open Source Vulnerability database (used by Renovate's vulnerability feed)

## Rules

1. Commit a Renovate configuration file (`renovate.json`, `renovate.json5`, or `.github/renovate.json5`) at the repository root and treat it as the single source of truth; do not configure Renovate via the cloud-app UI.
2. Pin the schema reference in the config (`"$schema": "https://docs.renovatebot.com/renovate-schema.json"`) so editors validate it locally and CI can validate it against the published schema.
3. Validate the Renovate config in CI on every pull request that changes it using `renovate-config-validator` (or the equivalent tool); treat a failed validation as a build failure.
4. Pin every preset reference to a tag or commit (`extends: ["github>org/renovate-config#v1.2.0"]`) when extending an internal or third-party preset; do not extend an unpinned preset whose behavior can shift under the team.
5. Set `timezone` explicitly in the config and define a `schedule` for routine PRs that excludes outside-of-hours and weekends (e.g. `["after 8am and before 6pm every weekday"]`); do not run routine updates on a 24/7 schedule.
6. Cap noise with explicit `prConcurrentLimit` and `prHourlyLimit` values (e.g. `prConcurrentLimit: 10`, `prHourlyLimit: 2`); do not run with the unbounded defaults on an active repo.
7. Enable the dependency dashboard (`dependencyDashboard: true`) and route it to a single tracking issue per repository; do not disable the dashboard on a repo that has any open Renovate updates.
8. Group routine, non-security updates into batched PRs by ecosystem and update type (`packageRules` with `groupName`, `matchUpdateTypes: ["minor", "patch"]`, weekly schedule) so the team reviews one consolidated PR per ecosystem per week.
9. Configure security updates as a separate, unbatched, always-on stream by extending `config:security` (or equivalent) and setting a `vulnerabilityAlerts` `packageRules` block with no schedule, no grouping, and a high `prPriority`; do not batch security PRs into the routine update grouping.
10. Honor the `dependency-management` and `vulnerability-scanning` SLAs by mapping severity to Renovate `prPriority` and labels (e.g. CVSS critical / CISA KEV → `priority: 10` + `security:critical` label); do not surface a known-exploited CVE on the same priority as a routine patch bump.
11. Configure `rangeStrategy` per ecosystem in line with the project's pinning rules from `dependency-management` (typically `"pin"` for applications, `"bump"` for libraries that publish ranges); do not rely on the Renovate ecosystem default without an explicit decision recorded in the config.
12. Enable `lockFileMaintenance` on a documented schedule (e.g. weekly) so transitive dependencies refresh independently of direct-dependency PRs; do not let a lockfile stagnate while only direct-dependency bumps drive churn.
13. Restrict `automerge: true` to safe categories only — patch and pin updates of dev-only dependencies, lockfile maintenance, and explicitly allowlisted packages — and require a green CI run before the merge fires; do not enable repo-wide automerge across all ecosystems and update types.
14. Forbid automerge on any update flagged as a security update, on any major-version bump, on any package without a stable release history, and on any package whose CODEOWNERS includes the security team; do not auto-land a security patch without human review.
15. Pin the Renovate runner version when self-hosting (Docker image digest, GitHub Action SHA, or signed binary); do not run a self-hosted Renovate against `renovate/renovate:latest`.
16. Run Renovate against a documented, allowlisted set of registries that matches the project's `dependency-management` registry allowlist; do not let Renovate resolve packages from registries the build does not consume.
17. Source Renovate's platform tokens, registry credentials, and webhook secrets from a secret manager, scope them to least privilege, and rotate them on a documented schedule; do not commit Renovate credentials or bake them into images.
18. Document the Renovate operating model in the repository (cloud vs self-hosted, who owns the config, who can approve preset changes, on-call for failed runs); do not run Renovate as orphaned automation no one owns.
