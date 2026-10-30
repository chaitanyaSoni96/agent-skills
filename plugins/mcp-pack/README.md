# MCP servers

`.mcp.json` declares MCP servers this repo ships. Empty by default.

## Format

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@scope/my-mcp-server"],
      "env": { "API_KEY": "..." }
    },
    "remote-server": {
      "type": "http",
      "url": "https://mcp.example.com/api"
    }
  }
}
```

## Installation note

Like hooks, MCP servers are configured through `settings.json` / your harness's
MCP config rather than auto-discovered from a directory. `install.sh` symlinks
this folder to `~/.agents/mcp/` for organization and reminds you to register the
servers in your config (or copy `.mcp.json` into your project root).
