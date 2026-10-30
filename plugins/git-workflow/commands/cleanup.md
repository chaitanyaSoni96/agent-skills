---
description: Clean up the current branch's commits — squash fixups, reorder, reword — before review.
argument-hint: [optional instructions, e.g. "squash everything into one"]
---

Load the **git-workflow** skill with the Skill tool before doing anything else (it may be listed as `git-workflow` or `git-workflow:git-workflow`). If the Skill tool doesn't list it, read `${CLAUDE_PLUGIN_ROOT}/skills/git-workflow/SKILL.md` directly. Then read `references/history-hygiene.md` and follow it — note that interactive rebase (`-i`) is not available in this environment, so use the non-interactive techniques it describes (`--fixup`/`--autosquash` with `GIT_SEQUENCE_EDITOR=true`, `reset --soft` + recommit, etc.).

Task: tidy the current branch's history into clean, atomic Conventional Commits. User instructions: $ARGUMENTS

1. Safety first: identify the base (`main` unless told otherwise) and check what's been pushed. Rewriting pushed commits needs explicit user confirmation. Never rewrite commits that are on the base branch itself.
2. Review the range: `git log <base>..HEAD --oneline` and per-commit diffs. Identify fixup noise ("wip", "typo", "address review"), commits that should merge, misordered or mislabeled messages, and non-atomic commits.
3. Propose the target history to the user (old list → new list) before rewriting anything.
4. Execute with the safest technique that achieves it, verifying after each step that `git diff <base>` is unchanged — cleanup must never alter the tree's content.
5. Show the final `git log <base>..HEAD --oneline`. If the branch was already pushed, present `git push --force-with-lease` for the user to run — do not push yourself.
