---
name: TRIP-2-implement
description: Implement and verify a change using its adaptive TRIP classification
argument-hint: "plan file or change to implement"
---

# Adaptive Implementation Mode

Implement `$ARGUMENTS` for **[PROJECT_NAME]** using the least orchestration that is safe.

## Step 0: Load or create the classification

Reuse the `Workflow Classification` from the active plan or handoff. If none exists, use `.claude/skills/trip-classify/SKILL.md` before delegating.

Read only:

1. `docs/ARCHI.md`, when present
2. `AGENTS.md` or `CLAUDE.md`, when present
3. The active task or frozen plan
4. Directly relevant source files
5. Directly relevant tests

Do not recursively read Markdown or ingest the full repository. Print the routing decision. If a direct invocation classifies as MEDIUM or HIGH but has no plan, return to `TRIP-1-plan` to create the required plan before delegation.

## Step 1: Decide branch scope

Create a dedicated `feat/` or `fix/` branch when release is enabled, the task is HIGH, or the user requests isolation. SMALL and MEDIUM work may stay on the current branch when release is skipped. Never overwrite unrelated working-tree changes.

## Step 2: Luna implementation

Luna implements every tier. Do not use Sol for implementation.

For a fresh session:

```bash
bash .claude/skills/codex-implement/scripts/start.sh \
    --prompt-file .claude/skills/codex-implement/prompts/implement.tpl \
    <plan-path-or-label> "<classification plus any scope limit>"
```

For later phases, retain the Luna thread:

```bash
export STATE_DIR=".claude/skills/codex-implement/state"
bash .claude/skills/codex-plan-review/scripts/resume.sh \
    --prompt-file .claude/skills/codex-implement/prompts/continue.tpl \
    <plan-path-or-label> "Now implement Phase 2"
```

The launcher must use `--sandbox workspace-write`, never unrestricted execution or `--yolo`. Parse `IMPLEMENTATION_COMPLETE` / `IMPLEMENTATION_PARTIAL`; resume only for a real next phase or substantial unfinished scope.

## Step 3: Fable diff review and fixes

After Luna reports:

- Inspect `git status -s` and the complete `git diff HEAD` against the task/plan and the classification.
- Read the changed source and directly relevant tests; do not reread unrelated documentation.
- Fix valid problems directly as Fable. Do not ping-pong routine fixes back to Luna.
- Verify completed plan checkboxes against the actual diff.
- If the implementation changes architecture, update `docs/ARCHI.md` in this same change and keep it curated.

## Step 4: Tier-aware verification

Verification is mandatory at every tier; breadth changes with risk.

### SMALL

Run the narrowest relevant lint/build/test or manual check. A copy-only change may need only a targeted build/lint or rendered check. Do not run the full suite by default.

### MEDIUM

Run relevant lint, type-check/build, and affected tests. Add or update tests for new business logic and observable behavior. Exercise an affected API/UI/integration contract when applicable.

### HIGH

Run the MEDIUM gate plus risk-focused behavioral tests and rollback/failure-path checks for the high-risk property. Authentication, destructive data, persistence, payments, security, concurrency, and public API behavior require at least one behavioral or integration verification; coverage debt cannot replace it.

Use the project commands inserted by `TRIP-init`:

```bash
# [ADAPT_TO_PROJECT: Replace with actual commands during Init]
[LINT_COMMAND] 2>&1 | tee /tmp/_trip2-lint.txt
[TYPECHECK_COMMAND] 2>&1 | tee /tmp/_trip2-typecheck.txt
[TEST_COMMAND] <pattern-for-affected-files>
```

Apply the `TRIP-test` seam ladder for hard-to-test code. Never hide code from coverage or lower a gate. Summarize: `lint: clean | typecheck: clean | tests: N passed (M new) | manual: ...`.

Fix failures before any Sol review.

## Step 5: Conditional Sol final review

- **SMALL**: skip Sol.
- **MEDIUM**: run one fresh Sol final code-review thread by default.
- **HIGH**: a fresh Sol final review is mandatory.
- **Overrides**: `skip sol review` and `budget mode` may skip MEDIUM Sol review. They cannot remove HIGH review. `maximum review` and `full trip` enable it.

At the start of this workflow, reset stale code-review state so the reviewer is independent of any previous run; resume that new thread only for its finding-resolution loop:

```bash
export STATE_DIR=".claude/skills/codex-code-review/state"
export TRIP_WORKFLOW_TIER="<SMALL|MEDIUM|HIGH>"
bash .claude/skills/codex-plan-review/scripts/reset.sh <plan-path-or-label>
bash .claude/skills/codex-plan-review/scripts/start.sh \
    --prompt-file .claude/skills/codex-code-review/prompts/start.tpl \
    <plan-path-or-label> "$GATE_SUMMARY"
```

Parse `APPROVED`, `REQUEST_CHANGES`, or `NEEDS_REWORK`. For findings:

1. Surface each finding with `file:line`.
2. Fable reads the code, fixes legitimate issues, and pushes back with evidence on invalid ones.
3. Re-run relevant verification.
4. Resume with concise notes and the new gate summary.

Cap at five rounds unless overridden. Sol is read-only and independent. Default Sol effort is `high`; HIGH classification selects `xhigh` through `_common.sh`.

After multi-round convergence, use `synthesize.tpl` to create the promotion-ready review state. Skip synthesis when Sol was skipped or Turn 1 already contains the full review.

## Step 6: Finish or release

Cross completed plan items and report implementation, verification, review status, and any limitations.

Release is **not automatic** for SMALL or MEDIUM and is optional for HIGH. Invoke `TRIP-3-release` only when the classification enables Release, the user explicitly requests it, or the user directly invokes `/TRIP-3-release`. `full trip` enables release. `skip release` always leaves the verified change uncommitted and untagged for the user to inspect.

The release skill retains its own explicit approvals before commit, tag, merge, or push.
