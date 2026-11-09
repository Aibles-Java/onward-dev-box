# HANDOFF

*State for the next session. Overwritten by `/save-memory`.*

## Current WIP (2026-11-09)

- Branch `feature/dev-box-v2`. One commit this session: `383695f`
  `docs(roadmap): mark repo progress with a three-state task tracker` —
  `index.html` only (84+/31-). Working tree otherwise clean.
- `index.html` is the "Cây Roadmap Devbox" page that arrived via the upload
  commit `db2e071`. It is **not** mentioned in `CLAUDE.md` and has no issue,
  no CI check, and no owner documented. Decide whether it belongs in this repo
  (and if so, add it to `CLAUDE.md`) — right now it is an orphan artifact that
  nonetheless holds the only workspace-wide progress view.
- The page now encodes a repo audit dated 2026-11-09: 12 tasks done (33h),
  8 in progress (30h, each with a "Còn thiếu" note), 61 not started, of 264h.
  Re-audit → update the task tuples **and** bump the `devbox-roadmap-seed-N`
  key, otherwise returning visitors keep the old snapshot.

## Context to Load

- `decisions/0019-roadmap-progress-audit.md` — the tick rule (Makefile counts
  as the unbuilt CLI only for capability-shaped tasks), why in-progress hours
  stay out of the %, and the CSS-escape / `file://` / kill-the-server gotchas
- `decisions/0017-smoke-test-script.md` — why `make smoke` is known-red and
  is marked in-progress rather than done on the roadmap

## Open items surfaced by the audit (not acted on)

1. `docs/INFRASTRUCTURE.md:51` says `doctor.sh` checks "disk" — it never has.
   Either add the check or fix the line.
2. Issue #18 (companion PR to `feature_flag`: retire its `docker-compose.yml`,
   point its CLAUDE.md/README at dev-box) is still open — the last open item
   from the Phase 3 list.
3. `postgres/init/` is database-per-service while the roadmap assumes
   schema-per-service + `search_path`. Divergence is deliberate so far; worth
   an explicit decision if more consumer services land.
4. Calibration `Actual`/`Δ` for issues #3–#13 still empty — needs the human's
   actual hours.

## Next steps

1. Push `feature/dev-box-v2` (this session's commit + this memory update).
2. Decide the fate of `index.html` (own it in `CLAUDE.md`, or move it out).
3. Pick up #18 if the roadmap work is done for now.
