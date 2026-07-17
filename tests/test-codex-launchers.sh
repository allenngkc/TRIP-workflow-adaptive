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

{
    printf 'FLOW=%s\n' "${CODEX_FLOW:-unset}"
    printf 'TIER=%s\n' "${TRIP_WORKFLOW_TIER:-unset}"
    printf 'STATE_DIR=%s\n' "${STATE_DIR:-unset}"
    for arg in "$@"; do
        printf 'ARG=%s\n' "$arg"
    done
} >> "$FAKE_CODEX_ARGS"

mode=start
if [ "${1:-}" = exec ] && [ "${2:-}" = resume ]; then
    mode=resume
fi

report=""
sandbox=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o|--output-last-message)
            report="$2"; shift 2 ;;
        --sandbox)
            sandbox="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [ "$mode" = start ] && [ -n "${FAKE_CODEX_SESSION:-}" ]; then
    printf '%s\n' "$sandbox" > "$FAKE_CODEX_SESSION"
fi
if [ "$mode" = resume ] && [ "${CODEX_FLOW:-}" = implementation ]; then
    inherited="$(cat "$FAKE_CODEX_SESSION" 2>/dev/null || true)"
    if [ "$inherited" != workspace-write ]; then
        echo "implementation resume did not inherit workspace-write" >&2
        exit 88
    fi
fi

if [ -n "$report" ]; then
    if [ "$mode" = resume ]; then
        printf 'resume report\n%s\n' "$([ "${CODEX_FLOW:-}" = implementation ] && echo IMPLEMENTATION_COMPLETE || echo APPROVED)" > "$report"
    else
        printf 'start report\n%s\n' "$([ "${CODEX_FLOW:-}" = implementation ] && echo IMPLEMENTATION_COMPLETE || echo APPROVED)" > "$report"
    fi
fi

if [ "${FAKE_CODEX_INVALID_JSON:-0}" = 1 ]; then
    printf '%s\n' '{not-json}'
elif [ "$mode" = start ]; then
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

echo "fake codex $mode stderr" >&2
exit "${FAKE_CODEX_EXIT:-0}"
FAKE_CODEX
chmod +x "$TMP_TEST/bin/codex"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_line() {
    local file="$1"
    local line="$2"
    grep -Fqx -- "$line" "$file" || fail "missing '$line' in $file"
}

assert_no_line() {
    local file="$1"
    local line="$2"
    if grep -Fqx -- "$line" "$file"; then
        fail "unexpected '$line' in $file"
    fi
}

export PATH="$TMP_TEST/bin:$PATH"

# SMALL implementation with a custom state path proves role selection is not
# inferred from a directory name.
export STATE_DIR="$TMP_TEST/custom-state"
export TRIP_WORKFLOW_TIER=SMALL
export FAKE_CODEX_ARGS="$TMP_TEST/small-start.args"
export FAKE_CODEX_SESSION="$TMP_TEST/small.session"
bash "$ROOT/skills/codex-implement/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-implement/prompts/implement.tpl" \
    "small implementation" \
    >"$TMP_TEST/small-start.stdout" 2>"$TMP_TEST/small-start.stderr"

assert_line "$FAKE_CODEX_ARGS" 'FLOW=implementation'
assert_line "$FAKE_CODEX_ARGS" 'TIER=SMALL'
assert_line "$FAKE_CODEX_ARGS" "STATE_DIR=$STATE_DIR"
assert_line "$FAKE_CODEX_ARGS" 'ARG=model=gpt-5.6-luna'
assert_line "$FAKE_CODEX_ARGS" 'ARG=model_reasoning_effort=medium'
assert_line "$FAKE_CODEX_ARGS" 'ARG=workspace-write'
assert_no_line "$FAKE_CODEX_ARGS" 'ARG=--skip-git-repo-check'
grep -Fq '[codex] command started: npm test' "$TMP_TEST/small-start.stdout" \
    || fail "fresh implementation progress was not live"
assert_line "$TMP_TEST/small.session" 'workspace-write'

