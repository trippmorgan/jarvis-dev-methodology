#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ab-test.sh — A/B testing harness for prompt variants
# Runs eval scenarios with two different prompt variants and compares results.
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

RUNS=3

usage() {
  echo -e "${BOLD}Usage:${NC} $(basename "$0") <eval-scenario-path> <promptA.md> <promptB.md> [OPTIONS]"
  echo ""
  echo "Run an eval scenario with two prompt variants and compare results."
  echo ""
  echo -e "${BOLD}Arguments:${NC}"
  echo "  eval-scenario-path   Path to eval scenario directory (must contain task.md and eval.sh)"
  echo "  promptA.md           Path to the first prompt variant"
  echo "  promptB.md           Path to the second prompt variant"
  echo ""
  echo -e "${BOLD}Options:${NC}"
  echo "  --runs N             Number of iterations per variant (default: 3)"
  echo "  --help, -h           Show this help message"
  echo ""
  echo -e "${BOLD}Example:${NC}"
  echo "  $(basename "$0") tests/eval/simple-module/ promptA.md promptB.md --runs 5"
  echo ""
  echo -e "${BOLD}Process:${NC}"
  echo "  For each run, per variant:"
  echo "    1. Read task.md from the eval scenario"
  echo "    2. Prepend the prompt variant to create a combined prompt"
  echo "    3. Print the agent-spawn command (TODO: wire to sessions_spawn)"
  echo "    4. Run eval.sh to score results"
  echo "    5. Log timing and results"
  echo ""
  echo "  After all runs, compare pass rates, average scores, and timing."
  exit 0
}

# ── Argument parsing ────────────────────────────────────────────────────────

