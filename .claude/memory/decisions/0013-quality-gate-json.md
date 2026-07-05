# 0013 — checked-in quality-gate JSON (issue #11)

## What

Added `sonarqube/quality-gate.json`: a checked-in, DEV/SIT-shared definition of
the team quality gate — `new_coverage` ratcheted at the current feature_flag
JaCoCo baseline (0, targeting 80% per `docs/INFRASTRUCTURE.md` §3) and
`new_blocker_violations` at 0. Wired `sonarqube/bootstrap.sh` step 5 to create
the named gate (`aibles-team-gate`) if missing, reconcile its conditions
against the JSON (update existing, add missing), and assign it to
`aibles:feature_flag` via `qualitygates/select` (not set as the instance
default — this SonarQube is shared across services). Verified end-to-end
against a live `quality`-profile instance, including a clean idempotent
re-run.

## Why + gotchas found during verification

- **SonarQube auto-adds "Clean as You Code" default conditions** (e.g.
  `new_violations`, `new_duplicated_lines_density`,
  `new_security_hotspots_reviewed`) to any newly created custom gate — they
  are not visible in the `qualitygates/create` response and only show up via
  `qualitygates/show`. Left alone, these would silently enforce rules beyond
  what issue #11 scoped (coverage + blocker issues only). `bootstrap.sh` now
  treats `quality-gate.json` as authoritative: after applying the desired
  conditions, it diffs `qualitygates/show` against the file's metric list and
  `qualitygates/delete_condition`s anything not listed.
- **`qualitygates/show` response can break naive JSON tooling** — piping
  directly through some shells/tools truncated or mis-parsed it in ad-hoc
  testing; parsing via `jq` from a saved response file was reliable, so the
  script always captures the response to a variable first rather than
  re-fetching inline mid-pipe.
- Reuses the `curl -G --data-urlencode` pattern from [[0012-sonar-bootstrap]]
  for all read-only gate lookups (`list`, `show`) to avoid the POST-by-default
  footgun.

## Alternatives considered

- Setting the new gate as the SonarQube instance default — rejected; this
  SonarQube instance is shared across future workspace services, and an
  instance-wide default would silently apply to projects this gate was never
  designed for. Explicit per-project assignment via `qualitygates/select`
  only.
