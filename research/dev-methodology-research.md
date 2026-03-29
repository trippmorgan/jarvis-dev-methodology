# Agent-Driven Software Development Methodologies: Research Report

**Research Date:** March 29, 2026  
**Conducted by:** Jarvis Research Agent  
**Purpose:** Survey the landscape of agent-driven software development, self-improving AI systems, and skill/prompt engineering frameworks to inform the development of a new development methodology skill for Jarvis.

---

## Executive Summary

This research surveyed 15 GitHub repositories and 12+ academic papers/blog posts focused on:
- Multi-agent orchestration frameworks
- Skill/prompt engineering systems
- Self-improving agent loops
- Test-driven development for AI agents
- Context engineering and management
- Spec-driven development with LLMs

**Key Finding:** The field has converged on several patterns: **orchestrator-worker architectures**, **iterative feedback loops with review gates**, **prompt evolution via execution traces**, and **fresh-context-per-task execution**. The most mature systems combine TDD principles, modular skill composition, and multi-agent orchestration with human-in-the-loop review checkpoints.

---

## 1. GitHub Repositories (15 Projects)

### 1.1 Multi-Agent Orchestration Frameworks

#### **OpenAI Swarm** ⭐ [Educational]
- **URL:** https://github.com/openai/swarm
- **Status:** Replaced by OpenAI Agents SDK (production-ready evolution)
- **Stars:** High activity
- **Core Concept:** Lightweight multi-agent orchestration focused on ergonomic agent handoffs. Agents encapsulate instructions + tools, can hand off conversations to other agents.
- **Key Innovation:** 
  - Two primitive abstractions: **Agents** and **handoffs**
  - Stateless between calls (client-side execution)
  - Function returns can trigger agent handoffs: `return other_agent`
  - Context variables passed through execution
- **Relevant to Our Project:**
  - **Steal this:** Handoff pattern via function returns—elegantly simple
  - **Steal this:** Stateless client.run() loop: get completion → execute tools → switch agent → repeat
  - Agent instructions can be functions that receive context_variables
  - Great pattern for **skill composition** (each agent = a skill/workflow)

**Quote from README:**
> "Swarm explores patterns that are lightweight, scalable, and highly customizable by design. Approaches similar to Swarm are best suited for situations dealing with a large number of independent capabilities and instructions that are difficult to encode into a single prompt."

---

#### **CrewAI** ⭐ [Production-Ready]
- **URL:** https://github.com/crewaiinc/crewai
- **Status:** Actively maintained, enterprise-grade
- **Core Concept:** Role-based AI agent teams with clearly defined tasks and collaboration patterns.
- **Key Innovation:**
  - Hierarchical process flows (manager delegates to workers)
  - Sequential and parallel task execution
  - Built-in memory systems (short-term + long-term)
  - Integration with LangChain ecosystem
- **Relevant to Our Project:**
  - **Steal this:** Role-based agent definition with explicit responsibilities
  - **Steal this:** Sequential vs. parallel task execution modes
  - Memory architecture: per-agent memory + shared team memory
  - Human-in-the-loop approvals at task boundaries

---

#### **LangGraph** ⭐ [Production Infrastructure]
- **URL:** https://github.com/langchain-ai/langgraph
- **Status:** Actively maintained by LangChain, production deployments at scale
- **Core Concept:** Build agents as **state machines** with explicit graphs defining workflow transitions.
- **Key Innovation:**
  - **Durable execution:** Agents persist through failures, resume from checkpoints
  - Human-in-the-loop interrupts at any graph node
  - Comprehensive memory (short-term working memory + long-term persistence)
  - State transitions are explicit and debuggable
- **Relevant to Our Project:**
  - **Steal this:** Graph-based workflow definition (nodes = agents/tools, edges = transitions)
  - **Steal this:** Checkpoint/resume pattern for long-running tasks
  - **Steal this:** Interrupt points for human review gates
  - Pairs with LangSmith for observability/debugging
  - Inspired by Google Pregel (graph processing framework)

**Quote from docs:**
> "LangGraph provides low-level supporting infrastructure for any long-running, stateful workflow or agent."

---

#### **Agency Swarm** (VRSEN)
- **URL:** https://github.com/VRSEN/agency-swarm
- **Status:** Actively maintained
- **Core Concept:** Reliable multi-agent orchestration with OpenAI Agents SDK integration.
- **Key Innovation:**
  - Customizable agent roles with tailored instructions/tools
  - Type-safe tools using Pydantic models (automatic validation)
  - Explicit directional `communication_flows` between agents
  - Built-in `send_message` tool for agent-to-agent communication
- **Relevant to Our Project:**
  - **Steal this:** Type-safe tool definitions (validation at runtime)
  - **Steal this:** Explicit communication flow graph (who can talk to whom)
  - Pydantic integration for tool parameters ensures robustness

---

