#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# evolve-prompts.sh — Dual-stream prompt evolution engine
# Reads execution traces, generates tactical patches and strategic updates
# Produces PROPOSED-CHANGES.md with prioritized improvement suggestions
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SPAWN_TEMPLATE="$SKILL_DIR/references/phase-2-execute.md"

OUTPUT_FILE=""
APPLY_FLAG=0
PROJECT_DIRS=()

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") /path/to/project [/path/to/project2 ...] [options]

Dual-stream prompt evolution engine. Reads execution traces from one or more
projects, analyzes failure patterns and aggregate metrics, and generates
proposed prompt patches and principle updates.

${BOLD}Streams:${NC}
  ${CYAN}Tactical${NC}   — Failure-driven prompt patches (specific edits)
  ${MAGENTA}Strategic${NC}  — Metrics-driven principle updates (systemic changes)

${BOLD}Arguments:${NC}
  /path/to/project     One or more project paths with .planning/TRACES.md

${BOLD}Options:${NC}
  --output FILE        Output path for proposed changes (default: ./PROPOSED-CHANGES.md)
  --apply              Print manual review instructions (does NOT auto-apply)
  --help, -h           Show this help message

${BOLD}Examples:${NC}
  $(basename "$0") /home/user/my-app
  $(basename "$0") ./project-a ./project-b --output improvements.md
  $(basename "$0") . --apply
EOF
}

# --- Argument parsing ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error:${NC} At least one project path is required." >&2
  echo "" >&2
  usage >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --apply)
      APPLY_FLAG=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo -e "${RED}Error:${NC} Unknown option: $1" >&2
      exit 1
      ;;
    *)
      PROJECT_DIRS+=("$(realpath "$1")")
      shift
      ;;
  esac
done

