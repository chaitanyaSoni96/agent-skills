# Stack building blocks

For each detected stack: the helper targets to define and the commands behind them.
Always prefer the project's own scripts/config over the defaults below: if
`package.json` has a `lint` script, call that; if `pyproject.toml` configures
ruff, call ruff. Check with `scripts/detect-stack.sh` (it lists scripts found).

Helper naming: `<prefix>-<verb>`. Prefixes: `go`, `js`, `py`, `rs`, `swift`, `jvm`,
`rb`, `php`, `ex`, `dotnet`. A monorepo with two stacks uses two prefixes; a
project with one stack may skip helpers and put the command in the public target.

## Go (`go.mod`)

| Helper | Command |
|---|---|
| `go-build` | `go build ./...` |
| `go-lint` | `golangci-lint run ./...` (else `go vet ./...`) |
| `go-test` | `go test ./...` |
| `go-test-short` | `go test ./... -short` |
| `go-cover` | `go test ./... -coverprofile=coverage.out -covermode=atomic` then `go tool cover -func=coverage.out \| tail -1` |
| fmt | `gofumpt -l -w .` (else `gofmt -l -w .`) |
| outdated | `go list -u -m -f '{{if and (not .Indirect) .Update}}  {{.Path}} {{.Version}} -> {{.Update.Version}}{{end}}' all` |
| generate | `go generate ./...`; pinned tools via `go run pkg@$(VER)` |

Run from the module dir (`cd apps/api && …`). Integration tests that start
containers use the `-short` flag as their skip switch; document that. Tests using
testcontainers need a container *socket*, not a CLI (see patterns.md "container
engine").

## Node (`package.json`)

Pick the package manager from the lockfile: `pnpm-lock.yaml` → pnpm,
`package-lock.json` → npm, `yarn.lock` → yarn, `bun.lock*` → bun. Never mix.
Call scripts, not binaries: `npm run -s lint`. Verify each exists first.

| Helper | Command |
|---|---|
| install | `pnpm install --frozen-lockfile` / `npm ci` (only if a `setup` target is wanted) |
| `js-build` | `<pm> run build` (monorepo+turbo: `pnpm turbo run build`) |
| `js-lint` | `<pm> run lint` (turbo: `pnpm turbo run lint`) |
| `js-typecheck` | `<pm> run typecheck` or `tsc --noEmit` |
| `js-test` | `<pm> run test` |
| fmt | `biome format --write .` / `prettier --write .` / `<pm> run format` |
| outdated | pnpm: `pnpm outdated -r --format json` (pretty-print with a node one-liner); npm: `npm outdated`; yarn: `yarn outdated` |

Workspaces: a root `pnpm-workspace.yaml`, or `workspaces` in `package.json`.
turbo (`turbo.json`) means aggregates call `<pm> turbo run <task>`; E2E that needs
containers or a built export must *not* be a turbo `test` task.

### Next.js (`next.config.*`)
`dev`: `next dev -p $(WEB_PORT)`; `build`: `next build`; `start`: `next start`.
Lint through the project's `lint` script (the `next lint` command was removed in
newer majors; do not assume it).

### NestJS (`nest-cli.json`)
`dev`: `nest start --watch`; `build`: `nest build`; tests via the `test` script
(jest). Often paired with a Next.js client in `client-*/server-*` dirs: give each a
`<dir>-` helper or use `-C dir`.

### Expo / React Native (`app.json`, `expo` dep)
`dev`: `expo start --port $(EXPO_PORT)`; web export: `expo export -p web`;
native release builds: `eas build` run by hand, not a default target. Pass the API
origin to the dev server by env (`EXPO_PUBLIC_*` or a config var), never bake
`localhost` into a build that will run on a device (`rules.md` §9).

### Tauri (`src-tauri/Cargo.toml`)
`dev`: `<pm> run tauri dev`; `build`: `<pm> run tauri build`. Rust side is a normal
Cargo helper set (`rs-*`, with `--manifest-path src-tauri/Cargo.toml`). Signing,
notarising and DMG steps are macOS-only: guard with `uname -s` or keep them out of
the default surface.

## Python

