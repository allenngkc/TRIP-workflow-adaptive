#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$ROOT/skills/trip-classify"
SKILL_FILE="$SKILL_DIR/SKILL.md"
AGENT_FILE="$SKILL_DIR/agents/openai.yaml"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[ -f "$SKILL_FILE" ] && [ -f "$AGENT_FILE" ] \
    || fail "trip-classify skill metadata is incomplete"
[ "$(head -1 "$SKILL_FILE")" = '---' ] \
    || fail "SKILL.md frontmatter does not start on line 1"

frontmatter="$(sed -n '2,/^---$/p' "$SKILL_FILE" | sed '$d')"
[ "$(printf '%s\n' "$frontmatter" | grep -c '^[a-z-]*:')" = 2 ] \
    || fail "SKILL.md frontmatter must contain only name and description"
printf '%s\n' "$frontmatter" | grep -qx 'name: trip-classify' \
    || fail "skill name does not match its folder"
printf '%s\n' "$frontmatter" | grep -q '^description: .\+' \
    || fail "skill description is missing"
grep -Fq 'Use $trip-classify' "$AGENT_FILE" \
    || fail "openai.yaml default prompt does not mention the skill"
if grep -Eq 'TODO|\[TODO' "$SKILL_FILE" "$AGENT_FILE"; then
    fail "generated scaffold TODO remains"
fi

bash -n "$SKILL_DIR/scripts/classify.sh"
echo "trip skill structure: PASS"
