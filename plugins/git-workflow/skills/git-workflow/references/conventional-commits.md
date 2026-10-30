# Conventional Commits

A commit message convention that makes history machine-readable (changelogs,
semver bumps) and human-scannable. Spec: https://www.conventionalcommits.org.

## Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Only the first line (`<type>(<scope>): <subject>`) is required. Scope is optional.

## Types

Use the type that names what *kind* of change this is. If two types apply, the
commit probably isn't atomic — split it.

| Type | Use for | SemVer |
|------|---------|--------|
| `feat` | A new feature or capability | MINOR |
| `fix` | A bug fix | PATCH |
| `docs` | Documentation only | — |
| `style` | Formatting, whitespace, semicolons — no code-behavior change | — |
| `refactor` | Code change that neither fixes a bug nor adds a feature | — |
| `perf` | A change that improves performance | PATCH |
| `test` | Adding or correcting tests | — |
| `build` | Build system or dependencies (npm, gradle, Docker, etc.) | — |
| `ci` | CI configuration and scripts (GitHub Actions, etc.) | — |
| `chore` | Maintenance that doesn't touch src or tests (configs, tooling) | — |
| `revert` | Reverts a previous commit | — |

## Scope

Optional noun in parentheses naming the area touched: `feat(auth):`,
`fix(parser):`, `refactor(api):`. Keep it short and consistent with scopes
already used in the repo (skim `git log` to match existing conventions). Omit it
if the change is broad or no clear scope fits.

## Subject line

- **Imperative mood**, present tense: "add", "fix", "remove" — not "added"/"adds".
  (It should complete the sentence "If applied, this commit will ___".)
- **No trailing period.** Lowercase first letter after the colon.
- **≤ 50 characters** if you can; hard cap around 72.
- Describe *what and why*, not *how*.

## Body (optional)

Wrap at ~72 columns. Explain motivation and contrast with previous behavior —
the *why*, which the diff can't convey. Separate from the subject with a blank
line. Bullet points are fine.

## Breaking changes

Signal an API/behavior break in one of two ways (or both):

- Append `!` after the type/scope: `feat(api)!: drop support for Node 16`
- Add a footer: `BREAKING CHANGE: <description of what breaks and the migration>`

A breaking change triggers a MAJOR version bump.

## Footers

`key: value` lines after a blank line. Common ones:

- `Refs: #123`, `Closes #123`, `Fixes #123` — link issues.
- `Co-authored-by: Name <email>` — credit collaborators.
- `BREAKING CHANGE: ...` — as above.

## Examples

**Simple fix:**
```
fix(auth): reject expired JWTs before signature check
```

**Feature with body and issue link:**
```
feat(search): add fuzzy matching to the command palette

Ranks results by Levenshtein distance so typos still surface the
intended command. Falls back to substring match when the query is
under three characters.

Closes #482
```

**Breaking change:**
```
refactor(config)!: load settings from XDG paths only

BREAKING CHANGE: ~/.apprc is no longer read. Move config to
~/.config/app/config.toml. See MIGRATION.md.
```

## Anti-patterns to avoid

- Vague subjects: `fix: bug`, `chore: stuff`, `update code`. Say what changed.
- Mixing changes: a `feat` commit that also reformats 40 unrelated files. Split it.
- Past tense / sentence case / trailing periods.
- Restating the diff line-by-line in the body instead of explaining *why*.