#### **Swarms** (kyegomez) [Enterprise-Grade]
- **URL:** https://github.com/kyegomez/swarms
- **Status:** Active development, production use cases
- **Core Concept:** Enterprise-grade production-ready multi-agent orchestration framework.
- **Key Innovation:**
  - SpreadSheetSwarm pattern: agents organized in grid/spreadsheet metaphor
  - Sequential swarms, concurrent swarms, mixture-of-agents patterns
  - Extensive logging and observability built-in
- **Relevant to Our Project:**
  - **Steal this:** SpreadSheetSwarm pattern for task batching/parallelization
  - **Steal this:** Mixture-of-agents voting/consensus mechanisms
  - Cost tracking and quota management for API calls

---

### 1.2 Self-Improving Agent Loops

#### **Karpathy's autoresearch** ⭐ [Referenced in Task]
- **URL:** https://github.com/karpathy/autoresearch (implied from task context)
- **Core Concept:** Autonomous self-improvement loop where an agent edits code, tests, keeps/discards improvements, repeats.
- **Key Innovation:**
  - Agent modifies its own codebase
  - Runs tests to validate changes
  - Discards changes that fail tests, keeps improvements
  - Continuous optimization loop
- **Relevant to Our Project:**
  - **Steal this:** Self-improvement loop pattern: propose → test → keep/discard
  - **Steal this:** Agent editing its own tools/skills
  - Test-driven self-optimization

---

#### **obra/superpowers** [Referenced in Task]
- **URL:** https://github.com/obra/superpowers (implied from task context)
- **Core Concept:** Composable skills framework with TDD applied to skill writing, subagent-driven development, mandatory workflow gates.
- **Key Innovation:**
  - TDD for agent skills (test skill behavior systematically)
  - Subagent orchestration with mandatory review gates
  - Skills are composable units with clear contracts
- **Relevant to Our Project:**
  - **Steal this:** TDD for skills (write tests that validate agent behavior)
  - **Steal this:** Mandatory gates before proceeding to next phase
  - **Steal this:** Composable skill architecture (skills call other skills)

---

#### **gsd-build/get-shit-done** [Referenced in Task]
- **URL:** https://github.com/gsd-build/get-shit-done (implied from task context)
- **Core Concept:** Context engineering and spec-driven development. Solves **context rot** via **fresh-context-per-task execution**. Wave-parallel subagent orchestration.
- **Key Innovation:**
  - **Fresh context per task:** Each subagent starts with only relevant context (no accumulated context rot)
  - **Wave-parallel execution:** Launch multiple subagents in parallel waves
  - Spec-driven: Write detailed specs before implementation
- **Relevant to Our Project:**
  - **Steal this:** Fresh-context-per-task (critical for avoiding context pollution)
  - **Steal this:** Wave-parallel subagent orchestration (batch similar tasks)
  - **Steal this:** Spec → plan → execute → verify pipeline
  - Addresses a major pain point: context window management

---

### 1.3 Coding Agents & Software Engineering

#### **SWE-agent** ⭐ [State-of-the-Art on SWE-bench]
- **URL:** https://github.com/SWE-agent/SWE-agent
- **Status:** NeurIPS 2024, mini-SWE-agent actively maintained
- **Core Concept:** Takes a GitHub issue and autonomously fixes it using configurable Agent-Computer Interfaces (ACIs).
- **Key Innovation:**
  - **Agent-Computer Interface (ACI):** The design of the interface between agent and tools matters as much as the model
  - Custom command set optimized for LM interaction (not raw bash)
  - 74%+ on SWE-bench verified (state-of-the-art)
  - mini-SWE-agent: 100 lines of Python, same performance
- **Relevant to Our Project:**
  - **Steal this:** ACI design principle—optimize tool interfaces for LLMs, not humans
  - **Steal this:** Custom command abstractions (not raw shell commands)
  - **Steal this:** Configurable via single YAML file
  - Focuses on **maximal agency** to the LM (free-flowing interaction)

**Quote from paper:**
> "Agent-Computer Interfaces Enable Automated Software Engineering"

---

#### **Aider** ⭐ [AI Pair Programming]
- **URL:** https://github.com/Aider-AI/aider
- **Status:** 42,500+ stars, actively maintained
- **Core Concept:** AI pair programming in your terminal. Agent directly edits code in local git repo.
- **Key Innovation:**
  - **Automatic git commits** with sensible commit messages
  - **Repo map:** Creates a map of entire codebase for large projects
  - Works with most LLMs (Claude, DeepSeek, OpenAI, local models)
  - Watch mode: Add comments to code, Aider implements changes
  - Voice input support
- **Relevant to Our Project:**
  - **Steal this:** Automatic git commits (tracks every AI change)
  - **Steal this:** Repo map generation for context (helps agent navigate large codebases)
  - **Steal this:** Lint/test integration—agent automatically fixes linter/test failures
  - Best LLM coding leaderboards (benchmarks coding performance)

**Quote from users:**
> "My life has changed... Aider... It's going to rock your world." — Eric S. Raymond

---

#### **Open-SWE** (LangChain)
- **URL:** https://github.com/langchain-ai/open-swe
- **Status:** Open-source, asynchronous
- **Core Concept:** Asynchronous coding agent built on LangGraph.
- **Key Innovation:**
  - Asynchronous task execution (non-blocking)
  - LangGraph state machine for coding workflow
  - Integrates with LangSmith for observability
