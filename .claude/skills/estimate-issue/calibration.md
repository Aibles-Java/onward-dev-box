# Estimate calibration log

Append-only. One row per estimated issue; fill `Actual (h)` and `Δ` when the issue
reaches Done (see `SKILL.md` → Calibration). `Δ` = Actual − Estimate.

| Issue | Estimated on | Size | Estimate (h) | Actual (h) | Δ | Basis / notes |
|-------|--------------|------|--------------|------------|---|---------------|
| 3 | 2026-07-04 | S | 3 | | | One init SQL file (given in issue) + fresh-boot psql verify + cross-repo feature_flag/Liquibase boot check around occupied port 5432 |
