# Estimate calibration log

Append-only. One row per estimated issue; fill `Actual (h)` and `Δ` when the issue
reaches Done (see `SKILL.md` → Calibration). `Δ` = Actual − Estimate.

| Issue | Estimated on | Size | Estimate (h) | Actual (h) | Δ | Basis / notes |
|-------|--------------|------|--------------|------------|---|---------------|
| 3 | 2026-07-04 | S | 3 | | | One init SQL file (given in issue) + fresh-boot psql verify + cross-repo feature_flag/Liquibase boot check around occupied port 5432 |
| 4 | 2026-07-04 | S | 1.5 | | | One documented .env.example (11 vars) + 2-line compose tag parameterization; verify is config -q only, no boot cycle. Human AFK — recommended value written, adjustable |
| 5 | 2026-07-04 | S | 2.5 | | | One Makefile, 7 targets (init/up/up-all/down/nuke/logs/db); up uses compose --wait; verify needs real boot cycle around ff_postgres squatting 5432. Human AFK — recommended value written, adjustable |
