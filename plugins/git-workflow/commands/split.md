---
description: Split a commit (or a mixed working tree) into atomic commits, down to line level.
argument-hint: [commit ref to split, or blank for the working tree]
---

Load the **git-workflow** skill with the Skill tool before doing anything else (it may be listed as `git-workflow` or `git-workflow:git-workflow`). If the Skill tool doesn't list it, read `${CLAUDE_PLUGIN_ROOT}/skills/git-workflow/SKILL.md` directly. Then read `references/commit-staging-workflow.md` (line-level staging) and, if splitting an existing commit, `references/history-hygiene.md`.

Task: split into atomic commits. Target: $ARGUMENTS (a commit ref, or the working tree if blank)

1. If a commit ref was given: check it isn't pushed/shared (warn and confirm if it is), then undo it in place with `git reset --soft` (HEAD~1 for the tip; for older commits follow the history-hygiene guide) so its changes are back in the index/working tree.
2. Map the changes into logical groups — one concern per commit. Explain the proposed split to the user as you go.
3. Stage each group in turn: whole files with `git add <paths>`; subsets of one file's diff with the skill's script — `partial_stage.py list <file>` then `partial_stage.py stage <file> --select …`.
4. Verify each slice with `git diff --cached` before committing with a proper `type(scope): subject` message.
5. Finish with `git log --oneline` showing the new commits, and confirm `git status` is clean (or shows only what was always uncommitted). Do not push; if the split rewrote pushed history, present `git push --force-with-lease` for the user to run.
