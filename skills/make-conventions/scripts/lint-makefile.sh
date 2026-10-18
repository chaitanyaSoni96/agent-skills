#!/usr/bin/env bash
# Check a Makefile against the make-conventions contract (reference/rules.md).
#
# Usage: lint-makefile.sh [Makefile]       (default: ./Makefile)
#
# Prints one line per finding: `WARN <rule> message`. Exit 0 when clean, 1 when
# there is at least one WARN. Read-only; runs `make -n` and `make help` at most.

set -uo pipefail

MF="${1:-Makefile}"
[ -f "$MF" ] || { echo "no such file: $MF" >&2; exit 2; }
DIR="$(dirname "$MF")"
BASE="$(basename "$MF")"

warns=0
warn() { printf 'WARN %-4s %s\n' "$1" "$2"; warns=$((warns + 1)); }
info() { printf 'info      %s\n' "$1"; }

# --- Parse targets: name, has-description, prerequisites, recipe body ---------
# awk emits TSV: kind<TAB>name<TAB>payload
parsed="$(awk '
  /^\.PHONY:/ { line=$0; gsub(/\t/," ",line); sub(/^\.PHONY:/,"",line); inphony=0; if (line ~ /\\$/) inphony=1; sub(/\\$/,"",line); phony=phony " " line; next }
  inphony     { line=$0; gsub(/\t/," ",line); inphony=0; if (line ~ /\\$/) inphony=1; sub(/\\$/,"",line); phony=phony " " line; next }
  /^[a-zA-Z0-9_.-]+[ \t]*:([^=]|$)/ && $0 !~ /^\.[A-Z_]+:/ && $0 !~ /^[a-zA-Z0-9_.-]+[ \t]*:[:?+]?=/ {
      if (cur != "") print "R\t" cur "\t" body
      split($0, a, ":"); cur=a[1]; gsub(/[ \t]/,"",cur)
      rest=substr($0, length(a[1])+2)
      desc = (rest ~ /##/) ? 1 : 0
      deps=rest; sub(/##.*/,"",deps); sub(/;.*/,"",deps)
      print "T\t" cur "\t" desc "\t" deps
      body=""; next
  }
  /^\t/ { if (cur != "") { l=$0; sub(/^\t/,"",l); body = body l "\x1f" } next }
  /^[^\t#]/ { if (cur != "") print "R\t" cur "\t" body; cur=""; body="" }
  END { if (cur != "") print "R\t" cur "\t" body; print "P\t" phony }
' "$MF")"

targets="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="T"{print $2}')"
phony="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="P"{print $2}')"

has_target() { printf '%s\n' "$targets" | grep -qx "$1"; }
is_described() { printf '%s\n' "$parsed" | awk -F'\t' -v t="$1" '$1=="T" && $2==t && $3==1{f=1} END{exit !f}'; }
all_deps="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="T"{print $4}' | tr ' ' '\n' | sed '/^$/d' | sort -u)"

public=0
for t in $targets; do is_described "$t" && public=$((public + 1)); done

# --- §1 help ------------------------------------------------------------------
has_target help || warn 1 "no 'help' target"
if ! grep -qE '^\.DEFAULT_GOAL[ \t]*:?=[ \t]*help' "$MF"; then
  first="$(printf '%s\n' "$targets" | head -1)"
  [ "$first" = "help" ] || warn 1 "bare 'make' does not run help (add: .DEFAULT_GOAL := help)"
fi
if grep -qE '^help:' "$MF" && grep -A3 '^help:' "$MF" | grep -qE '@echo[ \t]+"(Targets|Usage)'; then
  warn 1 "help is a hand-written list; generate it from '## ' descriptions"
fi
if [ "$public" -gt 8 ] && ! grep -qE '^##@ ' "$MF"; then
  warn 1 "$public documented targets but no '##@ Group' headers"
fi

# --- §2 core set --------------------------------------------------------------
for core in build lint test; do
  has_target "$core" || info "no '$core' target (fine if the project has none)"
done
if has_target test && ! has_target test-short; then
  info "'test' without 'test-short' (rule §4: add a fast loop if 'test' is slow)"
elif has_target test-short && ! has_target test; then
  warn 4 "'test-short' without 'test'"
fi

# --- §5 undocumented and unreachable ------------------------------------------
for t in $targets; do
  case "$t" in .*|help) continue ;; esac
  if ! is_described "$t" && ! printf '%s\n' "$all_deps" | grep -qx "$t"; then
    # not described and nothing depends on it; may still be called via $(MAKE) or a helper
    if ! grep -qE "(\\\$\(MAKE\)|make)[ \t]+[^#]*\b$t\b" "$MF"; then
      warn 5 "target '$t' has no '## description' and nothing depends on it (document it, inline it, or delete it)"
    fi
  fi
done

# --- §6 duplicates: identical non-empty recipes -------------------------------
dups="$(printf '%s\n' "$parsed" | awk -F'\t' '$1=="R" && $3!=""{c[$3]=c[$3] " " $2; n[$3]++} END{for(k in c) if(n[k]>1) print c[k]}')"
if [ -n "$dups" ]; then
  while IFS= read -r line; do warn 6 "identical recipes:$line (rule §6: delete one)"; done <<<"$dups"
fi
# targets with exactly one prerequisite and no recipe are pure aliases
alias_t="$(printf '%s\n' "$parsed" | awk -F'\t' '
  $1=="T"{dep[$2]=$4} $1=="R"{body[$2]=$3}
  END{for(t in dep){n=split(dep[t],d," "); if(n==1 && body[t]=="" && t!="help") print t " -> " d[1]}}')"
if [ -n "$alias_t" ]; then
  while IFS= read -r line; do info "pure alias: $line (fine as a public name for a helper; otherwise delete)"; done <<<"$alias_t"
fi

# --- §7 global installs -------------------------------------------------------
grep -nE '^\t[@-]*(pip3?|python[0-9.]* -m pip) install|npm (i|install) (-g|--global)|go install |cargo install |brew install|apt(-get)? install|gem install' "$MF" \
  | while IFS= read -r l; do warn 7 "global install in a recipe, line ${l%%:*}: pin and run the tool instead"; done
# unpinned go run / npx
grep -nE 'go run [^ ]+@latest|npx [^@ ]+ |uvx [a-z0-9_-]+( |$)' "$MF" | grep -vE '@v?[0-9]' \
  | while IFS= read -r l; do warn 7 "unpinned tool run, line ${l%%:*}"; done

# --- §8 hidden failures -------------------------------------------------------
grep -nE '\|\| *true' "$MF" | while IFS= read -r l; do
  ln="${l%%:*}"
  # allowed inside a target named outdated / cover / clean
  tgt="$(awk -v n="$ln" 'NR<=n && /^[a-zA-Z0-9_-]+:/{split($0,a,":");t=a[1]} END{print t}' "$MF")"
  case "$tgt" in outdated|clean|cover|e2e-stack-down) ;; *) warn 8 "'|| true' in target '$tgt' (line $ln) can hide a failure" ;; esac
