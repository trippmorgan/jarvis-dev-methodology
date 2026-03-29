#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# build-context.sh — Assemble context packets for sub-agent spawning
# Extracts global context (from SPEC.md) + task context (from PLAN.md)
# Enforces ~5000 token budget (estimated via word count * 1.3)
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TOKEN_BUDGET=5000
OUTPUT_FILE=""

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") /path/to/project <task-number> [--output file]

Build a context packet for a sub-agent to execute a specific task.
Combines global context from SPEC.md with task details from PLAN.md.

${BOLD}Arguments:${NC}
  /path/to/project   Path to the target project (must have .planning/)
  task-number        Task number to extract (e.g., 1, 2, 3)

${BOLD}Options:${NC}
  --output FILE      Write context packet to FILE instead of stdout
  --help, -h         Show this help message

${BOLD}Token Budget:${NC}
  Target: ~${TOKEN_BUDGET} tokens (estimated as word_count * 1.3)
  If budget exceeded, context is trimmed with a warning.

${BOLD}Examples:${NC}
  $(basename "$0") /home/user/my-app 3
  $(basename "$0") . 1 --output /tmp/context-task1.md
EOF
}

# --- Argument parsing ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  echo -e "${RED}Error:${NC} Missing required arguments" >&2
  echo "" >&2
  usage >&2
  exit 1
fi

PROJECT_DIR="$(realpath "$1")"
TASK_NUM="$2"
shift 2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Error:${NC} Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

PLANNING_DIR="$PROJECT_DIR/.planning"

# --- Validation ---
if [[ ! -d "$PLANNING_DIR" ]]; then
  echo -e "${RED}Error:${NC} No .planning/ directory found in $PROJECT_DIR" >&2
  echo -e "  Run ${BOLD}init-project.sh${NC} first." >&2
  exit 1
fi

if [[ ! -f "$PLANNING_DIR/PLAN.md" ]]; then
  echo -e "${RED}Error:${NC} .planning/PLAN.md not found" >&2
  exit 1
fi

if [[ ! -f "$PLANNING_DIR/SPEC.md" ]]; then
  echo -e "${RED}Error:${NC} .planning/SPEC.md not found" >&2
  exit 1
fi

