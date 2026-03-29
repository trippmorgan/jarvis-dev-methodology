#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# wave-executor.sh — Orchestrate wave-parallel execution via sub-agents
# Reads PLAN.md wave structure, builds context packets, spawns agents
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") /path/to/project <wave-number> [--dry-run]

Execute all tasks in a given wave by spawning sub-agents in parallel.
Reads wave structure from .planning/PLAN.md, builds context packets,
and generates openclaw-native sessions_spawn commands.

${BOLD}Arguments:${NC}
  /path/to/project   Path to the target project (must have .planning/)
  wave-number        Wave to execute (1, 2, 3, ...)

${BOLD}Options:${NC}
  --dry-run          Show what would execute without actually spawning agents
  --help, -h         Show this help message

${BOLD}Process:${NC}
  1. Parse PLAN.md for tasks in the specified wave
  2. Build context packets for each task (via build-context.sh)
  3. Generate sub-agent spawn commands
  4. Track task status in STATE.md

${BOLD}Examples:${NC}
  $(basename "$0") /home/user/my-app 1
  $(basename "$0") . 2 --dry-run
EOF
}

# --- Argument parsing ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  echo -e "${RED}Error:${NC} Missing required arguments" >&2
  usage >&2
  exit 1
fi

PROJECT_DIR="$(realpath "$1")"
WAVE_NUM="$2"
shift 2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo -e "${RED}Error:${NC} Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

PLANNING_DIR="$PROJECT_DIR/.planning"
PLAN_FILE="$PLANNING_DIR/PLAN.md"
STATE_FILE="$PLANNING_DIR/STATE.md"

# --- Validation ---
if [[ ! -d "$PLANNING_DIR" ]]; then
  echo -e "${RED}Error:${NC} No .planning/ directory found in $PROJECT_DIR" >&2
  echo -e "  Run ${BOLD}init-project.sh${NC} first." >&2
  exit 1
fi

if [[ ! -f "$PLAN_FILE" ]]; then
  echo -e "${RED}Error:${NC} .planning/PLAN.md not found" >&2
  exit 1
fi

