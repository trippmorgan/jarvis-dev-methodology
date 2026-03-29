# Phase 3: Review (Two-Stage)

## Purpose
Validate that completed work matches the spec AND meets quality standards.

## Two-Stage Review

### Stage 1: Spec Compliance
**Question:** Does the output satisfy the requirements?

Checklist:
- [ ] Every acceptance criterion from SPEC.md is met
- [ ] Every task's acceptance criteria from PLAN.md is met
- [ ] Edge cases from spec are handled
- [ ] No features added that weren't in spec (YAGNI)
- [ ] Non-goals are respected (nothing out-of-scope crept in)

### Stage 2: Code Quality
**Question:** Is the code clean, maintainable, and secure?

Checklist:
- [ ] Tests exist for all new functionality
- [ ] Tests are meaningful (not just "it doesn't crash")
- [ ] No hardcoded secrets or credentials
- [ ] Error handling is present and sensible
- [ ] Functions are focused (single responsibility)
- [ ] Naming is clear and consistent
- [ ] No obvious performance issues
- [ ] No duplicated logic
- [ ] Dependencies are justified

## Issue Classification

| Severity | Definition | Action |
|----------|------------|--------|
| **Critical** | Spec violation, security flaw, data loss risk | Blocks. Must fix before proceeding. |
| **Warning** | Code smell, missing edge case, poor naming | Should fix. Generate fix plan. |
| **Note** | Style preference, minor optimization | Optional. Log for future. |

## Review Output Format

Write to `.planning/REVIEW.md`:
```markdown
# Review: [Phase/Wave]

## Stage 1: Spec Compliance
- ✅ Criterion 1: Met
- ❌ Criterion 2: Not met — [explanation]
- ✅ Criterion 3: Met

## Stage 2: Code Quality
- ⚠️ Warning: [file:line] — [issue] — [suggested fix]
- ❌ Critical: [file:line] — [issue] — [required fix]
- 📝 Note: [file:line] — [observation]

## Summary
- Critical: [N] (must fix)
- Warnings: [N] (should fix)
- Notes: [N] (optional)

## Verdict: PASS / FAIL
```

## Gate
- **Zero critical issues** → PASS → proceed to Phase 4
- **Any critical issue** → FAIL → generate fix plan → re-execute → re-review
- Fix plans are atomic tasks (same format as Phase 1 tasks)
- Max 2 review cycles before escalating to human

## Anti-Patterns
- ❌ Reviewing your own code (orchestrator reviews, not the coding agent)
- ❌ Rubber-stamp reviews (actually check the criteria)
- ❌ Blocking on style preferences (notes, not criticals)
- ❌ Reviewing without running the tests first
