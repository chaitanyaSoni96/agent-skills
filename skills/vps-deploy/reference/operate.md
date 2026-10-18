# Operate

Day-two procedures. Read the project's Makefile and runbook first; where they
differ from this file, they win. Take `<prefix>`, `<env>`, `<state-dir>` and
`<deploy-user>` from `deploy/quadlet/` and the project's scripts. Confirm with
the person before any step that restarts a prod unit or changes a prod schema.

Two users exist on the VPS: a sudo-capable **admin account** (runs `setup.sh`,
nothing else) and the **deploy user** (owns `deploy/`, the secrets, the
containers, the rootless podman socket; never sudo). Deploy work is deploy-user
work.

## Release (to staging)

Dev-machine build:

```bash
make release          # DRY_RUN=1 make release prints the tag and stops
```

Applies the project's gate, computes the version, builds, pushes the version tag,
retags and pushes `:latest`. CI build: merging to `main` does the same after its
checks. Either way staging's app unit picks it up within 5 minutes, or at once if
the project's release also rolls.

Before releasing, check whether the release needs anything the box does not have
yet: a new required env var, a new unit, a new secret. Staging has no promote gate,
so those land on the box **before** the release, or staging crash-loops until they
do.

## Promote (to prod)

If the project has an explicit prod migration step, it comes first; see
[Migrations](#migrations).

```bash
make promote                     # lists released versions, pick one
make promote VERSION=<tag>       # or name it
git tag <tag> && git push origin <tag>   # instead, when CI promotes on a release tag
```

A registry-side copy of the built image over `:prod`; nothing is pulled locally and
nothing is rebuilt. With a release tag, the commit must already have its image, so
merge and let the pipeline pass first. Prod's app unit follows on the next tick. To
roll immediately: the project's roll command, or on the VPS as deploy user,
`podman auto-update`. A command named `roll` applies what the alias already points
at; it is not a rollback. Check the health endpoint afterwards.

## Rollback

Prod: promote the older tag. Every past version is still in the registry
(`skopeo list-tags docker://<image>`), so any older version, not only the previous
one, is the same step pointed backward. When CI gates the tag flow, use its manual
run or the project's documented command.

Staging has no promote; repoint `:latest` by hand and let the timer pick it up:

```bash
skopeo copy docker://<image>:<older tag> docker://<image>:latest
```

When CI moves `:latest`, the next merge undoes this, so hold merges until the fix.
The copy needs a registry token with write access on the machine running it.

A promote to an older image runs no migration `Down`, and data a newer migration
transformed stays transformed. If a project's `Down` destroys data, that belongs in
its runbook.

A promote gated on a migration marker may refuse an older version. Its migrations
are already applied, so nothing needs migrating. Use the project's bypass, with the
person's confirmation.

## Migrations

**On boot.** Nothing to run: the entrypoint migrates as the new container starts.
The migration must keep the previous version working (`architecture.md`). To undo
one, write a new one.

**Explicit on prod.** In order, from the dev machine: release; run the project's
migrate step (snapshot, status, confirm, up, record the marker and the down
command); promote. The step runs the migrations inside the image being promoted, so
the local checkout does not decide what applies. If a promote of a new version
refuses for lack of a marker, run the migrate step. Do not use its bypass unless the
person confirms the head is already applied.

## Verify what is running

```bash
curl -s https://<hostname>/<health path>     # should report the running version
```

VPS, deploy user: `systemctl --user status <prefix>-<env>-app`,
`journalctl --user -u <prefix>-<env>-app -n 100`.

## Unit files

**Edited an existing unit.** Dev machine, then VPS:

```bash
rsync -avz --delete deploy/ <deploy-user>@<host>:~/deploy/
ssh <deploy-user>@<host> 'export XDG_RUNTIME_DIR=/run/user/$(id -u); systemctl --user daemon-reload'
```

then restart only the unit that changed. The symlinks already point into
`~/deploy/`, so the edit is live once `daemon-reload` runs. Without ssh access to the
deploy user, use the full path below.

**Added, renamed or removed a unit.** The short path above would leave a dangling
link, which ungenerates every unit (`gotchas.md`). Either re-run `link-units.sh` as
the deploy user after the rsync, or take the full path:

```bash
rsync -avz --delete deploy/ <admin>@<host>:~/<prefix>-deploy/   # dev machine
sudo ENVS='<every env this box runs>' ~/<prefix>-deploy/setup.sh   # VPS, admin; re-syncs, prunes, re-links
```

The project's variable may have another name. Pass it unless the script remembers
it: an env left out loses its links.

then, as the deploy user, `systemctl --user daemon-reload` and restart what changed.
Neither script starts, stops or restarts anything.

**Changing which environments a box runs.** The environments variable on
`setup.sh`/`link-units.sh` is the *whole* declaration: an env left out has its links
removed. Stop that env's containers first; the script warns but does not stop them.

## Secrets

VPS, deploy user. Files live under the state dir, one per container, `chmod 600`.
Templates are `deploy/secrets.example/<env>.<service>.env`.

Run the project's secrets script after **any** hand edit. It creates missing files
from templates, fills what it can generate, derives fields such as the app's
database URL, and lists files that still contain `CHANGE_ME`. A project's script may
also set a running Postgres role's password to match the db file. If it does not,
that is an `ALTER ROLE` by hand.

**Rotate a secret.** Edit the *source* file (db or store env), re-run the script to
propagate, then restart the consumers: an object store that reads root credentials
at start needs `systemctl --user restart <prefix>-<env>-<store>`; the app needs a
restart too.

**A new required variable shipped with a release.** Add it to the template in the
repo, rsync, re-run the script on every box, *then* release. Staging follows
`:latest` with no gate, so the order matters.

## Bumping pinned images

Sidecars are pinned in their `.container` files and never auto-update. To bump: edit
`Image=` in every env's unit (keep any dev compose pin in step), commit, then follow
"Edited an existing unit". A tag pinned only to a major, like `postgres:18-alpine`,
needs `podman pull` before the restart. cloudflared is the only internet-facing
process; bump it on a schedule.

**Never bump the Postgres major by editing `Image=` alone.** The tag and the on-disk
cluster move together; a major is a dump/restore with downtime. Outline, deploy user,
one env at a time, staging first:

1. Before the window: commit the unit change (new data location named for the new
   major, new `Image=`, `PGDATA` matching the mount), sync, re-link, `daemon-reload`.
   All inert; the old container keeps running.
2. Stop the app unit. Take a fresh `pg_dump --format=custom` from the old container.
   Stop the old db unit.
3. Start the new db unit on its empty storage. Precreate every extra role the app
   uses, with its real attributes (`gotchas.md`), unless the image's first-start init
   script already makes them.
4. `pg_restore` into the new cluster; check row counts against the old.
5. Start the app unit; check the health endpoint. Keep the old data until verified.

## Backups

`<prefix>-backup@<env>.timer`, enabled once per env, runs a nightly
`pg_dump --format=custom` inside that env's db container into `~/backups/<env>/`,
plus whatever else the project chose (`choices.md`). Check a backup's dead-man ping
and off-site copy, when configured, by running the script by hand once.

Restore checks go into a **fresh throwaway container and volume**, never the live db;
see the precreate-roles note above. Expect grant errors for roles you did not
precreate; for a check, data still lands.

## Bootstrap or rebuild a box

`setup.md` §VPS bootstrap. The box is reproducible from the repo's `deploy/`, the
secrets files, the registry token and the tunnel tokens. Data comes from backups.
