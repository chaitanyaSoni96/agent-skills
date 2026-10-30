---
name: git-workflow
description: >-
  A disciplined git workflow following industry standards — use for ANY git
  authoring task: writing commit messages (Conventional Commits), staging and
  committing changes, deciding what belongs in a commit, partial/line-level
  commits, branch naming, opening pull requests, and rewriting history (rebase,
  squash, amend, fixup, splitting a commit). Reach for this whenever the user
  says "commit this," "write a commit message," "make a conventional commit,"
  "stage only part of this file," "split these changes," "create a branch for
  X," "open a PR," "clean up my commits," "squash these," "rebase onto main," or
  is otherwise doing version-control work and would benefit from atomic commits,
  proper commit messages, and safe history practices. Use it even when the user
  doesn't name a standard — if they're committing or shaping git history, this
  is the skill. Not for non-git VCS (svn, hg) or for GitHub Issues unrelated to a PR.
---

# Git workflow

This skill encodes a disciplined, industry-standard git workflow so commits are
**atomic**, messages follow **Conventional Commits**, and history stays clean and
safe. It bundles a script for true line-level partial commits (the part raw git
makes hard) and reference guides for each area — read the one that fits the task.

## Core principles (apply to every git task)

- **Atomic commits.** One commit = one logical change. If a diff mixes a fix, a
  refactor, and a formatting sweep, that's three commits — not one. This is the
  single highest-leverage habit; almost everything below serves it.
- **Conventional Commits.** Every message follows `type(scope): subject`. The
  format is machine-parseable (drives changelogs and semver) and forces you to
  name *what kind* of change this is — which surfaces non-atomic commits early.
- **Verify before you commit.** Look at `git diff --cached` so you commit exactly
  what you intend. Never `git commit -a` reflexively — it sweeps in unstaged work.
- **Pushing is outward-facing.** Don't push automatically. Stage the commit, then
  present the exact `git push` command for the user to run (or confirm first),
  especially for anything that rewrites shared history.

## Which guide to read

Load the reference that matches the task — don't read all of them. Each is a
focused, self-contained guide.

| Task | Read |
|------|------|
| Write or fix a commit message; what type/scope to use | [references/conventional-commits.md](references/conventional-commits.md) |
| Decide what goes in a commit; stage changes; **commit only part of a file** | [references/commit-staging-workflow.md](references/commit-staging-workflow.md) |
| Name a branch; keep it current; open a pull request | [references/branching-and-prs.md](references/branching-and-prs.md) |
| Rebase, squash, amend, fixup, reorder, or split an existing commit | [references/history-hygiene.md](references/history-hygiene.md) |

## The common flow

Most "commit this" requests follow the same shape:

1. **Inspect.** `git status` and `git diff` — understand what changed and whether
   it's one logical change or several.
2. **Split if needed.** If the working tree mixes unrelated changes, separate
   them into atomic commits. For subsets of a *single file's* diff, use the
   partial-staging script (see the staging guide) — it does true line-level
   selection that `git add -p` can't.
3. **Stage** the slice that belongs in this commit (`git add <paths>`, or the
   partial-staging script), then **verify** with `git diff --cached`.
4. **Commit** with a Conventional Commits message (no `-a`).
5. **Repeat** for the next logical change.
6. **Push:** present the `git push` command rather than running it unprompted.

## Partial / line-level commits (bundled capability)

The hardest part of atomic commits is committing only *some* lines of a file. The
bundled script reproduces GitHub Desktop's mechanism exactly — it rebuilds a
unified-diff patch from your selected lines and applies it with `git apply
--cached`:

```bash
python3 scripts/partial_stage.py list <file>            # diff with a [n] on each changed line
python3 scripts/partial_stage.py stage <file> --select 1,3-5   # stage only those lines
```

Full guidance, rules, and edge cases are in
[references/commit-staging-workflow.md](references/commit-staging-workflow.md).