events="$(find "$STATE_DIR" -name '*.events.ndjson' -print -quit)"
report="$(find "$STATE_DIR" -name '*.review.txt' -print -quit)"
[ "$(wc -l < "$events" | tr -d ' ')" = 5 ] \
    || fail "fresh implementation did not save all JSONL events"
assert_line "$events.stderr" 'fake codex start stderr'
grep -Fq 'fake codex start stderr' "$TMP_TEST/small-start.stderr" \
    || fail "fresh implementation stderr was not visible live"
grep -Fq 'IMPLEMENTATION_COMPLETE' "$report" \
    || fail "fresh implementation report was not preserved"

# Public implementation resume must explicitly retain Luna and the custom
# state path. The fake validates the sandbox inherited from the start.
export FAKE_CODEX_ARGS="$TMP_TEST/small-resume.args"
bash "$ROOT/skills/codex-implement/scripts/resume.sh" \
    --prompt-file "$ROOT/skills/codex-implement/prompts/continue.tpl" \
    "small implementation" \
    >"$TMP_TEST/small-resume.stdout" 2>"$TMP_TEST/small-resume.stderr"

assert_line "$FAKE_CODEX_ARGS" 'FLOW=implementation'
assert_line "$FAKE_CODEX_ARGS" 'ARG=model=gpt-5.6-luna'
assert_line "$FAKE_CODEX_ARGS" 'ARG=model_reasoning_effort=medium'
assert_no_line "$FAKE_CODEX_ARGS" 'ARG=--sandbox'
assert_no_line "$FAKE_CODEX_ARGS" 'ARG=--skip-git-repo-check'
grep -Fq '[codex] command started: npm run build' "$TMP_TEST/small-resume.stdout" \
    || fail "resumed implementation progress was not live"
[ "$(wc -l < "$events" | tr -d ' ')" = 9 ] \
    || fail "resumed implementation did not append all JSONL events"
[ "$(grep -c '^fake codex .* stderr$' "$events.stderr")" = 2 ] \
    || fail "fresh and resumed implementation stderr were not retained"
grep -Fq 'fake codex resume stderr' "$TMP_TEST/small-resume.stderr" \
    || fail "resumed implementation stderr was not visible live"
grep -Fq 'resume report' "$report" \
    || fail "resumed implementation report was not preserved"

run_implementation_profile() {
    local tier="$1"
    local effort="$2"
    local label="$3"
    export STATE_DIR="$TMP_TEST/$label-state"
    export TRIP_WORKFLOW_TIER="$tier"
    export FAKE_CODEX_ARGS="$TMP_TEST/$label.args"
    export FAKE_CODEX_SESSION="$TMP_TEST/$label.session"
    bash "$ROOT/skills/codex-implement/scripts/start.sh" \
        --prompt-file "$ROOT/skills/codex-implement/prompts/implement.tpl" \
        "$label" >"$TMP_TEST/$label.stdout" 2>"$TMP_TEST/$label.stderr"
    assert_line "$FAKE_CODEX_ARGS" 'FLOW=implementation'
    assert_line "$FAKE_CODEX_ARGS" 'ARG=model=gpt-5.6-luna'
    assert_line "$FAKE_CODEX_ARGS" "ARG=model_reasoning_effort=$effort"
    assert_line "$FAKE_CODEX_ARGS" 'ARG=workspace-write'
    assert_no_line "$FAKE_CODEX_ARGS" 'ARG=--skip-git-repo-check'
}

run_implementation_profile MEDIUM high medium-implementation
run_implementation_profile HIGH high high-implementation

run_review_profile() {
    local tier="$1"
    local effort="$2"
    local label="$3"
    export STATE_DIR="$TMP_TEST/$label-state"
    export TRIP_WORKFLOW_TIER="$tier"
    export FAKE_CODEX_ARGS="$TMP_TEST/$label.args"
    export FAKE_CODEX_SESSION="$TMP_TEST/$label.session"
    bash "$ROOT/skills/codex-plan-review/scripts/start.sh" \
        --prompt-file "$ROOT/skills/codex-plan-review/prompts/start.tpl" \
        "$label" >"$TMP_TEST/$label.stdout" 2>"$TMP_TEST/$label.stderr"
    assert_line "$FAKE_CODEX_ARGS" 'FLOW=review'
    assert_line "$FAKE_CODEX_ARGS" 'ARG=model=gpt-5.6-sol'
    assert_line "$FAKE_CODEX_ARGS" "ARG=model_reasoning_effort=$effort"
    assert_line "$FAKE_CODEX_ARGS" 'ARG=read-only'
    assert_no_line "$FAKE_CODEX_ARGS" 'ARG=--skip-git-repo-check'
}

