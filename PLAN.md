# Phased Build Plan

## Phase 1: Foundation (Current)
**Goal:** Core skill definition + reference documentation

- [x] Research report (15 repos, 12 papers)
- [x] SKILL.md with workflow overview
- [x] Reference docs for each phase (0-4, 6)
- [x] GitHub repo initialized
- [x] `.planning/` template generator script
- [x] Context packet builder script
- [x] Sub-agent spawn template (OpenClaw-native)

**Deliverable:** Usable as a manual process guide. Agent reads SKILL.md, follows phases.
**Gate:** Tripp reviews and approves structure.

---

## Phase 2: Automation Scripts
**Goal:** Scripts that automate the mechanical parts

- [x] `scripts/init-project.sh` — Creates `.planning/` directory with template files (SPEC.md, PLAN.md, STATE.md, TRACES.md)
- [x] `scripts/build-context.sh` — Assembles context packets for sub-agent spawning (extracts global + task context, enforces token budget)
- [x] `scripts/wave-executor.sh` — Orchestrates wave-parallel execution via `sessions_spawn` (spawn N agents, wait for completion, collect results)
- [x] `scripts/review-gate.sh` — Runs automated checks (tests pass, lint clean, type check) and reports gate status
- [x] `scripts/trace-logger.sh` — Captures execution traces (task, status, retries, tokens, time) to `.planning/TRACES.md`

**Deliverable:** Semi-automated workflow. Human triggers phases, scripts handle orchestration.
**Gate:** Scripts tested on a real project (dogfood).

---

## Phase 3: Integration Testing (Dogfood)
**Goal:** Use the methodology to build something real, capture traces

- [ ] Pick a real Jarvis project (candidate: kitchen hub dashboard rebuild, or new skill)
- [ ] Run full pipeline: spec → plan → execute → review → verify → ship
- [ ] Capture execution traces
- [ ] Document what worked, what broke, what's missing
- [ ] First round of tactical improvements from traces

**Deliverable:** Proven methodology with real-world traces.
**Gate:** Project ships successfully. Traces logged.

---

## Phase 4: Self-Improvement Loop
**Goal:** Build the Phase 6 (Improve) machinery

- [x] Eval suite with 4 representative tasks (simple-module, bug-fix, refactor, new-feature)
- [x] Trace analyzer script (clusters failure patterns, --json support)
- [x] Dual-stream evolution engine (tactical + strategic, PROPOSED-CHANGES.md output)
- [x] A/B testing harness for prompt variants (simulated runs, comparison table)
- [x] Metrics dashboard (pass rate, retries, tokens, time trends, Φ bar charts)

**Deliverable:** Self-improving methodology. Gets better with every project.
**Gate:** Demonstrate measurable improvement on eval suite after one evolution cycle.

---

## Phase 5: Advanced Features
**Goal:** Cost optimization, failure taxonomy, cross-project learning

- [ ] Cost-aware model router (task complexity → model selection)
- [ ] Failure mode catalog with auto-recovery strategies
- [ ] Cross-project skill library (skills learned from one project apply to others)
- [ ] Human feedback integration (store corrections, feed back into evolution)
- [ ] OpenClaw skill packaging (`.skill` file for distribution)

**Deliverable:** Production-grade methodology skill, distributable via ClaHub.
**Gate:** Used successfully on 3+ projects. Published to ClaHub.

---

## Timeline (Estimated)
| Phase | Duration | Depends On |
|-------|----------|------------|
| 1: Foundation | ✅ Done | — |
| 2: Automation | 1-2 sessions | Phase 1 |
| 3: Dogfood | 1 real project | Phase 2 |
| 4: Self-Improve | 2-3 sessions | Phase 3 traces |
| 5: Advanced | Ongoing | Phase 4 |
