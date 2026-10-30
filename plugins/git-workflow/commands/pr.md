---
description: Push the current branch and open a pull request with a proper title and body.
argument-hint: [optional context for the PR description]
---

Load the **git-workflow** skill with the Skill tool before doing anything else (it may be listed as `git-workflow` or `git-workflow:git-workflow`). If the Skill tool doesn't list it, read `${CLAUDE_PLUGIN_ROOT}/skills/git-workflow/SKILL.md` directly. Then read `references/branching-and-prs.md` and follow it.

Task: open a pull request for the current branch. Extra context: $ARGUMENTS

1. Inspect what the PR will contain: `git status` (nothing important left uncommitted), `git log <base>..HEAD --oneline`, and `git diff <base>...HEAD --stat`. Determine the base branch (usually `main`).
2. If there are uncommitted changes that belong in the PR, stop and suggest `/git-workflow:commit` first.
3. Pushing is outward-facing: show the exact `git push -u origin <branch>` command and confirm with the user before running it (unless they already told you to push).
4. Open the PR with `gh pr create` — title in Conventional Commit style summarizing the branch's net change; body with Summary and Test plan sections per the skill's guidance, covering ALL commits in the range, not just the latest.
5. Reply with the PR URL.
