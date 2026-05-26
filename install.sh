#!/usr/bin/env bash
# Install one or more skills from this repo into a harness's skills directory.
#
# Usage:
#   ./install.sh                          # install all skills for auto-detected harness
#   ./install.sh project-mgmt             # install a single skill
#   ./install.sh --harness opencode all   # explicit harness
#   ./install.sh --list                   # list available skills
#
# Harnesses supported: claude-code, opencode
# Default: claude-code (uses ~/.claude/skills/, which opencode also reads from)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${REPO_DIR}/skills"
HARNESS="claude-code"

print_skills() {
  echo "Available skills:"
  for d in "${SKILLS_DIR}"/*/; do
    name="$(basename "$d")"
    echo "  - ${name}"
  done
}

target_dir() {
  case "$1" in
    claude-code) echo "${HOME}/.claude/skills" ;;
    opencode)    echo "${HOME}/.config/opencode/skills" ;;
    *) echo "Unknown harness: $1" >&2; exit 1 ;;
  esac
}

install_one() {
  local name="$1"
  local src="${SKILLS_DIR}/${name}"
  local dst_dir
  dst_dir="$(target_dir "${HARNESS}")"
  local dst="${dst_dir}/${name}"

  if [[ ! -d "${src}" ]]; then
    echo "Skill not found: ${name}" >&2
    exit 1
  fi

  mkdir -p "${dst_dir}"

  if [[ -e "${dst}" || -L "${dst}" ]]; then
    echo "Already installed: ${dst} (remove it first to reinstall)"
    return
  fi

  ln -s "${src}" "${dst}"
  echo "Linked ${name} -> ${dst}"
}

# Parse args
TARGETS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness) HARNESS="$2"; shift 2 ;;
    --list)    print_skills; exit 0 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    all) TARGETS=(); for d in "${SKILLS_DIR}"/*/; do TARGETS+=("$(basename "$d")"); done; shift ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

# Default: install all
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  for d in "${SKILLS_DIR}"/*/; do TARGETS+=("$(basename "$d")"); done
fi

echo "Harness: ${HARNESS}"
echo "Target:  $(target_dir "${HARNESS}")"
echo ""

for t in "${TARGETS[@]}"; do
  install_one "$t"
done
