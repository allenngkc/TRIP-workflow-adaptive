#!/usr/bin/env bash
# Turn 1: start a fresh Codex review session for <target>, capture
# the thread_id from the JSON event stream, and write the final review
# to the per-target review file.
#
# Usage: start.sh --prompt-file <tpl> <target> [extra prompt text...]
# Exits 0 on success, propagates a non-zero Codex/pipeline status,
# or exits 1 on thread_id capture failure / 2 on an existing thread.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

PROMPT_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)
            PROMPT_FILE="$2"; shift 2 ;;
        --prompt-file=*)
            PROMPT_FILE="${1#*=}"; shift ;;
        --) shift; break ;;
        -*)
            echo "error: unknown flag: $1" >&2; exit 64 ;;
        *) break ;;
    esac
done

if [ -z "$PROMPT_FILE" ] || [ $# -lt 1 ]; then
    echo "usage: start.sh --prompt-file <tpl> <target> [extra prompt text...]" >&2
    exit 64
fi

TARGET="$1"; shift
EXTRA_PROMPT="${*:-}"
export TARGET EXTRA_PROMPT

THREAD_FILE="$(thread_file "$TARGET")"
REVIEW_FILE="$(review_file "$TARGET")"
EVENTS_FILE="$(events_file "$TARGET")"

if [ -f "$THREAD_FILE" ]; then
    echo "error: review session already exists for $TARGET" >&2
    echo "       thread id: $(cat "$THREAD_FILE")" >&2
    echo "       run resume.sh to continue, or reset.sh to start fresh." >&2
    exit 2
fi

PROMPT="$(load_prompt "$PROMPT_FILE")"

# Save full JSONL/stderr while rendering a concise live progress stream.
# stdin is closed to skip the "reading from stdin" detour; the review stays
# read-only. run_codex_with_progress participates in this script's pipefail.
if run_codex_with_progress \
    "$EVENTS_FILE" "$EVENTS_FILE.stderr" "$THREAD_FILE" truncate \
    codex exec \
        --json \
        --skip-git-repo-check \
        --sandbox read-only \
        --color never \
        -c model="$CODEX_MODEL" \
        -c model_reasoning_effort="$CODEX_EFFORT" \
        -o "$REVIEW_FILE" \
        "$PROMPT" \
        </dev/null
then
    :
else
    rc=$?
    [ -s "$THREAD_FILE" ] || capture_thread_from_events "$EVENTS_FILE" "$THREAD_FILE"
    echo "error: codex exec failed (rc=$rc)" >&2
    if [ -s "$THREAD_FILE" ]; then
        echo "thread id captured for resume: $(cat "$THREAD_FILE")" >&2
    fi
    echo "stderr saved to $EVENTS_FILE.stderr" >&2
    exit "$rc"
fi

# The live side stream normally writes this immediately; recover from the
# saved events if process scheduling delayed it.
[ -s "$THREAD_FILE" ] || capture_thread_from_events "$EVENTS_FILE" "$THREAD_FILE"
THREAD_ID="$(cat "$THREAD_FILE" 2>/dev/null || true)"

if [ -z "$THREAD_ID" ] || [ "$THREAD_ID" = "null" ]; then
    echo "error: no thread.started event found in $EVENTS_FILE" >&2
    echo "first 20 events:" >&2
    head -20 "$EVENTS_FILE" >&2
    exit 1
fi

echo "started review session for $TARGET"
echo "  thread id:   $THREAD_ID"
echo "  model/effort: $CODEX_MODEL / $CODEX_EFFORT"
echo "  review file: $REVIEW_FILE"
echo "---"
cat "$REVIEW_FILE"
