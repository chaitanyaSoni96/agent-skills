# Subagents

Drop one Markdown file per subagent here. Each file is installed as a subagent
the harness can dispatch to (`~/.agents/agents/<name>.md`).

## Format

```markdown
---
name: my-agent
description: One line describing when this agent should be used.
tools: Read, Grep, Glob, Bash      # optional — omit to inherit all tools
model: sonnet                       # optional — sonnet | opus | haiku | inherit
color: green                        # optional — UI hint
---

System prompt for the agent goes here. Describe its role, how it should
work, and what it should return.
```

See `example-agent.md` for a working template. Files named `README.md`,
`.gitkeep`, and dotfiles are ignored by `install.sh`.
