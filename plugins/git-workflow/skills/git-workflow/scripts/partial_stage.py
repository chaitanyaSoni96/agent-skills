#!/usr/bin/env python3
"""
partial_stage.py — Stage only selected lines of a file's changes, the way
GitHub Desktop does under the hood.

GitHub Desktop never calls `git add`. To commit a subset of a file's changes it
rebuilds a unified-diff patch containing only the selected +/- lines and applies
it to the index with `git apply --cached`. This script reproduces that exactly.

Two subcommands:

  list <file>
      Print the file's unstaged diff with a stable [index] on every changed
      (+/-) line. Context lines are shown without an index. Use this to decide
      which lines to stage.

  stage <file> --select <spec>
      Rebuild a patch containing ONLY the changed lines whose indices are in
      <spec> (e.g. "1,3,5-8") and apply it to the index. Other changes are left
      untouched in the working tree. <spec> uses the indices printed by `list`.

Patch-rebuild rules (mirrored from desktop/app/src/lib/patch-formatter.ts):
  - context line           -> kept as-is
  - SELECTED   addition    -> kept as `+...`
  - SELECTED   deletion    -> kept as `-...`
  - UNSELECTED addition    -> dropped (pretend it was never added)
  - UNSELECTED deletion    -> turned into a context line (pretend it still exists)
  - each hunk header's line counts are recomputed to match what survived
  - hunks with no surviving change are omitted entirely

Scope: modified, already-tracked text files. Binary files, brand-new/untracked
files, renames and deletions are out of scope and reported as errors.
"""

import argparse
import os
import subprocess
import sys


def run_git(args, cwd, stdin=None, check=True):
    result = subprocess.run(
        ["git"] + args,
        cwd=cwd,
        input=stdin,
        capture_output=True,
        text=True,
    )
    if check and result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(
            f"git {' '.join(args)} failed (exit {result.returncode})"
        )
    return result


def repo_root(path):
    d = path if os.path.isdir(path) else os.path.dirname(os.path.abspath(path))
    r = run_git(["rev-parse", "--show-toplevel"], cwd=d)
    return r.stdout.strip()


def rel_path(root, path):
    return os.path.relpath(os.path.abspath(path), root)


def get_diff(root, relpath):
    """Unstaged diff of the file (working tree vs index)."""
    r = run_git(
        ["diff", "--no-color", "--", relpath],
        cwd=root,
    )
    return r.stdout


class Line:
    __slots__ = ("kind", "text", "no_newline")

    def __init__(self, kind, text, no_newline=False):
        self.kind = kind  # 'context' | 'add' | 'delete'
        self.text = text  # full line WITHOUT trailing newline, INCLUDING +/-/space prefix
        self.no_newline = no_newline


class Hunk:
    def __init__(self, old_start, old_count, new_start, new_count, heading):
        self.old_start = old_start
        self.old_count = old_count
        self.new_start = new_start
        self.new_count = new_count
        self.heading = heading
        self.lines = []


def parse_hunk_header(header):
    # @@ -oldStart,oldCount +newStart,newCount @@ optional heading
    body = header[2:]  # drop leading @@
    at = body.index("@@")
    ranges = body[:at].strip()
    heading = body[at + 2:].rstrip("\n")
    minus, plus = ranges.split(" ")

    def parse_range(token):
        token = token[1:]  # drop leading - or +
        if "," in token:
            start, count = token.split(",")
            return int(start), int(count)
        return int(token), 1

    old_start, old_count = parse_range(minus)
    new_start, new_count = parse_range(plus)
    return old_start, old_count, new_start, new_count, heading.strip()


def parse_diff(diff_text):
    """Return (header_lines, hunks). header_lines are the pre-hunk metadata
    lines (diff --git, index, ---, +++). hunks is a list of Hunk."""
    lines = diff_text.split("\n")
    # Trailing empty string from split if text ended with newline.
    if lines and lines[-1] == "":
        lines.pop()

    header_lines = []
    hunks = []
    current = None
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        if line.startswith("@@"):
            (old_start, old_count, new_start, new_count, heading) = parse_hunk_header(line)
            current = Hunk(old_start, old_count, new_start, new_count, heading)
            hunks.append(current)
        elif current is None:
            header_lines.append(line)
        else:
            if line.startswith("\\"):
                # "\ No newline at end of file" applies to the previous line.
                if current.lines:
                    current.lines[-1].no_newline = True
                i += 1
                continue
            if line.startswith("+"):
                current.lines.append(Line("add", line))
            elif line.startswith("-"):
                current.lines.append(Line("delete", line))
            elif line.startswith(" ") or line == "":
                current.lines.append(Line("context", line if line else " "))
            else:
                # Unexpected line inside a hunk — bail rather than corrupt.
                raise SystemExit(f"Unexpected diff line: {line!r}")
        i += 1
    return header_lines, hunks


def guard_supported(header_lines, relpath):
    blob = "\n".join(header_lines)
    if "Binary files" in blob or "GIT binary patch" in blob:
        raise SystemExit(
            f"Cannot partial-stage a binary file: {relpath}"
        )
    for h in header_lines:
        if h.startswith("rename from") or h.startswith("rename to"):
            raise SystemExit(
                f"Renames are out of scope for partial staging: {relpath}"
            )
        if h.startswith("new file mode"):
            raise SystemExit(
                f"New/untracked files are out of scope: {relpath}. "
                "Stage the whole file with `git add` instead."
            )
        if h.startswith("deleted file mode"):
            raise SystemExit(
                f"Whole-file deletions are out of scope: {relpath}."
            )


