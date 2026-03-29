#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# trace-logger.sh — Append execution trace entries to .planning/TRACES.md
# Captures task status, retries, duration, model, tokens for analysis
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
TASK_NUM=""
STATUS=""
RETRIES="0"
DURATION=""
MODEL=""
TOKENS=""
NOTES=""
SHOW_SUMMARY=0

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") /path/to/project --task N --status PASS|FAIL [options]

Append trace entries to .planning/TRACES.md for execution analysis.

${BOLD}Arguments:${NC}
  /path/to/project     Path to the target project (must have .planning/)

${BOLD}Required Options:${NC}
  --task N             Task number
  --status STATUS      PASS, FAIL, or FAIL->PASS

${BOLD}Optional:${NC}
  --retries N          Number of retries (default: 0)
  --duration TIME      Execution duration (e.g., 3m, 45s, 2m30s)
  --model MODEL        Model used (e.g., sonnet, opus, haiku)
  --tokens N           Token count (e.g., 12000, 12k)
  --notes TEXT         Freeform notes about the execution

${BOLD}Flags:${NC}
  --summary            Show aggregate stats from existing traces
  --help, -h           Show this help message

${BOLD}Examples:${NC}
  $(basename "$0") . --task 1 --status PASS --retries 0 --duration 3m --model sonnet --tokens 12000
  $(basename "$0") . --task 2 --status FAIL --retries 2 --duration 8m --model sonnet --tokens 34000 --notes 'Type error in template'
  $(basename "$0") . --summary
EOF
}

# --- Argument parsing ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error:${NC} Missing required argument: project path" >&2
  usage >&2
  exit 1
fi

PROJECT_DIR="$(realpath "$1")"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)     TASK_NUM="$2"; shift 2 ;;
    --status)   STATUS="$2"; shift 2 ;;
    --retries)  RETRIES="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --model)    MODEL="$2"; shift 2 ;;
    --tokens)   TOKENS="$2"; shift 2 ;;
    --notes)    NOTES="$2"; shift 2 ;;
    --summary)  SHOW_SUMMARY=1; shift ;;
    *)
      echo -e "${RED}Error:${NC} Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

PLANNING_DIR="$PROJECT_DIR/.planning"
TRACES_FILE="$PLANNING_DIR/TRACES.md"

# --- Validation ---
if [[ ! -d "$PLANNING_DIR" ]]; then
  echo -e "${RED}Error:${NC} No .planning/ directory found in $PROJECT_DIR" >&2
  echo -e "  Run ${BOLD}init-project.sh${NC} first." >&2
  exit 1
fi

if [[ ! -f "$TRACES_FILE" ]]; then
  echo -e "${RED}Error:${NC} .planning/TRACES.md not found" >&2
  exit 1
fi

# --- Summary mode ---
if [[ $SHOW_SUMMARY -eq 1 ]]; then
  echo -e "${BOLD}${CYAN}Trace Summary${NC}"
  echo ""

  # Count statuses
  total=$(grep -cE '^\|[[:space:]]*[0-9]' "$TRACES_FILE" || true)
  passes=$(grep -cE '^\|[[:space:]]*[0-9]+[[:space:]]*\|[[:space:]]*PASS' "$TRACES_FILE" || true)
  fails=$(grep -cE '^\|[[:space:]]*[0-9]+[[:space:]]*\|[[:space:]]*FAIL' "$TRACES_FILE" || true)
  fail_pass=$(grep -cE '^\|[[:space:]]*[0-9]+[[:space:]]*\|[[:space:]]*FAIL.*PASS' "$TRACES_FILE" || true)

  echo -e "  ${BOLD}Total tasks traced:${NC} $total"
  echo -e "  ${GREEN}PASS (first try):${NC}  $passes"
  echo -e "  ${YELLOW}FAIL->PASS:${NC}        $fail_pass"
  echo -e "  ${RED}FAIL:${NC}              $fails"

  if [[ $total -gt 0 ]]; then
    pass_rate=$(( (passes * 100) / total ))
    echo -e "  ${BOLD}First-pass rate:${NC}   ${pass_rate}%"
  fi

  # Sum tokens (rough — extract numbers from tokens column)
  total_tokens=$(grep -oE '^\|[[:space:]]*[0-9]+[[:space:]]*\|[^|]*\|[^|]*\|[^|]*\|[^|]*\|[[:space:]]*([0-9]+k?)' "$TRACES_FILE" | grep -oE '[0-9]+k?' | while read -r t; do
    if [[ "$t" =~ k$ ]]; then
      echo "${t%k}000"
    else
      echo "$t"
    fi
  done | awk '{s+=$1} END {print s}' || true)

  if [[ -n "$total_tokens" && "$total_tokens" != "0" ]]; then
    echo -e "  ${BOLD}Total tokens:${NC}      $total_tokens"
  fi

  # Sum retries
  total_retries=$(grep -oE '^\|[[:space:]]*[0-9]+[[:space:]]*\|[^|]*\|[[:space:]]*([0-9]+)' "$TRACES_FILE" | grep -oE '[0-9]+$' | awk '{s+=$1} END {print s}' || true)
  if [[ -n "$total_retries" ]]; then
    echo -e "  ${BOLD}Total retries:${NC}     $total_retries"
  fi

  echo ""
  exit 0
