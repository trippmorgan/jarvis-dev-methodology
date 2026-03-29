#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# metrics-dashboard.sh — Terminal-based metrics dashboard for Jarvis traces
# Reads .planning/TRACES.md from one or more projects, aggregates and displays
# pass rates, token usage, Phi scores, model breakdowns, and recommendations.
# =============================================================================

# --- ANSI Colors and Styles ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Box-drawing characters
H_LINE='─'
V_LINE='│'
TL_CORNER='┌'
TR_CORNER='┐'
BL_CORNER='└'
BR_CORNER='┘'
T_DOWN='┬'
T_UP='┴'
T_RIGHT='├'
T_LEFT='┤'
CROSS='┼'

# Bar chart characters
BAR_FULL='█'
BAR_HALF='▓'
BAR_LIGHT='░'

# --- Usage ---
usage() {
  cat <<EOF
${BOLD}metrics-dashboard.sh${NC} — Jarvis Development Methodology metrics dashboard

${BOLD}Usage:${NC}
  $(basename "$0") /path/to/project [/path/to/project2 ...] [--help]

${BOLD}Arguments:${NC}
  /path/to/project     Project directory containing .planning/TRACES.md
                       or direct path to a TRACES.md file

${BOLD}Flags:${NC}
  --help, -h           Show this help message

${BOLD}Display Sections:${NC}
  1. Project summary table (tasks, pass rate, phi, tokens, time)
  2. Trend indicators (when multiple projects provided)
  3. Per-model performance breakdown
  4. Phi score distribution (ASCII bar chart)
  5. Top failure patterns
  6. Recommendations based on metrics

${BOLD}Examples:${NC}
  $(basename "$0") /path/to/my-project
  $(basename "$0") /path/to/project1 /path/to/project2
  $(basename "$0") /path/to/project/.planning/TRACES.md
EOF
}

# --- Helpers ---

# Repeat a character N times
repeat_char() {
  local char="$1" count="$2"
  printf '%0.s'"$char" $(seq 1 "$count")
}

# Parse time string (e.g., "2m30s", "45s", "3m") to seconds
parse_time_to_seconds() {
  local time_str="$1"
  local minutes=0 seconds=0

  if [[ "$time_str" == "-" || -z "$time_str" ]]; then
    echo 0
    return
  fi

  # Extract minutes
  if [[ "$time_str" =~ ([0-9]+)m ]]; then
    minutes="${BASH_REMATCH[1]}"
  fi
  # Extract seconds
  if [[ "$time_str" =~ ([0-9]+)s ]]; then
    seconds="${BASH_REMATCH[1]}"
  fi

  echo $(( minutes * 60 + seconds ))
}

# Format seconds back to human-readable
format_seconds() {
  local total="$1"
  if [[ "$total" -eq 0 ]]; then
    echo "-"
    return
  fi
  local m=$(( total / 60 ))
  local s=$(( total % 60 ))
  if [[ $m -gt 0 && $s -gt 0 ]]; then
    echo "${m}m${s}s"
  elif [[ $m -gt 0 ]]; then
    echo "${m}m"
  else
    echo "${s}s"
  fi
}

# Parse token string (e.g., "12100", "12k") to integer
parse_tokens() {
  local tok="$1"
  if [[ "$tok" == "-" || -z "$tok" ]]; then
    echo 0
    return
  fi
  tok=$(echo "$tok" | tr -d ',' | xargs)
  if [[ "$tok" =~ ^([0-9]+(\.[0-9]+)?)k$ ]]; then
    echo "${BASH_REMATCH[1]}" | awk '{printf "%d", $1 * 1000}'
  else
    echo "${tok%%.*}"
  fi
}

