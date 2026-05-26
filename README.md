# Skills

A collection of [Agent Skills](https://www.agensi.io/learn/skill-md-specification-open-standard) for AI coding harnesses. Each skill is a self-contained `SKILL.md` with YAML frontmatter and instructions, compatible with **Claude Code**, **opencode**, and any harness that implements the SKILL.md open standard.

## Skills

| Skill | Description |
|---|---|
| [project-mgmt](skills/project-mgmt/) | Manages project artifacts in `.agents/` — requirements, specs, plans, and documents. Full lifecycle support with cross-linking and ingest of existing docs. |

## Installation

### Claude Code — plugin marketplace (recommended)

```text
/plugin marketplace add chaitanyaSoni96/skills
/plugin install project-mgmt@skills
```

### Claude Code — manual

```bash
git clone https://github.com/chaitanyaSoni96/skills.git
cd skills
./install.sh project-mgmt
# or install everything:
./install.sh all
```

This symlinks `skills/project-mgmt/` into `~/.claude/skills/project-mgmt/`. Edits to the repo are picked up automatically.

### opencode

opencode also reads from `~/.claude/skills/`, so the Claude Code install path above works directly. To install into opencode's native skills directory instead:

```bash
./install.sh --harness opencode all
```

This symlinks into `~/.config/opencode/skills/`.

### Other harnesses

Skills are plain markdown with YAML frontmatter. If your harness doesn't auto-discover `SKILL.md` files, copy the contents of the relevant `skills/<name>/SKILL.md` into whatever instruction file your harness uses (e.g. `AGENTS.md`, `.cursorrules`).

## Repo layout

```
.
├── README.md
├── LICENSE
├── install.sh                          # Symlink helper
├── .claude-plugin/
│   └── marketplace.json                # Claude Code plugin marketplace manifest
└── skills/
    └── project-mgmt/
        └── SKILL.md
```

## Adding a new skill

1. Create `skills/<your-skill>/SKILL.md` with YAML frontmatter (`name`, `description`).
2. Add an entry to the `plugins` array in `.claude-plugin/marketplace.json`.
3. Add a row to the Skills table in this README.

## License

MIT — see [LICENSE](LICENSE).
