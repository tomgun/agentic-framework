#!/usr/bin/env bash
# memory-diff.sh — Produce structured PATCH blocks from a seed-file diff
#
# Given two revisions of memory-seed.md (or two files on disk), emit
# section-keyed PATCH blocks an agent can apply directly to MEMORY.md:
#
#   PATCH 1/3 — MODIFY section "Trigger Words" (anchor: trigger-words)
#   -  old line
#   +  new line
#   ...
#
# Section identity comes from `<!-- section: <slug> -->` HTML comments
# placed under each `^## ` header. Anchor-keyed parsing means renaming a
# section header yields MODIFY (not REMOVE+ADD).
#
# Usage:
#   memory-diff.sh <old_file> <new_file>
#   memory-diff.sh --rev <git-rev> <new_file>   # diff a git rev against a working file
#
# Always exits 0 (advisory). Prints PATCH blocks to stdout; status to stderr.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  memory-diff.sh <old_file> <new_file>
  memory-diff.sh --rev <git-rev> <seed-path-in-repo> <new_file>

Emits structured PATCH N/N blocks keyed by <!-- section: slug --> anchors.
EOF
}

# Split a seed file into sections keyed by anchor slug.
# Output: NUL-delimited records of "<slug>\t<header>\t<body>" written to
# the given output dir as files named "$slug.body" with sidecar "$slug.header".
_split_sections() {
    local file="$1"
    local out_dir="$2"
    mkdir -p "$out_dir"
    awk -v out="$out_dir" '
        BEGIN { slug = ""; header = ""; }
        /^<!-- section: [a-z0-9-]+ -->/ {
            # Flush previous section
            if (slug != "") {
                print body > (out "/" slug ".body");
                print header > (out "/" slug ".header");
                close(out "/" slug ".body");
                close(out "/" slug ".header");
            }
            match($0, /section: [a-z0-9-]+/);
            slug = substr($0, RSTART + 9, RLENGTH - 9);
            body = "";
            header = "";
            next;
        }
        /^## / {
            if (slug != "" && header == "") {
                header = $0;
                next;
            }
        }
        {
            if (slug != "") body = body $0 "\n";
        }
        END {
            if (slug != "") {
                print body > (out "/" slug ".body");
                print header > (out "/" slug ".header");
            }
        }
    ' "$file"
}

# Emit a single PATCH block, taking the patch number, total, kind, slug,
# header, and body text(s) as args.
_emit_patch() {
    local n="$1" total="$2" kind="$3" slug="$4" header_old="$5" header_new="$6"
    local body_old="$7" body_new="$8"

    local header_label="${header_new:-$header_old}"
    # Strip leading "## " for display
    header_label="${header_label#\#\# }"

    echo
    echo "PATCH $n/$total — $kind section \"$header_label\" (anchor: $slug)"
    case "$kind" in
        ADD)
            echo "+ <!-- section: $slug -->"
            echo "+ $header_new"
            echo "$body_new" | sed 's/^/+ /'
            ;;
        REMOVE)
            echo "- <!-- section: $slug -->"
            echo "- $header_old"
            echo "$body_old" | sed 's/^/- /'
            ;;
        MODIFY)
            # Unified diff of bodies only (header change reflected in label).
            if [ "$header_old" != "$header_new" ]; then
                echo "  (header renamed: \"$header_old\" → \"$header_new\")"
            fi
            diff -u --label "old:$slug" --label "new:$slug" \
                <(printf '%s' "$body_old") <(printf '%s' "$body_new") \
                | tail -n +3 || true
            ;;
    esac
}

