# Memory Index — onward-dev-box

*Loaded automatically at the start of every session. Keep entries to one line each.
Updated by `/save-memory`. See `README.md` for how this system works.*

<!-- Format: - [Title](path) — one-line hook. Newest relevant entries near the top. -->

- [issue #13 Phase 2 verification closed](decisions/0015-issue-13-phase2-verification.md) — re-verified live, added missing SonarQube Community limitation note to INFRASTRUCTURE.md (wasn't actually documented despite prior HANDOFF claim), checked off §6 DoD line
- [make sonar target](decisions/0014-make-sonar-target.md) — issue #12/#13: `sonar.qualitygate.wait=true` added on top of issue's literal command (bare call doesn't print/block on the gate verdict); verified end-to-end incl. both FF_DIR/SONAR_TOKEN error guards
- [quality-gate.json](decisions/0013-quality-gate-json.md) — issue #11: checked-in DEV/SIT-shared gate JSON; SonarQube auto-adds "Clean as You Code" conditions to new gates, so bootstrap.sh prunes anything not in the file; assigned per-project, never set as instance default
- [sonar bootstrap.sh](decisions/0012-sonar-bootstrap.md) — issue #10: admin password policy needs upper+lower+digit; `curl --data-urlencode` implies POST unless `-G`; tokens re-generate via revoke-then-generate (no same-name overwrite)
- [issue-board.sh done closes the issue](decisions/0011-close-issue-on-done.md) — issue #28: gitflow feature PRs merge into `develop`, not default branch `main`, so `Closes #N` never auto-fires; `done` now runs `gh issue close` explicitly
- [Phase 1 clean-machine verification](decisions/0010-verify-phase1-clean-machine.md) — issue #9: full clean-boot, nuke/up, doctor.sh 3-failure-mode, no-secrets checks all pass; stubbed `docker`/`java` on PATH to trigger failures non-destructively
- [wait-for.sh helper](decisions/0009-wait-for-helper.md) — auto-detected TCP (`/dev/tcp`) vs HTTP (curl) modes; `-e` body-match for SonarQube `status=UP` (200-while-STARTING gotcha); exits 0/1/2 = up/timeout/usage; no Makefile wiring (0007: compose `--wait` owns container waits)
- [doctor.sh preflight](decisions/0008-doctor-preflight.md) — run-all-checks + per-FAIL `fix:` line; port free-or-ours via `docker ps --filter publish=` vs fixed container_names; quality checks arg-gated with 3.9 GB Docker-mem floor; macOS awk gotcha (use `-v` + single-quoted program); Linux vm.max_map_count branch untested (no Linux host)
- [make run target](decisions/0007-make-run-target.md) — DB wait via idempotent `compose --profile core up -d --wait` (works from cold clone, no wait-for.sh); checkout check is `-x $(FF_DIR)/mvnw` with actionable error; 1.6 wait-for.sh narrowed to host-side waits (smoke on 8081)

- [Makefile lifecycle targets](decisions/0006-makefile-lifecycle-targets.md) — compose v2 `--wait` replaces wait-for.sh in `make up`; profile-gated services mean `down`/`logs`/`nuke` must pass all `--profile` flags (bare `down` matches nothing); `make db` is password-less via container-local trust; no dead targets
- [.env.example tunables](decisions/0005-env-example-tunables.md) — every compose `${VAR}` documented with identical defaults (empty `.env` ≡ copied example); image tags parameterized (`POSTGRES_TAG`, `ADMINER_TAG`); contract creds live in init SQL, not env
- [Idempotent init SQL](decisions/0004-idempotent-init-sql.md) — DO-block roles + `\gexec` databases so postgres/init SQL re-applies to a live instance; contract credentials verbatim; cross-repo verify via `SPRING_DATASOURCE_URL` override on port 5433
- [Compose authoring choices](decisions/0003-compose-authoring-choices.md) — postgres dual-profile (core+quality) for depends_on, fixed `onward` network name, postgres superuser ≠ ff_user (init SQL owns per-service users), sonarqube:community has curl not wget
- [Port issue/PR workflow skills](decisions/0002-port-issue-and-pr-skills.md) — create-pr, estimate-issue, issue-workflow + issue-board.sh ported from feature_flag with infra-adapted checklists; git-workflow release flow deliberately NOT ported
- [Claude Code harness setup](decisions/0001-claude-code-harness-setup.md) — Tier 3 harness ported from feature_flag: gitflow + conventional commits, memory lifecycle + push gate, cross-repo drift-monitor; settings.json hook wiring applied after explicit user confirmation
