#!/usr/bin/env bash
# Report what a project is made of, so a Makefile can be generated without guessing.
#
# Usage: detect-stack.sh [project-dir]     (default: .)
#
# Output is plain `key: value` lines, one fact each, grouped by heading. Read-only.
# Looks up to 3 levels deep and skips dependency/build directories.

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

PRUNE=(-name node_modules -o -name .git -o -name vendor -o -name target -o -name dist
       -o -name build -o -name .next -o -name .venv -o -name venv -o -name __pycache__
       -o -name Pods -o -name .gradle -o -name .build -o -name graphify-out)

# find_files NAME... -> relative paths of files with any of these names/globs
find_files() {
  local args=() first=1 n
  for n in "$@"; do
    if [ $first -eq 1 ]; then args+=(-name "$n"); first=0; else args+=(-o -name "$n"); fi
  done
  find . -maxdepth 3 \( "${PRUNE[@]}" \) -prune -o -type f \( "${args[@]}" \) -print 2>/dev/null \
    | sed 's|^\./||' | sort
}

section() { printf '\n## %s\n' "$1"; }
have() { [ -n "$(find_files "$@")" ]; }
list() { local f; f="$(find_files "$@")"; [ -n "$f" ] && printf '%s\n' "$f" | sed 's/^/  /'; return 0; }

echo "project: $(basename "$(pwd)")"

section "Stacks"
have go.mod                       && { echo "go:";           list go.mod; }
have package.json                 && { echo "node:";         list package.json; }
have pyproject.toml requirements.txt setup.py Pipfile \
                                  && { echo "python:";       list pyproject.toml requirements.txt setup.py Pipfile; }
have Cargo.toml                   && { echo "rust:";         list Cargo.toml; }
have pom.xml build.gradle build.gradle.kts \
                                  && { echo "jvm:";          list pom.xml build.gradle build.gradle.kts; }
have Package.swift project.yml '*.xcodeproj' \
                                  && { echo "swift/xcode:";  list Package.swift project.yml '*.xcodeproj'; }
have Gemfile                      && { echo "ruby:";         list Gemfile; }
have composer.json                && { echo "php:";          list composer.json; }
have mix.exs                      && { echo "elixir:";       list mix.exs; }
have '*.csproj' '*.sln'           && { echo "dotnet:";       list '*.csproj' '*.sln'; }
have deno.json deno.jsonc         && { echo "deno:";         list deno.json deno.jsonc; }

