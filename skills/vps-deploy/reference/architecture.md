# Architecture

The fixed model, and the reason behind each part. What a project may vary is in
`choices.md`.

## The shape

```
 dev machine or CI                   registry (GHCR, private)
 ─────────────────                   ───────────────────────
 release ─────build+push────────────▶ image:<version>   (immutable, kept forever)
         ─────retag─────────────────▶ image:latest      (mutable: what staging runs)
 promote ─────registry-side copy────▶ image:prod        (mutable: what prod runs)
                                            ▲
                                            │ podman-auto-update.timer, every 5 min,
                                            │ one manifest HEAD per AutoUpdate unit
 VPS, one rootless user with linger         │
 ──────────────────────────────────────────┼──────────────
   <prefix>-prod.network                    │   <prefix>-staging.network
   ┌────────────────────────┐               │   ┌───────────────────────────┐
   │ <prefix>-prod-app      │◀──────────────┴──▶│ <prefix>-staging-app      │
   │ <prefix>-prod-db       │                   │ <prefix>-staging-db       │
   │ <prefix>-prod-<store>  │                   │ <prefix>-staging-<store>  │
   │ <prefix>-prod-tunnel   │                   │ <prefix>-staging-tunnel   │
   └────────────────────────┘                   └───────────────────────────┘
   nothing shared: not a network, not a volume, not a tunnel
```

## Rulings

**Build once, promote by tag.** A version is built and pushed exactly once.
Which environment runs it is a registry-side retag, never a rebuild, so staging
and prod can only ever differ by *which* build, not by *how* it was built. Every
version tag stays in the registry; that list is the rollback list.

**Staging follows `:latest`; prod follows `:prod`.** Moving `:latest` is a
staging deploy. Prod moves only by a separate, deliberate act. A
single-environment project keeps both steps rather than letting prod track
`:latest`.

**The box pulls.** podman's own auto-update timer, with a drop-in that sets it
to every 5 minutes, checks each `AutoUpdate=registry` unit's watched tag and
restarts only a unit whose digest actually moved. A staging release restarts
staging; a promote restarts prod; neither touches the other. A wrapper may
trigger the same `podman auto-update` sooner, but the image still arrives by
pull.

**Rootless, with linger.** Everything runs as one dedicated non-root user per
app. `loginctl enable-linger` keeps that user's systemd instance and
`XDG_RUNTIME_DIR` alive with no session open, which is what lets
`systemctl --user` units and the timer run after a reboot or a logout.
Consequences: Quadlet units live under `~/.config/containers/systemd/`, the
registry `podman login` happens as that user (its `auth.json` is what
auto-update pulls with), no host ports are published, and a container escape
lands in an unprivileged account. Sharing a VPS with other apps is an expected
case, hence one user per app and the `<prefix>-` namespacing.

**One environment is one network, and nothing is shared.** Each env has its own
app, database, storage and tunnel, confined to that env's network. A shared edge
network would give the tunnel process, and transitively either env's app, a path
into the other env's containers.

**Only the app unit auto-updates.** Database, object-store, tunnel and other
sidecar images are pinned and bumped by hand, so an automated pull can never
surprise-upgrade the database. A Postgres major is never bumped by editing
`Image=`; that is a dump/restore with downtime (`operate.md`).

**Unit files are checked in; secrets are not.** `.container`, `.network` and
`.volume` files hold structure only and live under `deploy/quadlet/<env>/`. On
the VPS they are symlinked from a plain synced copy of `deploy/` into the user's
Quadlet directory. Secrets are env files under a state directory, one per
container so none inherits secrets it does not need.

**Migrations keep the previous version working.** The new schema arrives while
the old app still runs, briefly on every release and indefinitely after a
rollback. Add columns and tables freely; rename, drop or tighten only in a later
release, once no running version uses the old shape. An image rollback does not
run down-migrations.

**Public access is an outbound tunnel.** One tunnel per env dials out, so no port
opens on the host. With Cloudflare, hostnames stay one label deep
(`app-media.<domain>`, not `media.app.<domain>`) because the free wildcard
certificate covers only `*.<domain>`. Hostname-to-service routing lives in the
tunnel dashboard, the one piece of deploy configuration outside the repo.

**Secrets converge, they are not provisioned.** The secrets script is safe to
re-run at any time: it creates missing files from templates, fills what needs no
outside input, derives fields that must agree across files, and never
regenerates a value that is already set. Rotation is a deliberate hand edit
followed by a re-run.
