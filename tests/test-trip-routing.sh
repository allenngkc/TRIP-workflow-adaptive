#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN_SKILL="$ROOT/skills/TRIP-1-plan/SKILL.md"
IMPLEMENT_SKILL="$ROOT/skills/TRIP-2-implement/SKILL.md"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

grep -Fq 'Treat `Stages enabled` as the execution contract' "$PLAN_SKILL" \
    || fail "planning skill does not declare enabled stages authoritative"
grep -Fq 'Whenever **Fable planning** is enabled' "$PLAN_SKILL" \
    || fail "planning skill does not create override-enabled plans"
grep -Fq '**SMALL**: create a lightweight, focused plan' "$PLAN_SKILL" \
    || fail "planning skill lacks lightweight SMALL plans"
grep -Fq 'whenever **Sol plan review** is enabled' "$PLAN_SKILL" \
    || fail "planning skill does not execute override-enabled plan review"
grep -Fq 'If **Fable planning** is enabled but no plan exists' "$IMPLEMENT_SKILL" \
    || fail "implementation entry ignores the planning stage flag"
grep -Fq 'Run this stage whenever **Sol final review** is enabled' "$IMPLEMENT_SKILL" \
    || fail "implementation entry ignores the final-review stage flag"

echo "trip routing contract: PASS"
