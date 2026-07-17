#!/usr/bin/env bash
# Shared paths, key derivation, and prompt-loading helpers for the
# codex-plan-review and codex-code-review skills. Source-only.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# STATE_DIR can be overridden by the caller (e.g., codex-code-review
# exports its own state path before invoking the shared scripts).
# Default falls back to the script's own skill directory.
: "${STATE_DIR:=$SKILL_DIR/state}"
export STATE_DIR
mkdir -p "$STATE_DIR"

# Model/effort per explicit execution role (single source of truth).
# Callers MUST set CODEX_FLOW before sourcing this file. Tier defaults to
# MEDIUM for backwards-compatible manual invocations, but adaptive entry points
# pass it explicitly.
: "${CODEX_IMPLEMENT_MODEL_DEFAULT:=gpt-5.6-luna}"
: "${CODEX_REVIEW_MODEL_DEFAULT:=gpt-5.6-sol}"
: "${CODEX_IMPLEMENT_SMALL_EFFORT_DEFAULT:=medium}"
: "${CODEX_IMPLEMENT_MEDIUM_EFFORT_DEFAULT:=high}"
: "${CODEX_IMPLEMENT_HIGH_EFFORT_DEFAULT:=high}"
: "${CODEX_REVIEW_STANDARD_EFFORT_DEFAULT:=high}"
: "${CODEX_REVIEW_HIGH_EFFORT_DEFAULT:=xhigh}"

case "${TRIP_WORKFLOW_TIER:-MEDIUM}" in
    SMALL|small) TRIP_WORKFLOW_TIER=SMALL ;;
    MEDIUM|medium) TRIP_WORKFLOW_TIER=MEDIUM ;;
    HIGH|high) TRIP_WORKFLOW_TIER=HIGH ;;
    *)
        echo "error: TRIP_WORKFLOW_TIER must be SMALL, MEDIUM, or HIGH" >&2
        return 64
        ;;
esac

case "${CODEX_FLOW:-}" in
    implementation)
        CODEX_MODEL="$CODEX_IMPLEMENT_MODEL_DEFAULT"
        case "$TRIP_WORKFLOW_TIER" in
            SMALL)  CODEX_EFFORT="$CODEX_IMPLEMENT_SMALL_EFFORT_DEFAULT" ;;
            MEDIUM) CODEX_EFFORT="$CODEX_IMPLEMENT_MEDIUM_EFFORT_DEFAULT" ;;
            HIGH)   CODEX_EFFORT="$CODEX_IMPLEMENT_HIGH_EFFORT_DEFAULT" ;;
        esac
        ;;
    review)
        CODEX_MODEL="$CODEX_REVIEW_MODEL_DEFAULT"
        case "$TRIP_WORKFLOW_TIER" in
            HIGH) CODEX_EFFORT="$CODEX_REVIEW_HIGH_EFFORT_DEFAULT" ;;
            *)    CODEX_EFFORT="$CODEX_REVIEW_STANDARD_EFFORT_DEFAULT" ;;
        esac
        ;;
    *)
        echo "error: CODEX_FLOW must be explicitly set to implementation or review" >&2
        return 64
        ;;
esac
export CODEX_FLOW TRIP_WORKFLOW_TIER CODEX_MODEL CODEX_EFFORT
export CODEX_IMPLEMENT_MODEL_DEFAULT CODEX_REVIEW_MODEL_DEFAULT
export CODEX_IMPLEMENT_SMALL_EFFORT_DEFAULT CODEX_IMPLEMENT_MEDIUM_EFFORT_DEFAULT
export CODEX_IMPLEMENT_HIGH_EFFORT_DEFAULT CODEX_REVIEW_STANDARD_EFFORT_DEFAULT
export CODEX_REVIEW_HIGH_EFFORT_DEFAULT

# Git's repository check is a safety boundary. Only an explicit controlled
# escape hatch adds the Codex bypass flag.
CODEX_GIT_FLAGS=()
case "${TRIP_ALLOW_NON_GIT:-0}" in
    0) ;;
    1) CODEX_GIT_FLAGS+=(--skip-git-repo-check) ;;
    *)
        echo "error: TRIP_ALLOW_NON_GIT must be 0 or 1" >&2
        return 64
        ;;
esac

