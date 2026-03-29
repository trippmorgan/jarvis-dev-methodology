---
name: jarvis-dev-methodology
description: Use when building, planning, or executing any software project. Activates for feature development, bug fixes, refactoring, or new project creation. Enforces spec-driven planning, TDD, review gates, fresh-context sub-agent execution, and wave-parallel orchestration. Also use when asked to plan work, create implementation tasks, review code quality, or improve development process.
---

# Jarvis Development Methodology

A complete agentic software development workflow combining the best patterns from research (Superpowers, GSD, DSPy, SWE-agent, Anthropic agent playbook, SCOPE).

## Core Philosophy

1. **Spec before code** — understand before building
2. **TDD everything** — skills, code, and process
3. **Fresh context per task** — kill context rot
4. **Mandatory review gates** — no skipping checkpoints
5. **Self-improvement** — capture traces, evolve prompts

## Workflow Overview

```
[Spec] → [Plan] → [Execute] → [Review] → [Verify] → [Ship]
  ↑                                                      │
  └──────────── [Improve] ←────────────────────────────── ┘
```

### Phase 0: Spec (Brainstorm + Requirements)
- Socratic questioning until requirements are locked
- Generate SPEC.md with goals, constraints, edge cases
- **Gate: Human approves spec before planning begins**
- See `references/phase-0-spec.md`

### Phase 1: Plan (Decompose + DAG)
- Break spec into atomic tasks (2-5 min each)
- Build dependency DAG, group into waves
- Each task has: file paths, acceptance criteria, test requirements
- Generate PLAN.md with wave structure
- **Gate: Human approves plan before execution**
- See `references/phase-1-plan.md`

### Phase 2: Execute (Wave-Parallel Sub-Agents)
- Spawn fresh-context sub-agent per task
- Each agent gets: global summary + task details only (no history)
- TDD enforced: write test → fail → implement → pass → commit
- Wave N must complete before Wave N+1 starts
- **Gate: All tests pass + automated lint/type check**
- See `references/phase-2-execute.md`

### Phase 3: Review (Two-Stage)
- **Stage 1 — Spec Compliance:** Does output match requirements?
- **Stage 2 — Code Quality:** Is it clean, maintainable, secure?
- Review agent has explicit criteria checklist
- Issues categorized: critical (blocks), warning (should fix), note (optional)
- **Gate: Zero critical issues**
- See `references/phase-3-review.md`

### Phase 4: Verify (Human Walkthrough)
- Extract testable deliverables from spec
- Walk human through each one
- Auto-diagnose failures, generate fix plans
- **Gate: Human confirms acceptance**
- See `references/phase-4-verify.md`

### Phase 5: Ship (Deploy + Document)
- Atomic git commits with meaningful messages
- Update documentation, changelog
- Deploy if applicable
- **Gate: CI passes**

### Phase 6: Improve (Self-Evolution Loop)
- Capture execution traces (what worked, what failed)
- Dual-stream analysis:
  - **Tactical:** Fix specific failure patterns
  - **Strategic:** Evolve general principles
- Test improved prompts against eval set
- Promote winners, discard losers
- See `references/phase-6-improve.md`

## Context Management

### Hierarchical Context Model
```
Global Context (always present):
  - Project goals, architecture decisions, tech stack
  - ~500 tokens max

Phase Context (per phase):
  - Current phase objectives, constraints
  - Summaries of completed phases
  - ~1000 tokens max

Task Context (per sub-agent):
  - Task description, acceptance criteria, dependencies
  - Relevant file contents (retrieved on-demand)
  - NO conversation history from other tasks
```

### Context Budget
- Sub-agent spawns with < 5000 tokens of context
- Remaining window is 100% for the task
- Completed task outputs → summarized → fed to dependent tasks

## Review Gate Protocol

Gates are mandatory. No phase proceeds without passing its gate.

| Gate | Type | Condition | Escalation |
|------|------|-----------|------------|
| Spec Approval | Human | Explicit "approved" | Block |
| Plan Approval | Human | Explicit "approved" | Block |
| Tests Pass | Auto | 100% pass rate | Retry 3x → human |
| Lint/Type | Auto | Zero errors | Retry 2x → human |
| Spec Compliance | Auto | Zero critical issues | Retry 2x → human |
| Code Quality | Auto | Zero critical issues | Fix plan → retry |
| Acceptance | Human | Explicit "accepted" | Block |
| CI | Auto | Pipeline green | Block |

## TDD for Skills

Every skill in this methodology is itself tested:

1. **RED:** Run sub-agent WITHOUT the skill, document failures
2. **GREEN:** Apply skill, verify agent now succeeds
3. **REFACTOR:** Find new failure modes, patch, re-verify

Skill tests live in `tests/` as executable scenarios.

## Model Selection (Cost-Aware)

| Task Type | Recommended Model | Rationale |
|-----------|-------------------|-----------|
| Planning/Architecture | Opus | Complex reasoning needed |
| Code Generation | Sonnet | Good balance speed/quality |
| Test Writing | Sonnet | Pattern matching |
| Code Review | Opus | Judgment required |
| Linting/Formatting | Fast/Local | Mechanical task |
| Summarization | Sonnet/Local | Not reasoning-heavy |

## Φ (Phi) Scoring — Integration Quality

Every stage produces a Φ score (0→1) measuring integration quality. See `references/phi-scoring.md` for full methodology.

| Stage | Measures | Sweet Spot |
|-------|----------|------------|
| Spec Φ | Requirement cross-references | 0.3-0.6 |
| Plan Φ | DAG edge density | 0.15-0.35 |
| Execute Φ | Interface connectivity | 0.5-0.8 |
| Review Φ | Pattern consistency | 0.7-0.9 |
| Verify Φ | Emergent behaviors confirmed | 0.6-0.9 |

**Project Φ** = weighted average (verify 30%, execute 25%, review 20%, plan 15%, spec 10%)

Log Φ scores via trace-logger: `--phi 0.65 --phi-stage execute`

## Commands

When this skill is active, these workflows are available:

- **`/dev:spec`** — Start Phase 0 (brainstorm + spec)
- **`/dev:plan`** — Start Phase 1 (decompose + DAG)
- **`/dev:execute`** — Start Phase 2 (wave-parallel execution)
- **`/dev:review`** — Start Phase 3 (two-stage review)
- **`/dev:verify`** — Start Phase 4 (human walkthrough)
- **`/dev:ship`** — Start Phase 5 (deploy + document)
- **`/dev:improve`** — Start Phase 6 (self-evolution)
- **`/dev:status`** — Show current phase, progress, blockers
- **`/dev:resume`** — Resume from last checkpoint