fi

# --- Log mode: validate required fields ---
if [[ -z "$TASK_NUM" ]]; then
  echo -e "${RED}Error:${NC} --task is required" >&2
  exit 1
fi

if [[ -z "$STATUS" ]]; then
  echo -e "${RED}Error:${NC} --status is required" >&2
  exit 1
fi

# Validate status value
case "$STATUS" in
  PASS|FAIL|FAIL-\>PASS|FAIL→PASS) ;;
  *)
    echo -e "${YELLOW}Warning:${NC} Non-standard status '$STATUS' (expected PASS, FAIL, or FAIL->PASS)" >&2
    ;;
esac

# --- Format and append trace row ---
# Table format: | Task | Status | Retries | Time | Model | Tokens | Notes |
ROW="| ${TASK_NUM} | ${STATUS} | ${RETRIES} | ${DURATION:-"-"} | ${MODEL:-"-"} | ${TOKENS:-"-"} | ${NOTES:-""} |"

# Find the last table row or the table header separator and append after it
# Strategy: find the Tasks table, append after the last row or header
if grep -qE '^\|[[:space:]]*Task[[:space:]]*\|' "$TRACES_FILE"; then
  # Table exists — find the right insertion point
  # Get line number of the last table row (lines starting with |)
  # within the Tasks section
  local_section=0
  last_table_line=0
  line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "$line" =~ ^###[[:space:]]+Tasks ]]; then
      local_section=1
      continue
    fi
    if [[ $local_section -eq 1 ]]; then
      if [[ "$line" =~ ^\| ]]; then
        last_table_line=$line_num
      elif [[ -n "$line" && ! "$line" =~ ^\| && ! "$line" =~ ^[[:space:]]*$ && ! "$line" =~ ^\<!-- ]]; then
        break
      fi
    fi
  done < "$TRACES_FILE"

  if [[ $last_table_line -gt 0 ]]; then
    sed -i "${last_table_line}a\\${ROW}" "$TRACES_FILE"
  else
    # Fallback: just append to file
    echo "$ROW" >> "$TRACES_FILE"
  fi
else
  # No table found — append with header
  cat >> "$TRACES_FILE" <<EOF

### Tasks
| Task | Status | Retries | Time | Model | Tokens | Notes |
|------|--------|---------|------|-------|--------|-------|
$ROW
EOF
fi

# --- Output ---
if [[ "$STATUS" == "PASS" ]]; then
  echo -e "${GREEN}Logged:${NC} Task $TASK_NUM — ${GREEN}$STATUS${NC} (retries: $RETRIES)"
else
  echo -e "${YELLOW}Logged:${NC} Task $TASK_NUM — ${RED}$STATUS${NC} (retries: $RETRIES)"
fi

if [[ -n "$NOTES" ]]; then
  echo -e "  Notes: $NOTES"
fi
