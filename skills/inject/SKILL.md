---
name: inject
disable-model-invocation: true
description: |
  Use ONLY when the user types /inject or asks to "dump the codebase", "suck up the code", 
  "ingest the project", "inject the code", or output the entire human-readable codebase. 
   Dumps the entire human-readable codebase as a JSON blob. Defaults to raw `cat` output.
   Optionally supports RTK (Rust Token Killer) for token minimization via `/inject rtk`.
   Works in any directory; respects .gitignore when run inside a git repo.
   Outputs JSON with filename-to-content mapping. Triggers ONLY on explicit /inject or codebase dump requests.
---

# /inject Skill

Dumps the entire human-readable codebase as a JSON blob.

## Modes

- **`/inject`** (default): Raw file content using `cat` — no external dependencies.
- **`/inject rtk`**: Token-minimized content using RTK (Rust Token Killer) — requires RTK to be installed.

## Requirements
- **Git repo mode**: Uses `.gitignore` for filtering
- **Non-git mode**: Works from any directory; falls back to `$PWD` as workspace root
- **RTK mode only**: RTK installed (`rtk --version` should succeed)

## Execution Steps

1. **Determine mode**: Check if the user said `/inject rtk` or just `/inject`.

2. **Run injector** (both paths are relative to this SKILL.md's directory, i.e. the skill folder):
   - Default: `bash ./scripts/injector.sh`
   - RTK: `bash ./scripts/injector.sh -r`

3. **RTK not installed?** If `-r` fails with exit code 2, show the install command:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
   ```

4. **Read output**: The script prints the JSON path to stderr. Read that file.

5. **Present results**: Show the total word count and estimated token count of the JSON output (rough estimate: 1 token ≈ 0.75 words). Also report files processed and token savings if in RTK mode.

6. **Ask user**: Ask the user what to do next — e.g. save the JSON to a file in the workspace, copy to clipboard, or proceed with analysis of the injected codebase.
