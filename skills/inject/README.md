# inject

An opencode skill that dumps the entire human-readable codebase as a JSON blob.

## Prerequisites

- Git repository (to read `.gitignore` rules)
- **Optional**: [RTK](https://github.com/rtk-ai/rtk) — for token minimization mode:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  ```

## Installation

1. Clone or copy this directory to `~/skills/skills/inject/`
2. Add the command to your `opencode.json`:
   ```json
   {
     "command": {
       "inject": {
         "description": "Dump the entire human-readable codebase as a JSON blob.",
         "template": "Check if the user wants RTK mode (e.g. /inject rtk). If so, run `bash ~/skills/skills/inject/scripts/injector.sh -r`. Otherwise run `bash ~/skills/skills/inject/scripts/injector.sh`. Read the generated JSON file from /tmp/inject/. Present the metadata (files processed, token savings if RTK) and a preview of the first few entries. Ask the user if they want the full output saved elsewhere."
       }
     }
   }
   ```

## Usage

### Via opencode

```
/inject
```

### Direct script usage

```bash
# Default: output to /tmp/inject/<project>_<timestamp>.json
bash ~/skills/skills/inject/scripts/injector.sh

# With custom output path
bash ~/skills/skills/inject/scripts/injector.sh -o ./codebase.json
```

## What it does

1. Scans your workspace for all human-readable files
2. Respects `.gitignore` automatically
3. Excludes build artifacts (node_modules, dist, target, etc.)
4. Outputs JSON: `{ "relative/path": "content", ... }`
5. Saves to `/tmp/inject/<project>_<timestamp>.json`
6. Reports file counts (and token savings for RTK mode) to stderr

## Modes

### Default mode (`/inject`)
- Uses raw `cat` to read files
- No external dependencies beyond `git` and `python3`
- Metadata includes `total_tokens_est`

### RTK mode (`/inject rtk`)
- Uses [RTK](https://github.com/rtk-ai/rtk) for token minimization (60-90% savings)
- Requires RTK to be installed
- Metadata includes `rtk_version`, `original_tokens_est`, `minimized_tokens_est`, `savings_percent`

## Output Example

### Default mode

```json
{
  "metadata": {
    "project": "canvas",
    "generated_at": "2026-06-01T12:34:56Z",
    "files_found": 412,
    "files_processed": 268,
    "files_skipped": 144,
    "total_tokens_est": 450000,
    "output_file": "/tmp/inject/canvas_2026-06-01T12-34-56Z.json"
  },
  "files": {
    "src/main.tsx": "/* raw content */",
    "src-tauri/src/commands.rs": "/* raw content */"
  }
}
```

### RTK mode

```json
{
  "metadata": {
    "project": "canvas",
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
    "src/main.tsx": "/* minimized by rtk */",
    "src-tauri/src/commands.rs": "/* minimized by rtk */"
  }
}
```

## Supported Projects

Works with any project type:
- React / Next.js / Vite
- Node.js / TypeScript
- iOS / Android / React Native
- Rust / Cargo
- Python
- Go
- And more...

## License

MIT