# Derive a per-target key from a path-like string. For real paths we
# resolve to absolute; for non-path targets (branch names, commit
# ranges) we sanitize in place. Replace '/' with '__'; force any other
# non-portable characters to '_'.
target_key() {
    local target="$1"
    if [ -e "$target" ]; then
        local abs
        abs="$(realpath -- "$target" 2>/dev/null || readlink -f -- "$target")"
        if [ -z "$abs" ]; then
            echo "error: cannot resolve target path: $target" >&2
            return 1
        fi
        printf '%s' "$abs" | sed 's|^/||; s|/|__|g'
    else
        printf '%s' "$target" | sed 's|^/||; s|/|__|g; s|[^A-Za-z0-9._-]|_|g'
    fi
}

# Backwards-compatible alias used by older script call sites.
plan_key() { target_key "$@"; }

thread_file() {
    printf '%s/%s.thread' "$STATE_DIR" "$(target_key "$1")"
}

review_file() {
    printf '%s/%s.review.txt' "$STATE_DIR" "$(target_key "$1")"
}

events_file() {
    printf '%s/%s.events.ndjson' "$STATE_DIR" "$(target_key "$1")"
}

# Use Python's standard library instead of requiring jq. Prefer python3 but
# retain the Windows/Python launcher name used by some supported environments.
run_python() {
    if command -v python3 >/dev/null 2>&1; then
        python3 "$@"
    elif command -v python >/dev/null 2>&1; then
        python "$@"
    elif command -v py >/dev/null 2>&1; then
        py -3 "$@"
    else
        echo "error: Python 3 is required for Codex JSONL progress parsing" >&2
        return 127
    fi
}

# Render compact progress and optionally persist a thread id as soon as its
# event arrives. Agent messages stay in the final report file, not the terminal.
render_codex_progress() {
    local -a args=(-u "$SKILL_DIR/scripts/codex-progress.py")
    if [ "$#" -gt 0 ] && [ -n "$1" ]; then
        args+=(--thread-file "$1")
    fi
    run_python "${args[@]}"
}

capture_thread_from_events() {
    local events="$1"
    local destination="$2"
    local thread_id
    thread_id="$(run_python "$SKILL_DIR/scripts/codex-progress.py" --extract-thread "$events" 2>/dev/null)"
    if [ -n "$thread_id" ]; then
        printf '%s\n' "$thread_id" > "$destination"
    fi
}

# Run a Codex command while saving complete JSONL/stderr and showing concise
# progress. MODE is truncate for a fresh thread and append for resume turns.
# set -o pipefail above covers Codex, the JSONL tee, and the progress parser.
# The stderr tee runs in process substitution; its exit status is not part of
# the stdout pipeline and is intentionally not claimed here.
run_codex_with_progress() {
    if [ "$#" -lt 5 ]; then
        echo "error: run_codex_with_progress requires events stderr thread mode command..." >&2
        return 64
    fi

    local events="$1"
    local stderr_file="$2"
    local thread_destination="$3"
    local mode="$4"
    shift 4

    local -a tee_args=()
    case "$mode" in
        truncate)
            : > "$events"
            : > "$stderr_file"
            ;;
        append)
            tee_args=(-a)
            ;;
        *)
            echo "error: progress stream mode must be truncate or append" >&2
            return 64
            ;;
    esac

    "$@" \
        2> >(tee "${tee_args[@]}" "$stderr_file" >&2) \
        | tee "${tee_args[@]}" "$events" \
        | render_codex_progress "$thread_destination"
}

# Load a prompt template from $1 and substitute {{TARGET}} and
# {{EXTRA_PROMPT}} placeholders with the values of the $TARGET and
# $EXTRA_PROMPT environment variables. Other text passes through
# verbatim — no surprise expansion of unrelated $VAR sequences.
# Writes the substituted prompt to stdout.
load_prompt() {
    local tpl="$1"
    if [ ! -f "$tpl" ]; then
        echo "error: prompt template not found: $tpl" >&2
        return 1
    fi
    awk -v target="${TARGET-}" -v extra="${EXTRA_PROMPT-}" -v notes="${IMPLEMENTER_NOTES-}" '
        {
            gsub(/\{\{TARGET\}\}/, target)
            gsub(/\{\{EXTRA_PROMPT\}\}/, extra)
            gsub(/\{\{IMPLEMENTER_NOTES\}\}/, notes)
            print
        }
    ' "$tpl"
}
