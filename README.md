# Skills

A collection of [Agent Skills](https://www.agensi.io/learn/skill-md-specification-open-standard) and Claude Code plugins for AI coding harnesses. Skills are self-contained `SKILL.md` files; plugins additionally bundle slash commands, subagents, hooks, and MCP servers. Compatible with **Claude Code**, **opencode**, and any harness that implements the SKILL.md open standard.

## Plugins

Each plugin is a separate, independently installable unit.

| Plugin | Ships | Description |
|---|---|---|
| [project-mgmt](skills/project-mgmt/) | skill | Manages project artifacts in `.agents/` — requirements, specs, plans, documents. Full lifecycle support with cross-linking and ingest of existing docs. |
| [make-conventions](skills/make-conventions/) | skill | Generates, audits and simplifies Makefiles to one self-documenting, stack-agnostic surface, with a stack detector and a Makefile linter. |
| [vps-deploy](skills/vps-deploy/) | skill | General guidance for self-hosted VPS deployment: rootless podman, Quadlet units, GHCR, build-once release/promote, podman auto-update. |
| [git-workflow](plugins/git-workflow/) | skill + commands | Disciplined git workflow — atomic commits, Conventional Commits, line-level partial staging, branching, PRs, history hygiene. Commands: `/commit`, `/branch`, `/pr`, `/amend`, `/cleanup`, `/split`. |
| [agents-pack](plugins/agents-pack/) | subagents | Reusable subagents (currently a template). |
| [hooks-pack](plugins/hooks-pack/) | hooks | Event-hook definitions (scaffold). |
| [mcp-pack](plugins/mcp-pack/) | mcp | MCP server declarations (scaffold). |

## Installation

### Claude Code — plugin marketplace (recommended)

```text
/plugin marketplace add chaitanyaSoni96/agent-skills
/plugin install project-mgmt@agent-skills
/plugin install git-workflow@agent-skills    # any plugin from the table above
```

### Claude Code — manual

```bash
git clone https://github.com/chaitanyaSoni96/agent-skills.git
cd agent-skills
./install.sh project-mgmt
# or install everything:
./install.sh all
```

This symlinks each plugin's capabilities into `~/.agents/<type>/` — e.g. project-mgmt's skill → `~/.agents/skills/project-mgmt/`, git-workflow's command → `~/.agents/commands/git-workflow/`. Edits to the repo are picked up automatically.

`./install.sh` (no args) or `./install.sh all` installs everything. Other forms:

```bash
./install.sh project-mgmt      # a single skill by name
./install.sh --only commands   # just one capability type, across all plugins
./install.sh --list            # show everything this repo ships
```

> **Hooks and MCP servers** are configured through `settings.json`, not auto-discovered from a directory. `install.sh` symlinks them into `~/.agents/hooks/` and `~/.agents/mcp/` for organization and reminds you to register them (see each plugin's `README.md`).

### opencode

opencode also reads from `~/.claude/skills/`, so the Claude Code install path above works directly. To install into opencode's native skills directory instead:

```bash
./install.sh --harness opencode all
```

This symlinks into `~/.config/opencode/skills/`.

### Other harnesses

Skills are plain markdown with YAML frontmatter. If your harness doesn't auto-discover `SKILL.md` files, copy the contents of the relevant `skills/<name>/SKILL.md` into whatever instruction file your harness uses (e.g. `AGENTS.md`, `.cursorrules`).

## Repo layout

Each plugin is a self-contained directory holding one or more capability
subfolders. Single-skill plugins live under `skills/`; every other plugin lives
under `plugins/`.

```
.
├── README.md
├── LICENSE
├── install.sh                          # Symlink helper (all capability types)
├── .claude-plugin/
│   └── marketplace.json                # Claude Code plugin marketplace manifest
├── skills/
│   ├── make-conventions/                # skill plugin
│   ├── project-mgmt/                    # skill plugin
│   └── vps-deploy/                      # skill plugin
└── plugins/
    ├── git-workflow/                    # skill + command plugin
    │   ├── skills/
    │   │   └── git-workflow/            # SKILL.md, references/, scripts/
    │   └── commands/                    # → /git-workflow:commit, :branch, :pr,
    │       └── *.md                     #   :amend, :cleanup, :split
    ├── agents-pack/                     # subagent plugin
    │   └── agents/example-agent.md
    ├── hooks-pack/                      # hook plugin (settings-registered)
    │   └── hooks/hooks.json
    └── mcp-pack/                        # MCP plugin (settings-registered)
        └── .mcp.json
```

## Adding capabilities

A plugin can ship any mix of `skills/`, `commands/`, `agents/`, `hooks/hooks.json`,
and a root `.mcp.json`. To add a **new plugin**: create `plugins/<name>/` with the
relevant subfolders, add an entry to `.claude-plugin/marketplace.json`, and add a
row to the Plugins table above. To extend an **existing plugin**, just drop files
into its capability subfolders.

- **Skill** — `<plugin>/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`).
- **Command** — `<plugin>/commands/<name>.md` → `/<plugin>:<name>`. The plugin name is the command namespace under both `/plugin install` and `install.sh` (which symlinks `commands/` to `~/.agents/commands/<plugin>/`), so they stay identical.
- **Subagent** — `<plugin>/agents/<name>.md` with `name`/`description` frontmatter (see `plugins/agents-pack/README.md`).
- **Hook** — add to `<plugin>/hooks/hooks.json` (see `plugins/hooks-pack/README.md`).
- **MCP server** — add to `<plugin>/.mcp.json` (see `plugins/mcp-pack/README.md`).

## License

MIT — see [LICENSE](LICENSE).