section "Node details"
if have package.json; then
  pm=""
  [ -f pnpm-lock.yaml ] && pm="pnpm"
  [ -z "$pm" ] && [ -f yarn.lock ] && pm="yarn"
  [ -z "$pm" ] && { [ -f bun.lock ] || [ -f bun.lockb ]; } && pm="bun"
  [ -z "$pm" ] && [ -f package-lock.json ] && pm="npm"
  [ -z "$pm" ] && pm="unknown (no lockfile at root)"
  echo "package-manager: $pm"
  [ -f pnpm-workspace.yaml ] && echo "workspace: pnpm-workspace.yaml"
  [ -f turbo.json ] && echo "turbo: yes"
  [ -f nx.json ] && echo "nx: yes"
  have 'next.config.*'  && echo "framework: next.js ($(find_files 'next.config.*' | head -1))"
  have nest-cli.json    && echo "framework: nestjs ($(find_files nest-cli.json | head -1))"
  have app.json app.config.js app.config.ts && grep -qs '"expo"' package.json apps/*/package.json 2>/dev/null \
                        && echo "framework: expo"
  have tauri.conf.json  && echo "framework: tauri ($(find_files tauri.conf.json | head -1))"
  have 'vite.config.*'  && echo "bundler: vite"
  have biome.json biome.jsonc && echo "formatter: biome"
  have '.prettierrc*' 'prettier.config.*' && echo "formatter: prettier"
  have '.eslintrc*' 'eslint.config.*'     && echo "linter: eslint"
  echo "scripts (root package.json):"
  if command -v node >/dev/null 2>&1 && [ -f package.json ]; then
    node -e 'const s=(require("./package.json").scripts)||{};const k=Object.keys(s);console.log(k.length?k.map(x=>"  "+x+": "+s[x]).join("\n"):"  (none)")'
  fi
fi

section "Python details"
if have pyproject.toml requirements.txt; then
  pm="pip (requirements.txt)"
  [ -f uv.lock ] && pm="uv"
  grep -qs '^\[tool\.uv' pyproject.toml 2>/dev/null && pm="uv"
  [ -f poetry.lock ] && pm="poetry"
  echo "package-manager: $pm"
  grep -qs '^\[tool\.ruff' pyproject.toml 2>/dev/null && echo "lint/format: ruff"
  grep -qs '^\[tool\.pytest' pyproject.toml 2>/dev/null && echo "test: pytest"
  grep -qs '^\[tool\.mypy' pyproject.toml 2>/dev/null && echo "typecheck: mypy"
  grep -qs 'pyright' pyproject.toml 2>/dev/null && echo "typecheck: pyright"
  grep -qs '^\[tool\.uv\.workspace' pyproject.toml 2>/dev/null && echo "workspace: uv"
fi

section "Containers / services"
have 'compose*.yaml' 'compose*.yml' 'docker-compose*.yml' 'docker-compose*.yaml' \
  && { echo "compose files:"; list 'compose*.yaml' 'compose*.yml' 'docker-compose*.yml' 'docker-compose*.yaml'; }
have Dockerfile 'Dockerfile.*' 'Containerfile' && { echo "image builds:"; list Dockerfile 'Dockerfile.*' Containerfile; }
if command -v podman >/dev/null 2>&1; then echo "engine available: podman"; fi
if command -v docker >/dev/null 2>&1; then echo "engine available: docker"; fi
have '*.container' '*.quadlet' && { echo "quadlet units:"; list '*.container'; }

section "Codegen"
have sqlc.yaml sqlc.yml sqlc.json   && { echo "sqlc:";    list sqlc.yaml sqlc.yml sqlc.json; }
have buf.yaml buf.gen.yaml          && { echo "buf:";     list buf.yaml buf.gen.yaml; }
have '*.proto'                      && echo "protobuf: yes"
have 'openapi*.yaml' 'openapi*.yml' 'openapi*.json' 'swagger*.yaml' 'swagger*.json' \
                                    && { echo "openapi/swagger:"; list 'openapi*.yaml' 'openapi*.yml' 'openapi*.json' 'swagger*.yaml' 'swagger*.json'; }
have 'oapi-codegen*.yaml'           && { echo "oapi-codegen:"; list 'oapi-codegen*.yaml'; }
have schema.prisma                  && { echo "prisma:";  list schema.prisma; }
grep -rqs --include='*.go' '^//go:generate' . 2>/dev/null && echo "go:generate: yes"

section "Tests / e2e"
have 'playwright.config.*' && { echo "playwright:"; list 'playwright.config.*'; }
{ [ -d .maestro ] || find . -maxdepth 3 -name '*.yaml' -path '*maestro*' 2>/dev/null | grep -q .; } && echo "maestro: yes"
have 'jest.config.*' 'vitest.config.*' && { echo "unit runner:"; list 'jest.config.*' 'vitest.config.*'; }
have 'migrations' 2>/dev/null || true
[ -d migrations ] || find . -maxdepth 3 -type d -name migrations -not -path '*/node_modules/*' 2>/dev/null | grep -q . && echo "migrations dir: yes"

section "Config / deploy"
have .env.example .env.sample && { echo "env template:"; list .env.example .env.sample; }
[ -f .env ] && echo ".env present (git-ignored? $(git check-ignore -q .env 2>/dev/null && echo yes || echo NO))"
[ -d deploy ] && echo "deploy/: yes"
[ -d deploy/quadlet ] && echo "vps-deploy: yes (see the vps-deploy skill; Make exposes release/promote and the project's own deploy targets)"
have wrangler.toml fly.toml vercel.json netlify.toml && { echo "platform config:"; list wrangler.toml fly.toml vercel.json netlify.toml; }
[ -d .github/workflows ] && echo "CI: github actions" || echo "CI: none detected"

section "Existing Makefile"
if [ -f Makefile ]; then
  n=$(grep -cE '^[a-zA-Z0-9_.-]+:([^=]|$)' Makefile || true)
  d=$(grep -cE '^[a-zA-Z0-9_-]+:.*## ' Makefile || true)
  echo "Makefile: yes ($n targets, $d with ## descriptions)"
  [ -f Makefile.local ] && echo "Makefile.local: present"
  grep -qs 'Makefile.local' .gitignore 2>/dev/null && echo "Makefile.local git-ignored: yes"
else
  echo "Makefile: no"
fi