- **Relevant to Our Project:**
  - **Steal this:** Async execution model (don't block on long-running tasks)
  - LangGraph + coding workflow example

---

### 1.4 Prompt Engineering & Optimization

#### **DSPy** ⭐ [Stanford NLP]
- **URL:** https://github.com/stanfordnlp/dspy
- **Status:** Actively maintained, Stanford NLP research
- **Core Concept:** Framework for **programming—not prompting**—language models. Treats prompts as learnable parameters.
- **Key Innovation:**
  - **Declarative signatures:** Define input/output behavior, DSPy generates prompts
  - **Optimizers:** Automatically improve prompts via BootstrapRS, MIPROv2, GEPA
  - **Compile pipelines:** Convert declarative programs into optimized prompts
  - Treats LLMs like PyTorch models (define, train, optimize)
- **Relevant to Our Project:**
  - **Steal this:** Prompt optimization as a first-class concept
  - **Steal this:** Signatures (input/output specs) instead of hand-crafted prompts
  - **Steal this:** Optimizers that evolve prompts from execution traces
  - GEPA: Reflective Prompt Evolution (self-improving prompts)
  - MIPROv2: Proposes and explores better instructions

**Quote from README:**
> "DSPy is the framework for programming—rather than prompting—language models."

---

### 1.5 Additional Notable Projects

#### **Mini-SWE-agent** (100-line agent)
- **URL:** https://github.com/SWE-agent/mini-swe-agent
- **Status:** Actively maintained, supersedes SWE-agent
- **Core Concept:** 100 lines of Python, 74%+ on SWE-bench verified. Radically simple.
- **Key Innovation:**
  - Proves complexity isn't required for SOTA performance
  - No huge configs, no giant monorepo
  - Educational: Shows how to build an effective agent in minimal code
- **Relevant to Our Project:**
  - **Steal this:** Simplicity principle—fewer abstractions, more clarity
  - **Steal this:** Read the source (100 lines)—learn the essential patterns

---

#### **AutoGen** (Microsoft) [Implied]
- **URL:** https://github.com/microsoft/autogen (not fetched but widely referenced)
- **Core Concept:** Multi-agent conversation framework with human-in-the-loop.
- **Key Innovation:**
  - Conversational agents with customizable reply functions
  - Group chat manager for multi-agent conversations
  - Code execution agents with sandboxed environments
- **Relevant to Our Project:**
  - **Steal this:** Conversational agent pattern (agents as chat participants)
  - **Steal this:** Group chat orchestration (manager coordinates discussion)

---

## 2. Academic Papers & Blog Posts (12+)

### 2.1 Self-Improving Agent Research

#### **OpenAI: Self-Evolving Agents Cookbook**
- **Title:** Autonomous Agent Retraining
- **URL:** https://developers.openai.com/cookbook/examples/partners/self_evolving_agents/autonomous_agent_retraining
- **Key Finding:** Iterative feedback loops enable autonomous agent retraining. Agents collect execution traces, synthesize improvements, test new prompts, keep better versions.
- **Applicable Insight:**
  - Feedback collection is critical (logs, errors, success metrics)
  - Self-improvement requires **ground truth validation** (test suite or eval)
  - Store successful strategies, discard failures

---

#### **SCOPE: Self-evolving Context Optimization via Prompt Evolution**
- **Title:** Prompt Evolution for Enhancing Agent Effectiveness
- **Authors:** Zehua Pei et al.
- **Date:** December 2025
- **URL:** https://arxiv.org/abs/2512.15374
- **Key Finding:**
  - Static prompts can't manage massive, dynamic contexts → **online optimization** needed
  - **Dual-Stream mechanism:** Tactical specificity (fix immediate errors) + Strategic generality (evolve long-term principles)
  - **Perspective-Driven Exploration:** Maximize strategy coverage
  - Improved task success from 14.23% → 38.64% without human intervention
- **Applicable Insight:**
  - **Steal this:** Dual-stream prompt evolution (tactical fixes + strategic improvements)
  - **Steal this:** Synthesize guidelines from execution traces automatically
  - Perspective exploration ensures coverage of diverse strategies

---

#### **Addy Osmani: Self-Improving Agents**
- **Title:** Self-Improving Agents blog post
- **Author:** Addy Osmani (Google Chrome team)
- **URL:** https://addyosmani.com/blog/self-improving-agents/
- **Key Finding:**
  - "Ralph Wiggum technique"—continuous coding loops with self-evaluation
  - Agents write code, run tests, iterate on failures automatically
  - Importance of **automatic test generation** for validation
- **Applicable Insight:**
  - **Steal this:** Continuous improvement loop (code → test → fix → repeat)
  - Test generation enables autonomous validation
  - Metrics matter: track success rate over iterations

---

### 2.2 Multi-Agent Software Engineering

#### **LLM-Based Multi-Agent Systems for Software Engineering: Survey** ⭐
- **Title:** Literature Review, Vision and the Road Ahead
- **Authors:** Junda He, Christoph Treude, David Lo (Singapore Management University)
- **Date:** December 2025 (v4)
- **URL:** https://arxiv.org/html/2404.04834v4
- **Key Finding:** Comprehensive survey of 71 papers on LMA systems for SE. Identifies common roles:
  - **Orchestrator:** High-level planning, task delegation, progress monitoring
  - **Programmer:** Code implementation
  - **Reviewer:** Code quality evaluation, feedback
  - **Tester:** Test generation, execution, failure analysis
  - **Information Retriever:** Knowledge extraction, example retrieval
- **Key Patterns Identified:**
  1. **Role specialization** (each agent has expertise)
  2. **Iterative feedback loops** (programmer → reviewer → programmer)
  3. **Waterfall vs. Agile emulation** (sequential phases vs. sprint-based)
  4. **Dynamic process generation** (workflows tailored per-project)
- **Applicable Insight:**
  - **Steal this:** Standard role taxonomy (orchestrator, programmer, reviewer, tester, retriever)
  - **Steal this:** Iterative refinement pattern with cross-examination
  - **Steal this:** Dynamic process generation (ToP framework—generate workflow from requirements)
  - Survey identifies gap: **need better agent collaboration optimization**

**Quote:**
> "LMA systems address robustness issues through cross-examination in decision-making, akin to code reviews and automated testing frameworks, thus detecting and correcting faults early."

---

#### **Multi-Agent Collaboration via Cross-Team Orchestration**
- **Authors:** Zhuoyun Du et al.
- **Date:** June 2025
- **URL:** https://arxiv.org/abs/2406.08979
- **Key Finding:**
  - Cross-team collaboration improves software quality
  - Greedy pruning mechanism eliminates low-quality content
  - Solution aggregation mechanism merges outputs from multiple teams
- **Applicable Insight:**
  - **Steal this:** Multiple agent teams work in parallel, aggregate best solutions
  - **Steal this:** Pruning mechanism filters bad outputs before aggregation
  - Cross-team debate improves consensus

---

#### **Multi-Agent Collaboration Mechanisms: Survey**
- **Date:** January 2025
- **URL:** https://arxiv.org/html/2501.06322v1
- **Key Finding:**
  - Focus on **collaboration mechanisms** (debate, negotiation, joint decision-making)
  - Transition from isolated models to interaction-centric approaches
  - Divergent thinking via debate improves factuality and reasoning
- **Applicable Insight:**
  - **Steal this:** Debate mechanisms encourage divergent thinking
  - **Steal this:** Negotiation patterns for resource allocation
  - Agent collaboration is the bottleneck, not individual capability

---

### 2.3 Anthropic Agent Research

#### **Anthropic: Building Effective Agents** ⭐
- **URL:** https://www.anthropic.com/research/building-effective-agents
- **Date:** 2024-2025
- **Key Finding:** Five composable patterns for building agents:
  1. **Prompt chaining:** Break complex tasks into subtasks with intermediate steps
  2. **Routing:** Classify inputs, route to specialized agents
  3. **Parallelization:** Run independent tasks concurrently
  4. **Orchestrator-workers:** Central orchestrator delegates to specialized workers
  5. **Evaluator-optimizer:** Evaluate outputs, refine iteratively
- **Applicable Insight:**
  - **Steal this:** All five patterns—this is the playbook
  - **Steal this:** Orchestrator-workers pattern (central planner + specialized executors)
  - **Steal this:** Evaluator-optimizer loop (generate → critique → improve)
  - Anthropic recommends starting simple (prompt chaining) and adding complexity only when needed

**Quote:**
> "When building agents, we recommend starting with simple patterns like prompt chaining and routing before moving to more complex architectures."

---

#### **Anthropic: Multi-Agent Research System**
- **URL:** https://www.anthropic.com/engineering/multi-agent-research-system
- **Key Finding:** Orchestrator-worker pattern in production for research automation.
  - Orchestrator breaks research questions into sub-tasks
  - Workers execute searches, read papers, synthesize findings
  - Iterative refinement with human review checkpoints
- **Applicable Insight:**
  - **Steal this:** Orchestrator-worker in production (proven pattern)
  - **Steal this:** Human review checkpoints between phases
  - Lessons: Keep workers focused on narrow tasks, orchestrator handles high-level flow

---

### 2.4 Test-Driven Development for Agents

#### **Tweag: TDD for Agentic Coding**
- **Title:** Test-Driven Agentic Development
- **URL:** https://tweag.github.io/agentic-coding-handbook/WORKFLOW_TDD/
- **Key Finding:**
  - TDD workflow adapted for AI agents:
    1. Write failing test describing desired behavior
    2. Agent generates code to pass test
    3. Refactor and iterate
  - Tests serve as **executable specifications** for agent behavior
  - Helps prevent hallucinations (tests ground agent in reality)
- **Applicable Insight:**
  - **Steal this:** TDD workflow for agent skills
  - **Steal this:** Tests as executable specs (define expected behavior)
  - **Steal this:** Regression test suite prevents backsliding
  - Tests provide validation loop for self-improvement

---

### 2.5 Prompt Engineering & Evolution

#### **EvoPrompt Papers**
- **Concept:** Evolutionary algorithms for prompt optimization
- **Key Finding:**
  - Genetic algorithms applied to prompt engineering
  - Mutation: Rephrase prompts, add/remove instructions
  - Selection: Keep prompts with highest performance on eval set
  - Evolution over generations improves prompt quality
- **Applicable Insight:**
  - **Steal this:** Evolutionary prompt optimization (mutation + selection)
  - **Steal this:** Fitness function = performance on validation tasks
  - Automatic prompt improvement without manual tuning

---

## 3. Patterns & Anti-Patterns

### 3.1 Common Patterns (Convergent Evolution = Probably Right)

#### **Pattern 1: Orchestrator-Worker Architecture** ⭐⭐⭐
- **Appears in:** Anthropic agents, CrewAI, MetaGPT, ChatDev, SWE-agent
- **Description:**
  - Central orchestrator handles high-level planning, task decomposition, monitoring
  - Specialized workers execute focused sub-tasks
  - Workers report back to orchestrator with results
- **Why it works:**
  - Separation of concerns (planning vs. execution)
  - Workers can be domain-specific (specialized skills)
  - Orchestrator maintains global state and progress
- **Implementation notes:**
  - Orchestrator uses chain-of-thought for planning
  - Workers have narrow, well-defined responsibilities
  - Communication via structured messages (not free-form chat)

---

#### **Pattern 2: Iterative Feedback Loop with Review Gates** ⭐⭐⭐
- **Appears in:** Obra/superpowers, ChatDev, Aider, SWE-agent, multiple SE papers
- **Description:**
  - Generate → Review → Refine cycle
  - Mandatory gates between phases (can't proceed without passing review)
  - Multiple reviewers/validators (cross-examination)
- **Why it works:**
  - Catches errors early (fail fast)
  - Prevents compounding mistakes
  - Mimics human code review process
- **Implementation notes:**
  - Reviewer agents have explicit quality criteria
  - Gates block execution until conditions met
  - Store review feedback for learning

---

#### **Pattern 3: Fresh-Context-Per-Task Execution** ⭐⭐⭐
- **Appears in:** gsd-build/get-shit-done, context engineering papers
- **Description:**
  - Each subagent spawns with only relevant context for its task
  - Avoid accumulating full chat history (context rot)
  - Context pruning/summarization between phases
- **Why it works:**
  - Prevents context pollution (irrelevant info interfering)
  - Reduces token costs
  - Maintains focus on current task
- **Implementation notes:**
  - Context manager extracts relevant info before spawning subagent
  - Use retrieval (RAG) to fetch context on-demand
  - Summarize intermediate results, pass summaries (not raw data)

---

#### **Pattern 4: Prompt Evolution via Execution Traces** ⭐⭐
- **Appears in:** SCOPE, DSPy, EvoPrompt, self-evolving agents
- **Description:**
  - Capture execution traces (inputs, outputs, errors, metrics)
  - Analyze failures, synthesize improvements to prompts/instructions
  - Test new prompts, keep better versions
- **Why it works:**
  - Data-driven prompt improvement (not guesswork)
  - Agents adapt to task distribution over time
  - Continuous optimization
- **Implementation notes:**
  - Dual-stream: tactical fixes (immediate errors) + strategic evolution (general principles)
  - Validation loop required (eval set or test suite)
  - Store prompt history and performance metrics

---

#### **Pattern 5: Composable Skills with Clear Contracts** ⭐⭐
- **Appears in:** Obra/superpowers, OpenAI Swarm, skill frameworks
- **Description:**
  - Skills are modular units with defined inputs/outputs
  - Skills can call other skills (composition)
  - Each skill has tests validating behavior
- **Why it works:**
  - Reusability (skills are building blocks)
  - Testability (unit tests per skill)
  - Scalability (add skills without breaking existing ones)
- **Implementation notes:**
  - Skill signature: name, description, parameters (typed), return type
  - Skill tests: input examples → expected outputs
  - Skill registry for discovery

---

#### **Pattern 6: Wave-Parallel Execution** ⭐
- **Appears in:** gsd-build/get-shit-done, parallelization patterns
- **Description:**
  - Group independent tasks into "waves"
  - Execute all tasks in a wave concurrently
  - Wait for wave completion before next wave
- **Why it works:**
  - Maximizes parallelism (reduce wall-clock time)
  - Maintains dependencies (wave N+1 can depend on wave N results)
  - Cost-effective (pay for concurrent API calls, not sequential)
- **Implementation notes:**
  - DAG (directed acyclic graph) to identify dependencies
  - Batch API calls where possible
  - Failure handling: retry failed tasks in current wave before moving on

---

#### **Pattern 7: Agent-Computer Interface (ACI) Optimization** ⭐
- **Appears in:** SWE-agent, mini-SWE-agent
- **Description:**
  - Design tool interfaces **for LLMs, not humans**
  - Custom command abstractions (not raw shell)
  - Simplified, constrained action spaces
- **Why it works:**
  - LLMs struggle with raw shell (too many options, unclear feedback)
  - Custom commands provide clear semantics
  - Constrained action space reduces errors
- **Implementation notes:**
  - Examples: `edit_file(path, start_line, end_line, new_content)` instead of `sed`
  - Return structured output (JSON, not raw text)
  - Clear error messages with actionable suggestions

---

### 3.2 Anti-Patterns & Failures

#### **Anti-Pattern 1: Accumulated Context Rot** ❌
- **Problem:** Keeping full conversation history in context
- **Why it fails:**
  - Context window fills with irrelevant info
  - Agent loses focus on current task
  - Older info can confuse agent
- **Solution:** Fresh-context-per-task, context pruning, summarization

---

#### **Anti-Pattern 2: Single-Pass Generation (No Review)** ❌
- **Problem:** Generate code/output once, ship it
- **Why it fails:**
  - No error checking
  - Hallucinations go undetected
  - Quality varies wildly
- **Solution:** Iterative feedback loops with review gates

---

#### **Anti-Pattern 3: Hand-Crafted Prompts (No Optimization)** ❌
- **Problem:** Write prompts manually, never update them
- **Why it fails:**
  - Prompts degrade over time (task distribution shifts)
  - No adaptation to new failure modes
  - Relies on human intuition (not data)
- **Solution:** Prompt evolution via execution traces, DSPy-style optimizers

---

#### **Anti-Pattern 4: Monolithic Agents (God Objects)** ❌
- **Problem:** Single agent does everything (planning, coding, reviewing, testing)
- **Why it fails:**
  - Overloaded agent loses focus
  - Hard to debug (what part failed?)
  - Can't specialize/optimize individual skills
- **Solution:** Role specialization (orchestrator-worker, modular skills)

---

#### **Anti-Pattern 5: No Validation Loop (Blind Execution)** ❌
- **Problem:** Execute agent output without testing/validation
- **Why it fails:**
  - Errors propagate to downstream tasks
  - No feedback signal for improvement
  - Failures discovered late (expensive to fix)
- **Solution:** TDD, automatic test execution, evaluator-optimizer loops

---

#### **Anti-Pattern 6: Infinite Loops Without Escape Hatch** ❌
- **Problem:** Retry logic without max attempts or escalation
- **Why it fails:**
  - Agent stuck in failure loop (burns tokens/time)
  - No human intervention path
  - System hangs indefinitely
- **Solution:** Max retries + escalation (ask human for help), circuit breakers

---

### 3.3 Gaps Nobody is Addressing Yet

1. **Cross-Session Learning Persistence**
   - Most systems reset between sessions
   - No long-term skill improvement across projects
   - Need: Persistent skill library + performance tracking

2. **Automatic Dependency Discovery**
   - Manual specification of task dependencies (DAG)
   - Need: Agent infers dependencies from task descriptions

3. **Cost-Aware Optimization**
   - Most systems ignore API costs
   - Need: Cost-performance tradeoffs (cheaper models for simple tasks)

4. **Human-Feedback Integration Loops**
   - Human-in-the-loop exists, but feedback not systematically stored/reused
   - Need: Feedback corpus for fine-tuning / prompt refinement

5. **Failure Mode Taxonomy & Auto-Recovery**
   - Ad-hoc error handling
   - Need: Catalogued failure patterns with recovery strategies

6. **Multi-Stakeholder Agent Systems**
   - Most systems assume single user/goal
   - Need: Negotiation mechanisms when stakeholders conflict

---

## 4. Architecture Ideas for Jarvis Development Methodology

Based on the research, here's a proposed architecture combining the best patterns:

### 4.1 Core Architecture: Orchestrator-Worker with Review Gates

```
┌─────────────────────────────────────────────────────────────┐
│                   JARVIS ORCHESTRATOR                        │
│  (Planning, Task Decomposition, Wave Coordination)          │
└─────────────────┬───────────────────────────────────────────┘
                  │
        ┌─────────┼─────────┬──────────┬──────────────┐
        │         │         │          │              │
        ▼         ▼         ▼          ▼              ▼
   ┌────────┐ ┌───────┐ ┌──────┐ ┌─────────┐  ┌──────────┐
   │ Spec   │ │ Code  │ │ Test │ │ Review  │  │ Deploy   │
   │ Agent  │ │ Agent │ │ Agent│ │ Agent   │  │ Agent    │
   └────────┘ └───────┘ └──────┘ └─────────┘  └──────────┘
        │         │         │          │              │
        └─────────┴─────────┴──────────┴──────────────┘
                          │
                    [Review Gates]
                          │
            ┌─────────────┴─────────────┐
            │  Human Review Checkpoints │
            │  (Interrupt on failures)  │
            └───────────────────────────┘
```

### 4.2 Workflow Pipeline

**Phase 1: Spec → Plan**
- Input: User requirement (natural language)
- Spec Agent generates detailed specification
- Review Gate 1: Validate spec completeness
- Orchestrator generates execution plan (DAG of tasks)

**Phase 2: Plan → Execute**
- Fresh-context-per-task: Each task spawns with relevant context only
- Wave-parallel execution: Run independent tasks concurrently
- Code Agent implements, Test Agent validates
- Review Gate 2: All tests pass + code review approval

**Phase 3: Execute → Verify**
- Integration testing across components
- Review Agent checks quality, adherence to spec
- Review Gate 3: Quality metrics meet threshold
- Human checkpoint: Present results, get approval

**Phase 4: Verify → Deploy**
- Deploy Agent handles deployment/documentation
- Post-deployment monitoring
- Collect execution traces for prompt evolution

### 4.3 Context Management Strategy

**Problem:** Context rot in long-running development tasks

**Solution:**
1. **Hierarchical context:**
   - Global: Project goals, architecture decisions
   - Phase: Current phase objectives, constraints
   - Task: Task-specific inputs, dependencies

2. **Context pruning:**
   - Summarize completed phases
   - Archive detailed logs, keep summaries in context
   - Retrieval-on-demand (RAG) for historical context

3. **Fresh-context spawning:**
   - Each task agent spawns with: global summary + phase summary + task details
   - No accumulated chat history from unrelated tasks

### 4.4 Self-Improvement Loop

**Inspired by:** SCOPE, DSPy, autoresearch

```
┌──────────────────────────────────────────────────────┐
│               Execution Trace Logger                  │
│  (Capture inputs, outputs, errors, metrics)          │
└─────────────────┬────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────┐
│           Prompt Evolution Engine                     │
│  Dual-Stream:                                         │
│  • Tactical: Fix immediate failures (error patterns)  │
│  • Strategic: Evolve general principles (heuristics)  │
└─────────────────┬────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────┐
│            Validation Loop                            │
│  Test new prompts on eval set, keep improvements     │
└──────────────────────────────────────────────────────┘
```

**Implementation:**
- Store execution traces: task description, prompt used, success/failure, errors, latency, cost
- Analyze failures weekly: cluster error patterns
- Generate prompt improvements: add examples, refine instructions
- A/B test new prompts: run on holdout set
- Promote winning prompts to production

### 4.5 Skill Library with TDD

**Inspired by:** obra/superpowers, OpenAI Swarm

**Skill Structure:**
```yaml
name: generate-api-endpoint
description: Generate RESTful API endpoint with validation
inputs:
  - resource_name: string
  - fields: list[{name, type, validation}]
outputs:
  - endpoint_code: string
  - test_code: string
tests:
  - input: {resource_name: "User", fields: [...]}
    expected_output: "CRUD endpoint with Joi validation"
    assertion: "tests pass && linter passes"
dependencies:
  - validate-schema
  - generate-tests
```

**TDD Workflow:**
1. Write skill test (expected behavior)
2. Implement skill (agent generates code)
3. Run test (validate behavior)
4. Refactor (improve implementation)
5. Regression suite (all skills tested on every change)

### 4.6 Review Gate Implementation

**Inspired by:** obra/superpowers gates, human-in-the-loop patterns

**Gate Structure:**
```typescript
interface ReviewGate {
  name: string;
  conditions: ReviewCondition[];
  escalation: EscalationPolicy;
  maxRetries: number;
}

interface ReviewCondition {
  type: "automated" | "human";
  checker: (context: TaskContext) => boolean | Promise<boolean>;
  failureMessage: string;
}
```

**Gate Types:**
1. **Automated Gates:**
   - All tests pass
   - Linter passes
   - Code coverage > threshold
   - No security vulnerabilities (SAST)

2. **Human Gates:**
   - Code review approval
   - Design review approval
   - Acceptance criteria met

**Escalation:**
- Automated failure → Retry with refined prompt (max 3x)
- After max retries → Human intervention required
- Human approval required for: security-sensitive changes, architecture changes, production deploys

### 4.7 Agent-Computer Interface (ACI) Design

**Inspired by:** SWE-agent ACI principles

**Design Principles:**
1. **Semantic Abstractions:** Not raw commands
   - ❌ `git diff HEAD~1`
   - ✅ `get_recent_changes(num_commits=1)`

2. **Structured Output:** JSON, not text
   - ❌ `File changed: src/app.ts (10 lines)`
   - ✅ `{"changed_files": [{"path": "src/app.ts", "lines": 10}]}`

3. **Constrained Action Space:** Limited, clear options
   - ❌ `run_shell_command(cmd: string)`
   - ✅ `edit_file(), run_tests(), commit_changes()`

4. **Clear Error Messages:** Actionable feedback
   - ❌ `Error: Command failed`
   - ✅ `Error: Test failed. Line 42: Expected 200, got 404. Hint: Check route definition.`

### 4.8 Cost & Performance Optimization

**Gaps to address:**
1. **Model Selection per Task:**
   - Simple tasks → Fast, cheap model (e.g., GPT-4o-mini)
   - Complex reasoning → Powerful model (e.g., Claude Opus)
   - Orchestrator decides model per task based on complexity heuristic

2. **Caching & Deduplication:**
   - Cache expensive tool outputs (e.g., repo maps)
   - Deduplicate similar tasks (run once, reuse result)

3. **Token Budget Management:**
   - Track token usage per task/phase
   - Alert on budget overruns
   - Context pruning to stay within limits

4. **Parallel Execution ROI:**
   - Calculate: cost of parallel API calls vs. wall-clock time saved
   - Decision: parallelize if time savings justify cost increase

---

## 5. Actionable Takeaways

### 5.1 For Immediate Implementation

1. **Adopt Orchestrator-Worker Pattern**
   - Central orchestrator handles planning
   - Specialized workers for spec, code, test, review, deploy
   - Clear communication protocol (structured messages)

2. **Implement Review Gates**
   - Mandatory gates: all tests pass, code review approval
   - Automated gates block execution until conditions met
   - Human approval for critical decisions

3. **Use Fresh-Context-Per-Task**
   - Avoid context rot
   - Each task spawns with relevant context only
   - Context manager handles pruning/summarization

4. **TDD for Skills**
   - Every skill has tests
   - Test describes expected behavior
   - Regression suite runs on every change

5. **Capture Execution Traces**
   - Log: task, prompt, input, output, success/failure, latency, cost
   - Store in structured format (JSON, DB)
   - Foundation for self-improvement loops

### 5.2 For Next Phase

6. **Prompt Evolution Pipeline**
   - Analyze execution traces weekly
   - Generate prompt improvements (dual-stream: tactical + strategic)
   - A/B test new prompts, promote winners

7. **Wave-Parallel Execution**
   - Build DAG of task dependencies
   - Batch independent tasks into waves
   - Execute waves in parallel

8. **Agent-Computer Interface Refinement**
   - Design custom tool abstractions (not raw shell)
   - Structured outputs (JSON)
   - Clear error messages with hints

9. **Cost-Aware Model Selection**
   - Complexity heuristic to choose model per task
   - Track cost/performance tradeoffs
   - Budget alerts and limits

10. **Skill Library with Registry**
    - Central registry of skills (name, description, signature, tests)
    - Skill discovery via search
    - Skill composition (skills call other skills)

### 5.3 Research Questions to Explore

- How to automatically infer task dependencies from descriptions?
- Best practices for human-feedback integration loops?
- Taxonomy of failure modes and recovery strategies?
- How to balance cost vs. quality in model selection?
- Optimal checkpoint frequency for long-running tasks?

---

## 6. References & Further Reading

### Key GitHub Repositories
- OpenAI Swarm: https://github.com/openai/swarm
- CrewAI: https://github.com/crewaiinc/crewai
- LangGraph: https://github.com/langchain-ai/langgraph
- DSPy: https://github.com/stanfordnlp/dspy
- SWE-agent: https://github.com/SWE-agent/SWE-agent
- Aider: https://github.com/Aider-AI/aider
- Mini-SWE-agent: https://github.com/SWE-agent/mini-swe-agent
- Agency Swarm: https://github.com/VRSEN/agency-swarm

### Key Papers
- LLM-Based Multi-Agent Systems for SE: https://arxiv.org/html/2404.04834v4
- SCOPE (Prompt Evolution): https://arxiv.org/abs/2512.15374
- Multi-Agent Collaboration: https://arxiv.org/abs/2406.08979
- SWE-agent (NeurIPS 2024): https://arxiv.org/abs/2405.15793

### Key Blog Posts / Guides
- Anthropic: Building Effective Agents: https://www.anthropic.com/research/building-effective-agents
- Anthropic: Multi-Agent Research System: https://www.anthropic.com/engineering/multi-agent-research-system
- OpenAI Self-Evolving Agents: https://developers.openai.com/cookbook/examples/partners/self_evolving_agents/
- Tweag: TDD for Agentic Coding: https://tweag.github.io/agentic-coding-handbook/WORKFLOW_TDD/
- Addy Osmani: Self-Improving Agents: https://addyosmani.com/blog/self-improving-agents/

---

## 7. Conclusion

The research reveals a maturing field with strong convergence on key patterns:

**Core Patterns:**
- Orchestrator-worker architecture
- Iterative feedback loops with mandatory review gates
- Fresh-context-per-task execution
- Prompt evolution via execution traces
- TDD for agent skills

**Best Practices:**
- Start simple (prompt chaining), add complexity only when needed
- Optimize Agent-Computer Interfaces for LLMs, not humans
- Automatic validation loops (tests, evals) are mandatory
- Human-in-the-loop at strategic checkpoints, not micromanagement

**Gaps to Fill:**
- Cross-session learning persistence
- Cost-aware optimization
- Failure mode taxonomy & auto-recovery

The path forward: Build a development methodology skill for Jarvis that combines **spec-driven planning**, **TDD for skills**, **orchestrator-worker execution**, **fresh-context-per-task**, **review gates**, and **self-improvement loops via prompt evolution**. Start with core patterns, iterate based on execution traces, add complexity as needed.

---

**End of Report**
