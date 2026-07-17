#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLASSIFIER="$ROOT/skills/trip-classify/scripts/classify.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

classify() {
    bash "$CLASSIFIER" "$1"
}

assert_tier() {
    local expected="$1"
    local request="$2"
    local output
    output="$(classify "$request")"
    printf '%s\n' "$output" | grep -qx "Workflow tier: $expected" \
        || fail "expected $expected for: $request"
}

enabled_stages() {
    sed -n '/^Stages enabled:$/,/^Stages skipped:$/p' | sed '1d;$d'
}

skipped_stages() {
    sed -n '/^Stages skipped:$/,$p' | sed '1d'
}

# Required routing scenarios.
assert_tier SMALL "Fix a typo in one UI label."
assert_tier SMALL "Adjust one file's empty-state spacing and copy."
assert_tier MEDIUM "Add a normal multi-file feature with new business logic and affected tests."
assert_tier HIGH "Change authentication callback behavior in one file."
assert_tier HIGH "Add a database migration for the customer table."
assert_tier MEDIUM "Perform a large repetitive mechanical rename across many files."

full_output="$(classify "Fix a typo, full trip")"
for stage in \
    "Requirements grilling" "Fable planning" "Sol plan review" \
    "User plan approval" "Luna implementation" "Fable verification" \
    "Sol final review" "Release"
do
    printf '%s\n' "$full_output" | enabled_stages | grep -qx -- "- $stage" \
        || fail "full trip did not enable: $stage"
done

no_release_output="$(classify "Fix a typo, full trip, skip release")"
printf '%s\n' "$no_release_output" | enabled_stages | grep -qx -- '- Release' \
    && fail "skip release did not override full trip release"
printf '%s\n' "$no_release_output" | skipped_stages | grep -qx -- '- Release' \
    || fail "skip release was not shown in skipped stages"

skip_output="$(classify "Add a multi-file settings feature, skip sol review")"
printf '%s\n' "$skip_output" | enabled_stages | grep -q -- 'Sol .*review' \
    && fail "skip sol review left a Sol stage enabled for MEDIUM"
printf '%s\n' "$skip_output" | skipped_stages | grep -qx -- '- Sol final review' \
    || fail "skip sol review did not skip the MEDIUM final review"

promotion_output="$(classify "tier: small — change security-sensitive permission validation")"
printf '%s\n' "$promotion_output" | grep -qx 'Workflow tier: HIGH' \
    || fail "security-sensitive SMALL request was not promoted"
printf '%s\n' "$promotion_output" | grep -q 'was rejected' \
    || fail "unsafe downgrade rejection was not explained"
printf '%s\n' "$promotion_output" | enabled_stages | grep -qx -- '- Sol plan review' \
    || fail "HIGH promotion did not retain Sol plan review"
printf '%s\n' "$promotion_output" | enabled_stages | grep -qx -- '- Sol final review' \
    || fail "HIGH promotion did not retain Sol final review"

echo "trip classifier scenarios: PASS"
