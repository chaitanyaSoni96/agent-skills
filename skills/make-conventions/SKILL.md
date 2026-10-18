---
name: make-conventions
disable-model-invocation: true
description: Use when creating a Makefile for a project, or simplifying, auditing or extending an existing one — too many targets, nobody knows what each does, bare `make` prints nothing useful, or a new stack (Go, Node/pnpm/Next/Nest/Expo, Python/uv, Rust/Tauri, Swift, JVM) must be wired into a consistent dev/build/lint/test/fmt surface. Also use when asked to add an `outdated` or codegen-drift target.
---

# Make conventions

One small, self-documenting Makefile surface that looks the same in every project,
whatever the stack. The Makefile is a **menu of intents** (`dev`, `test`, `lint`…),
not a script dump: per-stack commands hide behind a stable public set.

**REQUIRED BACKGROUND:** read `reference/rules.md` once before generating or
editing anything. It is the contract; everything below applies it.

## Which mode

- **No Makefile yet** → *Generate*.
- **Makefile exists** → run `scripts/lint-makefile.sh Makefile` first, then *Simplify*.
- **Asked to add one capability** (outdated, codegen-check, compose infra, e2e) →
  *Extend*: find the matching block in `reference/patterns.md`, adapt, re-lint.

## Generate

1. **Detect.** Run `scripts/detect-stack.sh <project-dir>`. It prints stacks, package
   managers, workspace/monorepo markers, compose/Dockerfile, codegen configs, e2e
   configs and any existing Makefile. Trust it over guessing; if it finds nothing,
   ask what the project is.
2. **Ask only what cannot be detected** (one question at a time, recommended option
   first): container engine (podman / docker / detect), whether a deploy flow
   exists, whether there is CI (changes the comment on `test`), fixed dev ports.
   Skip any question the detector already answered.
3. **Build the public surface** from the fixed set in `rules.md` §2. For each
   detected stack, pull its lint/test/build/fmt/typecheck/dev commands from
   `reference/stacks.md` and wire them into *private* helpers named `<stack>-<verb>`
   (`go-lint`, `js-test`, `py-lint`…). Public targets are aggregates of helpers.
   Single-stack projects skip the helpers: the public target holds the command.
4. **Add the optional blocks** that apply, from `reference/patterns.md`: help,
   ports block, `Makefile.local`, pinned tools, compose infra, codegen + drift
   check, outdated, e2e with guaranteed cleanup, release/promote.
5. **Lint.** Run `scripts/lint-makefile.sh Makefile` and `make`; fix every
   warning or state why it is intentional. Never present an unlinted Makefile.
6. **Show the user `make` output** (the help), not the file. That is the review.

## Simplify

Run the linter, then in this order: delete duplicates and one-line aliases; move
building blocks out of the help (drop their `##`); add missing descriptions; group
with `##@`; replace a hand-written help list with the generated one. Before
deleting a target, grep the repo (docs, scripts, tests, configs) for `make <name>`
and keep anything referenced, or update the references. Report what was removed
and what was kept for a reason.

## Do not

- Do not invent targets nobody asked for. The fixed set is a ceiling for a new
  project, not a quota.
- Do not install tools globally from a recipe; pin and run them (`rules.md` §7).
- Do not hard-code machine facts (socket paths, IPs, home dirs); resolve or
  override them (`rules.md` §9).
- Do not hide a failing step with `|| true` unless the target is read-only
  reporting (`outdated`), and say so in a comment.
- Do not put stack- or repo-specific quirks in this skill's rules; they go in
  comments in the generated Makefile, next to the line they explain.
