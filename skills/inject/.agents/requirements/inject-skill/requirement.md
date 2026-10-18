---
title: Inject Skill
status: draft
created: 2026-06-01
links: [../spec/inject-skill.md]
---

# Inject Skill

## Problem

When working with AI coding assistants, users frequently need to provide the entire codebase context to the model for tasks like:
- Code review across the whole project
- Refactoring that touches multiple files
- Architecture analysis
- Bug hunting across module boundaries

Currently, users manually copy-paste files or use ad-hoc scripts. There is no standardized way to "inject" the entire human-readable codebase into an LLM context window.

## User Impact

- Wastes time manually collecting files
- Risk of missing files or including build artifacts
- No reproducible workflow across projects

## Success Criteria

1. User types `/inject` and gets a raw JSON representation of the entire codebase
2. Output respects `.gitignore` automatically
3. Works across project types (React, Node, iOS, Android, Rust, etc.)
4. Output format is JSON with `{ "relative/path": "raw-content" }` mapping
5. No external dependencies beyond standard unix tools (cat, git)
