# Phase 4: Verify (Human Walkthrough)

## Purpose
Confirm the output actually works from the human's perspective.

## Process

### Step 1: Extract Testable Deliverables
From SPEC.md, pull every acceptance criterion and convert to a human-testable action:

```markdown
## Verification Checklist

1. [ ] Can you [action]? → Expected: [result]
2. [ ] When you [trigger], does [expected behavior] happen?
3. [ ] Try [edge case] — does it handle it gracefully?
```

### Step 2: Walk Through One at a Time
Present each item to the human. Wait for confirmation.
- **"Yes"** → Mark pass, continue
- **"No"** or description of what's wrong → trigger diagnosis

### Step 3: Auto-Diagnose Failures
When something doesn't work:
1. Reproduce the failure
2. Read error logs / test output
3. Identify root cause
4. Generate a fix plan (atomic task format)
5. Present diagnosis and fix plan to human

### Step 4: Re-Execute Fix Plans
If fixes are needed:
- Run `/dev:execute` with just the fix plans
- Re-verify the fixed items
- Don't re-verify items that already passed

### Step 5: Gate — Human Acceptance
All items pass → human says "accepted" → proceed to Phase 5.

## Verification Output

Write to `.planning/VERIFY.md`:
```markdown
# Verification: [Project]

## Results
1. ✅ [Deliverable 1] — Confirmed working
2. ❌ [Deliverable 2] — Failed: [description]
   - Diagnosis: [root cause]
   - Fix plan: [task reference]
3. ✅ [Deliverable 3] — Confirmed working

## Status: PASS / FAIL
## Fixes Required: [N]
```

## Anti-Patterns
- ❌ Marking things as verified without human confirmation
- ❌ Skipping edge case verification
- ❌ Re-verifying items that already passed after a fix
- ❌ Manual debugging instead of auto-diagnosis
