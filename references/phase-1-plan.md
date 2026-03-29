# Phase 1: Plan (Decompose + DAG)

## Purpose
Break the approved spec into atomic, executable tasks with clear dependencies.

## Process

### Step 1: Task Decomposition
Break spec into tasks that are:
- **Atomic:** 2-5 minutes of agent work each
- **Testable:** Has concrete acceptance criteria
- **Self-contained:** Minimal dependencies on other tasks
- **Specific:** Exact file paths, function names, test cases

Each task must include:
```markdown
### Task [N]: [Title]
- **Files:** [exact paths to create/modify]
- **Depends on:** [task numbers, or "none"]
- **Acceptance Criteria:**
  - [ ] Test X passes
  - [ ] Function Y exists with signature Z
- **Test Requirements:**
  - Write test for [behavior] BEFORE implementation
- **Context Needed:** [what the sub-agent needs to know]
```

### Step 2: Dependency DAG
Build a directed acyclic graph of task dependencies.
- Identify which tasks can run in parallel (no shared dependencies)
- Group independent tasks into "waves"

### Step 3: Wave Grouping
```
Wave 1: [Task 1, Task 2, Task 3]  ← independent, run in parallel
Wave 2: [Task 4, Task 5]          ← depend on Wave 1 outputs
Wave 3: [Task 6]                  ← depends on Wave 2 outputs
```

### Step 4: Generate PLAN.md
Write to `.planning/PLAN.md`:
```markdown
# Implementation Plan

## Summary
[Total tasks] tasks in [N] waves
Estimated time: [X] minutes (parallel) / [Y] minutes (sequential)

## Wave 1 (parallel)
### Task 1: [Title]
...

## Wave 2 (parallel, depends on Wave 1)
### Task 4: [Title]
...
```

### Step 5: Gate — Human Approval
Present wave structure. Highlight:
- Total task count
- Parallel vs sequential time estimate
- Any risky or complex tasks
- Wait for explicit "approved"

## Principles
- **Vertical slices parallelize better** — "User feature end-to-end" > "All models, then all APIs"
- **Err toward more, smaller tasks** — easier to review, less context per agent
- **Every task writes tests first** — no exceptions
- **Context budget per task < 5000 tokens** — leave room for the actual work

## Anti-Patterns
- ❌ Tasks that take > 10 minutes
- ❌ Tasks without test requirements
- ❌ Circular dependencies
- ❌ Vague tasks ("implement the feature")
- ❌ Horizontal layers instead of vertical slices
