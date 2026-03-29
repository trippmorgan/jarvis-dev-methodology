# Proposed Prompt Evolution Changes

> **Analysis date:** 2026-03-29
> **Projects analyzed:** 1
> **Engine:** evolve-prompts.sh (dual-stream)

## Projects

- conway-dogfood

## Summary Statistics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Total tasks | 5 | - | - |
| First-pass rate | 100% | >80% | OK |
| Average retries/task | 0.00 | <0.5 | OK |
| Total tokens | 35800 | - | - |
| Avg tokens/task | 7160 | <10000 | OK |
| Total retries | 0 | - | - |
| Pure failures | 0 | 0 | OK |
| Recovered (FAIL->PASS) | 0 | - | - |

## Phi Integration Scores (Aggregate)

| Project | Stage | Score | Label |
|---------|-------|-------|-------|
| conway-dogfood | spec | 0.35 | Loosely connected |
| conway-dogfood | plan | 0.54 | Over-coupled |
| conway-dogfood | execute | 0.70 | Well integrated |
| conway-dogfood | review | 0.85 | Cohesive |
| conway-dogfood | verify | 0.85 | Emergent |

---

## Tactical Stream: Prompt Patches

> Specific, targeted edits to prompt templates based on observed failures.
> Reference template: `references/phase-2-execute.md`

**Patches generated:** 1


### [TACTICAL] Observation: Perfect execution

**Priority:** LOW
**Trigger:** 100% first-pass rate, 0 retries across 5 tasks
**Notes:** Current prompt template is working well. No patches needed.

Consider:
- Are tasks complex enough? If all tasks are trivial, the methodology is undertested.
- Try increasing task scope (combine related tasks) to test robustness.
- Current spawn template rules are effective — preserve them.

---


---

## Strategic Stream: Principle Updates

> Systemic changes to methodology principles based on aggregate metrics.
> These affect planning guidance, task decomposition, and quality targets.

**Updates generated:** 1


### [STRATEGIC] Update 1: Increase task complexity threshold

**Priority:** LOW
**Metric:** First-pass rate
**Current:** 100% | **Target:** 90-95% (stretching agents)

**Recommendation:**
Current tasks may be under-utilizing agent capabilities. Consider:
- Combining related tasks within the same wave
- Allowing tasks to touch more files (up to 5)
- Including refactoring tasks that require cross-file reasoning
- Adding tasks that require reading and understanding existing code

**Rationale:** A 100% pass rate may indicate tasks are too simple. Slightly increasing complexity tests the methodology's limits while maintaining high quality.

---


---

## Next Steps

1. **Review** each proposed change above
2. **Accept/reject** individual patches (edit this file to mark decisions)
3. **Apply accepted changes** to the relevant reference docs
4. **Run eval suite** to verify no regressions
5. **Commit** updated prompts with trace of what triggered the change

> Changes should be validated against the eval suite before promotion.
> See `references/phase-6-improve.md` for the full evolution protocol.
