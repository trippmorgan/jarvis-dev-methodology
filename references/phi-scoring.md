# Φ (Phi) Scoring — Integration Quality Metric

## Theory

Inspired by Integrated Information Theory (Tononi), Φ measures how much a system's whole exceeds the sum of its parts. Applied to software development, it quantifies **integration quality** at each stage — are we building a coherent system or a pile of independent pieces?

## Why Φ Matters for Development

Traditional metrics (tests pass, lint clean) measure **correctness** but not **coherence**. A project can pass all tests while being a collection of isolated modules that don't form a unified system. Φ catches this gap.

## Φ Per Stage

### Stage 0 — Spec Φ (Requirement Integration)

**Question:** Do requirements form an interconnected web or an isolated wish list?

**Measurement:**
```
spec_Φ = cross_references / max_possible_references

Where:
  cross_references = count of requirements that explicitly reference other requirements
  max_possible = n * (n-1) / 2  (all pairs)
```

**How to calculate:**
1. List all requirements from SPEC.md
2. For each pair, check: does one mention, depend on, or constrain the other?
3. Count bidirectional links
4. Normalize

**Interpretation:**
- Φ < 0.1 → **Fragmented** — requirements are a shopping list, not a design
- Φ 0.1-0.3 → **Loosely connected** — some integration, acceptable for early specs
- Φ 0.3-0.6 → **Well integrated** — requirements form a coherent vision
- Φ > 0.6 → **Entangled** — may be over-specified, hard to decompose

**Example:**
```
Requirements: [grid display, cell aging, color function, keyboard controls, mouse toggle]
Cross-refs: grid↔aging, grid↔color, aging↔color, mouse↔grid = 4
Max possible: 5*4/2 = 10
Spec Φ = 4/10 = 0.40 (Well integrated)
```

---

### Stage 1 — Plan Φ (Task Coupling / DAG Density)

**Question:** Is the task graph appropriately connected?

**Measurement:**
```
plan_Φ = actual_dependency_edges / max_possible_edges

Where:
  actual_edges = dependency links in the DAG
  max_possible = n * (n-1) / 2  (complete graph, minus cycles)
```

**Sweet spot:** Plan Φ should be moderate (0.15-0.35). Too low = isolated silos. Too high = nothing parallelizes.

**Interpretation:**
- Φ < 0.1 → **Too decomposed** — tasks don't relate, may produce fragmented output
- Φ 0.1-0.2 → **Loosely coupled** — good for parallelism
- Φ 0.2-0.4 → **Balanced** — healthy mix of independence and integration
- Φ > 0.4 → **Over-coupled** — sequential bottleneck, consider re-decomposing

**Bonus metric — Wave Efficiency:**
```
wave_efficiency = sequential_time / parallel_time
               = total_tasks / num_waves
```
Higher = better parallelism.

---

### Stage 2 — Execute Φ (Code Integration)

**Question:** Do the implemented components actually connect?

**Measurement:**
```
execute_Φ = connected_interfaces / total_interfaces

Where:
  connected_interfaces = functions/classes that import from or are imported by other task outputs
  total_interfaces = all public functions/classes across all task outputs
```

**How to calculate:**
1. After wave execution, scan all modified files
2. Build import graph (who imports what)
3. Count public interfaces (exported functions, classes)
4. Count connected interfaces (used by ≥1 other module)
5. Normalize

**Interpretation:**
- Φ < 0.2 → **Isolated** — components don't talk, integration work needed
- Φ 0.2-0.5 → **Partially integrated** — some connection, may need integration tasks
- Φ 0.5-0.8 → **Well integrated** — components form a working system
- Φ > 0.8 → **Tightly coupled** — watch for brittleness

**For single-file projects** (like Conway), measure function call graph density instead:
```
execute_Φ = actual_function_calls / possible_function_calls
```

---

### Stage 3 — Review Φ (Holistic Coherence)

**Question:** Does the codebase feel like one person wrote it?

**Measurement:**
```
review_Φ = consistent_patterns / total_patterns_checked

Patterns to check:
  - Naming convention consistency (camelCase vs snake_case)
  - Error handling pattern consistency
  - Comment/docstring style consistency
  - Import organization consistency
  - Return type consistency (always return X vs mixed)
```

**How to calculate:**
1. Sample 10-15 pattern checks across the codebase
2. For each, is it consistent across all files/functions?
3. Count consistent / total

**Interpretation:**
- Φ < 0.4 → **Incoherent** — feels like 5 different people wrote it
- Φ 0.4-0.7 → **Mostly coherent** — some inconsistencies
- Φ 0.7-0.9 → **Cohesive** — reads as a unified codebase
- Φ > 0.9 → **Pristine** — single-voice quality

---

### Stage 4 — Verify Φ (Emergent Behavior)

**Question:** Does the whole system exhibit behaviors no individual part has?

**Measurement:**
```
verify_Φ = emergent_behaviors_confirmed / emergent_behaviors_expected

Where:
  emergent = behaviors that require ≥2 components working together
  Expected emergent behaviors come from SPEC.md acceptance criteria that span multiple requirements
```

**Example for Conway:**
- Cell aging alone: just a counter
- Color function alone: just a palette
- Grid alone: just rectangles
- **Together:** Living patterns that evolve, change color, and respond to input = emergent
- Verify Φ = how many of these cross-cutting behaviors actually work

**Interpretation:**
- Φ < 0.3 → **Parts without whole** — components exist but don't produce emergent behavior
- Φ 0.3-0.6 → **Partial emergence** — some cross-cutting behavior works
- Φ 0.6-0.9 → **Emergent** — system exhibits expected integrated behaviors
- Φ > 0.9 → **Fully realized** — all expected emergent behaviors confirmed

---

## Aggregate Project Φ

```
project_Φ = weighted_average(spec_Φ, plan_Φ, execute_Φ, review_Φ, verify_Φ)

Weights:
  spec_Φ:    0.10  (foundation, but early)
  plan_Φ:    0.15  (structure matters)
  execute_Φ: 0.25  (integration is the core measure)
  review_Φ:  0.20  (coherence is quality)
  verify_Φ:  0.30  (emergence is the ultimate test)
```

**Project Φ interpretation:**
- < 0.3 → **Fragmented build** — parts work individually but don't cohere
- 0.3-0.5 → **Functional build** — works but feels assembled, not designed
- 0.5-0.7 → **Integrated build** — cohesive system with emergent behavior
- 0.7+ → **Unified build** — the whole genuinely exceeds the sum of its parts

---

## Recording Φ

Log Φ scores in TRACES.md alongside other metrics:

```markdown
## Φ Scores
| Stage | Φ Score | Label | Notes |
|-------|---------|-------|-------|
| Spec | 0.40 | Well integrated | 4/10 cross-refs |
| Plan | 0.25 | Balanced | 3 waves, good parallelism |
| Execute | 0.65 | Well integrated | 8/12 interfaces connected |
| Review | 0.80 | Cohesive | Consistent naming, error handling |
| Verify | 0.75 | Emergent | 3/4 cross-cutting behaviors confirmed |
| **Project** | **0.62** | **Integrated build** | |
```

## Meta-Connection

Conway's Game of Life is the canonical example of emergence from simple rules — making it the ideal first project to test Φ scoring. The simulation itself demonstrates that local cell interactions produce global patterns (gliders, oscillators, spaceships) that no individual cell "contains." Our Φ metric measures whether our *development process* achieves the same: do simple, focused tasks produce a system greater than their sum?