# --- Extract global context from PLAN.md ---
# The "Global Context" section contains the ~500 token summary
extract_global_context() {
  local in_section=0
  local result=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+Global[[:space:]]+Context ]]; then
      in_section=1
      continue
    fi
    if [[ $in_section -eq 1 && "$line" =~ ^---$ ]]; then
      break
    fi
    if [[ $in_section -eq 1 && "$line" =~ ^##[[:space:]] ]]; then
      break
    fi
    if [[ $in_section -eq 1 ]]; then
      result+="$line"$'\n'
    fi
  done < "$PLANNING_DIR/PLAN.md"

  # If no Global Context section found, fall back to SPEC.md summary
  if [[ -z "$result" || "$result" =~ ^[[:space:]]*$ ]]; then
    # Extract first meaningful section from SPEC.md (up to constraints)
    local in_spec=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^##[[:space:]]+Project[[:space:]]+Goal ]]; then
        in_spec=1
        result+="$line"$'\n'
        continue
      fi
      if [[ $in_spec -eq 1 && "$line" =~ ^##[[:space:]]+Constraints ]]; then
        result+="$line"$'\n'
        # Include constraints section too
        continue
      fi
      if [[ $in_spec -eq 1 && "$line" =~ ^##[[:space:]]+(Edge|Non-Goals|Architecture|Acceptance) ]]; then
        break
      fi
      if [[ $in_spec -eq 1 ]]; then
        result+="$line"$'\n'
      fi
    done < "$PLANNING_DIR/SPEC.md"
  fi

  echo "$result"
}

# --- Extract task context from PLAN.md ---
# Tasks follow the format: ### Task N: Title
extract_task_context() {
  local task_num="$1"
  local in_task=0
  local result=""

  while IFS= read -r line; do
    # Match "### Task N:" where N is the task number
    if [[ "$line" =~ ^###[[:space:]]+Task[[:space:]]+${task_num}:[[:space:]] ]]; then
      in_task=1
      result+="$line"$'\n'
      continue
    fi
    # Stop at the next task heading, wave heading, or document separator
    if [[ $in_task -eq 1 ]]; then
      if [[ "$line" =~ ^###[[:space:]]+Task[[:space:]] ]]; then
        break
      fi
      if [[ "$line" =~ ^##[[:space:]]+Wave ]]; then
        break
      fi
      if [[ "$line" =~ ^---$ ]]; then
        break
      fi
      result+="$line"$'\n'
    fi
  done < "$PLANNING_DIR/PLAN.md"

  echo "$result"
}

# --- Extract dependency summaries from STATE.md ---
# If the task has dependencies, pull their completion summaries
extract_dependency_context() {
  local task_num="$1"
  local deps=""

  # Find "Depends on:" line in task context
  local depends_line
  depends_line=$(extract_task_context "$task_num" | grep -i "depends on:" | head -1 || true)

  if [[ -z "$depends_line" || "$depends_line" =~ [Nn]one ]]; then
    return
  fi

  # Extract task numbers from depends line (e.g., "Task 1, Task 3" or "1, 3")
  local dep_nums
  dep_nums=$(echo "$depends_line" | grep -oE '[0-9]+' || true)

  if [[ -z "$dep_nums" ]]; then
    return
  fi

  echo "## Dependency Summaries"
  echo ""

  for dep_num in $dep_nums; do
    # Check STATE.md for completion info
    if [[ -f "$PLANNING_DIR/STATE.md" ]]; then
      local state_line
      state_line=$(grep -E "^\|[[:space:]]*[0-9]+[[:space:]]*\|[[:space:]]*${dep_num}[[:space:]]*\|" "$PLANNING_DIR/STATE.md" || true)
      if [[ -n "$state_line" ]]; then
        echo "- Task $dep_num: $state_line"
      else
        echo "- Task $dep_num: (no status recorded yet)"
      fi
    fi
  done
  echo ""
}

# --- Estimate token count ---
estimate_tokens() {
  local text="$1"
  local word_count
  word_count=$(echo "$text" | wc -w | tr -d ' ')
  # Rough estimate: 1 token ~ 0.75 words, so tokens ~ words * 1.3
  echo $(( word_count * 13 / 10 ))
}

# --- Build the context packet ---
GLOBAL_CONTEXT=$(extract_global_context)
TASK_CONTEXT=$(extract_task_context "$TASK_NUM")
DEP_CONTEXT=$(extract_dependency_context "$TASK_NUM")

# Validate task was found
if [[ -z "$TASK_CONTEXT" || "$TASK_CONTEXT" =~ ^[[:space:]]*$ ]]; then
  echo -e "${RED}Error:${NC} Task $TASK_NUM not found in PLAN.md" >&2
  exit 1
fi

# Assemble the packet
CONTEXT_PACKET="# Context Packet — Task $TASK_NUM

## Global Context
$GLOBAL_CONTEXT
## Task Details
$TASK_CONTEXT
$DEP_CONTEXT
## Instructions
You are a focused implementation agent. Your ONLY job is to complete Task $TASK_NUM using TDD.

RULES:
1. Write the test FIRST. Run it. It MUST fail.
2. Write the minimum code to pass the test.
3. Run the test. It MUST pass.
4. Refactor only if needed. Tests must stay green.
5. Commit when done.
6. Do NOT work on anything outside this task."

# --- Check token budget ---
ESTIMATED_TOKENS=$(estimate_tokens "$CONTEXT_PACKET")

if [[ $ESTIMATED_TOKENS -gt $TOKEN_BUDGET ]]; then
  echo -e "${YELLOW}Warning:${NC} Context packet is ~${ESTIMATED_TOKENS} tokens (budget: ${TOKEN_BUDGET})" >&2
  echo -e "  Consider trimming SPEC.md Global Context or task description." >&2
fi

# --- Output ---
if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$CONTEXT_PACKET" > "$OUTPUT_FILE"
  echo -e "${GREEN}Context packet written to${NC} $OUTPUT_FILE" >&2
  echo -e "  Estimated tokens: ${CYAN}~${ESTIMATED_TOKENS}${NC} / ${TOKEN_BUDGET}" >&2
else
  echo "$CONTEXT_PACKET"
fi
