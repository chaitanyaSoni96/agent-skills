#!/usr/bin/env bash
set -euo pipefail

# injector.sh - Dump entire codebase as raw or minimized JSON
# Usage: bash injector.sh [-o output.json] [-r]
#   -r: Use RTK (Rust Token Killer) for token minimization
# Requires: git, python3. Optional: rtk

OUTPUT_PATH=""
PROJECT_NAME=""
WORKSPACE_ROOT=""
USE_RTK=false
RTK_VERSION=""

# Check if RTK is installed
check_rtk() {
    if ! command -v rtk &> /dev/null; then
        echo "Error: RTK (Rust Token Killer) is not installed." >&2
        echo "Install with:" >&2
        echo "  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh" >&2
        exit 2
    fi
    RTK_VERSION=$(rtk --version | awk '{print $2}')
}

# Determine workspace root (git or current directory)
check_workspace() {
    if git rev-parse --is-inside-work-tree &> /dev/null; then
        WORKSPACE_ROOT=$(git rev-parse --show-toplevel)
        IS_GIT_REPO=true
    else
        WORKSPACE_ROOT="$PWD"
        IS_GIT_REPO=false
    fi
    PROJECT_NAME=$(basename "$WORKSPACE_ROOT")
}

# Create output directory
setup_output_dir() {
    mkdir -p /tmp/inject
}

