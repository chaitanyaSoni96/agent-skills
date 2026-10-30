#!/usr/bin/env bash
# Install capabilities from this repo's plugins into a harness's agent home dir.
#
# Each plugin lives in plugins/<name>/ (and the legacy skill in skills/<name>/)
# and may ship: skills, commands, agents, hooks, mcp. install.sh copies the
# entries of each capability into ~/.agents/<capability>/.
#
# Usage:
#   ./install.sh                          # install everything for auto-detected harness
#   ./install.sh all                      # same as above
#   ./install.sh project-mgmt             # install a single skill by name
#   ./install.sh --only commands          # install just one capability type
#   ./install.sh --harness opencode all   # explicit harness
#   ./install.sh --harness goose all      # explicit harness
#   ./install.sh --list                   # list what this repo ships
#
# Harnesses supported: claude-code, opencode, goose
# Default: claude-code (base ~/.agents/). goose shares that base — it reads
# ~/.agents/skills and ~/.agents/agents natively, but has no markdown commands
# (use YAML recipes). opencode uses its own base (~/.config/opencode/) with
# singular capability dirs. Pass --harness to target a specific one.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS="claude-code"
CAPABILITIES=(skills commands agents hooks mcp)

# Base dir per harness; each capability lives in <base>/<cap_dirname>/
target_base() {
  case "$1" in
    claude-code) echo "${HOME}/.agents" ;;
    opencode)    echo "${HOME}/.config/opencode" ;;
    # goose reads skills from ~/.agents/skills and agents from ~/.agents/agents
    # natively — the same base claude-code uses, so a claude-code install also
    # serves goose for those two capabilities.
    goose)       echo "${HOME}/.agents" ;;
    *) echo "Unknown harness: $1" >&2; exit 1 ;;
  esac
}

# On-disk directory name for a capability, per harness. opencode reads custom
# commands/agents/skills from SINGULAR dirs (command/, agent/, skill/); the
# ~/.agents convention is plural. Map accordingly.
cap_dirname() {
  local cap="$1"
  if [[ "${HARNESS}" == "opencode" ]]; then
    case "${cap}" in
      skills)   echo "skill" ;;
      commands) echo "command" ;;
      agents)   echo "agent" ;;
      *)        echo "${cap}" ;;
    esac
  else
    echo "${cap}"
  fi
}

is_ignored() {
  case "$(basename "$1")" in
    README.md|.gitkeep|.DS_Store) return 0 ;;
    *) return 1 ;;
  esac
}

# Copy one entry into a destination dir, optionally under a new name. Overwrites
# any existing entry so re-running picks up content changes.
copy_entry() {
  local src="$1" dst_dir="$2" name="${3:-$(basename "$1")}"
  local dst="${dst_dir}/${name}"
  mkdir -p "${dst_dir}"
  if [[ -e "${dst}" || -L "${dst}" ]]; then
    rm -rf "${dst}"
    cp -R "${src}" "${dst}"
    echo "    updated ${name} -> ${dst}"
  else
    cp -R "${src}" "${dst}"
    echo "    copied ${name} -> ${dst}"
  fi
}

