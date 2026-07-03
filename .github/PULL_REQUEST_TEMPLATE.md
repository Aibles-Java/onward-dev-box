<!-- Keep the title in Conventional Commits format: type(scope): subject -->

## Summary

<!-- What changed and why. 1-3 sentences, focus on the "why". -->

## Related issue/ticket

<!-- Link the GitHub issue, or write "N/A" -->

## Changes

<!-- Bullet list of the key changes, for the reviewer -->
-

## Test plan

<!-- How was this verified? Check what applies, add commands/output if useful. -->
- [ ] `shellcheck scripts/*.sh .claude/hooks/*.sh` clean (if any shell changed)
- [ ] `make nuke && make up` from a clean state passes (if compose/postgres-init changed)
- [ ] `make doctor` passes
- [ ] `../feature_flag` still connects to this infra (if anything contract-adjacent changed)

## Screenshots / evidence

<!-- Command output, logs, docker ps, etc. Delete this section if not applicable. -->

## Reviewer checklist

- [ ] No cross-repo contract break (Postgres `5432`, `feature_flag_db`/`ff_user`/`ff_password`) — or it is called out with a companion consumer-repo change
- [ ] New host ports are claimed in the port registry (`docs/INFRASTRUCTURE.md` §4)
- [ ] If `postgres/init/` touched: change is first-boot-only aware (documented `make nuke` or live-apply path)
- [ ] If `.claude/hooks/` touched: explicit human confirmation was given
- [ ] Base branch is correct (`develop` for features, `main` for hotfixes)