# Check if a file should be excluded by denylist
is_denied() {
    local file="$1"
    local basename=$(basename "$file")

    # Deny root-level and nested directories by prefix
    case "$file" in
        .git|.git/*|\
        .goose|.goose/*|\
        .windsurf|.windsurf/*|\
        .cline|.cline/*|\
        .cursor|.cursor/*|\
        .codex|.codex/*|\
        .agents|.agents/*|\
        .opencode|.opencode/*|\
        .openclaw|.openclaw/*|\
        .pnpm-store|.pnpm-store/*|\
        .next|.next/*|\
        .turbo|.turbo/*|\
        .vercel|.vercel/*|\
        .cache|.cache/*|\
        .parcel-cache|.parcel-cache/*|\
        .idea|.idea/*|\
        .vscode|.vscode/*|\
        .DS_Store|.DS_Store/*|\
        .worktrees|.worktrees/*|\
        node_modules|node_modules/*|\
        */node_modules|*/node_modules/*|\
        target|target/*|\
        */target|*/target/*|\
        dist|dist/*|\
        */dist|*/dist/*|\
        build|build/*|\
        */build|*/build/*|\
        out|out/*|\
        */out|*/out/*|\
        coverage|coverage/*|\
        */coverage|*/coverage/*|\
        playwright-report|playwright-report/*|\
        */playwright-report|*/playwright-report/*|\
        test-results|test-results/*|\
        */test-results|*/test-results/*|\
        Sample.canvas|Sample.canvas/*|\
        */Sample.canvas|*/Sample.canvas/*)
            return 0
            ;;
    esac

    # Deny extensions
    case "$basename" in
        *.lock|\
        *.tar.gz|*.zip|\
        *.png|*.jpg|*.jpeg|*.gif|*.svg|*.ico|\
        *.woff|*.woff2|*.ttf|*.eot|\
        *.mp4|*.mp3|*.pdf|\
        *.wasm|*.dll|*.so|*.dylib|*.exe|*.bin|\
        *.o|*.a|*.rmeta|*.rlib|\
        *.timestamp|*.tsbuildinfo|\
        .env|.env.*|\
        .eslintcache|.prettiercache)
            return 0
            ;;
    esac

    return 1
}

# Process all files
process_files() {
    local temp_dir=$(mktemp -d)
    local file_list="$temp_dir/files.txt"
    local gitignore_ignored="$temp_dir/ignored.txt"
    local pairs_file="$temp_dir/pairs.txt"

    # Find all files
    find "$WORKSPACE_ROOT" -type f > "$file_list"
    local files_found=$(wc -l < "$file_list")

    if [[ "$IS_GIT_REPO" == "true" ]]; then
        git -C "$WORKSPACE_ROOT" check-ignore -v -n --stdin < "$file_list" 2>/dev/null | \
            grep -v '^::' | cut -f2 > "$gitignore_ignored" || true
    fi

    declare -A ignored_map
    if [[ -s "$gitignore_ignored" ]]; then
        while IFS= read -r ignored_path; do
            ignored_map["$ignored_path"]=1
        done < "$gitignore_ignored"
    fi

    # Process each file
    local files_processed=0
    local files_skipped=0
    local raw_tokens=0
    local original_tokens=0
    local minimized_tokens=0
    local savings=0

    # Batch binary check for raw mode (one process for all files)
    local binary_map_file="$temp_dir/binary_map.txt"
    if [[ "$USE_RTK" != "true" ]]; then
        file --mime-type -f "$file_list" 2>/dev/null | \
            grep -iE ':\s*(application/|image/|audio/|video/|font/)' | \
            cut -d: -f1 > "$binary_map_file" || true
    fi
    declare -A binary_map
    if [[ -s "$binary_map_file" ]]; then
        while IFS= read -r bin_file; do
            binary_map["$bin_file"]=1
        done < "$binary_map_file"
    fi

    while IFS= read -r file; do
        local rel_path="${file#$WORKSPACE_ROOT/}"

        # Skip gitignored files (O(1) lookup)
        if [[ -n "${ignored_map[$file]:-}" ]]; then
            ((files_skipped++)) || true
            continue
        fi

        # Skip denylist
        if is_denied "$rel_path"; then
            ((files_skipped++)) || true
            continue
        fi

        local content_file="$temp_dir/content_$files_processed"
        local orig_size=$(wc -c < "$file")

        if [[ "$USE_RTK" == "true" ]]; then
            # Use RTK for minimization
            if ! rtk read "$file" > "$content_file" 2>/dev/null; then
                ((files_skipped++)) || true
                continue
            fi
            local mini_size=$(wc -c < "$content_file")
            ((original_tokens += orig_size / 4)) || true
            ((minimized_tokens += mini_size / 4)) || true
        else
            # Skip binary files when using raw cat (O(1) lookup)
            if [[ -n "${binary_map[$file]:-}" ]]; then
                ((files_skipped++)) || true
                continue
            fi

            # Read raw content directly from file
            cp "$file" "$content_file"
            ((raw_tokens += orig_size / 4)) || true
        fi

        # Store pair for batch JSON generation
        printf '%s\t%s\n' "$rel_path" "$content_file" >> "$pairs_file"
        ((files_processed++)) || true

    done < "$file_list"

    # Build final JSON
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local safe_timestamp=$(echo "$timestamp" | tr ':' '-')

    local output_path
    if [[ -z "$OUTPUT_PATH" ]]; then
        output_path="/tmp/inject/${PROJECT_NAME}_${safe_timestamp}.json"
    else
        output_path="$OUTPUT_PATH"
    fi

    if [[ "$USE_RTK" == "true" ]]; then
        savings=0
        if [[ $original_tokens -gt 0 ]]; then
            savings=$((100 - (minimized_tokens * 100 / original_tokens)))
        fi
    fi

    # Build metadata JSON
    local metadata_json
    if [[ "$USE_RTK" == "true" ]]; then
        metadata_json=$(python3 -c "
import json
md = {
    'project': '${PROJECT_NAME}',
    'generated_at': '${timestamp}',
    'files_found': ${files_found},
    'files_processed': ${files_processed},
    'files_skipped': ${files_skipped},
    'rtk_version': '${RTK_VERSION}',
    'original_tokens_est': ${original_tokens},
    'minimized_tokens_est': ${minimized_tokens},
    'savings_percent': ${savings},
    'output_file': '${output_path}'
}
print(json.dumps(md))
")
    else
        metadata_json=$(python3 -c "
import json
md = {
    'project': '${PROJECT_NAME}',
    'generated_at': '${timestamp}',
    'files_found': ${files_found},
    'files_processed': ${files_processed},
    'files_skipped': ${files_skipped},
    'total_tokens_est': ${raw_tokens},
    'output_file': '${output_path}'
}
print(json.dumps(md))
")
    fi

    # Single python3 invocation to generate the entire JSON output
    python3 -c '
import json, sys

pairs_file = sys.argv[1]
output_path = sys.argv[2]
metadata = json.loads(sys.argv[3])

with open(output_path, "w") as out:
    out.write("{\"metadata\":" + json.dumps(metadata) + ",\"files\":{")
    first = True
    with open(pairs_file, "r") as pf:
        for line in pf:
            line = line.rstrip("\n")
            if not line:
                continue
            relpath, content_path = line.split("\t", 1)
            with open(content_path, "r", encoding="utf-8", errors="ignore") as cf:
                content = cf.read()
            if not first:
                out.write(",")
            first = False
            out.write(json.dumps(relpath) + ":" + json.dumps(content))
    out.write("}}")
' "$pairs_file" "$output_path" "$metadata_json" || {
        echo "Error: Failed to generate JSON output" >&2
        rm -rf "$temp_dir"
        exit 3
    }

    # Cleanup
    rm -rf "$temp_dir"

    # Report to stderr
    echo "Inject complete: $output_path" >&2
    echo "Files found: $files_found" >&2
    echo "Files processed: $files_processed" >&2
    echo "Files skipped: $files_skipped" >&2

    if [[ "$USE_RTK" == "true" ]]; then
        echo "Original tokens: ~$original_tokens" >&2
        echo "Minimized tokens: ~$minimized_tokens" >&2
        echo "Savings: ${savings}%" >&2
    else
        echo "Total tokens: ~$raw_tokens" >&2
    fi

    echo "$output_path"
}

# Main
main() {
    # Parse args
    while getopts "o:r" opt; do
        case $opt in
            o) OUTPUT_PATH="$OPTARG" ;;
            r) USE_RTK=true ;;
            *) echo "Usage: $0 [-o output.json] [-r]" >&2; exit 1 ;;
        esac
    done

    check_workspace
    setup_output_dir
    
    if [[ "$USE_RTK" == "true" ]]; then
        check_rtk
    fi

    process_files
}

main "$@"
