---
name: vps-deploy
disable-model-invocation: true
description: Use when setting up or operating a self-hosted deployment on a single VPS with rootless podman, Quadlet units, a container registry (GHCR) and podman auto-update — a new project needs a deploy/ directory, or an existing one needs a release cut, a version promoted, a rollback, a migration applied, a unit edit pushed, a secret rotated or a pinned image bumped.
---

# VPS deploy

General guidance for running small apps on a VPS you control: **build each
version once, push an immutable image tag, let the box pull it.** Every
environment is a self-contained set of rootless Quadlet units on its own podman
network; only the app unit auto-updates.

**REQUIRED BACKGROUND:** read `reference/architecture.md` once before doing
anything else with this skill. It is short and every ruling below assumes it.

## Which mode

| The project has | Do |
|---|---|
| A `deploy/` directory or Quadlet units | **Operate.** Read its Makefile and runbook first, then place it in `reference/choices.md`, then use `reference/operate.md`. |
| Neither | **Set up.** Pick from `reference/choices.md`, then follow `reference/setup.md`. |

An existing project's own Makefile, scripts and runbook outrank every default
in this skill, including names, command spellings and health paths. Never guess
a container or unit name; read it from `deploy/quadlet/`. Leave a working setup
in its own shape; a difference from this skill's defaults is usually a choice.

On a new project, explain the reason for a rule the person wants to break. If
they still want it, it is their call: do it and record it in the runbook.

## Quick reference

Command names are conventions; the project's Makefile is the authority.

| Want to | Do | Where it runs |
|---|---|---|
| Ship a build to staging | `make release`, or merge to `main` when CI builds | dev machine or CI |
| Put a released version on prod | `make promote VERSION=<tag>`, or push a release tag when CI promotes | dev machine or CI |
| Roll prod back | Promote the older tag | dev machine or CI |
| Roll staging back | `skopeo copy` the older tag over `:latest` | dev machine |
| Migrate ahead of a promote | The project's explicit step, when it has one | dev machine |
| Apply it now, not on the timer | `podman auto-update`, or the project's roll command | VPS as deploy user, or wrapper |
| Push an edit to an existing unit | rsync `deploy/` to the deploy user, `daemon-reload` | both |
| Add, rename or remove a unit | rsync, then re-run `link-units.sh` or `setup.sh` | both |
| Fill or rotate secrets | The project's secrets script | VPS, as deploy user |
| Bump postgres or another sidecar | Edit `Image=`, commit, then "push an edit" | both |

Full procedures, with the order that matters, are in `reference/operate.md`.

## Rules that hold in every project

- **A version is built once and its tag never moves.** Environments differ only
  by which version their alias points at.
- **Prod moves only on a deliberate, named act:** a promote command or a release
  tag. Staging may follow automatically; prod never does.
- **The registry is how a version reaches the box.** The VPS pulls by tag. Never
  build on the box, copy an image to it, or hand-pull a new app image to get
  around a promote or a migration gate.
- **The VPS holds no source and no git clone.** Only `deploy/` is synced.
- **Only the app unit carries `AutoUpdate=registry`.** Everything else is pinned
  and bumped by hand.
- **Secrets live outside the repo**, one env file per container, `chmod 600`,
  owned by the deploy user. Only placeholder templates are checked in.
- **Confirm with the person before any step that restarts a prod unit or changes
  a prod schema.** A request naming that action on prod is the confirmation for
  it. A migration it did not name gets its own confirmation.
- **This skill gives no procedure for ssh keys or sshd configuration.** Follow
  what the project's own setup does, or leave it to the box administrator.

## Files

| File | Read when |
|---|---|
| `reference/architecture.md` | Always, once. The fixed model and why each part is the way it is. |
| `reference/choices.md` | Designing a deploy, or working out what an existing one chose. |
| `reference/setup.md` | Building a project's `deploy/` and bringing up a box. |
| `reference/operate.md` | Any day-two task. |
| `reference/gotchas.md` | Something on the VPS behaves oddly; check here before debugging. |
| `DESIGN.md` | Changing the skill itself. |
