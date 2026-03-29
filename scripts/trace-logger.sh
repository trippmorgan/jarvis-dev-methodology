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
PHI_SCORE=""
PHI_STAGE=""
PHI_LABEL=""
PHI_NOTES=""

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

${BOLD}Φ Scoring:${NC}
  --phi SCORE          Φ score (0.00-1.00) for a development stage
  --phi-stage STAGE    Stage: spec, plan, execute, review, verify
  --phi-notes TEXT     Notes about the Φ measurement

${BOLD}Flags:${NC}
  --summary            Show aggregate stats from existing traces
  --help, -h           Show this help message

${BOLD}Examples:${NC}
  $(basename "$0") . --task 1 --status PASS --retries 0 --duration 3m --model sonnet --tokens 12000
  $(basename "$0") . --task 2 --status FAIL --retries 2 --duration 8m --model sonnet --tokens 34000 --notes 'Type error in template'
  $(basename "$0") . --phi 0.40 --phi-stage spec --phi-notes '4/10 cross-refs'
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
    --phi)      PHI_SCORE="$2"; shift 2 ;;
    --phi-stage) PHI_STAGE="$2"; shift 2 ;;
    --phi-notes) PHI_NOTES="$2"; shift 2 ;;
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

  # Φ Scores
  if grep -qE '^\|[[:space:]]*(spec|plan|execute|review|verify)' "$TRACES_FILE"; then
    echo ""
    echo -e "${BOLD}${CYAN}Φ Integration Scores${NC}"
    
    # Parse phi table rows
    declare -A phi_scores=()
    declare -A phi_labels=()
    while IFS='|' read -r _ stage score label _; do
      stage=$(echo "$stage" | xargs)
      score=$(echo "$score" | xargs)
      label=$(echo "$label" | xargs)
      if [[ -n "$stage" && -n "$score" ]]; then
        phi_scores[$stage]="$score"
        phi_labels[$stage]="$label"
      fi
    done < <(grep -E '^\|[[:space:]]*(spec|plan|execute|review|verify)' "$TRACES_FILE" || true)

    for stage in spec plan execute review verify; do
      if [[ -n "${phi_scores[$stage]:-}" ]]; then
        score="${phi_scores[$stage]}"
        label="${phi_labels[$stage]:-}"
        # Color based on score
        score_num=$(echo "$score" | awk -F. '{printf "%d", $1*100 + ($2+0)}')
        if [[ $score_num -ge 60 ]]; then
          color="$GREEN"
        elif [[ $score_num -ge 30 ]]; then
          color="$YELLOW"
        else
          color="$RED"
        fi
        printf "  %-8s ${color}%s${NC}  %s\n" "$stage" "$score" "$label"
      fi
    done

    # Calculate project Φ (weighted average)
    if [[ ${#phi_scores[@]} -gt 0 ]]; then
      # Weights: spec=10, plan=15, execute=25, review=20, verify=30
      declare -A weights=([spec]=10 [plan]=15 [execute]=25 [review]=20 [verify]=30)
      weighted_sum=0
      weight_total=0
      for stage in "${!phi_scores[@]}"; do
        w="${weights[$stage]:-0}"
        s="${phi_scores[$stage]}"
        # Multiply score * weight * 100 for integer math
        ws=$(echo "$s $w" | awk '{printf "%d", $1 * $2 * 100}')
        weighted_sum=$((weighted_sum + ws))
        weight_total=$((weight_total + w))
      done
      if [[ $weight_total -gt 0 ]]; then
        project_phi=$(echo "$weighted_sum $weight_total" | awk '{printf "%.2f", $1 / ($2 * 100)}')
        # Label
        phi_int=$(echo "$project_phi" | awk -F. '{printf "%d", $1*100 + ($2+0)}')
        if [[ $phi_int -ge 70 ]]; then
          plabel="Unified build"
          pcolor="$GREEN"
        elif [[ $phi_int -ge 50 ]]; then
          plabel="Integrated build"
          pcolor="$GREEN"
        elif [[ $phi_int -ge 30 ]]; then
          plabel="Functional build"
          pcolor="$YELLOW"
        else
          plabel="Fragmented build"
          pcolor="$RED"
        fi
        echo ""
        echo -e "  ${BOLD}Project Φ: ${pcolor}${project_phi}${NC} — ${pcolor}${plabel}${NC}"
      fi
    fi
  fi

  echo ""
  exit 0
fi

# --- Φ logging mode ---
if [[ -n "$PHI_SCORE" ]]; then
  if [[ -z "$PHI_STAGE" ]]; then
    echo -e "${RED}Error:${NC} --phi-stage is required with --phi" >&2
    exit 1
  fi

  # Validate stage
  case "$PHI_STAGE" in
    spec|plan|execute|review|verify) ;;
    *)
      echo -e "${RED}Error:${NC} Invalid phi stage '$PHI_STAGE' (expected: spec, plan, execute, review, verify)" >&2
      exit 1
      ;;
  esac

  # Generate label from score
  score_int=$(echo "$PHI_SCORE" | tr -d '.')
  if [[ ${#score_int} -eq 1 ]]; then score_int="${score_int}0"; fi
  
  case "$PHI_STAGE" in
    spec)
      if [[ $score_int -ge 60 ]]; then PHI_LABEL="Entangled"
      elif [[ $score_int -ge 30 ]]; then PHI_LABEL="Well integrated"
      elif [[ $score_int -ge 10 ]]; then PHI_LABEL="Loosely connected"
      else PHI_LABEL="Fragmented"; fi
      ;;
    plan)
      if [[ $score_int -ge 40 ]]; then PHI_LABEL="Over-coupled"
      elif [[ $score_int -ge 20 ]]; then PHI_LABEL="Balanced"
      elif [[ $score_int -ge 10 ]]; then PHI_LABEL="Loosely coupled"
      else PHI_LABEL="Too decomposed"; fi
      ;;
    execute)
      if [[ $score_int -ge 80 ]]; then PHI_LABEL="Tightly coupled"
      elif [[ $score_int -ge 50 ]]; then PHI_LABEL="Well integrated"
      elif [[ $score_int -ge 20 ]]; then PHI_LABEL="Partially integrated"
      else PHI_LABEL="Isolated"; fi
      ;;
    review)
      if [[ $score_int -ge 90 ]]; then PHI_LABEL="Pristine"
      elif [[ $score_int -ge 70 ]]; then PHI_LABEL="Cohesive"
      elif [[ $score_int -ge 40 ]]; then PHI_LABEL="Mostly coherent"
      else PHI_LABEL="Incoherent"; fi
      ;;
    verify)
      if [[ $score_int -ge 90 ]]; then PHI_LABEL="Fully realized"
      elif [[ $score_int -ge 60 ]]; then PHI_LABEL="Emergent"
      elif [[ $score_int -ge 30 ]]; then PHI_LABEL="Partial emergence"
      else PHI_LABEL="Parts without whole"; fi
      ;;
  esac

  # Check if Φ table exists in TRACES.md
  PHI_ROW="| ${PHI_STAGE} | ${PHI_SCORE} | ${PHI_LABEL} | ${PHI_NOTES:-} |"

  if grep -qE '^\|[[:space:]]*Stage[[:space:]]*\|[[:space:]]*Φ' "$TRACES_FILE"; then
    # Φ table exists — check if stage already logged (update) or append
    if grep -qE "^\|[[:space:]]*${PHI_STAGE}[[:space:]]*\|" "$TRACES_FILE"; then
      # Update existing row
      sed -i "s|^\|[[:space:]]*${PHI_STAGE}[[:space:]]*\|.*|${PHI_ROW}|" "$TRACES_FILE"
      echo -e "${GREEN}Updated:${NC} Φ(${PHI_STAGE}) = ${GREEN}${PHI_SCORE}${NC} — ${PHI_LABEL}"
    else
      # Find last phi table row and append
      last_phi_line=$(grep -nE '^\|[[:space:]]*(spec|plan|execute|review|verify|----)' "$TRACES_FILE" | tail -1 | cut -d: -f1)
      if [[ -n "$last_phi_line" ]]; then
        sed -i "${last_phi_line}a\\${PHI_ROW}" "$TRACES_FILE"
      fi
      echo -e "${GREEN}Logged:${NC} Φ(${PHI_STAGE}) = ${GREEN}${PHI_SCORE}${NC} — ${PHI_LABEL}"
    fi
  else
    # Create Φ table
    cat >> "$TRACES_FILE" <<EOF

## Φ Integration Scores
| Stage | Φ Score | Label | Notes |
|-------|---------|-------|-------|
${PHI_ROW}
EOF
    echo -e "${GREEN}Logged:${NC} Φ(${PHI_STAGE}) = ${GREEN}${PHI_SCORE}${NC} — ${PHI_LABEL}"
  fi

  if [[ -n "$PHI_NOTES" ]]; then
    echo -e "  Notes: ${PHI_NOTES}"
  fi

  # If no task logging needed, exit
  if [[ -z "$TASK_NUM" ]]; then
    exit 0
  fi
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
