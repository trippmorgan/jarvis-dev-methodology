#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# trace-analyzer.sh — Analyze execution traces across projects
# Reads TRACES.md files, clusters failure patterns, identifies outliers,
# compares model performance, and produces markdown or JSON reports
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

JSON_MODE=0
TRACE_FILES=()

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") /path/to/project [/path/to/project2 ...] [--json]

Analyze execution traces from one or more projects. Reads .planning/TRACES.md
files and produces a diagnostic report: failure clusters, token-heavy tasks,
time outliers, model comparison, and recommendations.

${BOLD}Arguments:${NC}
  /path/to/project     Project directory (must contain .planning/TRACES.md)
                       OR direct path to a TRACES.md file
                       Multiple projects supported

${BOLD}Options:${NC}
  --json               Output machine-readable JSON instead of markdown
  --help, -h           Show this help message

${BOLD}Analysis:${NC}
  - Pass/fail rates per project and aggregate
  - Failure pattern clustering (by error type, task, model)
  - Token-heavy tasks (>10k tokens)
  - Time outliers (>5min execution)
  - Tasks requiring retries
  - Model performance comparison
  - Phi integration score trends

${BOLD}Examples:${NC}
  $(basename "$0") /home/user/my-app
  $(basename "$0") ./project-a ./project-b --json
  $(basename "$0") /path/to/TRACES.md
EOF
}

# --- Argument parsing ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error:${NC} Missing required argument: project path or TRACES.md path" >&2
  usage >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_MODE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      # Resolve to TRACES.md
      resolved="$(realpath "$1" 2>/dev/null || echo "$1")"
      if [[ -f "$resolved" && "$(basename "$resolved")" == "TRACES.md" ]]; then
        TRACE_FILES+=("$resolved")
      elif [[ -d "$resolved" && -f "$resolved/.planning/TRACES.md" ]]; then
        TRACE_FILES+=("$resolved/.planning/TRACES.md")
      else
        echo -e "${RED}Error:${NC} No TRACES.md found at $resolved or $resolved/.planning/TRACES.md" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ ${#TRACE_FILES[@]} -eq 0 ]]; then
  echo -e "${RED}Error:${NC} No trace files found" >&2
  exit 1
fi

# =============================================================================
# Parsing helpers
# =============================================================================

# Convert time string (2m, 2m30s, 45s, 3m20s) to total seconds
parse_time_to_seconds() {
  local t="$1"
  local minutes=0
  local seconds=0

  if [[ "$t" =~ ^([0-9]+)m([0-9]+)s$ ]]; then
    minutes="${BASH_REMATCH[1]}"
    seconds="${BASH_REMATCH[2]}"
  elif [[ "$t" =~ ^([0-9]+)m$ ]]; then
    minutes="${BASH_REMATCH[1]}"
  elif [[ "$t" =~ ^([0-9]+)s$ ]]; then
    seconds="${BASH_REMATCH[1]}"
  else
    echo "0"
    return
  fi

  echo $(( minutes * 60 + seconds ))
}

# Format seconds back to human-readable
format_seconds() {
  local s="$1"
  if [[ $s -ge 60 ]]; then
    local m=$((s / 60))
    local r=$((s % 60))
    if [[ $r -gt 0 ]]; then
      echo "${m}m${r}s"
    else
      echo "${m}m"
    fi
  else
    echo "${s}s"
  fi
}

# Parse token value (plain number or with k suffix)
parse_tokens() {
  local t="$1"
  t=$(echo "$t" | xargs)
  if [[ "$t" =~ ^([0-9]+)k$ ]]; then
    echo $(( ${BASH_REMATCH[1]} * 1000 ))
  elif [[ "$t" =~ ^[0-9]+$ ]]; then
    echo "$t"
  else
    echo "0"
  fi
}

# Extract project name from TRACES.md header
get_project_name() {
  local file="$1"
  local name
  name=$(grep -m1 '^# Execution Traces:' "$file" 2>/dev/null | sed 's/^# Execution Traces:[[:space:]]*//' || true)
  if [[ -z "$name" ]]; then
    # Fall back to directory name
    name=$(basename "$(dirname "$(dirname "$file")")")
  fi
  echo "$name"
}

# =============================================================================
# Data collection — parse all trace files
# =============================================================================

# Aggregate arrays (stored as newline-delimited strings for bash compat)
ALL_TASKS=""         # project|task|status|retries|time_s|model|tokens|notes
ALL_PHI=""           # project|stage|score|label|notes
ALL_FAILURES=""      # project|task|model|notes
TOTAL_PROJECTS=0

for trace_file in "${TRACE_FILES[@]}"; do
  TOTAL_PROJECTS=$((TOTAL_PROJECTS + 1))
  proj_name=$(get_project_name "$trace_file")

  # Parse task rows: lines matching | <number> | ... |
  while IFS='|' read -r _ task status retries time model tokens notes _; do
    task=$(echo "$task" | xargs)
    status=$(echo "$status" | xargs)
    retries=$(echo "$retries" | xargs)
    time=$(echo "$time" | xargs)
    model=$(echo "$model" | xargs)
    tokens=$(echo "$tokens" | xargs)
    notes=$(echo "$notes" | xargs)

    [[ -z "$task" || ! "$task" =~ ^[0-9]+$ ]] && continue

    time_s=$(parse_time_to_seconds "$time")
    token_n=$(parse_tokens "$tokens")

    ALL_TASKS+="${proj_name}|${task}|${status}|${retries}|${time_s}|${model}|${token_n}|${notes}"$'\n'

    # Collect failures
    if [[ "$status" == "FAIL" || "$status" == "FAIL->PASS" || "$status" == "FAIL"*"PASS" ]]; then
      ALL_FAILURES+="${proj_name}|${task}|${model}|${notes}"$'\n'
    fi
  done < <(grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$trace_file" || true)

  # Parse phi rows
  while IFS='|' read -r _ stage score label phi_notes _; do
    stage=$(echo "$stage" | xargs)
    score=$(echo "$score" | xargs)
    label=$(echo "$label" | xargs)
    phi_notes=$(echo "$phi_notes" | xargs)

    [[ -z "$stage" ]] && continue
    case "$stage" in
      spec|plan|execute|review|verify) ;;
      *) continue ;;
    esac

    ALL_PHI+="${proj_name}|${stage}|${score}|${label}|${phi_notes}"$'\n'
  done < <(grep -E '^\|[[:space:]]*(spec|plan|execute|review|verify)[[:space:]]*\|' "$trace_file" || true)
