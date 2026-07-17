---
name: TRIP-1-plan
description: Classify and plan a change using the adaptive TRIP workflow
argument-hint: "describe the feature or change"
---

# Adaptive Planning Mode

You are planning work for **[PROJECT_NAME]**. Classification comes before discovery, planning, or delegation.

## Step 0: Classify and route

Use `.claude/skills/trip-classify/SKILL.md` to classify `$ARGUMENTS`. Inspect only:

1. `docs/ARCHI.md`, when present
2. `AGENTS.md` or `CLAUDE.md`, when present
3. The active request
4. Source files directly relevant to estimating the change
5. Tests directly relevant to estimating verification

Do not recursively read Markdown or ingest the full repository. Print the classifier's `Workflow tier`, `Reason`, enabled stages, skipped stages, and any override notes before continuing.

- **SMALL**: skip the plan document and continue directly with `TRIP-2-implement`, carrying the classification and original request.
- **MEDIUM**: write a focused implementation plan. Skip requirements grilling, Sol plan review, and mandatory user approval unless an override enables them.
- **HIGH**: conduct requirements discovery, write a detailed frozen plan, run a fresh Sol plan review, and obtain user approval when user input is available.
- **`full trip`**: enable the complete original ceremony regardless of the underlying risk label.

Never downgrade HIGH because the user requested `tier: small`, `tier: medium`, `skip sol review`, or `budget mode`. Explain the promotion.

## Step 1: Discovery and clarification

### SMALL

Skip discovery unless one answer is genuinely blocking safe implementation.

### MEDIUM

Summarize the intended behavior and proceed from reasonable assumptions. Ask a concise question only for a blocking ambiguity that cannot be resolved from the repository. Do not run an extended requirements interview.

### HIGH

Before writing the plan, summarize your understanding and use `AskUserQuestion` to resolve expensive ambiguity around scope, observable behavior, constraints, compatibility, safety, migration/rollback, and acceptance criteria.

Ask only decision-relevant questions with concrete options. Continue until the contract is sufficiently clear, up to three rounds. If material ambiguity remains, stop and surface it; do not freeze an unsafe plan.

## Step 2: Create the plan

For MEDIUM or HIGH, propose a SemVer version and create:

`docs/1-plans/F_[version]_[feature-name].plan.md`

Place the classification immediately after the plan title so implementation inherits the route:

```markdown
# [Feature Name] Implementation Plan

## Workflow Classification

Workflow tier: MEDIUM
Reason: [concise risk/complexity judgment]
Stages enabled: [comma-separated stages]
Stages skipped: [comma-separated stages]
Override notes: [only when applicable]
```

Then use these sections:

```markdown
## Overview

[Purpose and observable result]

## Problem Statement

[Current limitation, when useful]

## Solution Architecture

[Design and data flow. For MEDIUM, keep this concise.]

## Implementation Details

### 1. [Component or file]

**File**: `path/to/file`

**Modifications**:

- Specific change
- Error/edge behavior

## Technical Considerations

[ADAPT_TO_PROJECT: Replace with project-specific concerns during Init]

- **Pattern Usage**: Existing patterns to follow
- **Risk and reversibility**: Failure modes and rollback
- **Compatibility**: Public or internal contracts
- **Architecture memory**: If architecture changes, update `docs/ARCHI.md` in the same implementation

## Files to Modify/Create

1. `path/to/file` (modify) - purpose

## Test Impact

- Existing affected tests and relevant commands
- New behavior that needs tests
- Integration/E2E or manual verification required

## To-dos

- [ ] Implementation task
- [ ] Tests and verification
- [ ] Update `docs/ARCHI.md` if architecture changes
```

MEDIUM plans may omit inapplicable sections and normally use one phase. HIGH plans must be detailed enough that Luna can implement without guessing; include migration/rollback, compatibility, security boundaries, failure behavior, and phased ordering when relevant.

Do not write implementation code or test code during planning.

## Step 3: Sol plan review

Run this stage only for HIGH, `include sol plan review`, `maximum review`, or `full trip`. MEDIUM skips it by default; SMALL has no plan to review.

Use a **fresh**, read-only Sol thread. Set the classification for centralized effort selection:

```bash
export STATE_DIR=".claude/skills/codex-plan-review/state"
export TRIP_WORKFLOW_TIER="<SMALL|MEDIUM|HIGH>"
bash .claude/skills/codex-plan-review/scripts/reset.sh <plan-path>
bash .claude/skills/codex-plan-review/scripts/start.sh \
    --prompt-file .claude/skills/codex-plan-review/prompts/start.tpl \
    <plan-path>
```

The reset is only for the start of this workflow; resume the same fresh thread for review iterations.

Parse the trailing tag:

- `APPROVED`: freeze the plan.
- `REQUEST_CHANGES`: critically assess each P1/P2, fix valid findings, document pushback, and resume.
- `NEEDS_REWORK`: surface the structural issue before rewriting.

Resume with concise implementer notes:

```bash
bash .claude/skills/codex-plan-review/scripts/resume.sh \
    --prompt-file .claude/skills/codex-plan-review/prompts/resume.tpl \
    --notes "Fixed X. Pushed back on Y because Z." \
    <plan-path>
```

Cap at five rounds unless the user set another limit. Sol is an independent reviewer, never the plan author or implementer. Routine Sol review uses `high`; HIGH classification selects `xhigh` centrally.

## Step 4: Freeze and hand off

Present the feature, approach, key files, workflow tier, enabled/skipped stages, and Sol status.

- **HIGH**: use `AskUserQuestion` to request approval of the frozen plan. Do not implement until the user approves when input is available.
- **MEDIUM**: user approval is optional. If the user requested planning only, stop after presenting the plan. If the active request already authorizes implementation, continue directly to `TRIP-2-implement` with the plan.
- **SMALL**: no plan approval; hand the original task and classification directly to `TRIP-2-implement`.
- **Full TRIP**: preserve the original explicit user-approval gate.

If the user changes scope materially after classification or approval, reclassify before delegation.

## [ADAPT_TO_PROJECT: Guidance Sections]

<!--
During Init, replace this block with guidance for the project's actual component types and patterns.
Keep it curated and derived from ARCHI.md; do not turn it into a repository dump.
-->
