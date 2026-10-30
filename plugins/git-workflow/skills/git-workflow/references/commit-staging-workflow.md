# Commit & staging workflow

Goal: every commit is **atomic** — one self-contained logical change that builds
and (ideally) passes tests on its own. This guide covers deciding what belongs
together, staging it, and committing only *part* of a file when needed.

## Deciding what goes in a commit

Before staging, run `git status` and `git diff` and ask: is this one logical
change, or several wearing a trenchcoat? Split when you see:

- A bug fix tangled with a refactor or a formatting sweep.
- Two unrelated features/fixes in the same working tree.
- A real change plus leftover debugging (a stray `print`/`console.log`).
- Changes that would need different commit *types* (`feat` + `fix` + `chore`).

Rule of thumb: if the commit subject needs an "and", it's probably two commits.

## Staging whole files or paths

When an entire file (or set of paths) belongs in the commit:

```bash
git add path/to/file.py path/to/other.py
git diff --cached            # verify exactly what's staged
git commit                   # message per conventional-commits.md
```

Never reflexively `git commit -a` — it stages every tracked modification,
defeating atomic commits and sweeping in things you meant to leave behind.

## Committing only part of a file

Two tools, depending on how fine-grained you need to be.

### Hunk-level: `git add -p`

For changes separated by context lines, interactively stage whole hunks:

```bash
git add -p path/to/file.py
```

Answer `y`/`n` per hunk; `s` splits a hunk where there's a context line between
changes. Fast when the changes you want are already in separate hunks.

### Line-level: the bundled script (GitHub Desktop's method)

When the changes you want are on **adjacent lines** (same hunk, no context
between them), `git add -p` can't separate them — `s` won't split and editing the
hunk by hand (`e`) means hand-correcting `@@` headers, which is error-prone. The
bundled `scripts/partial_stage.py` does true per-line selection by rebuilding the
patch and applying it with `git apply --cached` — the same mechanism GitHub
Desktop uses internally.

```bash
# 1. List the diff with a stable [n] on every changed (+/-) line:
python3 scripts/partial_stage.py list path/to/file.py

# 2. Read the output, map the user's intent to line indices, and stage them:
python3 scripts/partial_stage.py stage path/to/file.py --select 1,3-5
```

What the script does with your selection (mirrors GitHub Desktop's
`patch-formatter.ts`): selected lines are kept, unselected additions are dropped,
unselected deletions are demoted to context lines, and each hunk header's counts
are recomputed. Everything you didn't select stays in the working tree.

**Notes & limits:**
- Indices are valid only for the diff as it was when you ran `list`. If the file
  changes on disk, re-run `list` before `stage`.
- Scope is **modified, already-tracked text files**. The script rejects binary
  files, new/untracked files, renames, and whole-file deletions with a clear
  message — handle those with ordinary `git add`.
- Selecting one side of a modification is allowed and behaves like GitHub
  Desktop, but usually you want both halves of a change together.

## Verify, then commit

Always confirm the index holds exactly what you intend:

```bash
git diff --cached -- <file>     # what will be committed
git diff -- <file>              # what stays behind, unstaged
git commit                      # no -a
```

If the remaining changes should go into a *second* commit, repeat the cycle.

## Quick reference

| Situation | Approach |
|-----------|----------|
| Whole file(s) belong in the commit | `git add <paths>` |
| Want some hunks, separated by context | `git add -p` |
| Want some lines, adjacent / mid-hunk | `partial_stage.py list` → `stage --select` |
| Mixed unrelated changes in the tree | split into several atomic commits |
