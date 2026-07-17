![TRIP Workflow Banner](assets/trip-workflow-banner2.png)

![Version](https://img.shields.io/badge/version-2.1.0-blue) [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/PiLastDigit/TRIP-workflow/blob/master/LICENSE) ![Works with](https://img.shields.io/badge/Works_with-grey) [![Claude Code](https://img.shields.io/badge/Claude_Code-E5582B)](https://docs.anthropic.com/en/docs/claude-code) [![Codex CLI](https://img.shields.io/badge/Codex_CLI-10A37F)](https://developers.openai.com/codex/cli/) [![OpenCode](https://img.shields.io/badge/OpenCode-1a3a5c)](https://github.com/sst/opencode) [![Mistral Vibe](https://img.shields.io/badge/Mistral_Vibe-F7D046)](https://github.com/mistralai/mistral-vibe)

## What is TRIP?

A structured development workflow for AI coding agents that brings **memory**, **consistency**, and **reduced hallucination** (only humans should) to AI-assisted development. TRIP helps you enter flow state and eat features like buttered noodles.
It is also the acronym (reversed) of the historical 4-phases development cycle: **P**lan, **I**mplement, **R**eview, **T**est.  
**Note:** This adaptive fork keeps the v2 **Plan -> Implement -> Release** structure, but scales planning, independent review, testing, and release ceremony to the task. Every change is verified; only changes that benefit from premium review pay for it.

TRIP was initially designed for Claude Code using the [Agent Skills](https://agentskills.io/home) open standard (`SKILL.md`). Also compatible with OpenCode, Codex CLI, Mistral Vibe and more.

## Why TRIP?

There are tons of AI coding workflows out there like [Superpowers](https://github.com/obra/superpowers), [BMAD](https://github.com/bmad-code-org/BMAD-METHOD), [Gastown](https://github.com/steveyegge/gastown) and countless others. They might be powerful, but overwhelming for many of us dumb asses.

Even the "simple" ones come with:

- 47 different commands & skills to memorize
- Sub-agents swarm for God-knows-what
- Mutlti-chapters courses (sometimes paid lol)

**TRIP is different.** It's deliberately minimal:

| That's it           | Just these                                             |
| ------------------- | ------------------------------------------------------ |
| `/TRIP-1-plan`      | Classify first; skip, focus, or deepen planning         |
| `/TRIP-2-implement` | Luna writes; Fable verifies; Sol reviews when warranted |
| `/TRIP-3-release`   | Optional version, docs, commit, tag, merge, and push    |

![TRIP Workflow loop](assets/trip-workflow-loop2.png)

Three numbered skills. One architecture file. Zero PhD required.

The onboarding is: copy the folder, run init, start coding. If you can count to 3, you can TRIP.

## Adaptive workflow

Start with `/TRIP-1-plan <task>`. It invokes the shared `trip-classify` rules before any delegation. The enabled-stage list is authoritative: SMALL routes straight to implementation by default, but receives a lightweight plan and any requested review ceremony when overrides enable those stages. You can still invoke `/TRIP-2-implement` with an existing plan or task, and `/TRIP-3-release` remains available for explicit manual control.

| Tier | Typical work | Enabled by default | Skipped by default |
| --- | --- | --- | --- |
| **SMALL** | Typo, copy/UI tweak, simple config, obvious localized fix | Luna implementation; Fable diff review and relevant verification | Formal plan, requirements grilling, both Sol reviews, release |
| **MEDIUM** | Multi-file feature, endpoint, business logic, meaningful refactor, large mechanical rename | Fable plan; Luna implementation; Fable fixes/tests; one fresh Sol final review | Requirements grilling, Sol plan review, mandatory plan approval, release |
| **HIGH** | Auth, security, payments, database/data migration, destructive data, concurrency, public compatibility, major architecture | Requirements discovery; detailed plan; fresh Sol plan review; plan approval; Luna implementation; Fable fixes/tests; fresh Sol final review | Release unless explicitly requested |

Classification is a judgment call, not a rigid line-count formula. Risk and ambiguity dominate size: a one-file authentication change is HIGH, while a large repetitive low-risk rename can remain MEDIUM. Tooling migrations such as Jest-to-Vitest normally remain MEDIUM; database, schema, persistence, storage, or data migrations are HIGH. The classifier considers affected files, implementation size, ambiguity, architecture, security/auth, persistence, public API compatibility, payments, concurrency, integrations, testing complexity, reversibility, and data-loss potential.

### Overrides

Add preferences directly to the request: `tier: small`, `tier: medium`, `tier: high`, `skip sol review`, `include sol plan review`, `skip release`, `full trip`, `budget mode`, or `maximum review`.

- `full trip` enables every original stage, including release.
- `budget mode` or `skip sol review` can remove Sol from SMALL/MEDIUM while retaining Fable verification.
- `include sol plan review` and `maximum review` add independent review without forcing release.
- Overrides add ceremony without changing inherent risk. For example, `Fix typo, include sol plan review` remains SMALL but creates a lightweight plan and sends it to Sol.
- A lower tier or reduced review is rejected when auth, security, payments, migrations, destructive data, concurrency, public compatibility, or comparable HIGH risk is present. The classifier prints why it promoted the route.

Example output:

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

It was kept stupid simple because **the goal is to ship features, not to master a workflow**. The workflow should disappear into the background, not become a project of its own.

## Getting Started

1. Copy the `skills/` folder contents to your repo's `.claude/skills/` or whatever
2. Run `/TRIP-init [YourProjectName]`
3. Follow the interactive prompts
4. Review and approve the generated ARCHI.md

### Additional For Mistral users (if they exist)

Also copy `AskUserQuestion/` to your agent `/skills/`, it provides the `AskUserQuestion` tool that TRIP workflow rely on.  

Et voila! Start with requests such as `/TRIP-1-plan adjust the empty-state copy` or `/TRIP-1-plan add OAuth login, maximum review`. Use `/TRIP-1-plan <task>, full trip` to force the original complete workflow.

https://github.com/user-attachments/assets/d37bbc60-1868-4fa8-9be6-083b60d6a53d

## The Heart of TRIP: ARCHI.md

The `ARCHI.md` file is the **central nervous system** of this workflow. It serves as the AI agent's **long-term memory** of your codebase.

### Why ARCHI.md Matters

**1. Persistent Context Across Sessions**

AI agents have no memory between sessions. Every new conversation starts from zero. ARCHI.md solves this by providing a comprehensive, always-up-to-date snapshot of your architecture that the agent reads at the start of each task. Unlike tool-specific files like `CLAUDE.md` or `AGENTS.md`, ARCHI.md is purely about architecture. It's tool-agnostic, so it works with any agent. You can still reference it from your `CLAUDE.md` to include it in all conversations.

**2. Token Savings & Reduced Hallucination**

Without ARCHI.md, your agent must glob, grep, and read multiple files to piece together the architecture from scratch for every single session. This wastes tokens and leads to guessing: _"There's probably a utils folder..."_, _"This project likely uses Redux..."_. ARCHI.md eliminates both problems. The agent gets the full picture in one read for minimal exploration & hallucination.

**3. Balanced Detail vs Token Usage**

ARCHI.md is designed to be:

- **Detailed enough** to provide meaningful context, **concise enough** to not waste tokens
- **Structured** for quick navigation
- **Updated** after every architectural change

It's not a dump of your entire codebase, rather a curated architectural guide. Delegated workers read it first when present, then agent guidance, the active task/plan, and only directly relevant source and tests. Any architectural change must update `ARCHI.md` in the same implementation.

## The Init Process

The `TRIP-init` skill is a **script written in human language** that programmatically bootstraps the TRIP workflow in any repository.

### What Init Does

1. **Creates the docs structure** - Folders for plans, changelogs, reviews, tests, memos
2. **Explores your codebase** - Identifies languages, frameworks, patterns, conventions
3. **Classifies your project** - Web frontend? CLI tool? Embedded firmware? Library?
4. **Generates ARCHI.md** - Tailored to your specific project type
5. **Customizes the skills** - Replaces placeholders with your project's specifics

### The Placeholder System

The generic TRIP skills contain placeholders like:

- `[PROJECT_NAME]` - Your project's name
- `[VERSION_FILE]` - Where your version is stored (package.json, Cargo.toml, etc.)
- `[ADAPT_TO_PROJECT: ...]` - Sections to customize

Init walks you through questions and replaces these placeholders based on your answers, creating a workflow tailored to your project.

## More Skills

### `/codex-implement`

Luna implementation delegated to Codex CLI in a **workspace-write sandbox**: it reads the active task or approved plan, edits the working tree, runs relevant checks, and reports back with a completion tag. Fable then reviews and fixes the diff. Persistent thread per target supports multi-phase work without broad repository rereads.

### `/codex-plan-review` & `/codex-code-review`

Iterative Sol review loops powered by Codex CLI. HIGH plans get a fresh read-only plan review; MEDIUM/HIGH code gets a separate fresh final review unless a safe override skips MEDIUM review. Threads persist only within their own convergence loop (`start -> REQUEST_CHANGES -> fix -> resume -> APPROVED`).

Explicit `CODEX_FLOW=implementation|review` selects the role; state-directory names never select a model. Defaults remain centralized in `codex-plan-review/scripts/_common.sh`:

| Execution | Model role | Effort |
| --- | --- | --- |
| SMALL implementation | Luna | `medium` |
| MEDIUM implementation | Luna | `high` |
| HIGH implementation | Luna | `high` |
| SMALL override review or MEDIUM final review | Sol | `high` |
| HIGH plan or final review | Sol | `xhigh` |

Change the centralized `*_MODEL_DEFAULT` and `*_EFFORT_DEFAULT` variables to customize these values. Fable still owns requirements, plans, verification strategy, fixes, and final judgment.

Fresh and resumed implementation use the public `codex-implement/scripts/start.sh` and `resume.sh` entry points. Both explicitly select Luna; resume continues the workspace-write sandbox established by the fresh session.

Codex's Git repository safety check is enabled by default. In a controlled non-Git environment only, set `TRIP_ALLOW_NON_GIT=1` to add `--skip-git-repo-check`; do not use this escape hatch for normal TRIP work.

### Live Codex progress

Implementation, review, and resume launchers save the complete JSONL event stream and stderr under their existing state paths while printing a concise live stream: session/turn lifecycle, commands and tests starting/completing, file changes, and errors. Raw JSON is not dumped to the terminal. Thread IDs and final report files remain available for resume/show operations. The bundled parser uses only the Python 3 standard library (no `jq` package). `set -o pipefail` propagates Codex failures, JSONL `tee` failures, and parser failures. The stderr logger uses process substitution, so its own process exit status is not part of that pipeline; stderr is still displayed and saved during normal operation.

### `/TRIP-review` & `/TRIP-test`

The former steps 3 and 4, reborn as on-demand support skills: `/TRIP-review` is the manual fallback/audit review (same checklist as the Codex loop — single source of truth), `/TRIP-test` is the deep test-authoring reference with a seam ladder and a coverage-debt ledger for hard-to-test code.

### `/TRIP-upgrade`

Upgrades an existing project's TRIP skills to a newer version without losing project customizations. Extracts your project-specific content (test commands, checklist sections, technical considerations, version file paths), applies the new workflow skeleton, and re-injects the customizations. Copy the new skills to `new-TRIP/`, run the skill, done.

### `/codex-ask`

A grounded second opinion on **anything** — architecture calls, debugging hypotheses, research conclusions. Codex answers from inside the repo (read-only), threaded per topic for multi-round discussion. Advisory only: no verdict tags, nothing gated. TRIP-research uses it to red-team decision-grade findings before presenting them.

### `/TRIP-hotfix`

Streamlined workflow for production emergencies. Bypasses full TRIP for genuine crises (or lazy debugging).

### `/TRIP-research`

Exploratory investigation with defined compute level. For feasibility studies and technology evaluation. Produces documented findings, not production code.

### `/TRIP-compact`

Run this skill to compact ARCHI.md size while preserving relevance, accuracy, and coverage through summarization and restructuring. Token calculator script included.
As a rule of thumb, ARCHI.md should not exceed ~10% of context window.

## Multi-Agent: Using Different LLMs at Different Steps

![TRIP Workflow multiLLM](assets/trip-workflow-multiLLM4.png)

Just like you wouldn't smell your own fart, an LLM is unlikely to catch bugs in its own implementation. Some people conduct adversarial review with a different session but still the same model, which is..._meh_. The best approach is to introduce a different model in the same reasoning ballpark as the first one, that will most likely catch what the other missed.

The adaptive tiers use this multi-agent approach only where it buys meaningful confidence.

Considering Claude as your main and Codex as the copilot:

Fable classifies, plans where needed, reviews and fixes the diff, and owns verification. Luna implements. Sol independently reviews HIGH plans and MEDIUM/HIGH code in separate fresh threads. Sol never implements and is skipped for trivial work.
As of mid july 2026, this Fable + GPT5.6 harness combo is absolute peak.

## MCP Servers: Less Is More

Last piece of advise before your new coding quest: Every MCP server you add is extra context, extra latency, and extra confusion. Keep it minimal. The one use case where MCP genuinely shines is **up-to-date documentation**, so your agent stops hallucinating deprecated APIs/whatever. Two servers cover it: [Context7](https://github.com/upstash/context7) for current library & framework docs, and [Exa](https://github.com/exa-labs/exa-mcp-server) for web search when the answer isn't in any doc. No bloat beyond that.

## Contributing

PRs & forks are welcome

Happy tripping ! 🍄
