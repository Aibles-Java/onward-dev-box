---
name: git-workflow
description: >
  onward-dev-box git conventions — commit message format, branch naming, and
  PR flow. Apply when committing, branching, or opening a pull request.
  Trigger phrases: "commit", "create branch", "open PR", "git workflow".
metadata:
  template_version: "1.0.0"
---

# Git Workflow — onward-dev-box

Project-specific git rules, aligned with feature_flag's conventions. Follow these for
every commit, branch, and PR.

## Commits

Format: `type(scope): subject`
- Types: feat, fix, chore, docs, refactor, test, perf, ci
- Subject: imperative, ≤ 72 chars, no trailing period
- Body (optional): explain *why*, not *what*. Wrap at 72 columns.
- Breaking change (e.g. changing a port or credential other repos depend on):
  add `!` after type/scope, or a `BREAKING CHANGE:` footer — and note the
  consumer-repo impact in the body.

Examples:
- `feat(compose): add sonarqube service under quality profile`
- `fix(scripts): make doctor.sh detect compose v2 correctly`
- `feat(postgres)!: rename ff_user — requires feature_flag config update`

## Branches

- `feature/<short-slug>`  → merges into `develop`
- `hotfix/<short-slug>`   → branches from `main`, merges into `main` + `develop`
- Default working branch: `develop`. Never commit directly to `main`.

## Releases

This is an infra repo — no version artifacts, no release trains. Promoting
`develop` → `main` (via PR) is the "release"; `main` should always describe an
environment a developer can bring up from scratch. Tag only if a consumer repo
needs to pin a known-good dev-box state (`git tag -a devbox-YYYY.MM.DD`).

## Pull Requests

- PR title = the commit subject (or the dominant change if multiple commits).
- Body: summarize *what changed and why*, derived from `git log <base>..HEAD`.
- Test plan for infra changes: from a clean state, the affected `make` targets pass
  (`make nuke && make up` for compose/init changes; `shellcheck` clean for scripts).
- Call out any cross-repo contract change (ports, credentials, database names)
  explicitly — it needs a companion change in the consumer repo.

## Boundaries

- Do not force-push to shared branches (main, develop).
- Do not amend or rebase commits already pushed to a shared branch.
- Do not commit secrets or `.env` — only `.env.example` with local-only defaults.
- The pre-push memory gate applies: pushes with work commits must include a
  `.claude/memory/` update (see /save-memory), or use `SKIP_MEMORY_CHECK=1`
  deliberately.
