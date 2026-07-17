#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_TEST="$(mktemp -d "${TMP_BASE%/}/trip-progress.XXXXXX")"
case "$TMP_TEST" in
    "${TMP_BASE%/}"/trip-progress.*) ;;
    *) echo "unsafe temp path: $TMP_TEST" >&2; exit 1 ;;
esac
trap 'rm -rf -- "$TMP_TEST"' EXIT

export STATE_DIR="$TMP_TEST/state"
export CODEX_FLOW=review
# shellcheck source=../skills/codex-plan-review/scripts/_common.sh
source "$ROOT/skills/codex-plan-review/scripts/_common.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

fixture() {
    cat <<'JSONL'
{"type":"thread.started","thread_id":"thread-test-123"}
{"type":"turn.started"}
{"type":"item.started","item":{"type":"command_execution","command":"npm test","status":"in_progress"}}
{"type":"item.completed","item":{"type":"command_execution","command":"npm test","status":"completed","exit_code":0}}
{"type":"item.completed","item":{"type":"file_change","changes":[{"path":"src/app.js"},{"path":"tests/app.test.js"}]}}
{"type":"turn.completed"}
JSONL
}

progress="$(fixture | render_codex_progress)"
for expected in \
    '[codex] session started: thread-test-123' \
    '[codex] turn started' \
    '[codex] command started: npm test' \
    '[codex] command completed: npm test' \
    '[codex] file changes completed: src/app.js, tests/app.test.js' \
    '[codex] turn completed'
do
    printf '%s\n' "$progress" | grep -Fqx "$expected" \
        || fail "missing progress line: $expected"
done

emit_start() {
    fixture
    echo "diagnostic on stderr" >&2
}

events="$TMP_TEST/session.events.ndjson"
stderr_log="$events.stderr"
thread_file="$TMP_TEST/session.thread"

start_progress="$(run_codex_with_progress \
    "$events" "$stderr_log" "$thread_file" truncate emit_start \
    2>"$TMP_TEST/live.stderr")"

[ "$(wc -l < "$events" | tr -d ' ')" = 6 ] \
    || fail "fresh run did not save the full JSONL stream"
[ "$(cat "$thread_file")" = "thread-test-123" ] \
    || fail "thread id was not captured for resume"
grep -Fqx 'diagnostic on stderr' "$stderr_log" \
    || fail "stderr was not saved"
grep -Fqx 'diagnostic on stderr' "$TMP_TEST/live.stderr" \
    || fail "stderr was not visible live"
printf '%s\n' "$start_progress" | grep -Fqx '[codex] command started: npm test' \
    || fail "fresh run did not display progress"

emit_resume() {
    printf '%s\n' \
        '{"type":"turn.started"}' \
        '{"type":"item.started","item":{"type":"command_execution","command":"npm run build"}}' \
        '{"type":"item.completed","item":{"type":"command_execution","command":"npm run build","exit_code":0}}' \
        '{"type":"turn.completed"}'
}

resume_progress="$(run_codex_with_progress \
    "$events" "$stderr_log" "$thread_file" append emit_resume)"
[ "$(wc -l < "$events" | tr -d ' ')" = 10 ] \
    || fail "resume did not append its complete JSONL stream"
printf '%s\n' "$resume_progress" | grep -Fqx '[codex] command started: npm run build' \
    || fail "resume did not display progress"

emit_failure() {
    printf '%s\n' \
        '{"type":"turn.started"}' \
        '{"type":"turn.failed","error":{"message":"simulated failure"}}'
    return 7
}

set +e
run_codex_with_progress \
    "$TMP_TEST/failure.events.ndjson" "$TMP_TEST/failure.stderr" \
    "$TMP_TEST/failure.thread" truncate emit_failure \
    >"$TMP_TEST/failure.progress"
failure_rc=$?
set -e

[ "$failure_rc" = 7 ] \
    || fail "pipefail hid command failure (expected 7, got $failure_rc)"
grep -Fqx '[codex] turn failed: simulated failure' "$TMP_TEST/failure.progress" \
    || fail "failure event was not displayed"

emit_invalid_json() {
    printf '%s\n' '{not-json}'
}

set +e
run_codex_with_progress \
    "$TMP_TEST/parser.events.ndjson" "$TMP_TEST/parser.stderr" \
    "$TMP_TEST/parser.thread" truncate emit_invalid_json \
    >"$TMP_TEST/parser.progress" 2>"$TMP_TEST/parser.error"
parser_rc=$?
set -e

[ "$parser_rc" -ne 0 ] \
    || fail "parser failure was hidden by the pipeline"
grep -Fq '[codex] progress parser error:' "$TMP_TEST/parser.error" \
    || fail "parser failure was not reported"

echo "codex progress streaming: PASS"