Pick from the lockfile/config: `uv.lock` or `[tool.uv]` → uv; `poetry.lock` →
poetry; `requirements.txt` only → venv + pip.

| Helper | uv | poetry | pip |
|---|---|---|---|
| install | `uv sync` | `poetry install` | `python -m venv .venv && .venv/bin/pip install -r requirements.txt` |
| `py-lint` | `uv run ruff check .` | `poetry run ruff check .` | `.venv/bin/ruff check .` |
| fmt | `uv run ruff format .` | same with poetry | same with venv |
| typecheck | `uv run mypy .` or `pyright` (whichever is configured) | | |
| `py-test` | `uv run pytest` | `poetry run pytest` | `.venv/bin/python -m pytest` |
| outdated | `uv pip list --outdated` | `poetry show --outdated` | `.venv/bin/pip list --outdated` |

uv workspaces (`[tool.uv.workspace]`): `uv sync --all-packages`, run tests per
member with `--package`. Do not `pip install` into the system interpreter.

## Rust (`Cargo.toml`)

`rs-build`: `cargo build --workspace`; `rs-lint`: `cargo clippy --workspace
--all-targets -- -D warnings`; fmt: `cargo fmt --all`; `rs-test`: `cargo test
--workspace`; outdated: `cargo outdated` if installed (else `cargo update --dry-run`).
`cargo install` of a tool belongs in a documented one-time setup, not a recipe.

## Swift / Xcode (`Package.swift`, `project.yml`, `*.xcodeproj`)

SwiftPM-only: `swift build`, `swift test`, `swift format`/`swiftlint`.
XcodeGen: `gen` → `xcodegen generate`; `build: gen` →
`xcodebuild -project X.xcodeproj -scheme X -configuration Debug -derivedDataPath build build`;
UI tests the same with `test`. Wrap piped xcodebuild in `bash -o pipefail -c '… | tail -20'`
(the pipe otherwise hides the exit code). Ignore `build/`, `.build/` and the
generated `.xcodeproj` in `clean`. macOS-only: gate with `uname -s`.

## JVM (`pom.xml`, `build.gradle(.kts)`)

Use the wrapper (`./mvnw`, `./gradlew`) if present, never a global install.
Maven: `-q verify` (test), `-DskipTests package` (build). Gradle: `build`,
`test`, `check` (lint). Formatter/linter come from plugins (spotless, checkstyle):
call the task the build defines.

## Others (generate only if detected)

- **Ruby** (`Gemfile`): `bundle exec rubocop`, `bundle exec rspec`/`rake test`.
- **PHP** (`composer.json`): `composer run <script>`, `vendor/bin/phpunit`.
- **Elixir** (`mix.exs`): `mix format`, `mix test`, `mix credo`.
- **.NET** (`*.sln`/`*.csproj`): `dotnet build`, `dotnet test`, `dotnet format`.
- **Deno/Bun** (`deno.json`, `bun.lock*`): `deno task`/`bun run <script>`.

## Containers and services

`compose*.y(a)ml` → `compose-up`, `compose-down`, plus `logs`/`ps` only if the
project is a service stack. Use compose healthchecks and wait for them in
`dev-all` rather than sleeping. A `Dockerfile` alone → `image` (build) target.
Several compose files (`compose.proxy.yaml`, `compose.tunnel.yaml`) → one target per
overlay, described by what it adds.

## Codegen

Detect by config: `sqlc.yaml`, `buf.yaml`/`*.proto`, `openapi*.y(a)ml`,
`oapi-codegen*.yaml`, `swagger`, `prisma/schema.prisma`, `go:generate` lines.
Each generator is a `codegen-<name>` helper; `codegen` aggregates them;
`codegen-check` regenerates then fails if `git diff` over the generated paths is
non-empty (see patterns.md).

## End-to-end

Playwright (`playwright.config.*`) → `e2e`, with `e2e-build` if it needs a built
artifact. Maestro (`.maestro/`, `flows/`) → `e2e-mobile`. E2E that starts
infrastructure must own and destroy it (`rules.md` §12), use its own ports (§10),
and stay out of `test`/`turbo test`.
