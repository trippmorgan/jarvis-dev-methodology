# Phase 6: Improve (Self-Evolution Loop)

## Purpose
Capture execution traces, analyze patterns, evolve prompts and skills.

## Inspired By
- **SCOPE paper:** Dual-stream prompt evolution (tactical + strategic)
- **DSPy:** Programmatic prompt optimization
- **Karpathy autoresearch:** Autonomous improve-test-keep/discard loop

## Process

### Step 1: Capture Execution Traces
After every project, log to `.planning/TRACES.md`:

```markdown
## Trace: [Project Name] — [Date]

### Tasks
| Task | Status | Retries | Time | Model | Tokens | Notes |
|------|--------|---------|------|-------|--------|-------|
| 1    | PASS   | 0       | 3m   | Sonnet| 12k    |       |
| 2    | FAIL→PASS | 2   | 8m   | Sonnet| 34k    | Type error in template |
| 3    | PASS   | 0       | 2m   | Sonnet| 8k     |       |

### Failures
- Task 2: Agent generated code before tests (retry 1), then wrong test assertion (retry 2)
- Root cause: Task description didn't specify expected types

### Review Issues
- 1 critical: Missing error handling on API route
- 2 warnings: Inconsistent naming

### Human Verification
- 1 fix needed: Button didn't respond on mobile (CSS issue)
```

### Step 2: Analyze Patterns (Weekly/Per-Project)
Review accumulated traces. Look for:

**Tactical patterns (immediate fixes):**
- Same error type recurring? → Add to prompt/checklist
- Agent skipping tests? → Strengthen TDD instructions
- Context too large? → Prune context template
- Specific model struggling with task type? → Adjust model selection

**Strategic patterns (general principles):**
- Are vertical slices working better than horizontal? → Update planning guidance
- Are certain task sizes optimal? → Adjust decomposition rules
- Do review gates catch real issues? → Calibrate severity thresholds

### Step 3: Dual-Stream Evolution

**Tactical Stream:**
- Input: Specific failure instances
- Output: Prompt patches (add example, clarify instruction, add constraint)
- Test: Re-run failed task with patched prompt
- Keep if: Task passes without regression

**Strategic Stream:**
- Input: Aggregated patterns across projects
- Output: Updated principles in SKILL.md or reference docs
- Test: Run eval suite (representative tasks)
- Keep if: Overall pass rate improves or stays same

### Step 4: Eval Suite
Maintain a set of representative tasks in `tests/`:
```
tests/
  eval-simple-crud/       — Basic CRUD endpoint
  eval-complex-refactor/  — Multi-file refactoring
  eval-bug-fix/           — Bug from issue description
  eval-new-feature/       — Feature from spec
```

Each eval has:
- Input (task description)
- Expected output (tests that must pass)
- Baseline score (current pass rate)

### Step 5: Promote or Discard
- Run eval suite with current prompts → baseline score
- Run eval suite with evolved prompts → new score
- If new ≥ baseline → promote (update SKILL.md/references)
- If new < baseline → discard, analyze why

## Metrics to Track

| Metric | Target | Source |
|--------|--------|--------|
| Task pass rate (first attempt) | > 80% | Traces |
| Average retries per task | < 0.5 | Traces |
| Review critical issues | < 1 per project | Review output |
| Human verification fixes | < 2 per project | Verify output |
| Total tokens per task | Decreasing trend | Traces |
| Wall-clock time per project | Decreasing trend | Traces |

## Anti-Patterns
- ❌ Evolving prompts without testing against eval suite
- ❌ Keeping changes that regress other tasks
- ❌ Tactical fixes only (need strategic evolution too)
- ❌ Never reviewing traces (the data is useless if unread)
- ❌ Over-fitting to recent failures (maintain eval diversity)