# Color a value based on thresholds (green >= high, yellow >= mid, red otherwise)
color_threshold() {
  local value="$1" high="$2" mid="$3"
  if (( $(echo "$value >= $high" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${GREEN}${value}${NC}"
  elif (( $(echo "$value >= $mid" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${YELLOW}${value}${NC}"
  else
    echo -e "${RED}${value}${NC}"
  fi
}

# Draw a horizontal rule with box-drawing
draw_hr() {
  local width="${1:-78}"
  echo -e "${DIM}$(repeat_char "$H_LINE" "$width")${NC}"
}

# Draw a box-drawing table top
draw_table_top() {
  local widths=("$@")
  local line="${TL_CORNER}"
  for w in "${widths[@]}"; do
    line+="$(repeat_char "$H_LINE" "$((w + 2))")${T_DOWN}"
  done
  # Replace last T_DOWN with TR_CORNER
  line="${line%${T_DOWN}}${TR_CORNER}"
  echo -e "${DIM}${line}${NC}"
}

# Draw a table separator
draw_table_sep() {
  local widths=("$@")
  local line="${T_RIGHT}"
  for w in "${widths[@]}"; do
    line+="$(repeat_char "$H_LINE" "$((w + 2))")${CROSS}"
  done
  line="${line%${CROSS}}${T_LEFT}"
  echo -e "${DIM}${line}${NC}"
}

# Draw a table bottom
draw_table_bottom() {
  local widths=("$@")
  local line="${BL_CORNER}"
  for w in "${widths[@]}"; do
    line+="$(repeat_char "$H_LINE" "$((w + 2))")${T_UP}"
  done
  line="${line%${T_UP}}${BR_CORNER}"
  echo -e "${DIM}${line}${NC}"
}

# Print a table row with box-drawing borders
# Usage: draw_table_row "col1" "col2" ... -- width1 width2 ...
draw_table_row() {
  local cols=()
  local widths=()
  local in_widths=0
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      in_widths=1
      continue
    fi
    if [[ $in_widths -eq 0 ]]; then
      cols+=("$arg")
    else
      widths+=("$arg")
    fi
  done

  local line="${DIM}${V_LINE}${NC}"
  for i in "${!cols[@]}"; do
    local w="${widths[$i]:-20}"
    # We need to handle ANSI codes in the column value for proper padding
    local raw_col
    raw_col=$(echo -e "${cols[$i]}" | sed 's/\x1b\[[0-9;]*m//g')
    local raw_len=${#raw_col}
    local padding=$(( w - raw_len ))
    if [[ $padding -lt 0 ]]; then padding=0; fi
    line+=" ${cols[$i]}$(repeat_char ' ' "$padding") ${DIM}${V_LINE}${NC}"
  done
  echo -e "$line"
}

# --- Resolve trace file paths ---
resolve_traces_file() {
  local path="$1"
  if [[ -f "$path" && "$(basename "$path")" == "TRACES.md" ]]; then
    echo "$path"
  elif [[ -f "$path/.planning/TRACES.md" ]]; then
    echo "$path/.planning/TRACES.md"
  else
    return 1
  fi
}

# Extract project name from traces file or directory
project_name_from_path() {
  local path="$1"
  if [[ "$(basename "$path")" == "TRACES.md" ]]; then
    # Go up two levels: .planning/ -> project/
    local proj_dir
    proj_dir="$(dirname "$(dirname "$path")")"
    basename "$proj_dir"
  else
    basename "$path"
  fi
}

# --- Parse a single TRACES.md file into arrays ---
# Sets global arrays for the caller
parse_traces() {
  local traces_file="$1"

  P_TASK_NUMS=()
  P_STATUSES=()
  P_RETRIES=()
  P_TIMES=()
  P_MODELS=()
  P_TOKENS=()
  P_NOTES=()
  P_PHI_STAGES=()
  P_PHI_SCORES=()
  P_PHI_LABELS=()
  P_PHI_NOTES=()
  P_FAILURE_NOTES=()

  local in_tasks=0 in_phi=0

  while IFS= read -r line; do
    # Detect section headers
    if [[ "$line" =~ ^###[[:space:]]+Tasks ]]; then
      in_tasks=1; in_phi=0; continue
    fi
    if [[ "$line" =~ ^##[[:space:]]+.*[Pp]hi|^##[[:space:]].*Integration ]]; then
      in_tasks=0; in_phi=1; continue
    fi
    if [[ "$line" =~ ^## && ! "$line" =~ ^###[[:space:]]+Tasks && ! "$line" =~ [Pp]hi && ! "$line" =~ Integration ]]; then
      in_tasks=0; in_phi=0; continue
    fi

    # Parse task rows
    if [[ $in_tasks -eq 1 && "$line" =~ ^\|[[:space:]]*[0-9] ]]; then
      IFS='|' read -ra cols <<< "$line"
      # cols: [0]=empty [1]=task [2]=status [3]=retries [4]=time [5]=model [6]=tokens [7]=notes
      local task status retries time_val model tokens notes
      task=$(echo "${cols[1]:-}" | xargs)
      status=$(echo "${cols[2]:-}" | xargs)
      retries=$(echo "${cols[3]:-0}" | xargs)
      time_val=$(echo "${cols[4]:-"-"}" | xargs)
      model=$(echo "${cols[5]:-"-"}" | xargs)
      tokens=$(echo "${cols[6]:-"-"}" | xargs)
      notes=$(echo "${cols[7]:-}" | xargs)

      P_TASK_NUMS+=("$task")
      P_STATUSES+=("$status")
      P_RETRIES+=("$retries")
      P_TIMES+=("$time_val")
      P_MODELS+=("$model")
      P_TOKENS+=("$tokens")
      P_NOTES+=("$notes")

      if [[ "$status" == "FAIL" ]]; then
        P_FAILURE_NOTES+=("$notes")
      fi
    fi

    # Parse phi rows
    if [[ $in_phi -eq 1 && "$line" =~ ^\|[[:space:]]*(spec|plan|execute|review|verify) ]]; then
      IFS='|' read -ra cols <<< "$line"
      local stage score label phi_notes
      stage=$(echo "${cols[1]:-}" | xargs)
      score=$(echo "${cols[2]:-}" | xargs)
      label=$(echo "${cols[3]:-}" | xargs)
      phi_notes=$(echo "${cols[4]:-}" | xargs)

      P_PHI_STAGES+=("$stage")
      P_PHI_SCORES+=("$score")
      P_PHI_LABELS+=("$label")
      P_PHI_NOTES+=("$phi_notes")
    fi
  done < "$traces_file"
}

# Compute weighted project phi from P_PHI_STAGES / P_PHI_SCORES
compute_project_phi() {
  local weighted_sum=0 weight_total=0
  declare -A weights=([spec]=10 [plan]=15 [execute]=25 [review]=20 [verify]=30)

  for i in "${!P_PHI_STAGES[@]}"; do
    local stage="${P_PHI_STAGES[$i]}"
    local score="${P_PHI_SCORES[$i]}"
    local w="${weights[$stage]:-0}"
    local ws
    ws=$(echo "$score $w" | awk '{printf "%d", $1 * $2 * 100}')
    weighted_sum=$((weighted_sum + ws))
    weight_total=$((weight_total + w))
  done

  if [[ $weight_total -gt 0 ]]; then
    echo "$weighted_sum $weight_total" | awk '{printf "%.2f", $1 / ($2 * 100)}'
  else
    echo "-"
  fi
}

# --- Main ---

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error:${NC} No project paths provided." >&2
  echo "" >&2
  usage >&2
  exit 1
fi

# Collect valid trace files
TRACE_FILES=()
PROJECT_NAMES=()
PROJECT_PATHS=()

for arg in "$@"; do
  if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    usage
    exit 0
  fi
  local_file=""
  local_file=$(resolve_traces_file "$arg" 2>/dev/null) || true
  if [[ -z "$local_file" ]]; then
    echo -e "${YELLOW}Warning:${NC} No TRACES.md found for: $arg (skipping)" >&2
    continue
  fi
  TRACE_FILES+=("$local_file")
  PROJECT_NAMES+=("$(project_name_from_path "$arg")")
  PROJECT_PATHS+=("$arg")
done

if [[ ${#TRACE_FILES[@]} -eq 0 ]]; then
  echo -e "${RED}Error:${NC} No valid TRACES.md files found in provided paths." >&2
  exit 1
fi

# =============================================================================
# Section 0: Header
# =============================================================================
echo ""
echo -e "${BOLD}${CYAN}  ${BAR_FULL}${BAR_FULL}${BAR_FULL} JARVIS METRICS DASHBOARD ${BAR_FULL}${BAR_FULL}${BAR_FULL}${NC}"
echo -e "${DIM}  $(date '+%Y-%m-%d %H:%M:%S')  ${BAR_LIGHT}  ${#TRACE_FILES[@]} project(s) loaded${NC}"
echo ""

# =============================================================================
# Section 1: Project Summary Table
# =============================================================================

# Collect per-project aggregates
ALL_PROJ_NAMES=()
ALL_PROJ_TASKS=()
ALL_PROJ_PASSES=()
ALL_PROJ_PASS_RATES=()
ALL_PROJ_PHIS=()
ALL_PROJ_TOKENS=()
ALL_PROJ_TIMES=()
ALL_PROJ_RETRIES=()

# For model breakdown
declare -A MODEL_TASKS=()
declare -A MODEL_PASSES=()
declare -A MODEL_TOKENS=()
declare -A MODEL_TIME=()
ALL_MODELS=()

# For failure tracking
ALL_FAILURE_NOTES=()

for idx in "${!TRACE_FILES[@]}"; do
  parse_traces "${TRACE_FILES[$idx]}"

  local_total=${#P_TASK_NUMS[@]}
  local_passes=0
  local_tokens_sum=0
  local_time_sum=0
  local_retries_sum=0

  for i in "${!P_STATUSES[@]}"; do
    if [[ "${P_STATUSES[$i]}" == "PASS" || "${P_STATUSES[$i]}" == "FAIL->PASS" || "${P_STATUSES[$i]}" == "FAIL→PASS" ]]; then
      local_passes=$((local_passes + 1))
    fi
    local_tokens_sum=$(( local_tokens_sum + $(parse_tokens "${P_TOKENS[$i]}") ))
    local_time_sum=$(( local_time_sum + $(parse_time_to_seconds "${P_TIMES[$i]}") ))
    local_retries_sum=$(( local_retries_sum + ${P_RETRIES[$i]:-0} ))

    # Model aggregation
    mdl="${P_MODELS[$i]}"
    if [[ "$mdl" != "-" && -n "$mdl" ]]; then
      if [[ -z "${MODEL_TASKS[$mdl]+x}" ]]; then
        ALL_MODELS+=("$mdl")
        MODEL_TASKS[$mdl]=0
        MODEL_PASSES[$mdl]=0
        MODEL_TOKENS[$mdl]=0
        MODEL_TIME[$mdl]=0
      fi
      MODEL_TASKS[$mdl]=$(( MODEL_TASKS[$mdl] + 1 ))
      if [[ "${P_STATUSES[$i]}" == "PASS" || "${P_STATUSES[$i]}" == "FAIL->PASS" || "${P_STATUSES[$i]}" == "FAIL→PASS" ]]; then
        MODEL_PASSES[$mdl]=$(( MODEL_PASSES[$mdl] + 1 ))
      fi
      MODEL_TOKENS[$mdl]=$(( MODEL_TOKENS[$mdl] + $(parse_tokens "${P_TOKENS[$i]}") ))
      MODEL_TIME[$mdl]=$(( MODEL_TIME[$mdl] + $(parse_time_to_seconds "${P_TIMES[$i]}") ))
    fi
  done

  # Failure notes
  for fn in "${P_FAILURE_NOTES[@]}"; do
    ALL_FAILURE_NOTES+=("$fn")
  done

  local_pass_rate=0
  if [[ $local_total -gt 0 ]]; then
    local_pass_rate=$(( (local_passes * 100) / local_total ))
  fi

  local_phi=$(compute_project_phi)

  ALL_PROJ_NAMES+=("${PROJECT_NAMES[$idx]}")
  ALL_PROJ_TASKS+=("$local_total")
  ALL_PROJ_PASSES+=("$local_passes")
  ALL_PROJ_PASS_RATES+=("$local_pass_rate")
  ALL_PROJ_PHIS+=("$local_phi")
  ALL_PROJ_TOKENS+=("$local_tokens_sum")
  ALL_PROJ_TIMES+=("$local_time_sum")
  ALL_PROJ_RETRIES+=("$local_retries_sum")
done

echo -e "${BOLD}${WHITE}  PROJECT SUMMARY${NC}"
draw_hr 78

# Column widths: project=22 tasks=6 pass%=8 phi=7 tokens=10 time=8 retries=8
CW=(22 6 8 7 10 8 8)

draw_table_top "${CW[@]}"
draw_table_row "${BOLD}Project${NC}" "${BOLD}Tasks${NC}" "${BOLD}Pass %${NC}" "${BOLD}Phi${NC}" "${BOLD}Tokens${NC}" "${BOLD}Time${NC}" "${BOLD}Retries${NC}" -- "${CW[@]}"
draw_table_sep "${CW[@]}"

for i in "${!ALL_PROJ_NAMES[@]}"; do
  local_name="${ALL_PROJ_NAMES[$i]}"
  # Truncate name if needed
  if [[ ${#local_name} -gt 22 ]]; then
    local_name="${local_name:0:19}..."
  fi

  local_rate="${ALL_PROJ_PASS_RATES[$i]}"
  if [[ $local_rate -ge 90 ]]; then
    rate_str="${GREEN}${local_rate}%${NC}"
  elif [[ $local_rate -ge 70 ]]; then
    rate_str="${YELLOW}${local_rate}%${NC}"
  else
    rate_str="${RED}${local_rate}%${NC}"
  fi

  local_phi="${ALL_PROJ_PHIS[$i]}"
  if [[ "$local_phi" != "-" ]]; then
    phi_num=$(echo "$local_phi" | awk '{printf "%d", $1 * 100}')
    if [[ $phi_num -ge 60 ]]; then
      phi_str="${GREEN}${local_phi}${NC}"
    elif [[ $phi_num -ge 30 ]]; then
      phi_str="${YELLOW}${local_phi}${NC}"
    else
      phi_str="${RED}${local_phi}${NC}"
    fi
  else
    phi_str="${DIM}-${NC}"
  fi

  local_tok="${ALL_PROJ_TOKENS[$i]}"
  if [[ $local_tok -ge 1000 ]]; then
    tok_str=$(echo "$local_tok" | awk '{printf "%.1fk", $1/1000}')
  else
    tok_str="$local_tok"
  fi

  time_str=$(format_seconds "${ALL_PROJ_TIMES[$i]}")
  retries_str="${ALL_PROJ_RETRIES[$i]}"
  if [[ "$retries_str" -gt 0 ]]; then
    retries_str="${YELLOW}${retries_str}${NC}"
  else
    retries_str="${GREEN}${retries_str}${NC}"
  fi

  draw_table_row "$local_name" "${ALL_PROJ_TASKS[$i]}" "$rate_str" "$phi_str" "$tok_str" "$time_str" "$retries_str" -- "${CW[@]}"
done

draw_table_bottom "${CW[@]}"
echo ""

# =============================================================================
# Section 2: Trend Indicators (if multiple projects)
# =============================================================================
if [[ ${#ALL_PROJ_NAMES[@]} -gt 1 ]]; then
  echo -e "${BOLD}${WHITE}  TREND INDICATORS${NC}"
  draw_hr 78

  # Compare each project to the previous one
  for i in "${!ALL_PROJ_NAMES[@]}"; do
    if [[ $i -eq 0 ]]; then continue; fi
    prev=$((i - 1))

    name="${ALL_PROJ_NAMES[$i]}"
    if [[ ${#name} -gt 20 ]]; then name="${name:0:17}..."; fi

    # Pass rate trend
    rate_diff=$(( ALL_PROJ_PASS_RATES[$i] - ALL_PROJ_PASS_RATES[$prev] ))
    if [[ $rate_diff -gt 0 ]]; then rate_arrow="${GREEN}+${rate_diff}% ^${NC}"
    elif [[ $rate_diff -lt 0 ]]; then rate_arrow="${RED}${rate_diff}% v${NC}"
    else rate_arrow="${DIM}0% =${NC}"; fi

    # Phi trend
    phi_cur="${ALL_PROJ_PHIS[$i]}"
    phi_prev="${ALL_PROJ_PHIS[$prev]}"
    if [[ "$phi_cur" != "-" && "$phi_prev" != "-" ]]; then
      phi_diff=$(echo "$phi_cur $phi_prev" | awk '{printf "%.2f", $1 - $2}')
      phi_sign=$(echo "$phi_diff" | awk '{if ($1 > 0) print "+"; else if ($1 < 0) print ""; else print "="}')
      if [[ "$phi_sign" == "+" ]]; then phi_arrow="${GREEN}${phi_sign}${phi_diff} ^${NC}"
      elif [[ "$phi_sign" == "=" ]]; then phi_arrow="${DIM}${phi_diff} =${NC}"
      else phi_arrow="${RED}${phi_diff} v${NC}"; fi
    else
      phi_arrow="${DIM}n/a${NC}"
    fi

    # Token trend
    tok_diff=$(( ALL_PROJ_TOKENS[$i] - ALL_PROJ_TOKENS[$prev] ))
    if [[ $tok_diff -gt 0 ]]; then
      tok_k=$(echo "$tok_diff" | awk '{printf "%.1fk", $1/1000}')
      tok_arrow="${YELLOW}+${tok_k} ^${NC}"
    elif [[ $tok_diff -lt 0 ]]; then
      tok_k=$(echo "$(( -tok_diff ))" | awk '{printf "%.1fk", $1/1000}')
      tok_arrow="${GREEN}-${tok_k} v${NC}"
    else
      tok_arrow="${DIM}0 =${NC}"
    fi

    echo -e "  ${BOLD}${name}${NC} vs ${ALL_PROJ_NAMES[$prev]}:"
    echo -e "    Pass rate: ${rate_arrow}   Phi: ${phi_arrow}   Tokens: ${tok_arrow}"
  done
  echo ""
fi

# =============================================================================
# Section 3: Per-Model Performance Breakdown
# =============================================================================
if [[ ${#ALL_MODELS[@]} -gt 0 ]]; then
  echo -e "${BOLD}${WHITE}  MODEL PERFORMANCE${NC}"
  draw_hr 78

  MW=(12 8 8 12 10)
  draw_table_top "${MW[@]}"
  draw_table_row "${BOLD}Model${NC}" "${BOLD}Tasks${NC}" "${BOLD}Pass %${NC}" "${BOLD}Avg Tokens${NC}" "${BOLD}Avg Time${NC}" -- "${MW[@]}"
  draw_table_sep "${MW[@]}"

  for mdl in "${ALL_MODELS[@]}"; do
    local_tasks="${MODEL_TASKS[$mdl]}"
    local_passes="${MODEL_PASSES[$mdl]}"
    local_rate=0
    if [[ $local_tasks -gt 0 ]]; then
      local_rate=$(( (local_passes * 100) / local_tasks ))
    fi
    local_avg_tok=0
    if [[ $local_tasks -gt 0 ]]; then
      local_avg_tok=$(( MODEL_TOKENS[$mdl] / local_tasks ))
    fi
    local_avg_time=0
    if [[ $local_tasks -gt 0 ]]; then
      local_avg_time=$(( MODEL_TIME[$mdl] / local_tasks ))
    fi

    if [[ $local_rate -ge 90 ]]; then
      rate_str="${GREEN}${local_rate}%${NC}"
    elif [[ $local_rate -ge 70 ]]; then
      rate_str="${YELLOW}${local_rate}%${NC}"
    else
      rate_str="${RED}${local_rate}%${NC}"
    fi

    if [[ $local_avg_tok -ge 1000 ]]; then
      tok_str=$(echo "$local_avg_tok" | awk '{printf "%.1fk", $1/1000}')
    else
      tok_str="$local_avg_tok"
    fi

    time_str=$(format_seconds "$local_avg_time")

    mdl_display="${MAGENTA}${mdl}${NC}"
    draw_table_row "$mdl_display" "$local_tasks" "$rate_str" "$tok_str" "$time_str" -- "${MW[@]}"
  done

  draw_table_bottom "${MW[@]}"
  echo ""
fi

# =============================================================================
# Section 4: Phi Score Distribution (ASCII Bar Chart)
# =============================================================================
echo -e "${BOLD}${WHITE}  PHI SCORE DISTRIBUTION${NC}"
draw_hr 78

PHI_STAGES_ORDER=(spec plan execute review verify)
PHI_FOUND=0

for idx in "${!TRACE_FILES[@]}"; do
  parse_traces "${TRACE_FILES[$idx]}"
  if [[ ${#P_PHI_STAGES[@]} -eq 0 ]]; then continue; fi
  PHI_FOUND=1

  local_name="${PROJECT_NAMES[$idx]}"
  if [[ ${#local_name} -gt 30 ]]; then local_name="${local_name:0:27}..."; fi
  echo -e "  ${BOLD}${CYAN}${local_name}${NC}"

  for stage in "${PHI_STAGES_ORDER[@]}"; do
    local_score=""
    local_label=""
    for si in "${!P_PHI_STAGES[@]}"; do
      if [[ "${P_PHI_STAGES[$si]}" == "$stage" ]]; then
        local_score="${P_PHI_SCORES[$si]}"
        local_label="${P_PHI_LABELS[$si]}"
        break
      fi
    done

    if [[ -z "$local_score" ]]; then continue; fi

    # Bar: score * 40 chars wide
    bar_len=$(echo "$local_score" | awk '{printf "%d", $1 * 40}')
    empty_len=$(( 40 - bar_len ))
    if [[ $empty_len -lt 0 ]]; then empty_len=0; fi

    # Color based on score
    score_int=$(echo "$local_score" | awk '{printf "%d", $1 * 100}')
    bar_color=""
    if [[ $score_int -ge 60 ]]; then
      bar_color="$GREEN"
    elif [[ $score_int -ge 30 ]]; then
      bar_color="$YELLOW"
    else
      bar_color="$RED"
    fi

    printf "  %-8s ${bar_color}" "$stage"
    repeat_char "$BAR_FULL" "$bar_len"
    echo -ne "${DIM}"
    repeat_char "$BAR_LIGHT" "$empty_len"
    echo -e "${NC} ${bar_color}${local_score}${NC} ${DIM}${local_label}${NC}"
  done

  # Show weighted average
  local_phi=$(compute_project_phi)
  if [[ "$local_phi" != "-" ]]; then
    phi_int=$(echo "$local_phi" | awk '{printf "%d", $1 * 100}')
    phi_color=""
    if [[ $phi_int -ge 60 ]]; then phi_color="$GREEN"
    elif [[ $phi_int -ge 30 ]]; then phi_color="$YELLOW"
    else phi_color="$RED"; fi
    echo -e "  ${BOLD}weighted ${phi_color}$(repeat_char '=' $(echo "$local_phi" | awk '{printf "%d", $1 * 40}'))${NC}${BOLD}>${NC} ${phi_color}${BOLD}${local_phi}${NC} ${DIM}project score${NC}"
  fi
  echo ""
done

if [[ $PHI_FOUND -eq 0 ]]; then
  echo -e "  ${DIM}No Phi scores found in trace data.${NC}"
  echo ""
fi

# =============================================================================
# Section 5: Top 3 Failure Patterns
# =============================================================================
echo -e "${BOLD}${WHITE}  FAILURE ANALYSIS${NC}"
draw_hr 78

if [[ ${#ALL_FAILURE_NOTES[@]} -eq 0 ]]; then
  echo -e "  ${GREEN}No failures detected across all projects.${NC}"
  echo ""
else
  # Simple frequency: count duplicate notes, show top 3
  echo -e "  ${RED}${#ALL_FAILURE_NOTES[@]} failure(s) detected:${NC}"
  echo ""

  # Use sort/uniq to find patterns
  declare -A PATTERN_COUNTS=()
  for note in "${ALL_FAILURE_NOTES[@]}"; do
    clean_note=$(echo "$note" | xargs)
    if [[ -z "$clean_note" ]]; then clean_note="(no notes)"; fi
    PATTERN_COUNTS["$clean_note"]=$(( ${PATTERN_COUNTS["$clean_note"]:-0} + 1 ))
  done

  # Sort by count, take top 3
  rank=1
  while IFS= read -r entry; do
    if [[ $rank -gt 3 ]]; then break; fi
    count="${entry%%:*}"
    pattern="${entry#*:}"
    echo -e "  ${RED}${rank}.${NC} ${BOLD}${pattern}${NC} ${DIM}(${count}x)${NC}"
    rank=$((rank + 1))
  done < <(
    for key in "${!PATTERN_COUNTS[@]}"; do
      echo "${PATTERN_COUNTS[$key]}:${key}"
    done | sort -t: -k1 -rn
  )
  echo ""
fi

# =============================================================================
# Section 6: Recommendations
# =============================================================================
echo -e "${BOLD}${WHITE}  RECOMMENDATIONS${NC}"
draw_hr 78

RECS=()

# Check overall pass rate
total_tasks=0
total_passes=0
for i in "${!ALL_PROJ_TASKS[@]}"; do
  total_tasks=$(( total_tasks + ALL_PROJ_TASKS[$i] ))
  total_passes=$(( total_passes + ALL_PROJ_PASSES[$i] ))
done

if [[ $total_tasks -gt 0 ]]; then
  overall_rate=$(( (total_passes * 100) / total_tasks ))
  if [[ $overall_rate -eq 100 ]]; then
    RECS+=("${GREEN}*${NC} Perfect pass rate across all tasks -- consider increasing complexity or adding edge-case tests.")
  elif [[ $overall_rate -ge 90 ]]; then
    RECS+=("${GREEN}*${NC} Strong pass rate (${overall_rate}%) -- review failing tasks for recurring patterns.")
  elif [[ $overall_rate -ge 70 ]]; then
    RECS+=("${YELLOW}*${NC} Pass rate at ${overall_rate}% -- investigate common failure causes and consider smaller task decomposition.")
  else
    RECS+=("${RED}*${NC} Low pass rate (${overall_rate}%) -- tasks may be too large or underspecified. Break into smaller units.")
  fi
fi

# Check token usage
total_tokens_all=0
for t in "${ALL_PROJ_TOKENS[@]}"; do
  total_tokens_all=$((total_tokens_all + t))
done
if [[ $total_tasks -gt 0 ]]; then
  avg_tokens=$(( total_tokens_all / total_tasks ))
  if [[ $avg_tokens -gt 15000 ]]; then
    RECS+=("${YELLOW}*${NC} Token-heavy tasks detected (avg ${avg_tokens} tokens/task). Consider more focused task scoping to reduce cost.")
  elif [[ $avg_tokens -lt 3000 && $avg_tokens -gt 0 ]]; then
    RECS+=("${GREEN}*${NC} Efficient token usage (avg ${avg_tokens} tokens/task) -- tasks are well-scoped.")
  fi
fi

# Check retries
total_retries_all=0
for r in "${ALL_PROJ_RETRIES[@]}"; do
  total_retries_all=$((total_retries_all + r))
done
if [[ $total_retries_all -gt 0 ]]; then
  retry_ratio=$(echo "$total_retries_all $total_tasks" | awk '{printf "%.1f", $1/$2}')
  RECS+=("${YELLOW}*${NC} Retry ratio is ${retry_ratio} per task. High retry counts may indicate ambiguous specs or flaky tests.")
fi

# Check Phi scores
for i in "${!ALL_PROJ_PHIS[@]}"; do
  local_phi="${ALL_PROJ_PHIS[$i]}"
  if [[ "$local_phi" == "-" ]]; then continue; fi
  phi_int=$(echo "$local_phi" | awk '{printf "%d", $1 * 100}')
  if [[ $phi_int -lt 30 ]]; then
    RECS+=("${RED}*${NC} ${ALL_PROJ_NAMES[$i]}: Low Phi (${local_phi}) -- modules may be too isolated. Review integration points.")
  elif [[ $phi_int -ge 80 ]]; then
    RECS+=("${GREEN}*${NC} ${ALL_PROJ_NAMES[$i]}: Excellent Phi (${local_phi}) -- strong integration across stages.")
  fi
done

# Check time distribution
total_time_all=0
for t in "${ALL_PROJ_TIMES[@]}"; do
  total_time_all=$((total_time_all + t))
done
if [[ $total_tasks -gt 0 ]]; then
  avg_time=$(( total_time_all / total_tasks ))
  if [[ $avg_time -gt 600 ]]; then
    RECS+=("${YELLOW}*${NC} Average task time over 10 minutes. Consider splitting long-running tasks.")
  fi
fi

if [[ ${#RECS[@]} -eq 0 ]]; then
  RECS+=("${GREEN}*${NC} No specific recommendations -- metrics look healthy across the board.")
fi

for rec in "${RECS[@]}"; do
  echo -e "  $rec"
done

echo ""
draw_hr 78
echo -e "${DIM}  Dashboard generated by Jarvis Development Methodology${NC}"
echo ""
