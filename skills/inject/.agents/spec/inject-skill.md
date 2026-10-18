---
title: Inject Skill Technical Spec
status: draft
created: 2026-06-01
links: [../requirements/inject-skill/, ../../plans/todo/inject-skill-implementation/]
---

# Inject Skill Spec

## Overview

An opencode skill that dumps the entire human-readable codebase as a JSON blob. Defaults to raw `cat` output. Optionally supports RTK (Rust Token Killer) for token minimization via `/inject rtk`. Triggered by `/inject` command. Lives as a standalone skill under `~/skills/skills/inject/`.

## Architecture

```
~/skills/skills/inject/
├── SKILL.md                    # Skill definition (opencode instructions)
├── scripts/
│   └── injector.sh             # The codebase injection script
├── README.md                   # User-facing docs
├── opencode-snippet.json       # Copy-paste command registration
└── .agents/                    # Project management (this spec lives here)
```

## Script: `scripts/injector.sh`

### Behavior

1. **Parse options**: `-o output.json`, `-r` for RTK mode
2. **Check git repo**: Must be inside a git repository to read `.gitignore`.
3. **Create output dir**: `mkdir -p /tmp/inject/`
4. **Check RTK (if requested)**: Verify `rtk` is installed; exit 2 with install instructions if missing.
5. **Discover files**: Recursively find all files, filter through `git check-ignore`, apply denylist.
6. **Read content**: Feed each file through `cat <file>` (default) or `rtk read <file>` (RTK mode).
7. **Output**: Write JSON to `/tmp/inject/<cwd_basename>_<timestamp>.json`.
8. **Report**: Print metadata to stderr.

### File Inclusion

**Strategy**: Include everything by default, exclude specific patterns.

**Hard denylist** (always excluded regardless of gitignore):
- Directories: `node_modules/`, `target/`, `dist/`, `.git/`, `.pnpm-store/`, `.next/`, `build/`, `out/`, `coverage/`, `.turbo/`, `.vercel/`, `.cache/`, `.parcel-cache/`, `.idea/`, `.vscode/`, `playwright-report/`, `test-results/`
- Extensions: `*.lock`, `*.tar.gz`, `*.zip`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.svg`, `*.ico`, `*.woff`, `*.woff2`, `*.ttf`, `*.eot`, `*.mp4`, `*.mp3`, `*.pdf`, `*.wasm`, `*.dll`, `*.so`, `*.dylib`, `*.exe`, `*.bin`, `*.o`, `*.a`

**Gitignore integration**: All files matching `.gitignore` patterns are excluded.

### Output Format (Default Mode)

```json
{
  "metadata": {
    "project": "<cwd_basename>",
    "generated_at": "2026-06-01T12:34:56Z",
    "files_found": 412,
    "files_processed": 268,
    "files_skipped": 144,
    "total_tokens_est": 450000,
    "output_file": "/tmp/inject/canvas_2026-06-01T12-34-56Z.json"
  },
  "files": {
    "src/main.tsx": "<raw-content>",
    "src-tauri/src/commands.rs": "<raw-content>"
  }
}
```

### Output Format (RTK Mode)

```json
{
  "metadata": {
    "project": "<cwd_basename>",
    "generated_at": "2026-06-01T12:34:56Z",
    "rtk_version": "0.42.0",
    "files_found": 412,
    "files_processed": 268,
    "files_skipped": 144,
    "original_tokens_est": 450000,
    "minimized_tokens_est": 90000,
    "savings_percent": 80,
    "output_file": "/tmp/inject/canvas_2026-06-01T12-34-56Z.json"
  },
  "files": {
    "src/main.tsx": "<rtk-minimized-content>",
    "src-tauri/src/commands.rs": "<rtk-minimized-content>"
  }
}
```

### Output Rules

- JSON is **minified** (single line) for LLM consumption
- File paths are relative to workspace root
- Content values are strings (raw file content or RTK output)
- Metadata object is first for easy parsing
- Timestamp uses ISO 8601 with filesystem-safe characters (`:` replaced with `-`)

### Error Handling

| Scenario | Exit Code | Behavior |
|----------|-----------|----------|
| RTK not installed | 2 | Print `curl -fsSL .../install.sh \| sh` command |
| Not a git repo | 1 | Print "Must be run inside a git repository" |
| No files found | 1 | Print "No human-readable files found in workspace" |
| Success | 0 | Print JSON path to stderr |

### Usage

```bash
# Default: raw output to /tmp/inject/<name>_<timestamp>.json
bash ~/skills/skills/inject/scripts/injector.sh

