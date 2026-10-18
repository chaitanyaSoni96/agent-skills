# Set up

Building a project's `deploy/` and bringing up a box. Make the decisions in
`choices.md` first. This skill ships no templates: write the files for the
project from the shapes below.

## 1. Pick the names

| Name | Example | Used for |
|---|---|---|
| prefix | `myapp` | every container, network, volume and unit: `<prefix>-<env>-<service>` |
| image | `ghcr.io/<owner>/myapp` | release, promote, the app unit's `Image=` |
| deploy user | `myapp` | the rootless user on the VPS |
| state dir | `~/myapp` | where the secrets env files live on the VPS |
| envs | `prod staging` | `prod` watches `:prod`, every other env watches `:latest` |

One prefix and one deploy user per app. Two apps on one box get two users; that
is the isolation boundary between them.

## 2. Lay out deploy/

```
deploy/
  README.md            standalone runbook, so the box is operable without this skill
  release.sh           build + push one version, move :latest (unless CI does)
  promote.sh           registry-side copy of a version over :prod (unless CI does)
  setup.sh             root, idempotent: packages, deploy user, linger, handoff, links
  link-units.sh        deploy user: link units for the declared envs, prune dangling, never (re)start
  <secrets script>     deploy user: converge secrets files
  backup/<prefix>-backup.sh    when the project holds data; likewise its two systemd units
  quadlet/<env>/       one directory per env
  secrets.example/     <env>.<service>.env, placeholders only
  systemd/<prefix>-backup@.service
  systemd/<prefix>-backup@.timer
  systemd/podman-auto-update.timer.d/override.conf
```

**`release.sh`:** apply the chosen gate; compute the version; `podman build` with
it as a build arg; push the version tag; retag and push `:latest`. Support
`DRY_RUN=1`.

**`promote.sh`:** with no `VERSION`, list released tags with `skopeo list-tags`
and offer them. Check the image's version label, so only real release builds
qualify. Confirm, then:

```bash
skopeo copy "docker://$IMAGE:$VERSION" "docker://$IMAGE:prod"
```

**`link-units.sh`,** run as the deploy user, in this order, because a dangling link
stops Quadlet generating anything (`gotchas.md`):

1. Unlink units of environments not declared, warning if their containers run.
2. Prune dangling links:
   `find "$quadlet_dir" "$systemd_dir" -maxdepth 1 -xtype l -print -delete`.
3. Link declared environments' units, using `ln -sfn` for the systemd directory.
   Never start or stop anything.

**`override.conf`** makes the timer poll every 5 minutes:

```ini
[Timer]
OnCalendar=
OnCalendar=*:0/5
RandomizedDelaySec=0
```

**Backup timer:** `OnCalendar` nightly with `RandomizedDelaySec` and
`Persistent=true`. Give each app on a shared box its own hour, to keep disk and
CPU spikes apart.

## 3. Write the project-specific files

**Containerfile and entrypoint.** Multi-stage: build stages for each artifact, a
minimal final stage with a non-root user, `ARG APP_VERSION` baked into an `ENV`
the app reports on its health endpoint. The entrypoint runs idempotent migrations
when the project migrates on boot, then `exec`s the app so it is PID 1. If the app
serves its own web bundle, build it with no absolute API URL (`gotchas.md`).

**Quadlet units.** The app unit:

```ini
[Unit]
Description=myapp prod app
After=myapp-prod-db.service
Wants=myapp-prod-db.service

[Container]
ContainerName=myapp-prod-app
# prod watches :prod; every other env watches :latest
Image=ghcr.io/<owner>/myapp:prod
# The only unit with AutoUpdate
AutoUpdate=registry
Network=myapp-prod.network
EnvironmentFile=%h/myapp/prod.app.env
Notify=healthy
HealthCmd=wget -q -O /dev/null http://127.0.0.1:8080/healthz
HealthInterval=10s
HealthTimeout=5s
HealthRetries=3
# Longer than boot migrations take
HealthStartPeriod=60s
HealthOnFailure=kill

[Service]
Restart=always
RestartSec=5
TimeoutStartSec=120

[Install]
WantedBy=default.target
```

