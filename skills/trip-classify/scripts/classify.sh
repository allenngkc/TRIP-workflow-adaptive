#!/usr/bin/env bash
# Conservative text-only baseline for the adaptive TRIP classifier.
# Repository context and model judgment remain authoritative.

set -euo pipefail

if [ "$#" -gt 0 ]; then
    request="$*"
else
    request="$(cat)"
fi

lower="$(printf '%s' "$request" | tr '[:upper:]' '[:lower:]')"

# Remove common explicit negations before conservative risk keyword matching.
signals="$lower"
for phrase in \
    "no authentication impact" "no authorization impact" "no auth impact" \
    "no security impact" "not security-sensitive" "no migration" "no migrations" \
    "without a migration" "without migrations" "no database impact" \
    "no persistence impact" "no architectural impact" "no architecture impact" \
    "no concurrency impact" "no payment impact" "no financial impact" \
    "no public api impact" "no data-loss risk" "no data loss risk"
do
    signals="${signals//$phrase/}"
done

contains() {
    [[ "$lower" =~ $1 ]]
}

has_signal() {
    [[ "$signals" =~ $1 ]]
}

requested_tier=""
if contains 'tier[[:space:]]*:[[:space:]]*small'; then requested_tier="SMALL"; fi
if contains 'tier[[:space:]]*:[[:space:]]*medium'; then requested_tier="MEDIUM"; fi
if contains 'tier[[:space:]]*:[[:space:]]*high'; then requested_tier="HIGH"; fi

full_trip=false
budget_mode=false
skip_sol=false
include_plan_review=false
maximum_review=false
skip_release=false
request_release=false

contains 'full[[:space:]]+trip' && full_trip=true
contains 'budget[[:space:]]+mode' && budget_mode=true
contains 'skip[[:space:]]+sol[[:space:]]+review' && skip_sol=true
contains 'include[[:space:]]+sol[[:space:]]+plan[[:space:]]+review' && include_plan_review=true
contains 'maximum[[:space:]]+review' && maximum_review=true
contains 'skip[[:space:]]+release' && skip_release=true
contains '(include|run|perform|with|then)[[:space:]]+(the[[:space:]]+)?release|release[[:space:]]+requested' && request_release=true

base_tier="SMALL"
reason="Localized, reversible change with straightforward verification and no high-risk impact identified."

if has_signal 'authenticat|authoriz|oauth|access[[:space:]-]+control|credential|session[[:space:]-]+security'; then
    base_tier="HIGH"
    reason="Authentication or authorization impact requires the high-risk safety gates."
elif has_signal 'payment|billing|financial|money|invoice'; then
    base_tier="HIGH"
    reason="Payment or financial logic requires the high-risk safety gates."
elif has_signal 'database[[:space:]-]+migration|schema[[:space:]-]+migration|migrat(e|ion)|data[[:space:]-]+loss|destructive[[:space:]-]+data|drop[[:space:]]+(table|column)|delete[[:space:]-]+data'; then
    base_tier="HIGH"
    reason="Migration, destructive persistence, or data-loss risk requires the high-risk safety gates."
elif has_signal 'security[[:space:]-]+sensitive|vulnerab|secret|cryptograph|permission[[:space:]-]+boundary'; then
    base_tier="HIGH"
    reason="Security-sensitive behavior requires the high-risk safety gates."
elif has_signal 'concurren|race[[:space:]-]+condition|distributed[[:space:]-]+system|deadlock|atomicity'; then
    base_tier="HIGH"
    reason="Concurrency or distributed-system behavior requires the high-risk safety gates."
elif has_signal 'major[[:space:]-]+architect|public[[:space:]-]+api[[:space:]-]+compat|breaking[[:space:]-]+api|cross[[:space:]-]+cutting[[:space:]-]+refactor'; then
    base_tier="HIGH"
    reason="Major architecture or public compatibility impact requires the high-risk safety gates."
elif has_signal 'multi[[:space:]-]+file|new[[:space:]-]+feature|api[[:space:]-]+endpoint|business[[:space:]-]+logic|meaningful[[:space:]-]+refactor|external[[:space:]-]+integration|large[[:space:]-]+repetitive|mechanical[[:space:]-]+rename|across[[:space:]]+(many|multiple)[[:space:]]+files'; then
    base_tier="MEDIUM"
    reason="Multi-file or meaningful implementation work needs planning and tests without identified high-risk impact."
fi

tier="$base_tier"
override_note=""
case "$requested_tier" in
    HIGH)
        tier="HIGH"
        override_note="Requested tier: high was applied."
        ;;
    MEDIUM)
        if [ "$base_tier" = "HIGH" ]; then
            override_note="Requested tier: medium was rejected because high-risk signals require HIGH."
        else
            tier="MEDIUM"
            override_note="Requested tier: medium was applied."
        fi
        ;;
    SMALL)
        if [ "$base_tier" = "HIGH" ]; then
            override_note="Requested tier: small was rejected because high-risk signals require HIGH."
        else
            tier="SMALL"
            override_note="Requested tier: small was applied."
        fi
        ;;
esac

requirements=false
planning=false
plan_review=false
approval=false
implementation=true
verification=true
final_review=false
release=false

case "$tier" in
    MEDIUM)
        planning=true
        final_review=true
        ;;
    HIGH)
        requirements=true
        planning=true
        plan_review=true
        approval=true
        final_review=true
        ;;
esac

if $include_plan_review || $maximum_review; then
    planning=true
    plan_review=true
fi
if $maximum_review; then
    final_review=true
fi
if $request_release; then
    release=true
fi
if $skip_release; then
    release=false
fi

if $skip_sol || $budget_mode; then
    if [ "$tier" = "HIGH" ]; then
        if [ -n "$override_note" ]; then override_note="$override_note "; fi
        override_note="${override_note}Sol review reduction was rejected because HIGH requires independent plan and final review."
    elif ! $maximum_review && ! $full_trip; then
        plan_review=false
        final_review=false
    fi
fi

if $full_trip; then
    requirements=true
    planning=true
    plan_review=true
    approval=true
    implementation=true
    verification=true
    final_review=true
    release=true
    if [ -n "$override_note" ]; then override_note="$override_note "; fi
    override_note="${override_note}Full TRIP enabled every stage."
fi

# A specific no-release request wins over ceremony presets because release can
# mutate Git and remote state and always requires explicit intent.
if $skip_release; then
    release=false
    if [ -n "$override_note" ]; then override_note="$override_note "; fi
    override_note="${override_note}Release was explicitly skipped."
fi

echo "Workflow tier: $tier"
echo "Reason: $reason"
if [ -n "$override_note" ]; then
    echo "Override notes: $override_note"
fi
echo "Stages enabled:"
$requirements && echo "- Requirements grilling"
$planning && echo "- Fable planning"
$plan_review && echo "- Sol plan review"
$approval && echo "- User plan approval"
$implementation && echo "- Luna implementation"
$verification && echo "- Fable verification"
$final_review && echo "- Sol final review"
$release && echo "- Release"
echo "Stages skipped:"
$requirements || echo "- Requirements grilling"
$planning || echo "- Fable planning"
$plan_review || echo "- Sol plan review"
$approval || echo "- User plan approval"
$implementation || echo "- Luna implementation"
$verification || echo "- Fable verification"
$final_review || echo "- Sol final review"
$release || echo "- Release"