done

# Remove trailing newlines
ALL_TASKS=$(echo "$ALL_TASKS" | sed '/^$/d')
ALL_PHI=$(echo "$ALL_PHI" | sed '/^$/d')
ALL_FAILURES=$(echo "$ALL_FAILURES" | sed '/^$/d')

# =============================================================================
# Compute statistics
# =============================================================================

TOTAL_TASKS=0
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_RETRIED=0
TOTAL_TOKENS=0
TOTAL_TIME=0
TOKEN_HEAVY=""       # tasks with >10k tokens
TIME_OUTLIERS=""     # tasks with >5min
RETRY_TASKS=""       # tasks with retries > 0

# Model stats: model -> count|pass|tokens|time
declare -A MODEL_COUNT=()
declare -A MODEL_PASS=()
declare -A MODEL_TOKENS=()
declare -A MODEL_TIME=()

while IFS='|' read -r proj task status retries time_s model token_n notes; do
  [[ -z "$task" ]] && continue

  TOTAL_TASKS=$((TOTAL_TASKS + 1))
  TOTAL_TOKENS=$((TOTAL_TOKENS + token_n))
  TOTAL_TIME=$((TOTAL_TIME + time_s))

  if [[ "$status" == "PASS" ]]; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi

  if [[ "$retries" -gt 0 ]]; then
    TOTAL_RETRIED=$((TOTAL_RETRIED + 1))
    RETRY_TASKS+="${proj}|${task}|${retries}|${model}|${notes}"$'\n'
  fi

  if [[ $token_n -gt 10000 ]]; then
    TOKEN_HEAVY+="${proj}|${task}|${token_n}|${model}|${notes}"$'\n'
  fi

  if [[ $time_s -gt 300 ]]; then
    TIME_OUTLIERS+="${proj}|${task}|${time_s}|${model}|${notes}"$'\n'
  fi

  # Model tracking
  if [[ -n "$model" && "$model" != "-" ]]; then
    MODEL_COUNT[$model]=$(( ${MODEL_COUNT[$model]:-0} + 1 ))
    if [[ "$status" == "PASS" ]]; then
      MODEL_PASS[$model]=$(( ${MODEL_PASS[$model]:-0} + 1 ))
    fi
    MODEL_TOKENS[$model]=$(( ${MODEL_TOKENS[$model]:-0} + token_n ))
    MODEL_TIME[$model]=$(( ${MODEL_TIME[$model]:-0} + time_s ))
  fi
