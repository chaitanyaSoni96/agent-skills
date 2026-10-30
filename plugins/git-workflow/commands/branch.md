---
description: Create a well-named branch for a piece of work and switch to it.
argument-hint: <what the branch is for, e.g. "fix login redirect loop">
---

Load the **git-workflow** skill with the Skill tool before doing anything else (it may be listed as `git-workflow` or `git-workflow:git-workflow`). If the Skill tool doesn't list it, read `${CLAUDE_PLUGIN_ROOT}/skills/git-workflow/SKILL.md` directly. Then read `references/branching-and-prs.md` and follow its naming conventions.

Task: create a branch for: $ARGUMENTS

1. Run `git status` and `git branch --show-current` to see where we are. If the working tree has uncommitted changes, tell the user they'll carry over to the new branch.
2. Derive a branch name per the skill's convention (`type/short-kebab-description`, matching the Conventional Commit type of the work). If the task description is empty, infer it from the current diff — or ask.
3. Create the branch from the appropriate base (usually up-to-date `main`) and switch to it: `git switch -c <name>`.
4. Confirm the branch and base to the user.
