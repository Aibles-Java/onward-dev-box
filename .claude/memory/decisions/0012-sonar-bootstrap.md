# 0012 — sonarqube/bootstrap.sh (issue #10)

## What

Added `sonarqube/bootstrap.sh`: idempotent first-run automation against the
SonarQube API — wait for `/api/system/status` UP (reuses `scripts/wait-for.sh`),
rotate the default `admin/admin` password to `SONAR_ADMIN_PASSWORD`, create the
`aibles:feature_flag` project, and (re)generate an analysis token written to
`.env` as `SONAR_TOKEN=`. Added `SONAR_ADMIN_PASSWORD` to `.env.example`.
Verified end-to-end against a live `quality`-profile SonarQube (fresh instance
+ a clean re-run to confirm idempotency).

Quality-gate creation (step 5 in the issue) is explicitly out of scope — a
separate issue owns the checked-in JSON gate definition
(`docs/INFRASTRUCTURE.md` §3, item 2.1).

## Why + gotchas found during verification

- **SonarQube password policy**: rejects passwords missing an uppercase char,
  lowercase char, or digit (e.g. plain `sonar_admin_password` failed twice with
  distinct 400 errors before landing on `Sonar_admin_password1`). Any future
  change to `SONAR_ADMIN_PASSWORD`'s default must satisfy all three classes.
- **`curl --data-urlencode` implies `-X POST`** unless `-G` is also passed —
  bit both the idempotency check (`/api/projects/search`) and the password
  probe. Any read-only SonarQube API call using query params in future scripts
  needs `-G`, otherwise the API returns 405 (wrong verb) or worse, silently
  mutates state on what looks like a read.
- **Tokens can't be regenerated under the same name** — SonarQube errors if you
  `generate` a token whose name already exists. Idempotent re-run pattern:
  `revoke` (ignore failure) then `generate`, both keyed on a fixed
  `TOKEN_NAME=onward-dev-box`.
- `.env` sourcing inside the script needs `source` on its own line for
  `# shellcheck disable=SC1090` to actually suppress the warning — combining
  `set -a; source "$ENV_FILE"; set +a` on one line does not apply the directive.

## Alternatives considered

- Storing the quality gate JSON and wiring it in this same script — rejected;
  issue #10's own description carves it out as a separate issue, and the gate
  definition needs its own review (shared DEV/SIT parity).
