# Phase 2: Execute (Wave-Parallel Sub-Agents)

## Purpose
Execute the plan using fresh-context sub-agents, one per task, with TDD enforced.

## Process

### Step 1: Prepare Context Packets
For each task, assemble a context packet:
```
Global Context (~500 tokens):
  - Project name and goal (from SPEC.md summary)
  - Tech stack and constraints
  - Architecture decisions

Task Context (~2000 tokens):
  - Task description and acceptance criteria
  - Test requirements
  - Relevant file contents (only what this task touches)
  - Outputs from dependency tasks (summaries, not full output)
```

**Total context per agent < 5000 tokens.** This is the budget.

### Step 2: Execute Wave N
For each task in the current wave, spawn a sub-agent with:
- The context packet (NOT the full conversation history)
- TDD instructions (below)
- The task description

Run all tasks in the wave concurrently.

### Step 3: TDD Enforcement (Per Task)
Each sub-agent follows this cycle:

```
1. READ the task and acceptance criteria
2. WRITE a failing test (RED)
3. RUN the test — confirm it fails
4. WRITE minimal code to pass (GREEN)
5. RUN the test — confirm it passes
6. REFACTOR if needed (keep tests green)
7. COMMIT with meaningful message
```

**Critical:** If the agent writes code before tests, discard and restart.

### Step 4: Wave Gate
Before proceeding to Wave N+1:
- All tasks in Wave N must complete
- All tests must pass
- Lint/type check must pass
- If any task fails after 3 retries → escalate to human

### Step 5: Summarize Wave Output
For each completed task, generate a summary:
```markdown
Task [N]: [Title]
- Status: PASS / FAIL
- Files modified: [list]
- Tests added: [count]
- Key decisions: [any architectural choices made]
```

Feed summaries (not full output) to dependent tasks in next wave.

## Sub-Agent Spawn Template

```
You are a focused implementation agent. Your ONLY job is to complete this task using TDD.

PROJECT: [name]
TECH STACK: [stack]

YOUR TASK:
[task description]

ACCEPTANCE CRITERIA:
[criteria list]

DEPENDENCIES (already completed):
[summaries from prior wave tasks]

RULES:
1. Write the test FIRST. Run it. It MUST fail.
2. Write the minimum code to pass the test.
3. Run the test. It MUST pass.
4. Refactor only if needed. Tests must stay green.
5. Commit when done.
6. Do NOT work on anything outside this task.
```

## Failure Handling

| Failure | Action |
|---------|--------|
| Test won't pass (3 attempts) | Generate diagnosis, escalate to human |
| Lint errors | Auto-fix, retry once |
| Type errors | Fix, retry once, then escalate |
| Sub-agent goes off-task | Kill, respawn with stricter prompt |
| Dependency output missing | Block wave, check prior wave status |

## Anti-Patterns
- ❌ Passing full conversation history to sub-agents
- ❌ Letting sub-agents skip tests
- ❌ Running Wave N+1 before Wave N completes
- ❌ Sub-agents working on tasks outside their assignment
- ❌ Infinite retry loops (max 3 retries per task)