done <<< "$ALL_TASKS"

# Clean up trailing newlines
TOKEN_HEAVY=$(echo "$TOKEN_HEAVY" | sed '/^$/d')
TIME_OUTLIERS=$(echo "$TIME_OUTLIERS" | sed '/^$/d')
RETRY_TASKS=$(echo "$RETRY_TASKS" | sed '/^$/d')

# =============================================================================
# Generate recommendations
# =============================================================================

RECOMMENDATIONS=()

if [[ $TOTAL_TASKS -gt 0 ]]; then
  pass_pct=$(( (TOTAL_PASS * 100) / TOTAL_TASKS ))

  if [[ $pass_pct -lt 80 ]]; then
    RECOMMENDATIONS+=("Pass rate is ${pass_pct}% — consider breaking complex tasks into smaller units or adding clearer acceptance criteria")
  fi

  if [[ -n "$TOKEN_HEAVY" ]]; then
    heavy_count=$(echo "$TOKEN_HEAVY" | wc -l)
    RECOMMENDATIONS+=("${heavy_count} task(s) exceeded 10k tokens — review for scope creep or overly broad task definitions")
  fi

  if [[ -n "$TIME_OUTLIERS" ]]; then
    outlier_count=$(echo "$TIME_OUTLIERS" | wc -l)
    RECOMMENDATIONS+=("${outlier_count} task(s) exceeded 5 minutes — investigate for blocking operations or retry loops")
  fi

  if [[ -n "$RETRY_TASKS" ]]; then
    retry_count=$(echo "$RETRY_TASKS" | wc -l)
    RECOMMENDATIONS+=("${retry_count} task(s) required retries — review failure patterns for systemic issues")
  fi

  avg_tokens=0
  if [[ $TOTAL_TOKENS -gt 0 ]]; then
    avg_tokens=$((TOTAL_TOKENS / TOTAL_TASKS))
  fi
  if [[ $avg_tokens -gt 8000 ]]; then
    RECOMMENDATIONS+=("Average token usage is ${avg_tokens} per task — consider more focused task scoping to reduce cost")
  fi
fi

if [[ -z "$ALL_PHI" ]]; then
  RECOMMENDATIONS+=("No Phi integration scores found — consider adding Phi scoring to track build quality over time")
fi

if [[ $TOTAL_TASKS -eq 0 ]]; then
  RECOMMENDATIONS+=("No task data found in provided trace files")
fi

