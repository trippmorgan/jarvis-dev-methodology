# Jarvis Development Methodology

An agentic software development methodology combining orchestrator-worker architecture, TDD, review gates, fresh-context execution, and self-improvement loops.

Built from research surveying 15 open-source projects and 12 academic papers on agent-driven software engineering.

## What This Is

A skill (and set of tools) for AI coding agents that enforces a complete development workflow:

**Spec → Plan → Execute → Review → Verify → Ship → Improve**

Each phase has mandatory gates. No shortcuts.

## Key Patterns

| Pattern | Source | Implementation |
|---------|--------|----------------|
| Orchestrator-Worker | Anthropic, CrewAI | Central planner + specialized sub-agents |
| Review Gates | Superpowers (obra) | Mandatory checkpoints between phases |
| Fresh-Context-Per-Task | GSD (TÂCHES) | Sub-agents spawn with only relevant context |
| TDD for Skills | Superpowers (obra) | RED-GREEN-REFACTOR for agent behaviors |
| Wave-Parallel Execution | GSD (TÂCHES) | Dependency DAG, batch independent tasks |
| Prompt Evolution | SCOPE, DSPy | Dual-stream improvement from execution traces |
| ACI Design | SWE-agent | Tools designed for LLMs, not humans |

## Research

See `research/dev-methodology-research.md` for the full 1000-line research report.

## Status

🚧 Phase 1 — Core skill definition and reference docs.

## License

MIT
