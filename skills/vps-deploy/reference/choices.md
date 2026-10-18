# Choices

What a project may vary within the fixed model. Each row is a real fork: pick one
for a new project, or identify which one an existing project took. For a new
project, the first option is the default unless its reason does not apply.

## Release

| Decision | Options | Choose by |
|---|---|---|
| **Where images are built** | Dev machine: `make release`. CI: a push to `main` builds, tests and moves `:latest`. | CI when the project has a test pipeline worth waiting for. CI needs only its own registry token and never reaches the box. |
| **How prod is promoted** | Command: `make promote VERSION=<tag>`. Release tag: pushing `v*` checks that commit's pipeline passed, copies the image already built for it over `:prod`, and adds `:v*` as a second name for that digest, with no rebuild. | Follows from the build location. A CI project can keep the command as a documented bypass. |
| **Version tag** | `git describe` (readable). Full commit SHA (no tag discipline needed). | Either; report it on the health endpoint. |
| **Release gate** | Clean tree plus a marker that `make test` passed on exactly `HEAD`. CI: the pipeline is the gate. None: dirty builds allowed, suffixed `-dirty`/`-filthy-<hash>`, staging only. | A gate once the project has real users. Dirty builds only while staging is a scratch space. |
| **Pre-release scans** | Lint, dependency audit and secret scan as prerequisites of `release`. | Add them when they run in reasonable time. |

## Rollout

| Decision | Options | Choose by |
|---|---|---|
| **When the box applies a move** | Timer only: nothing on the dev machine opens ssh. Timer plus a wrapper: `make roll`, `make ship` run `podman auto-update` over ssh and confirm the version is live. | Timer only is the smaller trust surface. A wrapper suits a person who wants confirmation in the same terminal. |
| **Failed-release rollback** | `Notify=healthy` with `HealthCmd`: the unit is started only once healthy, so auto-update can restore the previous image. `HealthCmd` alone: the app restarts on failure, with no image rollback to rely on. | `Notify=healthy`, with `TimeoutStartSec` and `HealthStartPeriod` longer than boot migrations. Test it with a deliberately broken staging release. |
| **Health path** | Project-defined, such as `/healthz`, `/health`, `/api/healthz`. | Should report the running version and not depend on optional services, so a blip cannot restart the app. Keep a separate readiness endpoint for dependency detail. |

## Migrations

| Decision | Options | Choose by |
|---|---|---|
| **When they run** | On boot everywhere: the entrypoint migrates, then `exec`s the app, and a promote migrates itself. Explicit on prod: staging migrates on boot; prod runs snapshot, status, confirm, up as a separate step, and the promote refuses without a marker from that step. | On boot for a small schema with one instance per env. Explicit when a bad migration would be costly or down-migrations can destroy data. Explicit pairs with a promote command, since CI cannot see a marker on a dev machine. |
| **Which role migrates** | An owner role for migrations and a lesser role for the app, with the owner URL removed before the app starts. One role. | Separate roles whenever the app relies on row-level security. |

## Storage

| Decision | Options | Choose by |
|---|---|---|
| **Database and file location** | Named podman volumes, with the database volume named for its Postgres major. Host folders with `UserNS=keep-id:uid=<image uid>`, on a mounted block volume if needed. | Volumes are simplest. Host folders make files directly inspectable, and a block volume can hold them. |
| **Uploaded files** | A volume or folder, restricted by the app. S3-compatible store with presigned URLs and a second public hostname. | A store when browsers upload directly or files are large. |
| **Database transport** | Plain on the private env network. TLS with a self-signed pair and `sslmode=require`. | TLS when the app refuses plain connections in production, or the database may move off-box. |

## Secrets

| Decision | Options | Choose by |
|---|---|---|
| **Script shape** | All envs, placeholders filled unattended. Per env, prompting for outside values. | Either; it must stay safe to re-run. |
| **Placeholder guard** | App refuses placeholders at start. Unit `ExecStartPre` greps for `CHANGE_ME`. | The unit guard is the one that stops a database initialising on a template. Use both where possible. |
| **Proxy trust** | Fill the trusted-proxy setting from `podman network inspect <prefix>-<env>`, and re-run the script once a unit has created the network. No such setting. | Required when the app rate-limits or logs by client IP; otherwise a forged `X-Forwarded-For` is believed. |

## Backups

Each level includes the ones before it.

| Level | What it adds |
|---|---|
| Local | Nightly `pg_dump --format=custom` inside the db container, N-day retention |
| Files | Uploads volume tar, or a mirror of the bucket |
| Off-site | Encrypted to a public `age` key, uploaded with rclone, private key kept off the box |
| Alerting | Dead-man ping on success, so a *missing* backup alerts too |
| Drill | A scheduled restore into a throwaway container, with row counts recorded |

Go to at least off-site and alerting before holding data you cannot recreate.

## Sidecars

Each is a pinned unit on the env's network: Postgres, an object store, Redis, a
staging-only SMTP sink so staging never sends real mail, and anything else the
app needs. MinIO's upstream images are archived; check an S3-compatible store is
still maintained before pinning it.