`HealthCmd` runs inside the container, so it must use a tool the image has. Drop the
`After=`/`Wants=` lines, or point them at the right unit, when there is no database.

Other units follow the same shape, with no `AutoUpdate`:

| Unit | Notes |
|---|---|
| `<prefix>-<env>-db` + its volume | Pinned; `Environment=PGDATA=` matching `Volume=`; volume named for the major; `HealthCmd=pg_isready` |
| `<prefix>-<env>-<store>` + its volume | S3-compatible store plus a oneshot bucket-init; needs a second tunnel hostname |
| `<prefix>-<env>-cloudflared` | The tunnel. Pinned; `After=` the app; token from its own env file |
| Any other sidecar | A pinned image with an env file and a network line |
| `<prefix>-<env>.network` | One per env, nothing else joins it |

Every long-running unit: `Network=<prefix>-<env>.network`, `Restart=always`,
`WantedBy=default.target`, no published ports, and its own `EnvironmentFile=` when
it takes settings.

**Secrets templates,** `deploy/secrets.example/<env>.<service>.env`, one per
container. Use one word for values the script can generate and `CHANGE_ME` for
those needing a person (SMTP credentials, tunnel tokens, the domain). A value the
app must copy from another file is derived by the script, so the two can never
disagree. List every variable whose dev default is silently wrong in prod: the
environment name gating `Secure` cookies, public base URL, trusted origins, public
store endpoint. Nothing should be left to the binary's defaults.

**Makefile targets.** `release` and `promote` at minimum, each execing its script,
plus whatever `choices.md` added (`migrate`, `roll`, `sync`).

**Runbook.** `deploy/README.md`: what lives in `deploy/`, the choices this project
made, the bootstrap, the secrets, the tunnel hostnames, first start,
release/promote/rollback, and the project's migration and data notes.

## 4. VPS bootstrap

Debian, a sudo-capable admin account, nothing else installed.

1. Dev machine: `rsync -avz --delete deploy/ <admin>@<host>:~/<prefix>-deploy/`.
   Name the directory for the app: on a shared admin account, a plain `~/deploy/`
   would overwrite another app's copy.
2. VPS, admin: `sudo ENVS='prod staging' ~/<prefix>-deploy/setup.sh`. Installs
   podman, skopeo, rsync, uidmap and what the backups need; creates the deploy
   user; enables linger; copies the directory to the deploy user's `~/deploy/`;
   runs `link-units.sh` as that user. Re-runnable. The assignment goes **after**
   `sudo` (`gotchas.md`).
3. VPS, deploy user (`su - <deploy-user>` or ssh):
   `podman login <registry>` with a read-only pull token. A credential, so it is
   never scripted.
4. Run the secrets script, then fill every remaining `CHANGE_ME` by hand. Set the
   environment-name variable per file.
5. Tunnel: one remotely-managed tunnel per env, hostnames one label deep, app
   hostname to `http://<prefix>-<env>-app:<port>` and, if present, the media
   hostname to the store's port. Token into `<env>.cloudflared.env`.
6. `systemctl --user daemon-reload` and
   `systemctl --user enable --now podman-auto-update.timer`.
7. First start, per env: sidecars first, then re-run the secrets script if it reads
   the network. From the dev machine or CI, release (and promote for prod, since
   `:prod` does not exist until something is promoted), then
   `systemctl --user start <prefix>-<env>-app`. Verify the health endpoint reports
   the version.
8. If the project has backups, `systemctl --user enable --now <prefix>-backup@<env>.timer`
   per env.

Keep the deploy user out of sudo, with key-only remote login. How that is enforced
belongs to the box administrator.
