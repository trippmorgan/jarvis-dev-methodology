# Phase 0: Spec (Brainstorm + Requirements)

## Purpose
Extract a clear, complete specification from a rough idea before any code is written.

## Process

### Step 1: Socratic Questioning
Ask until you understand completely. Key areas:
- **Goal:** What does success look like?
- **Users:** Who uses this? How?
- **Constraints:** Tech stack, timeline, budget, compatibility
- **Edge Cases:** What happens when things go wrong?
- **Non-Goals:** What are we explicitly NOT building?

Ask 2-3 questions at a time. Don't overwhelm.

### Step 2: Requirements Extraction
Categorize into:
- **v1 (Must Have):** Ship-blocking features
- **v2 (Should Have):** Important but can wait
- **Out of Scope:** Explicitly excluded

### Step 3: Generate SPEC.md
Write to `.planning/SPEC.md`:

```markdown
# Project: [Name]

## Goal
[1-2 sentence summary]

## Requirements (v1)
- [ ] Requirement 1
- [ ] Requirement 2

## Requirements (v2 — Future)
- [ ] Future requirement 1

## Out of Scope
- Thing we're not doing

## Constraints
- Tech stack: [...]
- Must integrate with: [...]

## Edge Cases
- What if [scenario]? → [handling]

## Acceptance Criteria
- [ ] Criterion 1 (testable)
- [ ] Criterion 2 (testable)
```

### Step 4: Gate — Human Approval
Present spec in digestible chunks. Wait for explicit "approved" before proceeding.

## Anti-Patterns
- ❌ Jumping to code before spec is approved
- ❌ Asking 10 questions at once
- ❌ Vague acceptance criteria ("it should work well")
- ❌ Spec that's longer than the code will be
