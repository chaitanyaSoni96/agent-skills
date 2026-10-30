# History hygiene — rebase, squash, amend, fixup, split

Tools for reshaping commits *after* they're made. They all rewrite history, so
one rule governs everything here:

> **The Golden Rule:** never rewrite history that others may have based work on.
> Rewriting your own local / un-pushed commits (or a private feature branch only
> you use) is safe and encouraged. Rewriting `main` or a shared branch forces
> everyone else to recover — don't, unless the whole team has agreed.

After any history rewrite the local branch diverges from its remote, so the push
will be rejected as non-fast-forward. Push with **`--force-with-lease`** (which
refuses if someone else pushed in the meantime), never bare `--force`. As always,
present the push command rather than running it unprompted.

## Amend the last commit

Fix the most recent commit's message or contents (before it's shared):

```bash
git commit --amend                       # edit message (opens editor)
git commit --amend -m "fix(auth): correct token expiry check"
git add forgotten_file.py && git commit --amend --no-edit   # add a file, keep message
```

## Squash / reword / reorder with interactive rebase

`git rebase -i <base>` opens a todo list of commits with an action per line.
`<base>` is usually `origin/main` or a count like `HEAD~4`.

> Interactive rebase opens an editor and can't run in a non-interactive shell. If
> you're in an automated/headless context, set the editor to a non-interactive
> command or prepare the actions explicitly; otherwise hand the command to the
> user to run.

Actions:

| Action | Effect |
|--------|--------|
| `pick` | keep the commit as-is |
| `reword` | keep the commit, edit its message |
| `edit` | pause at this commit to amend its contents |
| `squash` | merge into the previous commit, combine messages |
| `fixup` | merge into the previous commit, **discard** this message |
| `drop` | remove the commit entirely |
| (reorder lines) | reorders the commits |

```bash
git rebase -i origin/main      # tidy a whole feature branch before a PR
git rebase -i HEAD~3           # operate on the last 3 commits
```

A common pre-PR cleanup: `pick` the first real commit, `fixup` the
"oops typo" / "address review" commits into it, `reword` the rest into proper
Conventional Commits.

## Autosquash (the clean way to fix an earlier commit)

When you spot a problem in an earlier commit while still working, make a fixup
commit targeting it, then let rebase fold it in automatically:

```bash
git commit --fixup <target-sha>          # creates "fixup! <target subject>"
git rebase -i --autosquash origin/main   # auto-orders the fixup under its target
```

`git commit --squash <sha>` works the same but lets you also extend the message.

## Splitting one commit into several

To break a too-large commit into atomic pieces:

1. `git rebase -i <base>` and mark the target commit `edit`.
2. When rebase pauses on it, undo the commit but keep the changes unstaged:
   ```bash
   git reset HEAD~
   ```
3. Re-stage and commit in logical slices — use the staging workflow
   (`git add -p` or `partial_stage.py`) to separate changes, committing each with
   its own Conventional Commits message. See commit-staging-workflow.md.
4. `git rebase --continue` when the working tree is clean.

This is the right tool when the user asks to "split my last commit" or "break
this commit up" — it operates on *existing history*, unlike partial staging which
works on the *uncommitted* working tree.

## Undoing things safely

- **Unstage** a file (keep changes): `git restore --staged <file>` (or
  `git reset HEAD <file>` on older git).
- **Undo the last commit, keep changes staged:** `git reset --soft HEAD~1`.
- **Undo the last commit, keep changes unstaged:** `git reset HEAD~1`.
- **Revert a *published* commit** (safe — makes a new inverse commit, no rewrite):
  `git revert <sha>`. Prefer this over reset for anything already pushed.
- **Recover from a botched rebase/reset:** `git reflog` shows where HEAD has been;
  `git reset --hard <reflog-sha>` returns to a prior state. The reflog is your
  safety net — almost nothing is truly lost for ~90 days.