# Compare two split-section directories and emit PATCH blocks.
_emit_patches() {
    local old_dir="$1" new_dir="$2"

    # Collect slugs from both sides
    local old_slugs new_slugs all_slugs
    old_slugs=$(find "$old_dir" -maxdepth 1 -name '*.body' -printf '%f\n' 2>/dev/null \
                | sed 's/\.body$//' | sort)
    new_slugs=$(find "$new_dir" -maxdepth 1 -name '*.body' -printf '%f\n' 2>/dev/null \
                | sed 's/\.body$//' | sort)
    all_slugs=$(printf '%s\n%s\n' "$old_slugs" "$new_slugs" | sort -u | grep -v '^$' || true)

    # First pass: classify each slug → ADD / REMOVE / MODIFY / unchanged.
    local changes=""
    while IFS= read -r slug; do
        [ -z "$slug" ] && continue
        local in_old=0 in_new=0
        [ -f "$old_dir/$slug.body" ] && in_old=1
        [ -f "$new_dir/$slug.body" ] && in_new=1
        local kind=""
        if [ "$in_old" -eq 1 ] && [ "$in_new" -eq 0 ]; then
            kind=REMOVE
        elif [ "$in_old" -eq 0 ] && [ "$in_new" -eq 1 ]; then
            kind=ADD
        else
            # Both present — compare bodies + headers
            local h_old h_new b_old b_new
            h_old=$(cat "$old_dir/$slug.header" 2>/dev/null || echo "")
            h_new=$(cat "$new_dir/$slug.header" 2>/dev/null || echo "")
            b_old=$(cat "$old_dir/$slug.body" 2>/dev/null || echo "")
            b_new=$(cat "$new_dir/$slug.body" 2>/dev/null || echo "")
            if [ "$h_old" = "$h_new" ] && [ "$b_old" = "$b_new" ]; then
                continue
            fi
            kind=MODIFY
        fi
        changes+="$slug $kind"$'\n'
    done <<< "$all_slugs"

    local total
    total=$(printf '%s' "$changes" | grep -c . || echo 0)

    if [ "$total" -eq 0 ]; then
        echo "(no structural changes; only formatting or pre-anchor content)" >&2
        return 0
    fi

    local n=0
    while IFS=' ' read -r slug kind; do
        [ -z "$slug" ] && continue
        n=$((n + 1))
        local h_old="" h_new="" b_old="" b_new=""
        [ -f "$old_dir/$slug.header" ] && h_old=$(cat "$old_dir/$slug.header")
        [ -f "$new_dir/$slug.header" ] && h_new=$(cat "$new_dir/$slug.header")
        [ -f "$old_dir/$slug.body" ] && b_old=$(cat "$old_dir/$slug.body")
        [ -f "$new_dir/$slug.body" ] && b_new=$(cat "$new_dir/$slug.body")
        _emit_patch "$n" "$total" "$kind" "$slug" \
            "$h_old" "$h_new" "$b_old" "$b_new"
    done <<< "$changes"
}

# --- Argument parsing ---
if [ $# -lt 2 ]; then
    usage >&2
    exit 0
fi

OLD_INPUT=""
NEW_INPUT=""
TMP_OLD=""

if [ "$1" = "--rev" ]; then
    [ $# -eq 4 ] || { usage >&2; exit 0; }
    REV="$2"
    SEED_REPO_PATH="$3"
    NEW_INPUT="$4"
    TMP_OLD=$(mktemp)
    if ! git show "${REV}:${SEED_REPO_PATH}" > "$TMP_OLD" 2>/dev/null; then
        echo "(couldn't extract $SEED_REPO_PATH at $REV — fallback to whole-file refresh)" >&2
        rm -f "$TMP_OLD"
        exit 0
    fi
    OLD_INPUT="$TMP_OLD"
else
    OLD_INPUT="$1"
    NEW_INPUT="$2"
fi

if [ ! -f "$OLD_INPUT" ] || [ ! -f "$NEW_INPUT" ]; then
    echo "(missing input file — fallback to whole-file refresh)" >&2
    [ -n "$TMP_OLD" ] && rm -f "$TMP_OLD"
    exit 0
fi

WORK_DIR=$(mktemp -d)
trap '[ -n "$TMP_OLD" ] && rm -f "$TMP_OLD"; rm -rf "$WORK_DIR"' EXIT

_split_sections "$OLD_INPUT" "$WORK_DIR/old"
_split_sections "$NEW_INPUT" "$WORK_DIR/new"
_emit_patches "$WORK_DIR/old" "$WORK_DIR/new"