run_review_profile MEDIUM high medium-final-review
run_review_profile HIGH xhigh high-plan-review
run_review_profile HIGH xhigh high-final-review

# Review resume also establishes review flow explicitly.
export STATE_DIR="$TMP_TEST/medium-final-review-state"
export TRIP_WORKFLOW_TIER=MEDIUM
export FAKE_CODEX_ARGS="$TMP_TEST/medium-review-resume.args"
export FAKE_CODEX_SESSION="$TMP_TEST/medium-final-review.session"
bash "$ROOT/skills/codex-plan-review/scripts/resume.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/resume.tpl" \
    "medium-final-review" \
    >"$TMP_TEST/medium-review-resume.stdout" 2>"$TMP_TEST/medium-review-resume.stderr"
assert_line "$FAKE_CODEX_ARGS" 'FLOW=review'
assert_line "$FAKE_CODEX_ARGS" 'ARG=model=gpt-5.6-sol'
assert_line "$FAKE_CODEX_ARGS" 'ARG=model_reasoning_effort=high'

# Explicit non-Git opt-in adds the bypass; default cases above retained the
# repository check by omitting it.
export STATE_DIR="$TMP_TEST/non-git-state"
export TRIP_WORKFLOW_TIER=SMALL
export TRIP_ALLOW_NON_GIT=1
export FAKE_CODEX_ARGS="$TMP_TEST/non-git.args"
export FAKE_CODEX_SESSION="$TMP_TEST/non-git.session"
bash "$ROOT/skills/codex-plan-review/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/start.tpl" \
    "non-git opt-in" >"$TMP_TEST/non-git.stdout" 2>"$TMP_TEST/non-git.stderr"
assert_line "$FAKE_CODEX_ARGS" 'ARG=--skip-git-repo-check'
unset TRIP_ALLOW_NON_GIT

# A Codex failure must survive tee and parsing unchanged.
export STATE_DIR="$TMP_TEST/failure-state"
export TRIP_WORKFLOW_TIER=MEDIUM
export FAKE_CODEX_ARGS="$TMP_TEST/failure.args"
export FAKE_CODEX_SESSION="$TMP_TEST/failure.session"
export FAKE_CODEX_EXIT=9
set +e
bash "$ROOT/skills/codex-plan-review/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/start.tpl" \
    "launcher failure" >"$TMP_TEST/failure.stdout" 2>"$TMP_TEST/failure.stderr"
failure_rc=$?
set -e
unset FAKE_CODEX_EXIT
[ "$failure_rc" = 9 ] \
    || fail "launcher hid Codex failure (expected 9, got $failure_rc)"

# A successful Codex process emitting invalid JSON must still fail through the
# unbuffered parser.
export STATE_DIR="$TMP_TEST/parser-failure-state"
export FAKE_CODEX_ARGS="$TMP_TEST/parser-failure.args"
export FAKE_CODEX_SESSION="$TMP_TEST/parser-failure.session"
export FAKE_CODEX_INVALID_JSON=1
set +e
bash "$ROOT/skills/codex-plan-review/scripts/start.sh" \
    --prompt-file "$ROOT/skills/codex-plan-review/prompts/start.tpl" \
    "parser failure" >"$TMP_TEST/parser-failure.stdout" 2>"$TMP_TEST/parser-failure.stderr"
parser_rc=$?
set -e
unset FAKE_CODEX_INVALID_JSON
[ "$parser_rc" -ne 0 ] || fail "launcher hid parser failure"
grep -Fq '[codex] progress parser error:' "$TMP_TEST/parser-failure.stderr" \
    || fail "launcher parser failure was not reported"

echo "codex launchers: PASS"
