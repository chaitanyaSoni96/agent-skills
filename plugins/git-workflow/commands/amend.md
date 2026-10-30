---
description: Safely fold staged/working changes into the last commit, or reword its message.
argument-hint: [optional new message or instructions]
---

Load the **git-workflow** skill with the Skill tool before doing anything else (it may be listed as `git-workflow` or `git-workflow:git-workflow`). If the Skill tool doesn't list it, read `${CLAUDE_PLUGIN_ROOT}/skills/git-workflow/SKILL.md` directly. Then read `references/history-hygiene.md` and follow its safety rules.

Task: amend the last commit. User instructions: $ARGUMENTS

1. Safety first: check whether the last commit has been pushed (`git status -sb`, compare with `@{u}` if it exists). If it's already on the remote, warn that amending rewrites shared history and get explicit confirmation before proceeding.
2. Show the user what the amend will do: `git log -1 --stat` plus `git diff --cached` / `git diff` for what would be folded in.
3. Only fold in changes that belong to the same logical change as the last commit — if they're a different concern, recommend a new commit (`/git-workflow:commit`) instead of amending.
4. Stage precisely what belongs, then `git commit --amend` (keep the message unless the user asked to reword; if rewording, follow Conventional Commits).
5. Show the resulting commit with `git log -1 --stat`. If a force-push is now needed, present `git push --force-with-lease` for the user to run — never plain `--force`, and never run it yourself.