def index_changed_lines(hunks):
    """Assign a sequential 1-based index to every add/delete line across all
    hunks. Returns a dict index -> (hunk_idx, line_idx)."""
    mapping = {}
    idx = 0
    for hi, hunk in enumerate(hunks):
        for li, line in enumerate(hunk.lines):
            if line.kind in ("add", "delete"):
                idx += 1
                mapping[idx] = (hi, li)
    return mapping


def cmd_list(root, relpath):
    diff_text = get_diff(root, relpath)
    if not diff_text.strip():
        print(f"No unstaged changes in {relpath}.")
        return 0
    header_lines, hunks = parse_diff(diff_text)
    guard_supported(header_lines, relpath)

    idx = 0
    print(f"# {relpath}")
    print("# [n] marks a selectable changed line. Context lines have no index.")
    print()
    for hunk in hunks:
        heading = f"  {hunk.heading}" if hunk.heading else ""
        print(f"@@ -{hunk.old_start},{hunk.old_count} "
              f"+{hunk.new_start},{hunk.new_count} @@{heading}")
        for line in hunk.lines:
            if line.kind == "context":
                print(f"      {line.text}")
            else:
                idx += 1
                # line.text already has its +/- prefix
                print(f"[{idx:>3}] {line.text}")
        print()
    print(f"# {idx} selectable line(s). "
          f"Stage with: partial_stage.py stage {relpath} --select <e.g. 1,3-5>")
    return 0


def parse_select(spec):
    selected = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            for v in range(int(a), int(b) + 1):
                selected.add(v)
        else:
            selected.add(int(part))
    return selected


def format_hunk_header(old_start, old_count, new_start, new_count, heading):
    old = f"{old_start}" if old_count == 1 else f"{old_start},{old_count}"
    new = f"{new_start}" if new_count == 1 else f"{new_start},{new_count}"
    head = f" {heading}" if heading else ""
    return f"@@ -{old} +{new} @@{head}\n"


def build_patch(relpath, hunks, mapping, selected):
    """Rebuild a unified-diff patch containing only the selected changed lines."""
    # Reverse map: (hi, li) -> True if selected
    selected_cells = set()
    for i in selected:
        if i in mapping:
            selected_cells.add(mapping[i])

    body = ""
    for hi, hunk in enumerate(hunks):
        hunk_buf = ""
        old_count = 0
        new_count = 0
        any_change = False

        for li, line in enumerate(hunk.lines):
            is_selected = (hi, li) in selected_cells

            if line.kind == "context":
                hunk_buf += f"{line.text}\n"
                old_count += 1
                new_count += 1
            elif is_selected:
                hunk_buf += f"{line.text}\n"
                if line.kind == "add":
                    new_count += 1
                else:  # delete
                    old_count += 1
                any_change = True
            else:
                # Unselected.
                if line.kind == "add":
                    # Pretend it was never added: drop it.
                    continue
                else:  # delete
                    # Pretend it still exists: turn into a context line.
                    hunk_buf += f" {line.text[1:]}\n"
                    old_count += 1
                    new_count += 1

            if line.no_newline:
                hunk_buf += "\\ No newline at end of file\n"

        if not any_change:
            continue

        body += format_hunk_header(
            hunk.old_start, old_count, hunk.new_start, new_count, hunk.heading
        )
        body += hunk_buf

    if not body:
        return None

    header = f"--- a/{relpath}\n+++ b/{relpath}\n"
    return header + body


def cmd_stage(root, relpath, spec):
    diff_text = get_diff(root, relpath)
    if not diff_text.strip():
        raise SystemExit(f"No unstaged changes in {relpath}.")
    header_lines, hunks = parse_diff(diff_text)
    guard_supported(header_lines, relpath)

    mapping = index_changed_lines(hunks)
    selected = parse_select(spec)

    unknown = [i for i in selected if i not in mapping]
    if unknown:
        raise SystemExit(
            f"Selection refers to indices that don't exist: {sorted(unknown)}. "
            f"Valid range is 1..{len(mapping)}. Re-run `list` to refresh."
        )
    if not selected:
        raise SystemExit("Empty selection — nothing to stage.")

    patch = build_patch(relpath, hunks, mapping, selected)
    if patch is None:
        raise SystemExit("Selection produced an empty patch — nothing to stage.")

    apply_args = [
        "apply", "--cached", "--unidiff-zero", "--whitespace=nowarn", "-"
    ]
    result = run_git(apply_args, cwd=root, stdin=patch, check=False)
    if result.returncode != 0:
        sys.stderr.write("\n--- Generated patch ---\n")
        sys.stderr.write(patch)
        sys.stderr.write("--- git apply error ---\n")
        sys.stderr.write(result.stderr)
        raise SystemExit("git apply --cached failed (see patch + error above).")

    print(f"Staged {len(selected)} selected line(s) of {relpath}.")
    print("Review with:  git diff --cached -- " + relpath)
    print("Remaining unstaged changes left in the working tree.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list", help="show diff with selectable line indices")
    p_list.add_argument("file")

    p_stage = sub.add_parser("stage", help="stage only the selected changed lines")
    p_stage.add_argument("file")
    p_stage.add_argument("--select", required=True,
                         help="indices to stage, e.g. '1,3,5-8'")

    args = parser.parse_args()

    if not os.path.exists(args.file):
        raise SystemExit(f"File not found: {args.file}")

    root = repo_root(args.file)
    relpath = rel_path(root, args.file)

    if args.cmd == "list":
        return cmd_list(root, relpath)
    elif args.cmd == "stage":
        return cmd_stage(root, relpath, args.select)


if __name__ == "__main__":
    sys.exit(main())
