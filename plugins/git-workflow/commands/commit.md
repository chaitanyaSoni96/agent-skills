---
description: Commit the working tree as atomic Conventional Commits, split into logical chunks. Does not push.
argument-hint: [optional instructions, e.g. "only the auth changes"]
---

Load the **git-workflow** skill with the Skill tool before doing anything else (it may be listed as `git-workflow` or `git-workflow:git-workflow`). If the Skill tool doesn't list it, read `${CLAUDE_PLUGIN_ROOT}/skills/git-workflow/SKILL.md` directly. Follow its core principles and "common flow"; read `references/conventional-commits.md` and `references/commit-staging-workflow.md` as it directs.

Task: create Conventional Commit(s) for the current working tree, split into atomic commits. Do not push.

User instructions (may narrow scope): $ARGUMENTS

1. Inspect everything that changed — `git status`, `git diff`, `git diff --staged` (in parallel).
2. Group changes into atomic commits: one logical change each. Never mix unrelated changes. For subsets of a single file's diff, use the skill's `partial_stage.py` script.
3. Per chunk: stage only its files/hunks, verify with `git diff --cached`, then commit with a `type(scope): subject` message. Never use `git commit -a`.
4. Finish with `git log --oneline -n <chunk count>` to show the result, and present the `git push` command for the user to run — do not push yourself.
