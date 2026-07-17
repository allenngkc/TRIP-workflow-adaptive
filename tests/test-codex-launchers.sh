#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_TEST="$(mktemp -d "${TMP_BASE%/}/trip-launchers.XXXXXX")"
case "$TMP_TEST" in
    "${TMP_BASE%/}"/trip-launchers.*) ;;
    *) echo "unsafe temp path: $TMP_TEST" >&2; exit 1 ;;
esac
trap 'rm -rf -- "$TMP_TEST"' EXIT

mkdir -p "$TMP_TEST/bin"
cat > "$TMP_TEST/bin/codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
set -euo pipefail

printf '%s ' "$@" >> "$FAKE_CODEX_ARGS"
printf '\n' >> "$FAKE_CODEX_ARGS"

mode=start
if [ "${1:-}" = exec ] && [ "${2:-}" = resume ]; then
    mode=resume
fi

report=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o|--output-last-message)
            report="$2"
            shift 2
            ;;
        *) shift ;;
    esac
done

if [ -n "$report" ]; then
    if [ "$mode" = resume ]; then
        printf 'resume report\nAPPROVED\n' > "$report"
    else
        printf 'start report\nAPPROVED\n' > "$report"
    fi
fi

if [ "$mode" = start ]; then
    printf '%s\n' \
        '{"type":"thread.started","thread_id":"fake-thread-123"}' \
        '{"type":"turn.started"}' \
        '{"type":"item.started","item":{"type":"command_execution","command":"npm test"}}' \
        '{"type":"item.completed","item":{"type":"command_execution","command":"npm test","exit_code":0}}' \
        '{"type":"turn.completed"}'
else
    printf '%s\n' \
        '{"type":"turn.started"}' \
        '{"type":"item.started","item":{"type":"command_execution","command":"npm run build"}}' \
        '{"type":"item.completed","item":{"type":"command_execution","command":"npm run build","exit_code":0}}' \
        '{"type":"turn.completed"}'
fi

echo "fake codex stderr" >&2
exit "${FAKE_CODEX_EXIT:-0}"
FAKE_CODEX
chmod +x "$TMP_TEST/bin/codex"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

export PATH="$TMP_TEST/bin:$PATH"
export FAKE_CODEX_ARGS="$TMP_TEST/codex.args"
export STATE_DIR="$TMP_TEST/review-state"

start_output="$(bash "$ROOT/skills/codex-plan-review/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/start.tpl" \
    "launcher review" 2>"$TMP_TEST/start.stderr")"

events="$(find "$STATE_DIR" -name '*.events.ndjson' -print -quit)"
thread="$(find "$STATE_DIR" -name '*.thread' -print -quit)"
report="$(find "$STATE_DIR" -name '*.review.txt' -print -quit)"
[ -n "$events" ] && [ -n "$thread" ] && [ -n "$report" ] \
    || fail "start did not create event, thread, and report state"
[ "$(cat "$thread")" = fake-thread-123 ] \
    || fail "start did not retain the thread id"
[ "$(wc -l < "$events" | tr -d ' ')" = 5 ] \
    || fail "start did not save all JSONL events"
grep -Fqx 'fake codex stderr' "$events.stderr" \
    || fail "start did not save stderr"
grep -Fq '[codex] command started: npm test' <<< "$start_output" \
    || fail "start did not show concise command progress"
grep -Fq 'start report' <<< "$start_output" \
    || fail "start did not print the existing report file"
grep -Fq -- '--sandbox read-only' "$FAKE_CODEX_ARGS" \
    || fail "review launcher did not use read-only sandbox"

resume_output="$(bash "$ROOT/skills/codex-plan-review/scripts/resume.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/resume.tpl" \
    "launcher review" 2>"$TMP_TEST/resume.stderr")"
[ "$(wc -l < "$events" | tr -d ' ')" = 9 ] \
    || fail "resume did not append all JSONL events"
grep -Fq '[codex] command started: npm run build' <<< "$resume_output" \
    || fail "resume did not show concise command progress"
grep -Fq 'resume report' <<< "$resume_output" \
    || fail "resume did not print the existing report file"

export STATE_DIR="$TMP_TEST/implement-state"
implement_output="$(bash "$ROOT/skills/codex-implement/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-implement/prompts/implement.tpl" \
    "launcher implementation" 2>"$TMP_TEST/implement.stderr")"
grep -Fq -- '--sandbox workspace-write' "$FAKE_CODEX_ARGS" \
    || fail "implementation launcher did not use workspace-write"
grep -Fq '[codex] command started: npm test' <<< "$implement_output" \
    || fail "implementation start did not show progress"

export STATE_DIR="$TMP_TEST/high-review-state"
export TRIP_WORKFLOW_TIER=HIGH
high_output="$(bash "$ROOT/skills/codex-plan-review/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/start.tpl" \
    "high-risk review" 2>"$TMP_TEST/high.stderr")"
unset TRIP_WORKFLOW_TIER
grep -Fq 'model/effort: gpt-5.6-sol / xhigh' <<< "$high_output" \
    || fail "HIGH review did not select centralized xhigh effort"

export STATE_DIR="$TMP_TEST/failure-state"
export FAKE_CODEX_EXIT=9
set +e
bash "$ROOT/skills/codex-plan-review/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/start.tpl" \
    "launcher failure" \
    >"$TMP_TEST/failure.stdout" 2>"$TMP_TEST/failure.stderr"
failure_rc=$?
set -e
unset FAKE_CODEX_EXIT

[ "$failure_rc" = 9 ] \
    || fail "launcher hid Codex failure (expected 9, got $failure_rc)"
grep -Fq 'thread id captured for resume: fake-thread-123' "$TMP_TEST/failure.stderr" \
    || fail "failed start did not preserve the resume thread id"
grep -Fq '[codex] turn completed' "$TMP_TEST/failure.stdout" \
    || fail "failed start lost its live progress stream"

echo "codex launchers: PASS"
