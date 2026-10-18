# Gotchas

Each of these cost real time once. Check here before debugging the VPS.

## systemd and Quadlet

**`systemctl --user` over a non-interactive ssh fails with a bus error.**
"Failed to connect to user scope bus … `$DBUS_SESSION_BUS_ADDRESS` and
`$XDG_RUNTIME_DIR` not defined" is not a broken unit. A plain `ssh host cmd`
gets no login session. Prefix with
`export XDG_RUNTIME_DIR=/run/user/$(id -u)`; linger keeps that directory
alive. `su - <user>` sets it for you through pam_systemd, which is why the
`su` path never needed it.

**One dangling symlink ungenerates every unit.** Quadlet does not skip a file
it cannot read: it abandons the whole run ("No files parsed from …") and
generates nothing. Every `<prefix>-*` unit then reports "not found" while the
containers keep running unmanaged. Cause: a unit deleted or renamed in the
repo, then only the rsync half of the update flow run, leaving the link
pointing at nothing. `setup.sh`/`link-units.sh` prune these; by hand:
`find ~/.config/containers/systemd/ ~/.config/systemd/user/ -maxdepth 1 -xtype l -print -delete`
then `daemon-reload`. Containers that kept running are still unmanaged until their
unit starts. Starting it replaces the container, which is a restart, so on prod
confirm first and choose the moment. A container whose unit was removed has no unit
to take it over; remove it with `podman stop` and `podman rm`.

**`sudo` scrubs the environment.** `VAR=x sudo script.sh` silently loses
`VAR`. Put the assignment after `sudo`: `sudo VAR=x script.sh`. Scripts that
care echo the value they resolved as their first line; read it.

**`su - user && cmd` does not run `cmd` as user.** `su` opens an interactive
shell; the `&&` half runs when you exit it, back as yourself. One command per
line.

**A promote does not apply unit-file changes.** `Image=` retags move images;
an edited `.container` (new `EnvironmentFile=`, healthcheck tweak) needs the
rsync plus `daemon-reload` plus a restart of that unit. A released image that
needs a new unit-level variable will not get it from the promote alone.

**Linking the drop-in directory needs `ln -sfn`.** The systemd directory holds
a drop-in *directory* (`podman-auto-update.timer.d/`) as well as unit files;
without `-n` a re-run plants a second link inside the already-linked directory
instead of refreshing the link.

**The deploy user's default shell mangles multi-line pastes** when it is
`/bin/sh`. `ssh user@host -t bash` or `su - user -s /bin/bash` to paste a
block.

## Registry and auto-update

**`podman auto-update --rollback` does not undo a promote.** It only enables
rollback-on-failure during an update run. A release that comes up healthy but
wrong stays up; rollback is a promote pointed backward.

**`HealthCmd` alone may not trigger an image rollback.** Without
`Notify=healthy`, the unit can count as started as soon as the container starts,
so the update run sees success. `HealthOnFailure=kill` then restarts the bad
image in a loop. Set `Notify=healthy` and prove the rollback with a deliberately
broken staging release.

**Download counts on the registry are the timer polling.** One manifest check
every 5 minutes per `AutoUpdate=registry` unit lands on whichever version the
watched alias resolves to (about 288 a day per unit). It is not adoption. If
the count roughly doubles, `:prod` and `:latest` resolve to the same digest.

**`:latest` and the version tag share one registry package version** because
they are the same digest. Deleting "the latest version" in the registry UI
deletes the immutable tag too.

## Postgres

**`POSTGRES_PASSWORD` is read once, when the volume is first initialised.**
Start the db unit before the secrets are final and Postgres keeps the
original password forever while every file holds the new one. Symptom: the
app unit dies at boot with "password authentication failed" even though the
files agree. Fix: re-run the secrets script while the db container is running;
its converge step is an `ALTER ROLE` over the container's trusted local
socket, so no old password is needed. Do not diagnose with
`podman exec … psql -h localhost`: the image trusts loopback with no password
check, so it succeeds regardless. Reproduce the app's real path instead
(`podman run --rm --network <prefix>-<env> --env-file <env>.app.env <postgres image> sh -c 'psql "$DATABASE_URL" -c "select 1"'`).

**postgres:18 moved `PGDATA`.** The image defaults to
`/var/lib/postgresql/18/docker` and declares its volume at
`/var/lib/postgresql`. Every unit that mounts a data volume must carry
`Environment=PGDATA=<mount path>` matching its `Volume=` line, or the cluster
is not where you mounted it. A wrong major against an existing volume is loud
("database files are incompatible with server") and leaves the data untouched.

**A `pg_dump` restore does not carry cluster-level roles.** A custom-format
database dump has the grants *to* a role but not the role. Restoring into a
fresh cluster without precreating every extra role the app uses fails the
grant statements and drops those privileges on the floor. Precreate the roles
with their real attributes before `pg_restore`.

**Keep `log_statement` off.** Any per-boot `ALTER ROLE … PASSWORD` the
entrypoint runs is a literal SQL statement; with `log_statement=all` or `ddl`
it lands, password included, in the db container's log on every boot.

**Name the data volume for the Postgres major it holds** (`-db-data-18`). A
major upgrade creates the next volume beside it; nothing is reused, and the
two are unambiguous during the window both exist.

**Postgres refuses a TLS key it does not own, and rootless podman changes who
that is.** A host file owned by the deploy user appears as root in the
container. Run `podman unshare chown <postgres uid>:<postgres uid>` on the key.
The uid differs by image variant (70 on alpine, 999 on Debian), so keep the
variant pinned. `ls -l` then shows a strange owner and plain `cat` is denied,
which is correct; read it with `podman unshare cat`.

## Build and image

**Do not bake an API URL into a same-origin web bundle.** If the app serves
its own web export, the export must fall through to same-origin; a baked
absolute URL sends the browser cross-origin and breaks `SameSite` cookies. It
is also what makes one image usable by every environment.

**Do not set the app-version variable in an env file, not even blank.** The
image bakes it in as an `ENV` from the build arg; any `EnvironmentFile` entry
for that key overrides it and blanks what the health endpoint reports.

**Untracked files are part of the build context.** `git diff` cannot see them,
which is why the release script counts them as `filthy` and hashes them into
the tag.

## Tunnel

**Presigned object-store URLs are host-bound.** The app's S3 endpoint setting
must be the public media hostname (with SSL on), not the in-network container
address, or browser uploads fail signature checks. The app's own traffic to the
store then hairpins through the edge; accept it at image sizes.

**Free-plan request bodies are capped at 100 MB** through the tunnel. Fine for
images, worth knowing before video.

**cloudflared is the only internet-facing process.** Old client versions get
deprecated; bump its pin on a schedule, not only when something breaks.
