# Hooks

`hooks.json` defines event hooks. Put any scripts the hooks invoke alongside it
in this folder.

## Format

```json
{
  "description": "What these hooks do",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "bash \"$REPO/hooks/format.sh\"" }
        ]
      }
    ]
  }
}
```

## Installation note

Unlike skills, commands, and agents, hooks are **not** auto-discovered by
dropping a file in a directory — the harness reads them from `settings.json`.
`install.sh` symlinks this folder to `~/.agents/hooks/` for organization, then
prints a reminder to register the hooks in your `settings.json`:

```json
{ "hooks": { "...": "..." } }   // merge the contents of hooks.json here
```
