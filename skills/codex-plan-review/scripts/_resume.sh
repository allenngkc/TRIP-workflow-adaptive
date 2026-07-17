#!/usr/bin/env bash
# Shared low-level resume mechanics. Public wrappers must set CODEX_FLOW and
# any flow-specific default STATE_DIR before invoking this script.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

PROMPT_FILE=""
IMPLEMENTER_NOTES=""
while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-file)
            PROMPT_FILE="$2"; shift 2 ;;
        --prompt-file=*)
            PROMPT_FILE="${1#*=}"; shift ;;
        --notes)
            IMPLEMENTER_NOTES="$2"; shift 2 ;;
        --notes=*)
            IMPLEMENTER_NOTES="${1#*=}"; shift ;;
        --) shift; break ;;
        -*)
            echo "error: unknown flag: $1" >&2; exit 64 ;;
        *) break ;;
    esac
done

if [ -z "$PROMPT_FILE" ] || [ $# -lt 1 ]; then
    echo "usage: resume.sh --prompt-file <tpl> [--notes '...'] <target> [extra prompt text...]" >&2
    exit 64
fi

TARGET="$1"; shift
EXTRA_PROMPT="${*:-}"
export TARGET EXTRA_PROMPT IMPLEMENTER_NOTES

THREAD_FILE="$(thread_file "$TARGET")"
REPORT_FILE="$(review_file "$TARGET")"
EVENTS_FILE="$(events_file "$TARGET")"

if [ ! -f "$THREAD_FILE" ]; then
    echo "error: no $CODEX_FLOW session for $TARGET" >&2
    echo "       run the matching start.sh first." >&2
    exit 2
fi
THREAD_ID="$(cat "$THREAD_FILE")"

PROMPT="$(load_prompt "$PROMPT_FILE")"

# Resume inherits the sandbox selected by the original session. Append each
# turn to the same JSONL/stderr logs and show the same concise live progress.
if run_codex_with_progress \
    "$EVENTS_FILE" "$EVENTS_FILE.stderr" "$THREAD_FILE" append \
    codex exec resume "$THREAD_ID" \
        "${CODEX_GIT_FLAGS[@]}" \
        --json \
        -c model="$CODEX_MODEL" \
        -c model_reasoning_effort="$CODEX_EFFORT" \
        -o "$REPORT_FILE" \
        "$PROMPT" \
        </dev/null
then
    :
else
    rc=$?
    echo "error: codex exec resume failed (rc=$rc)" >&2
    echo "thread remains available for resume: $THREAD_ID" >&2
    echo "stderr saved to $EVENTS_FILE.stderr" >&2
    exit "$rc"
fi

echo "resumed $CODEX_FLOW session for $TARGET"
echo "  thread id:   $THREAD_ID"
echo "  model/effort: $CODEX_MODEL / $CODEX_EFFORT"
echo "  report file: $REPORT_FILE"
echo "---"
cat "$REPORT_FILE"
