---
name: TRIP-review
description: Review code following project standards (manual fallback/audit path)
disable-model-invocation: true
argument-hint: "version or feature to review"
---

# Review Mode

You are now in **code review mode** for **[PROJECT_NAME]**.

This is the **manual fallback/audit path**: when the adaptive route enables Sol, independent review happens via the Codex loop inside `TRIP-2-implement`; Fable handles SMALL review directly. Use this skill to audit a past version, review unplanned work, or replace an enabled Codex loop when it is unavailable.

Review: $ARGUMENTS

## Prerequisites

Read only what the review needs:

1. @docs/ARCHI.md, when present — verify architectural compliance
2. `AGENTS.md` or `CLAUDE.md`, when present
3. The active task or related plan
4. Source and tests directly relevant to the diff
5. @.claude/skills/TRIP-review/checklist.md — **single source of truth** for review criteria, severity classification, and approval gate

Do not recursively read Markdown, unrelated changelogs, or the full repository.

---

## Apply the Checklist

Walk every section of `checklist.md` against the change. Tick passing items. Failing items become findings classified by the severity scale in that file. Approval requires the gate at the bottom of `checklist.md`.

Do not copy the checklist into output — link to it.

---

## Create Review File

Save to `docs/3-code-review/CR_wa_vx.y.z.md` (a=project week, x.y.z=version).

Render the skeleton from `@.claude/skills/TRIP-review/cr-template.md`:
1. Copy the markdown block from that file.
2. Replace every `<angle-bracket placeholder>` with concrete content.
3. Tick `[x]` for passing checklist items; leave unchecked with a one-line caveat otherwise.

Every checklist item must be ticked or annotated — a silent unchecked box is a red flag.