if [[ ${#RECOMMENDATIONS[@]} -eq 0 ]]; then
  RECOMMENDATIONS+=("All metrics look healthy — no issues detected")
fi

# =============================================================================
# Output: JSON mode
# =============================================================================

if [[ $JSON_MODE -eq 1 ]]; then
  # Build JSON manually (no jq dependency required)

  # --- Projects array ---
  json_projects="["
  first_proj=1
  for trace_file in "${TRACE_FILES[@]}"; do
    proj_name=$(get_project_name "$trace_file")

    # Per-project stats
    p_total=0; p_pass=0; p_tokens=0; p_time=0
    p_tasks_json="["
    first_task=1

    while IFS='|' read -r proj task status retries time_s model token_n notes; do
      [[ -z "$task" ]] && continue
      [[ "$proj" != "$proj_name" ]] && continue

      p_total=$((p_total + 1))
      [[ "$status" == "PASS" ]] && p_pass=$((p_pass + 1))
      p_tokens=$((p_tokens + token_n))
      p_time=$((p_time + time_s))

      [[ $first_task -eq 0 ]] && p_tasks_json+=","
      first_task=0

      # Escape notes for JSON
      json_notes=$(echo "$notes" | sed 's/\\/\\\\/g; s/"/\\"/g')
      p_tasks_json+="{\"task\":${task},\"status\":\"${status}\",\"retries\":${retries},\"time_seconds\":${time_s},\"model\":\"${model}\",\"tokens\":${token_n},\"notes\":\"${json_notes}\"}"
    done <<< "$ALL_TASKS"

    p_tasks_json+="]"

    # Pass rate
    p_pass_rate=0
    if [[ $p_total -gt 0 ]]; then
      p_pass_rate=$(( (p_pass * 100) / p_total ))
    fi

    # Phi scores for this project
    p_phi_json="{"
    first_phi=1
    while IFS='|' read -r proj stage score label phi_notes; do
      [[ -z "$stage" ]] && continue
      [[ "$proj" != "$proj_name" ]] && continue

      [[ $first_phi -eq 0 ]] && p_phi_json+=","
      first_phi=0

      json_phi_notes=$(echo "$phi_notes" | sed 's/\\/\\\\/g; s/"/\\"/g')
      p_phi_json+="\"${stage}\":{\"score\":${score},\"label\":\"${label}\",\"notes\":\"${json_phi_notes}\"}"
    done <<< "${ALL_PHI:-}"

    p_phi_json+="}"

    [[ $first_proj -eq 0 ]] && json_projects+=","
    first_proj=0

    json_proj_name=$(echo "$proj_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    json_projects+="{\"name\":\"${json_proj_name}\",\"tasks\":${p_tasks_json},\"total_tasks\":${p_total},\"pass_count\":${p_pass},\"pass_rate\":${p_pass_rate},\"total_tokens\":${p_tokens},\"total_time_seconds\":${p_time},\"phi_scores\":${p_phi_json}}"
  done
  json_projects+="]"

  # --- Failure patterns ---
  json_failures="["
  first_fail=1
  while IFS='|' read -r proj task model notes; do
    [[ -z "$task" ]] && continue

    [[ $first_fail -eq 0 ]] && json_failures+=","
    first_fail=0

    json_f_proj=$(echo "$proj" | sed 's/\\/\\\\/g; s/"/\\"/g')
    json_f_notes=$(echo "$notes" | sed 's/\\/\\\\/g; s/"/\\"/g')
    json_failures+="{\"project\":\"${json_f_proj}\",\"task\":${task},\"model\":\"${model}\",\"notes\":\"${json_f_notes}\"}"
  done <<< "${ALL_FAILURES:-}"
  json_failures+="]"

  # --- Recommendations ---
  json_recs="["
  first_rec=1
  for rec in "${RECOMMENDATIONS[@]}"; do
    [[ $first_rec -eq 0 ]] && json_recs+=","
    first_rec=0
    json_rec=$(echo "$rec" | sed 's/\\/\\\\/g; s/"/\\"/g')
    json_recs+="\"${json_rec}\""
  done
  json_recs+="]"

  # --- Model stats ---
  json_models="{"
  first_model=1
  for model in "${!MODEL_COUNT[@]}"; do
    [[ $first_model -eq 0 ]] && json_models+=","
    first_model=0

    m_count=${MODEL_COUNT[$model]}
    m_pass=${MODEL_PASS[$model]:-0}
    m_tokens=${MODEL_TOKENS[$model]:-0}
    m_time=${MODEL_TIME[$model]:-0}
    m_pass_rate=0
    m_avg_tokens=0
    m_avg_time=0

    if [[ $m_count -gt 0 ]]; then
      m_pass_rate=$(( (m_pass * 100) / m_count ))
      m_avg_tokens=$((m_tokens / m_count))
      m_avg_time=$((m_time / m_count))
    fi

    json_models+="\"${model}\":{\"tasks\":${m_count},\"pass_count\":${m_pass},\"pass_rate\":${m_pass_rate},\"total_tokens\":${m_tokens},\"avg_tokens\":${m_avg_tokens},\"total_time_seconds\":${m_time},\"avg_time_seconds\":${m_avg_time}}"
  done
  json_models+="}"

  # --- Aggregate ---
  avg_tokens_all=0
  avg_time_all=0
  agg_pass_rate=0
  if [[ $TOTAL_TASKS -gt 0 ]]; then
    avg_tokens_all=$((TOTAL_TOKENS / TOTAL_TASKS))
    avg_time_all=$((TOTAL_TIME / TOTAL_TASKS))
    agg_pass_rate=$(( (TOTAL_PASS * 100) / TOTAL_TASKS ))
  fi

  cat <<ENDJSON
{
  "projects": ${json_projects},
  "aggregate": {
    "total_projects": ${TOTAL_PROJECTS},
    "total_tasks": ${TOTAL_TASKS},
    "total_pass": ${TOTAL_PASS},
    "total_fail": ${TOTAL_FAIL},
    "pass_rate": ${agg_pass_rate},
    "total_tokens": ${TOTAL_TOKENS},
    "avg_tokens_per_task": ${avg_tokens_all},
    "total_time_seconds": ${TOTAL_TIME},
    "avg_time_seconds": ${avg_time_all},
    "tasks_with_retries": ${TOTAL_RETRIED}
  },
  "model_stats": ${json_models},
  "failure_patterns": ${json_failures},
  "recommendations": ${json_recs}
}
ENDJSON
  exit 0
fi

# =============================================================================
# Output: Markdown mode
# =============================================================================

echo "# Trace Analysis Report"
echo ""
echo "> Generated: $(date +%Y-%m-%d)"
echo "> Projects analyzed: ${TOTAL_PROJECTS}"
echo ""

# --- Aggregate summary ---
echo "## Aggregate Summary"
echo ""
echo "| Metric | Value |"
echo "|--------|-------|"
echo "| Total projects | ${TOTAL_PROJECTS} |"
echo "| Total tasks | ${TOTAL_TASKS} |"

if [[ $TOTAL_TASKS -gt 0 ]]; then
  agg_pass_rate=$(( (TOTAL_PASS * 100) / TOTAL_TASKS ))
  avg_tokens_all=$((TOTAL_TOKENS / TOTAL_TASKS))
  avg_time_all=$((TOTAL_TIME / TOTAL_TASKS))

  echo "| Pass (first try) | ${TOTAL_PASS} |"
  echo "| Fail / retried | ${TOTAL_FAIL} |"
  echo "| Pass rate | ${agg_pass_rate}% |"
  echo "| Total tokens | ${TOTAL_TOKENS} |"
  echo "| Avg tokens/task | ${avg_tokens_all} |"
  echo "| Total time | $(format_seconds $TOTAL_TIME) |"
  echo "| Avg time/task | $(format_seconds $avg_time_all) |"
  echo "| Tasks with retries | ${TOTAL_RETRIED} |"
fi
echo ""

# --- Per-project breakdown ---
echo "## Per-Project Breakdown"
echo ""

for trace_file in "${TRACE_FILES[@]}"; do
  proj_name=$(get_project_name "$trace_file")

  echo "### ${proj_name}"
  echo ""
  echo "| Task | Status | Retries | Time | Model | Tokens | Notes |"
  echo "|------|--------|---------|------|-------|--------|-------|"

  while IFS='|' read -r proj task status retries time_s model token_n notes; do
    [[ -z "$task" ]] && continue
    [[ "$proj" != "$proj_name" ]] && continue

    time_fmt=$(format_seconds "$time_s")
    echo "| ${task} | ${status} | ${retries} | ${time_fmt} | ${model} | ${token_n} | ${notes} |"
  done <<< "$ALL_TASKS"

  # Per-project pass rate
  p_total=0; p_pass=0
  while IFS='|' read -r proj task status _ _ _ _ _; do
    [[ -z "$task" ]] && continue
    [[ "$proj" != "$proj_name" ]] && continue
    p_total=$((p_total + 1))
    [[ "$status" == "PASS" ]] && p_pass=$((p_pass + 1))
  done <<< "$ALL_TASKS"

  if [[ $p_total -gt 0 ]]; then
    p_rate=$(( (p_pass * 100) / p_total ))
    echo ""
    echo "**Pass rate:** ${p_rate}% (${p_pass}/${p_total})"
  fi

  # Phi scores for this project
  has_phi=0
  while IFS='|' read -r proj stage score label phi_notes; do
    [[ -z "$stage" ]] && continue
    [[ "$proj" != "$proj_name" ]] && continue

    if [[ $has_phi -eq 0 ]]; then
      echo ""
      echo "**Phi Integration Scores:**"
      echo ""
      echo "| Stage | Score | Label | Notes |"
      echo "|-------|-------|-------|-------|"
      has_phi=1
    fi

    echo "| ${stage} | ${score} | ${label} | ${phi_notes} |"
  done <<< "${ALL_PHI:-}"

  echo ""
done

# --- Failure patterns ---
echo "## Failure Patterns"
echo ""

if [[ -z "$ALL_FAILURES" ]]; then
  echo "No failures found across any project. Clean execution."
  echo ""
else
  echo "| Project | Task | Model | Notes |"
  echo "|---------|------|-------|-------|"

  while IFS='|' read -r proj task model notes; do
    [[ -z "$task" ]] && continue
    echo "| ${proj} | ${task} | ${model} | ${notes} |"
  done <<< "$ALL_FAILURES"

  echo ""

  # Cluster by model
  echo "### Failures by Model"
  echo ""
  declare -A FAIL_BY_MODEL=()
  while IFS='|' read -r _ _ model _; do
    [[ -z "$model" || "$model" == "-" ]] && continue
    FAIL_BY_MODEL[$model]=$(( ${FAIL_BY_MODEL[$model]:-0} + 1 ))
  done <<< "$ALL_FAILURES"

  for model in "${!FAIL_BY_MODEL[@]}"; do
    echo "- **${model}:** ${FAIL_BY_MODEL[$model]} failure(s)"
  done
  echo ""
fi

# --- Token-heavy tasks ---
echo "## Token-Heavy Tasks (>10k)"
echo ""

if [[ -z "$TOKEN_HEAVY" ]]; then
  echo "No tasks exceeded the 10k token threshold."
  echo ""
else
  echo "| Project | Task | Tokens | Model | Notes |"
  echo "|---------|------|--------|-------|-------|"

  while IFS='|' read -r proj task token_n model notes; do
    [[ -z "$task" ]] && continue
    echo "| ${proj} | ${task} | ${token_n} | ${model} | ${notes} |"
  done <<< "$TOKEN_HEAVY"

  echo ""
fi

# --- Time outliers ---
echo "## Time Outliers (>5min)"
echo ""

if [[ -z "$TIME_OUTLIERS" ]]; then
  echo "No tasks exceeded the 5-minute threshold."
  echo ""
else
  echo "| Project | Task | Time | Model | Notes |"
  echo "|---------|------|------|-------|-------|"

  while IFS='|' read -r proj task time_s model notes; do
    [[ -z "$task" ]] && continue
    echo "| ${proj} | ${task} | $(format_seconds "$time_s") | ${model} | ${notes} |"
  done <<< "$TIME_OUTLIERS"

  echo ""
fi

# --- Retry tasks ---
echo "## Tasks Requiring Retries"
echo ""

if [[ -z "$RETRY_TASKS" ]]; then
  echo "No tasks required retries. First-pass success across the board."
  echo ""
else
  echo "| Project | Task | Retries | Model | Notes |"
  echo "|---------|------|---------|-------|-------|"

  while IFS='|' read -r proj task retries model notes; do
    [[ -z "$task" ]] && continue
    echo "| ${proj} | ${task} | ${retries} | ${model} | ${notes} |"
  done <<< "$RETRY_TASKS"

  echo ""
fi

# --- Model comparison ---
echo "## Model Performance Comparison"
echo ""

if [[ ${#MODEL_COUNT[@]} -eq 0 ]]; then
  echo "No model data available."
  echo ""
else
  echo "| Model | Tasks | Pass Rate | Avg Tokens | Avg Time |"
  echo "|-------|-------|-----------|------------|----------|"

  for model in "${!MODEL_COUNT[@]}"; do
    m_count=${MODEL_COUNT[$model]}
    m_pass=${MODEL_PASS[$model]:-0}
    m_tokens=${MODEL_TOKENS[$model]:-0}
    m_time=${MODEL_TIME[$model]:-0}

    m_pass_rate=0
    m_avg_tokens=0
    m_avg_time=0

    if [[ $m_count -gt 0 ]]; then
      m_pass_rate=$(( (m_pass * 100) / m_count ))
      m_avg_tokens=$((m_tokens / m_count))
      m_avg_time=$((m_time / m_count))
    fi

    echo "| ${model} | ${m_count} | ${m_pass_rate}% | ${m_avg_tokens} | $(format_seconds $m_avg_time) |"
  done

  echo ""
fi

# --- Recommendations ---
echo "## Recommendations"
echo ""

for rec in "${RECOMMENDATIONS[@]}"; do
  echo "- ${rec}"
done
echo ""