if [[ ${#PROJECT_DIRS[@]} -eq 0 ]]; then
  echo -e "${RED}Error:${NC} At least one project path is required." >&2
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$(pwd)/PROPOSED-CHANGES.md"
fi

DATE=$(date +%Y-%m-%d)

# =============================================================================
# Data collection — parse traces from all projects
# =============================================================================

# Aggregate counters
TOTAL_TASKS=0
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_FAIL_PASS=0
TOTAL_RETRIES=0
TOTAL_TOKENS=0
TOTAL_PROJECTS=0
PROJECT_NAMES=()

# Collected issues (newline-separated)
FAILURE_NOTES=""
RETRY_NOTES=""
ALL_TASK_ROWS=""

# Phi data
PHI_DATA=""

echo -e "${BOLD}${CYAN}Dual-Stream Prompt Evolution Engine${NC}"
echo -e "${DIM}Analyzing execution traces...${NC}"
echo ""

for project_dir in "${PROJECT_DIRS[@]}"; do
  traces_file="$project_dir/.planning/TRACES.md"

  if [[ ! -f "$traces_file" ]]; then
    echo -e "  ${YELLOW}SKIP${NC} $project_dir — no .planning/TRACES.md found"
    continue
  fi

  project_name=$(basename "$project_dir")
  PROJECT_NAMES+=("$project_name")
  TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))

  echo -e "  ${GREEN}READ${NC} $project_name"

  # Parse task rows: lines matching | <number> | ... |
  while IFS='|' read -r _ task status retries duration model tokens notes _; do
    task=$(echo "$task" | xargs 2>/dev/null || true)
    status=$(echo "$status" | xargs 2>/dev/null || true)
    retries=$(echo "$retries" | xargs 2>/dev/null || true)
    duration=$(echo "$duration" | xargs 2>/dev/null || true)
    model=$(echo "$model" | xargs 2>/dev/null || true)
    tokens=$(echo "$tokens" | xargs 2>/dev/null || true)
    notes=$(echo "$notes" | xargs 2>/dev/null || true)

    # Skip non-data rows
    [[ "$task" =~ ^[0-9]+$ ]] || continue

    TOTAL_TASKS=$((TOTAL_TASKS + 1))
    ALL_TASK_ROWS+="${project_name}|${task}|${status}|${retries}|${duration}|${model}|${tokens}|${notes}"$'\n'

    # Count statuses
    case "$status" in
      PASS)
        TOTAL_PASS=$((TOTAL_PASS + 1))
        ;;
      FAIL-\>PASS|FAIL*PASS)
        TOTAL_FAIL_PASS=$((TOTAL_FAIL_PASS + 1))
        ;;
      FAIL)
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        ;;
    esac

    # Accumulate retries
    if [[ "$retries" =~ ^[0-9]+$ ]]; then
      TOTAL_RETRIES=$((TOTAL_RETRIES + retries))
    fi

    # Accumulate tokens
    if [[ -n "$tokens" && "$tokens" != "-" ]]; then
      token_val="$tokens"
      if [[ "$token_val" =~ [kK]$ ]]; then
        token_val="${token_val%[kK]}"
        token_val=$((token_val * 1000))
      fi
      if [[ "$token_val" =~ ^[0-9]+$ ]]; then
        TOTAL_TOKENS=$((TOTAL_TOKENS + token_val))
      fi
    fi

    # Collect failure/retry notes
    if [[ "$status" != "PASS" && -n "$notes" ]]; then
      FAILURE_NOTES+="[${project_name} Task ${task}] ${notes}"$'\n'
    fi
    if [[ "$retries" =~ ^[0-9]+$ && "$retries" -gt 0 && -n "$notes" ]]; then
      RETRY_NOTES+="[${project_name} Task ${task}, ${retries} retries] ${notes}"$'\n'
    fi

  done < <(grep -E '^\|[[:space:]]*[0-9]' "$traces_file" 2>/dev/null || true)

  # Parse Phi scores
  while IFS='|' read -r _ stage score label phi_notes _; do
    stage=$(echo "$stage" | xargs 2>/dev/null || true)
    score=$(echo "$score" | xargs 2>/dev/null || true)
    label=$(echo "$label" | xargs 2>/dev/null || true)
    phi_notes=$(echo "$phi_notes" | xargs 2>/dev/null || true)

    case "$stage" in
      spec|plan|execute|review|verify)
        PHI_DATA+="${project_name}|${stage}|${score}|${label}|${phi_notes}"$'\n'
        ;;
    esac
  done < <(grep -E '^\|[[:space:]]*(spec|plan|execute|review|verify)' "$traces_file" 2>/dev/null || true)

  # Parse explicit failure sections
  if grep -qE '^### Failures' "$traces_file"; then
    in_failures=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^###[[:space:]]+Failures ]]; then
        in_failures=1
        continue
      fi
      if [[ $in_failures -eq 1 ]]; then
        if [[ "$line" =~ ^### || "$line" =~ ^## ]]; then
          break
        fi
        if [[ "$line" =~ ^- ]]; then
          FAILURE_NOTES+="[${project_name}] ${line#- }"$'\n'
        fi
      fi
    done < "$traces_file"
  fi

  # Parse review issues
  if grep -qE '^### Review Issues' "$traces_file"; then
    in_review=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^###[[:space:]]+Review ]]; then
        in_review=1
        continue
      fi
      if [[ $in_review -eq 1 ]]; then
        if [[ "$line" =~ ^### || "$line" =~ ^## ]]; then
          break
        fi
        if [[ "$line" =~ ^- ]]; then
          FAILURE_NOTES+="[${project_name} Review] ${line#- }"$'\n'
        fi
      fi
    done < "$traces_file"
  fi
done

echo ""

if [[ $TOTAL_PROJECTS -eq 0 ]]; then
  echo -e "${RED}Error:${NC} No projects with .planning/TRACES.md found." >&2
  exit 1
fi

# =============================================================================
# Compute aggregate metrics
# =============================================================================

if [[ $TOTAL_TASKS -gt 0 ]]; then
  FIRST_PASS_RATE=$(( (TOTAL_PASS * 100) / TOTAL_TASKS ))
  AVG_RETRIES=$(echo "$TOTAL_RETRIES $TOTAL_TASKS" | awk '{printf "%.2f", $1 / $2}')
  AVG_TOKENS=$(( TOTAL_TOKENS / TOTAL_TASKS ))
else
  FIRST_PASS_RATE=0
  AVG_RETRIES="0.00"
  AVG_TOKENS=0
fi

HAS_FAILURES=0
if [[ $TOTAL_FAIL -gt 0 || $TOTAL_FAIL_PASS -gt 0 || -n "$FAILURE_NOTES" ]]; then
  HAS_FAILURES=1
fi

# Display summary
echo -e "${BOLD}Aggregate Metrics${NC}"
echo -e "  Projects analyzed:     ${TOTAL_PROJECTS}"
echo -e "  Total tasks:           ${TOTAL_TASKS}"
echo -e "  First-pass rate:       ${FIRST_PASS_RATE}%"
echo -e "  Average retries/task:  ${AVG_RETRIES}"
echo -e "  Total tokens:          ${TOTAL_TOKENS}"
echo -e "  Average tokens/task:   ${AVG_TOKENS}"
echo ""

# =============================================================================
# Read current spawn template for diff references
# =============================================================================

CURRENT_RULES=""
if [[ -f "$SPAWN_TEMPLATE" ]]; then
  CURRENT_RULES=$(sed -n '/^RULES:/,/^```$/p' "$SPAWN_TEMPLATE" | head -20)
fi

# =============================================================================
# STREAM 1: Tactical — failure-driven prompt patches
# =============================================================================

echo -e "${BOLD}${CYAN}Stream 1: Tactical Analysis${NC}"

TACTICAL_PATCHES=""
TACTICAL_COUNT=0

# --- Pattern: Tests skipped or code written before tests ---
generate_tactical_patch() {
  local id="$1"
  local priority="$2"
  local title="$3"
  local trigger="$4"
  local before="$5"
  local after="$6"
  local rationale="$7"

  TACTICAL_COUNT=$((TACTICAL_COUNT + 1))
  TACTICAL_PATCHES+="
### [TACTICAL] Patch ${TACTICAL_COUNT}: ${title}

**Priority:** ${priority}
**Trigger:** ${trigger}
**Rationale:** ${rationale}

\`\`\`diff
- ${before}
+ ${after}
\`\`\`

---
"
}

if [[ $HAS_FAILURES -eq 1 ]]; then
  # Analyze failure patterns
  echo -e "  Analyzing failure patterns..."

  # Pattern: TDD violations (code before tests, skipped tests)
  tdd_violations=$(echo "$FAILURE_NOTES" | grep -ciE 'test|tdd|skip.*test|code.*before.*test|wrong.*test|assertion' || true)
  if [[ $tdd_violations -gt 0 ]]; then
    echo -e "    ${RED}FOUND${NC} TDD violations: ${tdd_violations} instance(s)"
    generate_tactical_patch \
      "tdd-checkpoint" \
      "HIGH" \
      "Add explicit TDD checkpoint to spawn template" \
      "${tdd_violations} task(s) had TDD-related failures" \
      "1. Write the test FIRST. Run it. It MUST fail." \
      "1. Write the test FIRST. Run it. It MUST fail.
+    CHECKPOINT: Paste the failing test output before proceeding.
+    If you wrote ANY implementation code before the test, STOP and restart." \
      "Agents skip TDD when not explicitly gated. Adding a checkpoint forces the agent to prove the test exists and fails before writing implementation."
  fi

  # Pattern: Type errors
  type_errors=$(echo "$FAILURE_NOTES" | grep -ciE 'type.?error|typescript|type.*mismatch|wrong.*type|type.*check' || true)
  if [[ $type_errors -gt 0 ]]; then
    echo -e "    ${RED}FOUND${NC} Type errors: ${type_errors} instance(s)"
    generate_tactical_patch \
      "type-check" \
      "HIGH" \
      "Add type-checking instruction to spawn template" \
      "${type_errors} task(s) had type-related failures" \
      "5. Commit when done." \
      "5. Run type checker (tsc --noEmit / mypy) before committing.
+ 6. Commit when done." \
      "Type errors are caught late in the cycle. Running type checks before commit catches them early and avoids retry loops."
  fi

  # Pattern: Import/dependency errors
  import_errors=$(echo "$FAILURE_NOTES" | grep -ciE 'import|module|require|depend|missing.*file|cannot.*find' || true)
  if [[ $import_errors -gt 0 ]]; then
    echo -e "    ${RED}FOUND${NC} Import/dependency errors: ${import_errors} instance(s)"
    generate_tactical_patch \
      "dependency-check" \
      "MEDIUM" \
      "Add dependency verification step" \
      "${import_errors} task(s) had import/dependency failures" \
      "DEPENDENCIES (already completed):
[summaries from prior wave tasks]" \
      "DEPENDENCIES (already completed):
+ [summaries from prior wave tasks]
+
+ VERIFY BEFORE STARTING:
+ - Check that all imported modules exist
+ - Confirm dependency task outputs match expected interfaces" \
      "Import errors indicate incomplete dependency summaries. Adding a verification step forces agents to validate their environment before coding."
  fi

  # Pattern: Missing error handling
  error_handling=$(echo "$FAILURE_NOTES" | grep -ciE 'error.?handl|missing.*catch|unhandled|no.*validation|missing.*check' || true)
  if [[ $error_handling -gt 0 ]]; then
    echo -e "    ${RED}FOUND${NC} Missing error handling: ${error_handling} instance(s)"
    generate_tactical_patch \
      "error-handling" \
      "MEDIUM" \
      "Add error handling requirement to rules" \
      "${error_handling} task(s) lacked proper error handling" \
      "6. Do NOT work on anything outside this task." \
      "6. Include error handling for all external calls and user inputs.
+ 7. Do NOT work on anything outside this task." \
      "Review gates consistently catch missing error handling. Embedding the requirement in the spawn template prevents the issue upstream."
  fi

  # Pattern: Off-task behavior
  off_task=$(echo "$FAILURE_NOTES" | grep -ciE 'off.?task|outside.*scope|unrelated|went.*off' || true)
  if [[ $off_task -gt 0 ]]; then
    echo -e "    ${RED}FOUND${NC} Off-task behavior: ${off_task} instance(s)"
    generate_tactical_patch \
      "scope-guard" \
      "LOW" \
      "Strengthen scope guard in spawn template" \
      "${off_task} task(s) exhibited off-task behavior" \
      "6. Do NOT work on anything outside this task." \
      "6. Do NOT work on anything outside this task.
+    SCOPE GUARD: If you find yourself editing files not listed in your
+    task context, STOP. You are off-task. Return to the task description." \
      "Agents occasionally drift from their assigned task. A stronger scope guard with specific instructions reduces this."
  fi

  # Collect any unmatched failure notes for generic patch
  matched_patterns=$((tdd_violations + type_errors + import_errors + error_handling + off_task))
  if [[ $matched_patterns -eq 0 && -n "$FAILURE_NOTES" ]]; then
    echo -e "    ${YELLOW}NOTE${NC} Unclassified failures detected — included in report"
    TACTICAL_PATCHES+="
### [TACTICAL] Patch: Review unclassified failures

**Priority:** MEDIUM
**Trigger:** Failures detected but no common pattern matched
**Rationale:** Manual review needed to identify root cause

**Failure notes:**
$(echo "$FAILURE_NOTES" | sed 's/^/- /')

---
"
    TACTICAL_COUNT=$((TACTICAL_COUNT + 1))
  fi

else
  # No failures — generate optimization suggestions
  echo -e "  ${GREEN}No failures detected.${NC} Generating optimization suggestions..."

  # Token optimization
  if [[ $AVG_TOKENS -gt 10000 ]]; then
    echo -e "    ${YELLOW}OPT${NC} Average tokens/task (${AVG_TOKENS}) is high — suggest context pruning"
    generate_tactical_patch \
      "token-optimize" \
      "LOW" \
      "Reduce context packet size for token efficiency" \
      "Average tokens/task is ${AVG_TOKENS} (target: <8000)" \
      "Total context per agent < 5000 tokens. This is the budget." \
      "Total context per agent < 4000 tokens. This is the budget.
+    OPTIMIZATION: Only include file contents the task directly modifies.
+    Use interface summaries (type signatures) instead of full file contents." \
      "All tasks pass but token usage is high. Tighter context budgets reduce cost and latency without impacting pass rates."
  elif [[ $AVG_TOKENS -gt 0 ]]; then
    echo -e "    ${GREEN}OK${NC}  Average tokens/task (${AVG_TOKENS}) is within acceptable range"
  fi

  # Perfect run — what went well
  if [[ $FIRST_PASS_RATE -eq 100 && $TOTAL_RETRIES -eq 0 ]]; then
    echo -e "    ${GREEN}PERFECT${NC} 100% first-pass rate with zero retries"
    TACTICAL_PATCHES+="
### [TACTICAL] Observation: Perfect execution

**Priority:** LOW
**Trigger:** 100% first-pass rate, 0 retries across ${TOTAL_TASKS} tasks
**Notes:** Current prompt template is working well. No patches needed.

Consider:
- Are tasks complex enough? If all tasks are trivial, the methodology is undertested.
- Try increasing task scope (combine related tasks) to test robustness.
- Current spawn template rules are effective — preserve them.

---
"
    TACTICAL_COUNT=$((TACTICAL_COUNT + 1))
  fi
fi

echo -e "  ${BOLD}Tactical patches generated:${NC} ${TACTICAL_COUNT}"
echo ""

# =============================================================================
# STREAM 2: Strategic — metrics-driven principle updates
# =============================================================================

echo -e "${BOLD}${MAGENTA}Stream 2: Strategic Analysis${NC}"

STRATEGIC_UPDATES=""
STRATEGIC_COUNT=0

generate_strategic_update() {
  local priority="$1"
  local title="$2"
  local metric="$3"
  local current="$4"
  local target="$5"
  local recommendation="$6"
  local rationale="$7"

  STRATEGIC_COUNT=$((STRATEGIC_COUNT + 1))
  STRATEGIC_UPDATES+="
### [STRATEGIC] Update ${STRATEGIC_COUNT}: ${title}

**Priority:** ${priority}
**Metric:** ${metric}
**Current:** ${current} | **Target:** ${target}

**Recommendation:**
${recommendation}

**Rationale:** ${rationale}

---
"
}

# --- First-pass rate analysis ---
if [[ $FIRST_PASS_RATE -lt 80 ]]; then
  echo -e "    ${RED}LOW${NC}  First-pass rate: ${FIRST_PASS_RATE}% (target: >80%)"
  generate_strategic_update \
    "HIGH" \
    "Improve task decomposition granularity" \
    "First-pass rate" \
    "${FIRST_PASS_RATE}%" \
    ">80%" \
    "Break tasks into smaller, more atomic units. Each task should:
- Touch 1-3 files maximum
- Have a single clear acceptance criterion
- Be completable in under 3 minutes
- Not require understanding of more than 2 dependency outputs" \
    "Low first-pass rates indicate tasks are too complex or ambiguous for single-context agents. Smaller tasks have higher pass rates."
elif [[ $FIRST_PASS_RATE -eq 100 ]]; then
  echo -e "    ${GREEN}HIGH${NC} First-pass rate: 100% — consider raising complexity"
  generate_strategic_update \
    "LOW" \
    "Increase task complexity threshold" \
    "First-pass rate" \
    "100%" \
    "90-95% (stretching agents)" \
    "Current tasks may be under-utilizing agent capabilities. Consider:
- Combining related tasks within the same wave
- Allowing tasks to touch more files (up to 5)
- Including refactoring tasks that require cross-file reasoning
- Adding tasks that require reading and understanding existing code" \
    "A 100% pass rate may indicate tasks are too simple. Slightly increasing complexity tests the methodology's limits while maintaining high quality."
else
  echo -e "    ${GREEN}OK${NC}   First-pass rate: ${FIRST_PASS_RATE}% (within target)"
fi

# --- Retry analysis ---
avg_retry_high=$(echo "$AVG_RETRIES" | awk '{print ($1 > 0.5) ? 1 : 0}')
if [[ $avg_retry_high -eq 1 ]]; then
  echo -e "    ${YELLOW}HIGH${NC} Average retries: ${AVG_RETRIES}/task (target: <0.5)"
  generate_strategic_update \
    "MEDIUM" \
    "Reduce retry rate through better task specs" \
    "Average retries per task" \
    "${AVG_RETRIES}" \
    "<0.5" \
    "High retry rates waste tokens and time. Improve task specifications:
- Add explicit type signatures in task descriptions
- Include example inputs/outputs for ambiguous tasks
- Specify exact file paths to create/modify
- Add negative examples (what NOT to do)" \
    "Retries indicate the task description or context was insufficient for first-attempt success."
else
  echo -e "    ${GREEN}OK${NC}   Average retries: ${AVG_RETRIES}/task (within target)"
fi

# --- Token efficiency analysis ---
if [[ $AVG_TOKENS -gt 15000 ]]; then
  echo -e "    ${RED}HIGH${NC} Average tokens: ${AVG_TOKENS}/task — investigate bloat"
  generate_strategic_update \
    "HIGH" \
    "Reduce token consumption per task" \
    "Average tokens per task" \
    "${AVG_TOKENS}" \
    "<10000" \
    "Token bloat indicates context packets are too large or agents are generating excessive output. Actions:
- Audit context packets for unnecessary file inclusions
- Use interface summaries instead of full file contents
- Set explicit output length constraints in spawn template
- Consider switching verbose tasks to a smaller/faster model" \
    "High token usage increases cost and latency. Most well-scoped tasks should complete within 10k tokens."
elif [[ $AVG_TOKENS -gt 8000 ]]; then
  echo -e "    ${YELLOW}MODERATE${NC} Average tokens: ${AVG_TOKENS}/task — room for optimization"
  generate_strategic_update \
    "LOW" \
    "Optimize context packet size" \
    "Average tokens per task" \
    "${AVG_TOKENS}" \
    "<8000" \
    "Context packets can likely be trimmed without impacting pass rates:
- Replace full file contents with relevant function signatures
- Summarize dependency outputs more aggressively
- Remove boilerplate from context (license headers, comments)" \
    "Moderate token usage that could be reduced. Not urgent but improves efficiency over time."
else
  echo -e "    ${GREEN}OK${NC}   Average tokens: ${AVG_TOKENS}/task (efficient)"
fi

# --- Phi integration analysis ---
if [[ -n "$PHI_DATA" ]]; then
  echo ""
  echo -e "  ${BOLD}Phi Integration Analysis${NC}"

  # Calculate average phi per stage across projects
  for stage in spec plan execute review verify; do
    stage_scores=$(echo "$PHI_DATA" | grep "|${stage}|" | cut -d'|' -f3 || true)
    if [[ -n "$stage_scores" ]]; then
      avg_phi=$(echo "$stage_scores" | awk '{s+=$1; n++} END {if(n>0) printf "%.2f", s/n; else print "0.00"}')
      avg_int=$(echo "$avg_phi" | awk -F. '{printf "%d", $1*100 + ($2+0)}')

      if [[ $avg_int -lt 30 ]]; then
        echo -e "    ${RED}LOW${NC}  Phi(${stage}): ${avg_phi}"
        generate_strategic_update \
          "HIGH" \
          "Improve integration at ${stage} stage" \
          "Phi(${stage})" \
          "${avg_phi}" \
          ">0.50" \
          "Low integration score at the ${stage} stage indicates components are not well connected. Review:
- Are ${stage} outputs being consumed by downstream stages?
- Is the ${stage} phase producing artifacts that reference each other?
- Consider adding cross-reference requirements to ${stage} templates" \
          "Low Phi scores indicate fragmented work products. The ${stage} stage needs stronger integration requirements."
      elif [[ $avg_int -lt 50 ]]; then
        echo -e "    ${YELLOW}MED${NC}  Phi(${stage}): ${avg_phi}"
      else
        echo -e "    ${GREEN}OK${NC}   Phi(${stage}): ${avg_phi}"
      fi
    fi
  done
fi

echo ""
echo -e "  ${BOLD}Strategic updates generated:${NC} ${STRATEGIC_COUNT}"
echo ""

# =============================================================================
# Generate PROPOSED-CHANGES.md
# =============================================================================

echo -e "${BOLD}Writing proposed changes...${NC}"

PROJECT_LIST=""
for pname in "${PROJECT_NAMES[@]}"; do
  PROJECT_LIST+="- ${pname}"$'\n'
done

cat > "$OUTPUT_FILE" <<DOCEOF
# Proposed Prompt Evolution Changes

> **Analysis date:** ${DATE}
> **Projects analyzed:** ${TOTAL_PROJECTS}
> **Engine:** evolve-prompts.sh (dual-stream)

## Projects

${PROJECT_LIST}
## Summary Statistics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Total tasks | ${TOTAL_TASKS} | - | - |
| First-pass rate | ${FIRST_PASS_RATE}% | >80% | $(if [[ $FIRST_PASS_RATE -ge 80 ]]; then echo "OK"; else echo "BELOW TARGET"; fi) |
| Average retries/task | ${AVG_RETRIES} | <0.5 | $(if [[ $avg_retry_high -eq 0 ]]; then echo "OK"; else echo "ABOVE TARGET"; fi) |
| Total tokens | ${TOTAL_TOKENS} | - | - |
| Avg tokens/task | ${AVG_TOKENS} | <10000 | $(if [[ $AVG_TOKENS -le 10000 ]]; then echo "OK"; else echo "HIGH"; fi) |
| Total retries | ${TOTAL_RETRIES} | - | - |
| Pure failures | ${TOTAL_FAIL} | 0 | $(if [[ $TOTAL_FAIL -eq 0 ]]; then echo "OK"; else echo "HAS FAILURES"; fi) |
| Recovered (FAIL->PASS) | ${TOTAL_FAIL_PASS} | - | - |

DOCEOF

# Append failure notes if any
if [[ -n "$FAILURE_NOTES" ]]; then
  cat >> "$OUTPUT_FILE" <<DOCEOF
## Observed Failure Patterns

$(echo "$FAILURE_NOTES" | sed 's/^/- /')

DOCEOF
fi

# Append Phi summary if any
if [[ -n "$PHI_DATA" ]]; then
  cat >> "$OUTPUT_FILE" <<'DOCEOF'
## Phi Integration Scores (Aggregate)

| Project | Stage | Score | Label |
|---------|-------|-------|-------|
DOCEOF

  while IFS='|' read -r proj stage score label notes; do
    if [[ -n "$stage" ]]; then
      echo "| ${proj} | ${stage} | ${score} | ${label} |" >> "$OUTPUT_FILE"
    fi
  done <<< "$PHI_DATA"

  echo "" >> "$OUTPUT_FILE"
fi

# Tactical section
cat >> "$OUTPUT_FILE" <<DOCEOF
---

## Tactical Stream: Prompt Patches

> Specific, targeted edits to prompt templates based on observed failures.
> Reference template: \`references/phase-2-execute.md\`

**Patches generated:** ${TACTICAL_COUNT}

DOCEOF

if [[ $TACTICAL_COUNT -gt 0 ]]; then
  echo "$TACTICAL_PATCHES" >> "$OUTPUT_FILE"
else
  echo "_No tactical patches needed. Current templates are performing well._" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

# Strategic section
cat >> "$OUTPUT_FILE" <<DOCEOF

---

## Strategic Stream: Principle Updates

> Systemic changes to methodology principles based on aggregate metrics.
> These affect planning guidance, task decomposition, and quality targets.

**Updates generated:** ${STRATEGIC_COUNT}

DOCEOF

if [[ $STRATEGIC_COUNT -gt 0 ]]; then
  echo "$STRATEGIC_UPDATES" >> "$OUTPUT_FILE"
else
  echo "_No strategic updates needed. Methodology metrics are within targets._" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
fi

# Next steps section
cat >> "$OUTPUT_FILE" <<DOCEOF

---

## Next Steps

1. **Review** each proposed change above
2. **Accept/reject** individual patches (edit this file to mark decisions)
3. **Apply accepted changes** to the relevant reference docs
4. **Run eval suite** to verify no regressions
5. **Commit** updated prompts with trace of what triggered the change

> Changes should be validated against the eval suite before promotion.
> See \`references/phase-6-improve.md\` for the full evolution protocol.
DOCEOF

echo -e "  ${GREEN}Written:${NC} ${OUTPUT_FILE}"
echo ""

# =============================================================================
# Apply flag handling
# =============================================================================

if [[ $APPLY_FLAG -eq 1 ]]; then
  echo -e "${BOLD}${YELLOW}--apply flag detected${NC}"
  echo ""
  echo -e "  Auto-apply is ${BOLD}disabled by design${NC}. Prompt evolution requires human review."
  echo ""
  echo -e "  ${BOLD}To apply changes:${NC}"
  echo -e "    1. Review ${OUTPUT_FILE}"
  echo -e "    2. Accept or reject each proposed change"
  echo -e "    3. Manually edit the target files:"
  echo -e "       - ${CYAN}references/phase-2-execute.md${NC} (spawn template)"
  echo -e "       - ${CYAN}SKILL.md${NC} (methodology principles)"
  echo -e "    4. Run eval suite: ${DIM}scripts/review-gate.sh /path/to/eval-project${NC}"
  echo -e "    5. If eval passes, commit with:"
  echo -e "       ${DIM}git commit -m \"evolve: apply prompt patches from [date] analysis\"${NC}"
  echo ""
fi

# =============================================================================
# Final summary
# =============================================================================

echo -e "${BOLD}${CYAN}Evolution Analysis Complete${NC}"
echo -e "  Projects:  ${TOTAL_PROJECTS}"
echo -e "  Tasks:     ${TOTAL_TASKS}"
echo -e "  Tactical:  ${TACTICAL_COUNT} patch(es)"
echo -e "  Strategic: ${STRATEGIC_COUNT} update(s)"
echo -e "  Output:    ${OUTPUT_FILE}"
