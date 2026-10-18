# The contract

Twelve rules. A Makefile that follows them has a menu anyone can read in ten
seconds and a surface that is identical across projects.

## 1. Self-documenting

Bare `make` prints help (`.DEFAULT_GOAL := help`). The help is generated from the
file: groups are `##@ Group name` lines, targets are `name: deps ## description`.
Never maintain a hand-written target list; it rots first.

## 2. A small fixed public set, named by intent

Use these names when the project has the concept; omit those it does not:

| Target | Meaning |
|---|---|
| `dev` | Run the main thing locally with reload |
| `dev-all` | Everything `dev` needs (infra + backend + frontend), one terminal |
| `build` | Build every deliverable |
| `lint` | Static checks, including typecheck |
| `test` | The full gate (may need containers; says how long it takes) |
| `test-short` | The fast loop: seconds, no containers, no network |
| `fmt` | Format everything in place |
| `typecheck` | Only when it is useful on its own |
| `cover` | Coverage report. Reporting, never a gate |
| `codegen` / `codegen-check` | Regenerate / fail on drift |
| `outdated` | Read-only dependency report |
| `clean` | Delete build output only, never data |

Names are verbs/nouns of intent, not tool names: `lint`, not `golangci`.

## 3. Aggregates fan out to every stack

`lint: js-lint go-lint`. Nobody should need to remember which tool covers which
part of a polyglot repo. Order cheap checks first.

## 4. One fast loop, one full gate

`test-short` and `test` both exist or neither does. `test` is the only gate before
pushing; if there is no CI, say so in the comment above it. Tests that silently
skip without a dependency (container engine, database) must be called out in that
comment, because a skipped test looks exactly like a passing one.

## 5. Private helpers carry no `##`

Per-stack building blocks (`go-test`, `js-build`) have no `##` so they stay out of
the help, and are listed in `.PHONY`. If a helper is only used once, inline it.

## 6. No duplicates

If two targets have the same recipe, delete one. Aliases (`js-dev` = `dev`),
trivial wrappers (`e2e-screenshots` that prints a path) and per-tool targets that
`fmt`/`lint` already cover do not earn a slot. Before deleting, grep the repo for
`make <name>`.

## 7. Pinned tools, run not installed

Tool versions live in one block at the top: `SQLC_VERSION := v1.31.1`. Run them by
version (`go run tool@$(V)`, `npx tool@$(V)`, `uvx tool==$(V)`, a downloaded binary
checked against a sha256). Never `pip install`, `npm i -g` or `go install` inside a
recipe: that makes results depend on the machine.

## 8. Reporting is separate from gating

`cover` and `outdated` print and exit 0. `codegen-check` and `lint` fail. Never
let a reporting target block a gate or a gate hide behind `|| true`.

## 9. Overridable config, machine facts resolved

Defaults use `?=`. Precedence is documented: shell env > `.env` > Makefile
defaults. A git-ignored `Makefile.local` (`-include`d) holds per-machine
overrides. Anything that varies by machine (a socket path, a LAN IP, `uname`) is
resolved at expansion time or overridable, never hard-coded. Use `=` (lazy) for a
value built by `$(shell …)` so it only runs when a target uses it.

## 10. One ports block

Every port is a variable declared once; every target that needs it reads the
variable. Pick uncommon defaults (above 1024, away from 3000/5432/8080) so projects
can run side by side, and keep e2e on its own range so it can never touch dev data.

## 11. Comments say why

Descriptions (`##`) say what, in under ~100 characters. Prose comments above a
block say *why it is this way* — the trap it avoids, the decision it records.
Destructive or interactive targets say so in the `##` text ("destructive",
"interactive").

## 12. Cleanup always runs

Any target that starts something (emulator, stack, server) tears it down on every
exit path — a `trap`, a wrapper script with `trap … EXIT`, or `.ONESHELL`-safe
cleanup — not only on success. `clean` removes build output; a separate, loudly
described target removes data.

## Also

- `SHELL := /bin/bash` and, when a recipe pipes, `.SHELLFLAGS := -eo pipefail -c`
  so `cmd | tail` cannot swallow a failure.
- List every non-file target in `.PHONY`.
- Recipes `@echo "==> …"` one line per phase so long targets show progress.
- Put the long `ifeq`/platform logic in a clearly marked block, not mid-file.
