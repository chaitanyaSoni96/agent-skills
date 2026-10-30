# Branching & pull requests

## Branch naming

Use a short, descriptive, kebab-case name prefixed by type. Match whatever the
repo already uses (skim `git branch -a` first); if there's no house style, this
is a safe default:

```
<type>/<short-description>
```

| Prefix | For |
|--------|-----|
| `feature/` (or `feat/`) | new functionality — `feature/oauth-login` |
| `fix/` | bug fixes — `fix/null-pointer-on-logout` |
| `chore/` | maintenance, deps, tooling — `chore/bump-eslint` |
| `docs/` | documentation — `docs/api-readme` |
| `refactor/` | non-behavioral code changes |
| `hotfix/` | urgent production fixes |

Optionally include a ticket id: `feature/PROJ-123-oauth-login`. Keep names lower
case, words separated by hyphens, no spaces.

```bash
git switch -c feature/oauth-login        # create + switch (modern)
git checkout -b feature/oauth-login      # equivalent (older syntax)
```

**Never commit straight to `main`/`master`** on a shared repo. If you're on the
default branch with uncommitted work that should be a feature, branch first.

## Keeping a branch current

Bring in upstream changes before opening or updating a PR so the diff is clean:

```bash
git fetch origin
git rebase origin/main      # linear history (preferred for feature branches)
# — or —
git merge origin/main       # if the team prefers merge commits
```

Prefer `rebase` for your own un-pushed feature branch (keeps history linear). If
the branch is already pushed and shared, see history-hygiene.md before rebasing —
rewriting shared history forces collaborators to recover.

## Opening a pull request

A good PR is reviewable: focused scope, a title that says what changed, and a
body that explains why.

- **Title:** follow Conventional Commits, same as a commit subject —
  `feat(auth): add OAuth login`. Many repos derive the squash-merge commit from
  the PR title, so this matters.
- **Body:** what changed and why; how to test; screenshots for UI; and a
  `Closes #123` / `Fixes #123` line to auto-close the linked issue on merge.
- **Scope:** one logical change per PR. A 2,000-line PR mixing a feature and a
  refactor is hard to review — split it.

With the GitHub CLI:

```bash
git push -u origin feature/oauth-login
gh pr create --title "feat(auth): add OAuth login" --body "..."
gh pr create --fill        # derive title/body from commits
```

## Pushing

Pushing is outward-facing — don't do it unprompted. Stage the commits, then
present the exact command for the user to run (or confirm first):

```bash
git push -u origin feature/oauth-login
```

`-u` sets upstream tracking on the first push so later pushes are a bare
`git push`. Never `git push --force` to a shared branch; use `--force-with-lease`
only on your own branch and only when you understand what you're overwriting
(see history-hygiene.md).
