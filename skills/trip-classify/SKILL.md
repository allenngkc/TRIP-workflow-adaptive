---
name: trip-classify
description: Classify a software task into the adaptive TRIP SMALL, MEDIUM, or HIGH workflow before planning or implementation. Use for every TRIP feature, fix, refactor, configuration change, migration, or release request to select requirements discovery, planning, Luna implementation, Fable verification, Sol review, and release stages while honoring safe user overrides.
---

# Adaptive TRIP Classifier

Classify before delegating work. Make a judgment from risk, ambiguity, and repository context; do not reduce this to line or file counts.

## Read narrowly

Read only what helps classify the task:

1. `docs/ARCHI.md`, when present
2. `AGENTS.md` or `CLAUDE.md`, when present
3. The active request or frozen plan
4. Source files directly relevant to the task
5. Tests directly relevant to the task

Do not recursively read Markdown or ingest the whole repository. Estimate affected files and implementation size from the architecture and relevant paths.

## Establish the base tier

Use risk and ambiguity as the strongest signals.

- **SMALL**: localized, obvious, reversible, normally about 1-2 files, with simple verification and no architecture, security, auth, persistence, migration, payment, concurrency, public-API, or data-loss impact.
- **MEDIUM**: multi-file feature, moderate business logic, endpoint, meaningful refactor, external integration, or repetitive mechanical change that needs tests but has no high-risk property and no expensive unresolved ambiguity.
- **HIGH**: ambiguous requirements with expensive consequences, major architecture or cross-cutting work, or any authentication, authorization, security-sensitive behavior, payment/financial logic, database/schema/data migration, destructive persistence operation, data-loss risk, concurrency/distributed behavior, or public API compatibility risk.

Promote a small-looking change to HIGH when any high-risk property is present. Do not promote a large repetitive low-risk rename to HIGH merely because it touches many files.

Consider all of these explicitly: affected-file estimate, implementation size, ambiguity, architecture, security, authentication/authorization, persistence/database, migrations, public API compatibility, payments, concurrency, external integrations, testing complexity, reversibility, data loss, and the user's cost/review preference.

For a quick conservative baseline, run:

```bash
bash .claude/skills/trip-classify/scripts/classify.sh "$ARGUMENTS"
```

Correct the baseline when repository evidence or semantic context is stronger.

## Apply overrides safely

Recognize these phrases case-insensitively:

- `tier: small`, `tier: medium`, `tier: high`
- `skip sol review`
- `include sol plan review`
- `skip release`
- `full trip`
- `budget mode`
- `maximum review`

Treat overrides as preferences:

- A requested higher tier is allowed.
- Never honor `tier: small`, `tier: medium`, `skip sol review`, or `budget mode` when it removes HIGH safety gates. State the conflict and retain HIGH.
- `skip sol review` and `budget mode` may remove Sol final review for SMALL or MEDIUM; Fable verification remains mandatory.
- `include sol plan review` adds Fable planning and a fresh Sol plan review even below HIGH.
- `maximum review` adds fresh Sol plan and final reviews; it does not imply release.
- `full trip` enables every stage, including release, without changing the underlying risk label.
- Release is otherwise skipped unless explicitly requested or `/TRIP-3-release` is invoked.

Enabled stages are authoritative. Tier describes inherent risk; it does not cancel ceremony added by an override. In particular, create a lightweight plan for SMALL whenever Fable planning is enabled, and run Sol plan review whenever that stage is enabled.

## Select stages

| Tier | Default stages |
| --- | --- |
| SMALL | Luna implementation -> Fable lightweight diff review and relevant verification |
| MEDIUM | Fable plan -> Luna implementation -> Fable diff review/fixes/tests -> fresh Sol final review -> Fable resolves valid findings |
| HIGH | Fable requirements discovery -> detailed frozen plan -> fresh Sol plan review -> user approval when available -> Luna implementation -> Fable diff review/fixes/tests -> fresh Sol final review -> Fable resolves valid findings |

Plan depth follows risk when planning is enabled: SMALL is lightweight, MEDIUM is focused, and HIGH is detailed. A generic tooling/framework/test migration is normally MEDIUM; database, schema, persistence, storage, or data migration is HIGH. Promote a tooling migration only when repository context shows major architecture, compatibility, or other HIGH risk.

Use Sol only for independent review. Never use the same Sol thread for plan and final code review, and never use Sol to implement. Export `TRIP_WORKFLOW_TIER` before launch so centralized configuration selects Luna `medium/high/high` for SMALL/MEDIUM/HIGH and Sol `xhigh` only for HIGH review.

If implementation changes architecture, require `docs/ARCHI.md` to be updated in the same change when that file is present.

## Emit the routing decision

Print the decision before planning or delegation:

```text
Workflow tier: MEDIUM
Reason: Multi-file feature with new business logic, but no migration, security, or architectural impact.
Stages enabled:
- Fable planning
- Luna implementation
- Fable verification
- Sol final review
Stages skipped:
- Requirements grilling
- Sol plan review
- User plan approval
- Release
```

Add `Override notes:` when an override changes the route or is rejected. Carry this classification into the plan or implementation handoff so later stages do not silently reclassify the task.
