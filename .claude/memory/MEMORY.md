# Memory Index — onward-dev-box

*Loaded automatically at the start of every session. Keep entries to one line each.
Updated by `/save-memory`. See `README.md` for how this system works.*

<!-- Format: - [Title](path) — one-line hook. Newest relevant entries near the top. -->

- [Idempotent init SQL](decisions/0004-idempotent-init-sql.md) — DO-block roles + `\gexec` databases so postgres/init SQL re-applies to a live instance; contract credentials verbatim; cross-repo verify via `SPRING_DATASOURCE_URL` override on port 5433
- [Compose authoring choices](decisions/0003-compose-authoring-choices.md) — postgres dual-profile (core+quality) for depends_on, fixed `onward` network name, postgres superuser ≠ ff_user (init SQL owns per-service users), sonarqube:community has curl not wget
- [Port issue/PR workflow skills](decisions/0002-port-issue-and-pr-skills.md) — create-pr, estimate-issue, issue-workflow + issue-board.sh ported from feature_flag with infra-adapted checklists; git-workflow release flow deliberately NOT ported
- [Claude Code harness setup](decisions/0001-claude-code-harness-setup.md) — Tier 3 harness ported from feature_flag: gitflow + conventional commits, memory lifecycle + push gate, cross-repo drift-monitor; settings.json hook wiring applied after explicit user confirmation