done

# --- §9 hard-coded machine facts ----------------------------------------------
grep -nE '/home/[a-z]+|/Users/[A-Za-z]+|/run/user/[0-9]+|[^0-9.]192\.168\.[0-9]+\.[0-9]+' "$MF" \
  | grep -vE '^[0-9]+:[[:space:]]*#' \
  | while IFS= read -r l; do warn 9 "hard-coded machine path/IP, line ${l%%:*}: resolve or make overridable"; done
if grep -qE '\?=' "$MF" && ! grep -qE '^-?include[ \t]+Makefile\.local' "$MF"; then
  info "uses '?=' defaults but no '-include Makefile.local' for per-machine overrides"
fi

# --- §10 ports repeated as literals -------------------------------------------
lit_ports="$(grep -oE '(--port|-p|:)[ =]?[0-9]{4,5}\b' "$MF" | grep -oE '[0-9]{4,5}' | sort | uniq -c | awk '$1>1{print $2}')"
for p in $lit_ports; do
  grep -qE "^[A-Z_]*PORT[A-Z_]*[ \t]*\??=[ \t]*$p\b" "$MF" || warn 10 "port $p appears more than once as a literal; make it a variable"
done

# --- Also: .PHONY coverage, shell flags ----------------------------------------
for t in $targets; do
  case "$t" in .*|*%*) continue ;; esac
  printf '%s\n' "$phony" | tr -s ' \t' '\n\n' | grep -qx "$t" || [ -e "$DIR/$t" ] || warn P ".PHONY is missing '$t'"
done
if grep -qE '^\t.*\|[^|]' "$MF" && ! grep -qE '^\.SHELLFLAGS|pipefail' "$MF"; then
  warn S "recipes pipe but pipefail is not set (add: .SHELLFLAGS := -eo pipefail -c)"
fi

# --- Runtime checks (only if make exists) -------------------------------------
if command -v make >/dev/null 2>&1 && has_target help; then
  if ! (cd "$DIR" && make -f "$BASE" -n help >/dev/null 2>&1); then
    warn R "'make help' does not parse/run"
  else
    out="$(cd "$DIR" && make -f "$BASE" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
    [ -n "$out" ] || warn R "bare 'make' prints nothing"
    printf '%s\n' "$out" | grep -qE '\$\(' && warn R "help text shows an unexpanded \$(VAR); keep variables out of '##' descriptions"
  fi
fi

echo
echo "documented targets: $public   total targets: $(printf '%s\n' "$targets" | wc -l | tr -d ' ')   warnings: $warns"
[ "$warns" -eq 0 ]