# Every directory that may hold capability subfolders: the legacy skills root
# (its children are skills) plus each plugin under plugins/.
plugin_roots() {
  [[ -d "${REPO_DIR}/plugins" ]] && for d in "${REPO_DIR}"/plugins/*/; do echo "${d%/}"; done
}

# Install one capability across all plugins (and the legacy skills/ root).
install_capability() {
  local cap="$1"
  local base; base="$(target_base "${HARNESS}")"
  local dst_dir="${base}/$(cap_dirname "${cap}")"
  local printed=0

  _header() { if [[ ${printed} -eq 0 ]]; then echo "${cap}:"; printed=1; fi; }

  # Legacy: top-level skills/<name>/ are skills.
  if [[ "${cap}" == "skills" && -d "${REPO_DIR}/skills" ]]; then
    for d in "${REPO_DIR}"/skills/*/; do
      [[ -d "${d}" ]] || continue
      is_ignored "${d%/}" && continue
      _header; copy_entry "${d%/}" "${dst_dir}"
    done
  fi

  while IFS= read -r root; do
    [[ -n "${root}" ]] || continue
    local pname; pname="$(basename "${root}")"
    case "${cap}" in
      commands)
        # goose has no markdown slash-commands; its equivalent is a YAML recipe
        # (.agents/recipes/ or $GOOSE_RECIPE_PATH). We don't convert, so skip.
        if [[ "${HARNESS}" == "goose" ]]; then
          local src_dir="${root}/commands"
          [[ -d "${src_dir}" ]] || continue
          _header
          echo "    skipping ${pname}: goose uses YAML recipes, not markdown commands"
          continue
        fi
        # Symlink the whole commands/ dir under the plugin name so the harness
        # namespaces them as /<plugin>:<command> — matching `/plugin install`.
        local src_dir="${root}/commands"
        [[ -d "${src_dir}" ]] || continue
        _header; copy_entry "${src_dir}" "${dst_dir}" "${pname}"
        ;;
      skills|agents|hooks)
        local src_dir="${root}/${cap}"
        [[ -d "${src_dir}" ]] || continue
        for e in "${src_dir}"/* "${src_dir}"/.[!.]*; do
          [[ -e "${e}" ]] || continue
          is_ignored "${e}" && continue
          _header; copy_entry "${e}" "${dst_dir}"
        done
        ;;
      mcp)
        # MCP servers are declared in a plugin-root .mcp.json.
        local f="${root}/.mcp.json"
        [[ -f "${f}" ]] || continue
        _header; copy_entry "${f}" "${dst_dir}" "${pname}.mcp.json"
        ;;
    esac
  done < <(plugin_roots)

  # Hooks and MCP servers are configured via settings, not auto-discovered.
  if [[ ${printed} -eq 1 && ( "${cap}" == "hooks" || "${cap}" == "mcp" ) ]]; then
    local cfg="settings.json"
    [[ "${HARNESS}" == "opencode" ]] && cfg="opencode.json"
    [[ "${HARNESS}" == "goose" ]] && cfg="config.yaml (extensions:)"
    echo "    note: ${cap} are not auto-loaded — register them in ${cfg} (see plugins/*/README.md)"
  fi
}

# Install a single named skill (backward-compatible path).
install_skill() {
  local name="$1"
  local src="${REPO_DIR}/skills/${name}"
  [[ -d "${src}" ]] || src="${REPO_DIR}/plugins/${name}/skills/${name}"
  if [[ ! -d "${src}" ]]; then
    echo "Skill not found: ${name}" >&2
    exit 1
  fi
  echo "skills:"
  copy_entry "${src}" "$(target_base "${HARNESS}")/$(cap_dirname skills)"
}

print_inventory() {
  echo "This repo ships:"
  echo "  skills:"
  for d in "${REPO_DIR}"/skills/*/; do [[ -d "${d}" ]] && echo "    - $(basename "${d}")"; done
  while IFS= read -r root; do
    [[ -n "${root}" ]] || continue
    echo "  plugin $(basename "${root}"):"
    for cap in skills commands agents hooks; do
      [[ -d "${root}/${cap}" ]] || continue
      for e in "${root}/${cap}"/* "${root}/${cap}"/.[!.]*; do
        [[ -e "${e}" ]] || continue; is_ignored "${e}" && continue
        echo "    - ${cap}/$(basename "${e}")"
      done
    done
    [[ -f "${root}/.mcp.json" ]] && echo "    - mcp/.mcp.json"
  done < <(plugin_roots)
}

# Parse args
NAMED=()
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness) HARNESS="$2"; shift 2 ;;
    --only)    ONLY="$2"; shift 2 ;;
    --list)    print_inventory; exit 0 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    all) shift ;;
    *) NAMED+=("$1"); shift ;;
  esac
done

echo "Harness: ${HARNESS}"
echo "Base:    $(target_base "${HARNESS}")"
echo ""

if [[ -n "${ONLY}" ]]; then
  install_capability "${ONLY}"
elif [[ ${#NAMED[@]} -gt 0 ]]; then
  for n in "${NAMED[@]}"; do install_skill "${n}"; done
else
  for cap in "${CAPABILITIES[@]}"; do install_capability "${cap}"; done
fi
