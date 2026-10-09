# Kyle's Kaneo fork

Everything fork-specific lives in this folder, so upstream merges never touch it.

## Branches

| Branch | What it is | Rule |
|---|---|---|
| `main` | Mirror of `usekaneo/kaneo:main` | Never commit here. `sync-upstream.sh` keeps it current. |
| `kyle` | What dockerhost runs: an upstream release plus our patches | Default branch. Changes arrive only by PR. |
| `fix/*`, `feature/*` | One change each | Cut from the upstream release tag that `kyle` is on, so the branch can also go upstream. |
| `sync/vX.Y.Z` | An upstream release merged into `kyle` | Created by `sync-upstream.sh`. |

`kyle` follows upstream **release tags**, not upstream `main`. This matches what
`ghcr.io/usekaneo/kaneo:latest` shipped before the fork.

## A fix or feature

1. `git switch -c fix/<desc> $(git describe --tags --abbrev=0 --match 'v*' kyle)`
2. Write a failing test, then the fix. Run `pnpm --filter @kaneo/web run test` or
   `pnpm --filter @kaneo/api run test`. Every command needs
   `nix shell nixpkgs#nodejs_24 nixpkgs#pnpm_10 -c …`.
3. Push the branch and open a PR to `kyle`. Kyle merges it.
4. To offer it upstream: their `CONTRIBUTING.md` requires an issue with the
   `ready-for-contribution` label first. The PR text must be in Kyle's own words
   (`AI_POLICY.md`).

## Taking an upstream release

1. `kyle/sync-upstream.sh` (or `kyle/sync-upstream.sh v2.37.0`). It mirrors `main`
   and creates `sync/<tag>` with the release merged in.
   - Exit 2 means a merge conflict, left in progress. Resolve it and commit.
2. Gate: `pnpm install --frozen-lockfile && pnpm run build:dependencies`, then the
   web and API test suites.
3. Push `sync/<tag>` and open a PR to `kyle`. Kyle merges it.

Once upstream ships one of our patches, the merge absorbs it; no extra step.

## Deploying to dockerhost

`services/kaneo/docker-compose.yaml` in `~/source/docker_deployments` builds the
`kaneo` service from `https://github.com/KyleJFischer/kaneo.git#kyle`.

Run every `docker compose` command from the repo root. `services/kaneo` is pulled
in with `include:`, and the root compose file defines its network and variables,
so running Compose from that folder fails with `refers to undefined network internal`.

One step at a time, checking each before the next:

```sh
ssh dockerhost
cd ~/source/docker_deployments
docker tag kaneo-kyle:latest kaneo-kyle:previous     # rollback point
docker compose build kaneo                           # Kaneo keeps running
docker exec kaneo-postgres pg_dump -U kaneo kaneo | gzip > ~/backups/kaneo/kaneo-pre-$(date +%Y%m%dT%H%M%S).sql.gz
chmod 600 ~/backups/kaneo/*.sql.gz                   # the dump holds password hashes
docker compose up -d --no-deps kaneo                 # a few seconds of downtime
```

Verify that it actually works, not just that the container is up: `/api/health` returns ok, and global
search for a task key opens that task.

**Rollback:** `docker tag kaneo-kyle:previous kaneo-kyle:latest && docker compose up -d --no-deps kaneo`.
If a migration ran, restore the dump too.

## Tests

`kyle/sync-upstream.test.sh` runs the script against throwaway repos.