# RTK mode: token-minimized output
bash ~/skills/skills/inject/scripts/injector.sh -r

# Custom output path
bash ~/skills/skills/inject/scripts/injector.sh -o ./my-output.json

# RTK with custom path
bash ~/skills/skills/inject/scripts/injector.sh -r -o ./my-output.json
```

## Skill: `SKILL.md`

```markdown
---
name: inject
description: |
  Use ONLY when the user types /inject or asks to "dump the codebase", "suck up the code", 
  "ingest the project", "inject the code", or output the entire human-readable codebase. 
  Dumps the entire human-readable codebase as a JSON blob. Defaults to raw `cat` output.
  Optionally supports RTK (Rust Token Killer) for token minimization via `/inject rtk`.
  Requires git to be installed. Respects .gitignore. Outputs JSON 
  with filename-to-content mapping. Triggers ONLY on explicit /inject or codebase dump requests.
---

# /inject Skill

Dumps the entire human-readable codebase as a JSON blob.

## Modes

- **`/inject`** (default): Raw file content using `cat` — no external dependencies.
- **`/inject rtk`**: Token-minimized content using RTK (Rust Token Killer) — requires RTK to be installed.

## Requirements
- Git must be installed
- Must be run from within a git repository (to read .gitignore rules)
- **RTK mode only**: RTK installed (`rtk --version` should succeed)

## Execution Steps

1. **Determine mode**: Check if the user said `/inject rtk` or just `/inject`.

2. **Run injector**:
   - Default: `bash ~/skills/skills/inject/scripts/injector.sh`
   - RTK: `bash ~/skills/skills/inject/scripts/injector.sh -r`

3. **RTK not installed?** If `-r` fails with exit code 2, show the install command:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
   ```

4. **Read output**: The script prints the JSON path to stderr. Read that file.

5. **Present results**: Show the metadata (files processed, token savings if RTK) and a preview of the first 5 entries. Ask if the user wants the full output saved to a custom path or copied to clipboard.

6. **Optional**: If the user requests, write the JSON to a specific file in the workspace (e.g., `codebase-injected.json`).
```

## opencode.json Registration

```json
{
  "command": {
    "inject": {
      "description": "Dump the entire human-readable codebase as a JSON blob. Default: raw cat. Optional: /inject rtk for RTK minimization. Respects .gitignore. Outputs to /tmp/inject/.",
      "template": "Check if the user wants RTK mode (e.g. /inject rtk). If so, run `bash ~/skills/skills/inject/scripts/injector.sh -r`. Otherwise run `bash ~/skills/skills/inject/scripts/injector.sh`. If the RTK command fails with exit code 2, tell the user to run: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh. Read the generated JSON file from /tmp/inject/. Present the metadata (files processed, token savings if RTK) and a preview of the first few entries. Ask the user if they want the full output saved elsewhere."
    }
  }
}
```

## Trade-offs

1. **Default mode**: No token minimization with raw `cat`, but zero external dependencies.
2. **RTK mode**: 60-90% token savings, but requires installing RTK.
3. **Git dependency**: Requires `git` to read `.gitignore`. Non-git projects will need a manual file list or `.gitignore` creation.
4. **Raw JSON output**: Human-readable content, but can be large for big repos.
5. **/tmp output**: Auto-cleaned by the OS, but user must manually move if they want persistence.

## Risks

1. **RTK not installed**: Mitigated by clear error message with one-liner install command.
2. **Huge repos**: Deferred to v2. Could add `--max-files` flag or streaming output.
3. **Sensitive files**: `.env` files are typically gitignored, but if not, they could be included. Denylist does not currently exclude `.env` specifically.

## Future Enhancements

- Add `--max-files` flag for huge repositories
- Add `--include` / `--exclude` glob patterns as CLI flags
- Add streaming output for repos larger than context window
- Add `.env` and secrets to default denylist
- Support non-git projects with manual `.gitignore` equivalent
