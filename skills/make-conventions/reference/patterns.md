# Reusable blocks

Copy the block, adapt names. Recipes use a literal TAB. Each block lists the rule
it implements.

## Header

```make
SHELL := /bin/bash
# Only when a recipe pipes: stop `cmd | tail` swallowing a failure.
.SHELLFLAGS := -eo pipefail -c
.DEFAULT_GOAL := help
```

## Help + groups (rules §1, §5)

```make
help:
	@awk 'BEGIN{FS=":.*## "} /^##@ /{printf "\n\033[1m%s\033[0m\n", substr($$0,5)} /^[a-zA-Z0-9_-]+:.*## /{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Develop
dev: ## Run the app with reload
```

Notes: `help` itself has no `##` so it is not listed. The awk reads the file as
text, so a `$(VAR)` inside a description is printed literally; keep variables out
of descriptions. Helpers have no `##`.

## Ports and local overrides (rules §9, §10)

```make
-include Makefile.local   # git-ignored; per-machine overrides

API_PORT      ?= 1980
WEB_PORT      ?= 1981
POSTGRES_PORT ?= 15432
```

Add `Makefile.local` to `.gitignore`. Pick one uncommon block of ports per
project; e2e gets its own block (e.g. +1000 for the API, a distinct DB port).

## `.env` awareness (rules §9) — only when the app loads a `.env` itself

If the app reads a `.env` but the Makefile also passes the same variables inline,
the inline value wins and the file is silently ignored. Resolve by omitting from
the inline assignments any key the `.env` defines:

```make
DOTENV_FILE := $(if $(ENV_FILE),$(ENV_FILE),$(firstword $(wildcard .env)))
DOTENV_KEYS := $(if $(wildcard $(DOTENV_FILE)),$(shell sed -n \
	's/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\?\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*=.*/\2/p' \
	$(DOTENV_FILE)))
ext = $(if $(findstring environment,$(origin $(1))),x)$(if $(findstring command,$(origin $(1))),x)
env = $(if $(call ext,$(1))$(filter $(1),$(DOTENV_KEYS)),,$(1)="$(2)")
# use:  $(call env,DATABASE_URL,$(DEV_DATABASE_URL)) mycmd
```

Read only the key side of each line in make; the app's own parser owns values, so
the two can never disagree.

## Pinned tools (rule §7)

```make
SQLC_VERSION := v1.31.1
codegen-sql:
	go run github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION) generate
```

Equivalents: `npx --yes tool@$(V)`, `uvx tool==$(V)`. For a prebuilt binary,
download once into `bin/` named with the version, verify with `sha256sum -c`, and
detect OS/arch with `uname -s`/`uname -m` (map `x86_64|amd64` → `x64`,
`arm64|aarch64` → `arm64`).

## Container engine

Ask once. Options:

```make
# Fixed engine (recommended when the repo only supports one): spell it out.
compose-up:
	podman compose -f deploy/compose.yaml up -d

# Detected engine:
CONTAINER ?= $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)
compose-up:
	$(CONTAINER) compose -f deploy/compose.yaml up -d
```

Library tests (testcontainers etc.) need the engine's *socket*, not its CLI, and
the path moves per user. Resolve it lazily:

```make
PODMAN_API_SOCKET = $(shell podman info --format '{{.Host.RemoteSocket.Path}}' 2>/dev/null)
PODMAN_API_ENV    = $(if $(PODMAN_API_SOCKET),DOCKER_HOST=unix://$(PODMAN_API_SOCKET))
go-test:
	$(PODMAN_API_ENV) go test ./...
```

Docker's equivalent is `DOCKER_HOST` already set by the daemon; do nothing.
Silence podman's compose banner with `export PODMAN_COMPOSE_WARNING_LOGS = false`.
Rootless engines cannot bind ports below 1024; choose ports accordingly.

## Waiting for infra instead of sleeping

```make
dev-all: compose-up ## Everything for local work in one terminal
	@until podman compose -f deploy/compose.yaml exec -T db pg_isready -q >/dev/null 2>&1; do sleep 1; done
	@trap 'kill 0' INT TERM; \
		( cd backend && go run . ) & \
		( pnpm --filter web dev --port $(WEB_PORT) ) & \
		wait
```

Ctrl-C stops the foreground processes; say in an `@echo` that infra keeps running
and which target stops it.

## Codegen + drift check (rule §8)

```make
GENERATED_PATHS := internal/gen packages/client/src/schema.d.ts

codegen: codegen-go codegen-sql codegen-ts ## Regenerate all generated code

codegen-check: codegen ## Regenerate and fail if the committed output drifted
	@if ! git diff --quiet -- $(GENERATED_PATHS); then \
		echo "ERROR: codegen drift. Run 'make codegen' and commit the result."; \
		git --no-pager diff --stat -- $(GENERATED_PATHS); \
		exit 1; \
	fi
	@echo "codegen is up to date."
```

Comment above it who runs it (CI, or "nothing does — run it yourself").

## Test gate comments (rule §4)

```make
# The full sweep. <No CI | CI also runs this>. ~N min, almost all of it <the slow
# part>. <Dependency> must be reachable: without it the integration tests SKIP
# rather than fail, so a green run proves less than it looks like.
test: js-test go-test ## Full sweep (needs <dep>, ~N min)
test-short: js-test go-test-short ## Fast loop: no containers, seconds
```

## Outdated (rule §8)

Read-only; each section may fail alone so one stack cannot hide another.

```make
outdated: ## Report newer deps and pinned tools (read-only)
	@echo "==> JS"; pnpm outdated -r || true
	@echo "==> Go (direct only)"; cd backend && go list -u -m -f '{{if and (not .Indirect) .Update}}  {{.Path}} {{.Version}} -> {{.Update.Version}}{{end}}' all | sed '/^$$/d'
	@echo "==> Pinned tools"
	@cd backend && echo "  sqlc $(SQLC_VERSION) -> $$(go list -m -f '{{.Version}}' github.com/sqlc-dev/sqlc@latest)"
```

Use a node one-liner on `pnpm outdated --format json` for one line per package
when the default table is too wide. Mention exact-pinned packages are deliberate
(framework SDK matches) and major bumps need care.

## E2E with guaranteed teardown (rule §12)

Put lifecycle in a script or the test runner's global setup/teardown, not in
Make; the target just calls it:

```make
e2e-mobile: ## Boot emulator + stack, run flows, ALWAYS tear down (FLOWS= narrows)
	POSTGRES_PORT=$(POSTGRES_PORT) API_PORT=$(API_PORT) scripts/e2e-mobile.sh $(FLOWS)
```

The script starts with `trap cleanup EXIT INT TERM` before starting anything.
Add a separate `e2e-stack-down` for the case the whole machine died mid-run.

## Release / promote (interactive)

```make
release: ## Build + push one immutable image version (interactive)
	IMAGE=$(IMAGE) ./deploy/release.sh
promote: ## Point an environment at a released version (interactive; VERSION= optional)
	IMAGE=$(IMAGE) VERSION=$(VERSION) ./deploy/promote.sh
```

If the project follows the `vps-deploy` skill, these two targets are the minimum
Make exposes; it may add `migrate`, `roll` or `sync` depending on its deploy
choices.

## Platform branching

```make
HOST_OS   := $(shell uname -s)
HOST_ARCH := $(shell uname -m)
ifeq ($(HOST_OS),Darwin)
  # macOS-only: signing, notarising, xcodebuild
endif
```

Keep macOS-only targets either behind this guard or out of the help on Linux.