[[ $# -eq 0 ]] && usage
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage

if [[ $# -lt 3 ]]; then
  echo -e "${RED}Error:${NC} Expected at least 3 arguments: <eval-path> <promptA> <promptB>"
  echo "Run with --help for usage."
  exit 1
fi

EVAL_DIR="$1"
PROMPT_A="$2"
PROMPT_B="$3"
shift 3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error:${NC} --runs requires a positive integer"
        exit 1
      fi
      RUNS="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo -e "${RED}Error:${NC} Unknown option: $1"
      exit 1
      ;;
  esac
done

# ── Validate inputs ─────────────────────────────────────────────────────────

if [[ ! -d "$EVAL_DIR" ]]; then
  echo -e "${RED}Error:${NC} Eval scenario directory not found: $EVAL_DIR"
  exit 1
fi

if [[ ! -f "$EVAL_DIR/task.md" ]]; then
  echo -e "${RED}Error:${NC} No task.md found in $EVAL_DIR"
  exit 1
fi

if [[ ! -f "$EVAL_DIR/eval.sh" ]]; then
  echo -e "${RED}Error:${NC} No eval.sh found in $EVAL_DIR"
  exit 1
fi

if [[ ! -f "$PROMPT_A" ]]; then
  echo -e "${RED}Error:${NC} Prompt variant A not found: $PROMPT_A"
  exit 1
fi

if [[ ! -f "$PROMPT_B" ]]; then
  echo -e "${RED}Error:${NC} Prompt variant B not found: $PROMPT_B"
  exit 1
fi

EVAL_NAME="$(basename "$EVAL_DIR")"
TASK_CONTENT="$(cat "$EVAL_DIR/task.md")"

# ── Helper functions ─────────────────────────────────────────────────────────

build_combined_prompt() {
  local prompt_file="$1"
  local prompt_content
  prompt_content="$(cat "$prompt_file")"
  printf '%s\n\n---\n\n%s' "$prompt_content" "$TASK_CONTENT"
}

run_variant() {
  local variant_label="$1"
  local prompt_file="$2"
  local run_num="$3"

  echo -e "\n${CYAN}--- ${variant_label} | Run ${run_num}/${RUNS} ---${NC}"

  # Step 1-2: Build combined prompt
  local combined_prompt
  combined_prompt="$(build_combined_prompt "$prompt_file")"

  # Step 3: Print the command that WOULD spawn an agent
  # TODO: Wire to sessions_spawn when agent orchestration is available
  echo -e "  ${DIM}[TODO] Would spawn agent with combined prompt (${#combined_prompt} chars):${NC}"
  echo -e "  ${DIM}  sessions_spawn --prompt <combined-prompt> --workdir ${EVAL_DIR}${NC}"
  echo -e "  ${DIM}  Skipping agent execution (simulated mode)${NC}"

  # Step 4: Run eval.sh and capture score + timing
  local start_time end_time elapsed score exit_code
  start_time="$(date +%s%N)"

  set +e
  local eval_output
  eval_output="$(bash "$EVAL_DIR/eval.sh" 2>&1)"
  exit_code=$?
  set -e

  end_time="$(date +%s%N)"
  elapsed=$(( (end_time - start_time) / 1000000 ))  # milliseconds

  # Extract score from eval output (looks for "SCORE: NN/100")
  score="$(echo "$eval_output" | grep -oP 'SCORE:\s*\K\d+' || echo "0")"

  local passed=0
  if [[ $exit_code -eq 0 ]]; then
    passed=1
    echo -e "  ${GREEN}PASS${NC} | Score: ${score}/100 | Time: ${elapsed}ms"
  else
    echo -e "  ${RED}FAIL${NC} | Score: ${score}/100 | Time: ${elapsed}ms"
  fi

  # Return results via global arrays (bash workaround for subshell scoping)
  echo "${passed}:${score}:${elapsed}"
}

# ── Run the experiment ───────────────────────────────────────────────────────

echo -e "\n${BOLD}${BLUE}A/B Test: ${EVAL_NAME}${NC}"
echo -e "${DIM}Variant A: ${PROMPT_A}${NC}"
echo -e "${DIM}Variant B: ${PROMPT_B}${NC}"
echo -e "${DIM}Runs per variant: ${RUNS}${NC}"

# Storage arrays
declare -a A_PASSED=()
declare -a A_SCORES=()
declare -a A_TIMES=()
declare -a B_PASSED=()
declare -a B_SCORES=()
declare -a B_TIMES=()

# Run Variant A
echo -e "\n${BOLD}${GREEN}=== Variant A ===${NC}"
for (( i=1; i<=RUNS; i++ )); do
  result="$(run_variant "Variant A" "$PROMPT_A" "$i")"
  # Last line of output is the data line
  data_line="$(echo "$result" | tail -1)"
  IFS=':' read -r p s t <<< "$data_line"
  A_PASSED+=("$p")
  A_SCORES+=("$s")
  A_TIMES+=("$t")
  # Print all but last line (the UI output)
  echo "$result" | head -n -1
done

# Run Variant B
echo -e "\n${BOLD}${YELLOW}=== Variant B ===${NC}"
for (( i=1; i<=RUNS; i++ )); do
  result="$(run_variant "Variant B" "$PROMPT_B" "$i")"
  data_line="$(echo "$result" | tail -1)"
  IFS=':' read -r p s t <<< "$data_line"
  B_PASSED+=("$p")
  B_SCORES+=("$s")
  B_TIMES+=("$t")
  echo "$result" | head -n -1
done

# ── Compute statistics ───────────────────────────────────────────────────────

sum_array() {
  local -n arr=$1
  local total=0
  for val in "${arr[@]}"; do
    total=$((total + val))
  done
  echo "$total"
}

a_pass_count="$(sum_array A_PASSED)"
b_pass_count="$(sum_array B_PASSED)"
a_score_sum="$(sum_array A_SCORES)"
b_score_sum="$(sum_array B_SCORES)"
a_time_sum="$(sum_array A_TIMES)"
b_time_sum="$(sum_array B_TIMES)"

a_pass_rate=$(( a_pass_count * 100 / RUNS ))
b_pass_rate=$(( b_pass_count * 100 / RUNS ))

# Use awk for floating-point averages
a_avg_score="$(awk "BEGIN { printf \"%.0f\", ${a_score_sum} / ${RUNS} }")"
b_avg_score="$(awk "BEGIN { printf \"%.0f\", ${b_score_sum} / ${RUNS} }")"

a_avg_time="$(awk "BEGIN { printf \"%.1f\", ${a_time_sum} / ${RUNS} / 1000 }")"
b_avg_time="$(awk "BEGIN { printf \"%.1f\", ${b_time_sum} / ${RUNS} / 1000 }")"

# ── Determine winner ────────────────────────────────────────────────────────

# Use average score as the primary comparison metric
if [[ "$a_avg_score" -eq 0 && "$b_avg_score" -eq 0 ]]; then
  score_diff_pct=0
else
  max_score="$a_avg_score"
  if (( b_avg_score > a_avg_score )); then
    max_score="$b_avg_score"
  fi
  if (( max_score > 0 )); then
    score_diff_abs=$(( a_avg_score - b_avg_score ))
    if (( score_diff_abs < 0 )); then
      score_diff_abs=$(( -score_diff_abs ))
    fi
    score_diff_pct=$(( score_diff_abs * 100 / max_score ))
  else
    score_diff_pct=0
  fi
fi

if (( score_diff_pct <= 5 )); then
  winner="No significant difference"
elif (( a_avg_score > b_avg_score )); then
  if (( score_diff_pct > 10 )); then
    winner="Variant A (high confidence)"
  else
    winner="Variant A (moderate confidence)"
  fi
else
  if (( score_diff_pct > 10 )); then
    winner="Variant B (high confidence)"
  else
    winner="Variant B (moderate confidence)"
  fi
fi

# ── Output comparison table ──────────────────────────────────────────────────

# Pad strings to fixed width
pad() {
  local str="$1"
  local width="$2"
  printf "%-${width}s" "$str"
}

W=46  # total inner width

echo ""
echo -e "${BOLD}"
printf '╔'; printf '═%.0s' $(seq 1 $W); printf '╗\n'
printf '║'; printf '%*s' $(( (W + 18) / 2 )) "A/B Test Results"; printf '%*s' $(( (W - 18 + 1) / 2 )) ""; printf '║\n'
printf '╠'; printf '═%.0s' $(seq 1 $W); printf '╣\n'
printf '║ Eval: %-*s║\n' $((W - 7)) "$EVAL_NAME"
printf '║ Runs per variant: %-*s║\n' $((W - 19)) "$RUNS"
printf '╠'; printf '═%.0s' $(seq 1 12); printf '╦'; printf '═%.0s' $(seq 1 14); printf '╦'; printf '═%.0s' $(seq 1 $((W - 28))); printf '╣\n'
COL3=$((W - 29))
printf '║ %-10s ║ %-12s ║ %-'"${COL3}"'s║\n' "Metric" "Variant A" "Variant B"
printf '╠'; printf '═%.0s' $(seq 1 12); printf '╬'; printf '═%.0s' $(seq 1 14); printf '╬'; printf '═%.0s' $(seq 1 $((W - 28))); printf '╣\n'
printf '║ %-10s ║ %-12s ║ %-'"${COL3}"'s║\n' "Pass rate" "${a_pass_rate}%" "${b_pass_rate}%"
printf '║ %-10s ║ %-12s ║ %-'"${COL3}"'s║\n' "Avg score" "$a_avg_score" "$b_avg_score"
printf '║ %-10s ║ %-12s ║ %-'"${COL3}"'s║\n' "Avg time" "${a_avg_time}s" "${b_avg_time}s"
printf '╠'; printf '═%.0s' $(seq 1 12); printf '╩'; printf '═%.0s' $(seq 1 14); printf '╩'; printf '═%.0s' $(seq 1 $((W - 28))); printf '╣\n'
printf '║ Winner: %-*s║\n' $((W - 9)) "$winner"
printf '╚'; printf '═%.0s' $(seq 1 $W); printf '╝\n'
echo -e "${NC}"

# Exit with appropriate code
if [[ "$winner" == *"No significant"* ]]; then
  exit 0
elif [[ "$winner" == *"Variant A"* ]]; then
  exit 0
else
  exit 0
fi