# --- Extract tasks for the given wave ---
# Waves are marked as: ## Wave N (...)
# Tasks within a wave: ### Task N: Title
extract_wave_tasks() {
  local wave="$1"
  local in_wave=0
  local tasks=()

  while IFS= read -r line; do
    # Match wave header: "## Wave N" (with optional parenthetical)
    if [[ "$line" =~ ^##[[:space:]]+Wave[[:space:]]+${wave}([[:space:]]|$) ]]; then
      in_wave=1
      continue
    fi
    # Stop at next wave header or end-of-section marker
    if [[ $in_wave -eq 1 ]]; then
      if [[ "$line" =~ ^##[[:space:]]+Wave[[:space:]] ]]; then
        break
      fi
      if [[ "$line" =~ ^---$ ]]; then
        break
      fi
      # Extract task numbers
      if [[ "$line" =~ ^###[[:space:]]+Task[[:space:]]+([0-9]+): ]]; then
        tasks+=("${BASH_REMATCH[1]}")
      fi
    fi
  done < "$PLAN_FILE"

  echo "${tasks[@]}"
}

# --- Update STATE.md with task status ---
update_state() {
  local task_num="$1"
  local wave_num="$2"
  local status="$3"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${YELLOW}Warning:${NC} STATE.md not found, cannot update status" >&2
    return
  fi

  local date_now
  date_now=$(date +%Y-%m-%d)

  # Check if task row already exists
  if grep -qE "^\|[[:space:]]*${wave_num}[[:space:]]*\|[[:space:]]*${task_num}[[:space:]]*\|" "$STATE_FILE" 2>/dev/null; then
    # Update existing row
    sed -i "s/|[[:space:]]*${wave_num}[[:space:]]*|[[:space:]]*${task_num}[[:space:]]*|.*$/| ${wave_num} | ${task_num} | ${status} | 0 | ${date_now} |/" "$STATE_FILE"
  else
    # Append new row after the table header
    # Find the line with "Notes |" (end of table header) and append after it
    local header_line
    header_line=$(grep -n "Notes[[:space:]]*|" "$STATE_FILE" | head -1 | cut -d: -f1 || true)
    if [[ -n "$header_line" ]]; then
      sed -i "${header_line}a\\| ${wave_num} | ${task_num} | ${status} | 0 | |" "$STATE_FILE"
    fi
  fi
}

# --- Extract task title from PLAN.md ---
get_task_title() {
  local task_num="$1"
  grep -E "^###[[:space:]]+Task[[:space:]]+${task_num}:" "$PLAN_FILE" | sed 's/^###[[:space:]]*Task[[:space:]]*[0-9]*:[[:space:]]*//' | head -1
}

# --- Main execution ---
TASKS=$(extract_wave_tasks "$WAVE_NUM")

if [[ -z "$TASKS" ]]; then
  echo -e "${RED}Error:${NC} No tasks found for Wave $WAVE_NUM in PLAN.md" >&2
  echo -e "  Check that PLAN.md has a '## Wave $WAVE_NUM' section with tasks." >&2
  exit 1
fi

TASK_ARRAY=($TASKS)
TASK_COUNT=${#TASK_ARRAY[@]}

echo -e "${BOLD}${CYAN}Wave $WAVE_NUM Execution${NC}"
echo -e "  Tasks: ${TASK_COUNT}"
echo -e "  Project: ${PROJECT_DIR}"
if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "  Mode: ${YELLOW}DRY RUN${NC}"
fi
echo ""

# --- Build context packets and spawn commands ---
for task_num in "${TASK_ARRAY[@]}"; do
  task_title=$(get_task_title "$task_num")
  echo -e "${BOLD}Task ${task_num}:${NC} ${task_title:-"(untitled)"}"

  # Build context packet
  CONTEXT_FILE="$PLANNING_DIR/.context-task-${task_num}.md"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${CYAN}[dry-run]${NC} Would build context: $SCRIPT_DIR/build-context.sh $PROJECT_DIR $task_num --output $CONTEXT_FILE"
  else
    "$SCRIPT_DIR/build-context.sh" "$PROJECT_DIR" "$task_num" --output "$CONTEXT_FILE" 2>&1 | sed 's/^/  /'
  fi

  # Generate spawn command (openclaw-native sessions_spawn format)
  SPAWN_CMD="openclaw sessions_spawn \\
  --name \"task-${task_num}-$(echo "$task_title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | head -c 30)\" \\
  --context-file \"$CONTEXT_FILE\" \\
  --working-dir \"$PROJECT_DIR\" \\
  --model sonnet"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${CYAN}[dry-run]${NC} Would spawn:"
    echo "    $SPAWN_CMD"
  else
    echo -e "  ${GREEN}Spawn command:${NC}"
    echo "    $SPAWN_CMD"

    # Update STATE.md
    update_state "$task_num" "$WAVE_NUM" "SPAWNED"
    echo -e "  ${GREEN}STATE.md updated${NC}"
  fi
  echo ""
done

# --- Summary ---
if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}${BOLD}Dry run complete.${NC} ${TASK_COUNT} tasks would be spawned for Wave ${WAVE_NUM}."
  echo -e "Run without --dry-run to execute."
else
  echo -e "${GREEN}${BOLD}Wave ${WAVE_NUM} dispatched.${NC} ${TASK_COUNT} tasks spawned."
  echo -e ""
  echo -e "Next steps:"
  echo -e "  1. Monitor sub-agent sessions for completion"
  echo -e "  2. Run ${BOLD}review-gate.sh${NC} when all tasks complete"
  echo -e "  3. Update STATE.md with final task statuses"
  echo -e "  4. Log traces with ${BOLD}trace-logger.sh${NC}"
fi
