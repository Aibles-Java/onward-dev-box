---
name: create-pr
description: >
  Open a GitHub pull request for onward-dev-box using this project's fixed
  format (Summary, Related issue, Changes, Test plan, Screenshots, Reviewer
  checklist) instead of a generic PR description. Trigger phrases: "create pr",
  "open pr", "raise pr", "make a pull request", "push and open a PR".
metadata:
  template_version: "1.0.0"
argument-hint: "[issue-number]"
---

# /create-pr

Opens a pull request for the current branch using this repo's fixed format
(matches `.github/PULL_REQUEST_TEMPLATE.md`, so Claude-authored and human-authored
PRs look the same). See `.claude/skills/git-workflow/SKILL.md` for the underlying
branch/commit conventions this builds on.

## Steps

### 1 — Determine base branch

Read the current branch name (`git branch --show-current`):
- `feature/*` → base is `develop`
- `hotfix/*` → base is `main`
- anything else (e.g. already on `develop`/`main`) → ask the user what base to use;
  do not guess

### 2 — Gather context

- `git log <base>..HEAD --oneline` and `git diff <base>...HEAD` — the full set of
  commits/changes going into this PR (not just the latest commit)
- `git status` — confirm no uncommitted changes are being left out; if there are,
  ask before proceeding
- Issue number: use the `$1` argument if passed (e.g. `/create-pr 7`); otherwise
  look for an issue-like token in the branch name (e.g. `feature/issue-7-slug`); if
  none found, write "N/A" in the Related issue section — never fabricate an issue
  number

### 3 — Draft the PR body

Fill in this exact structure — do not add, remove, or rename sections:

```markdown
## Summary

[1-3 sentences: what changed and why, derived from the commits above]

## Related issue/ticket

[issue link, `Closes #N`, or "N/A"]

## Changes

- [bullet per logical change, derived from the commit log/diff]

## Test plan

- [ ] `shellcheck scripts/*.sh .claude/hooks/*.sh` clean (if any shell changed)
- [ ] `make nuke && make up` from a clean state passes (if compose/postgres-init changed)
- [ ] `make doctor` passes
- [ ] `../feature_flag` still connects to this infra (if anything contract-adjacent changed)

[Only if command output/logs/screenshots are available or the change affects what
a developer sees, keep the section below; otherwise omit it entirely rather than
leaving it empty:]

## Screenshots / evidence

[paste evidence]

## Reviewer checklist

- [ ] No cross-repo contract break (Postgres `5432`, `feature_flag_db`/`ff_user`/`ff_password`) — or it is called out with a companion consumer-repo change
- [ ] New host ports are claimed in the port registry (`docs/INFRASTRUCTURE.md` §4)
- [ ] If `postgres/init/` touched: change is first-boot-only aware (documented `make nuke` or live-apply path)
- [ ] If `.claude/hooks/` touched: explicit human confirmation was given
- [ ] Base branch is correct (`develop` for features, `main` for hotfixes)
```

Check off (`[x]`) only items you actually verified in this session — never mark a
checklist item done without evidence (e.g. don't check "`make doctor` passes"
unless you ran it in this session and it passed). Drop test-plan lines whose
"if …" condition doesn't apply to this PR rather than leaving them unchecked.

### 4 — Title

Conventional Commits format: `type(scope): subject` — same rules as
`git-workflow`'s commit format (imperative, ≤72 chars). Use the dominant commit's
subject if the branch has one logical change; otherwise summarize.

### 5 — Push and create

1. Push the branch if not already tracking a remote: `git push -u origin <branch>`
   (the pre-push memory gate applies — see `git-workflow` boundaries)
2. Create the PR targeting the base from step 1:
   ```bash
   gh pr create --base <base> --title "<title>" --body "$(cat <<'EOF'
   <body from step 3>
   EOF
   )"
   ```
3. Report the returned PR URL to the user.

## Boundaries

- Never force-push or rewrite history to "clean up" a PR — see `git-workflow`
  boundaries.
- Never push to or open a PR against `main` directly from a `feature/*` branch —
  base must be `develop`.
- Do not open the PR without showing the drafted title+body to the user first if
  this is the first PR created in the session (subsequent PRs in the same session
  can skip re-confirming the format, not the content).
