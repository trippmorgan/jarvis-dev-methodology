#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# review-gate.sh — Automated review gate checker
# Runs tests, lint, type checks and reports gate status (PASS/FAIL)
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PHASE="execute"  # default phase: execute gate (tests + lint + types)

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") /path/to/project [--phase execute|review]

Run automated review gate checks on a project. Auto-detects the test
framework, linter, and type checker.

${BOLD}Arguments:${NC}
  /path/to/project   Path to the target project (must have .planning/)

${BOLD}Options:${NC}
  --phase PHASE      Gate phase to check (default: execute)
                       execute — tests pass, lint clean, type check
                       review  — all execute checks + spec compliance scan
  --help, -h         Show this help message

${BOLD}Checks:${NC}
  Tests:    npm test / pytest / go test / cargo test (auto-detected)
  Lint:     eslint / ruff / golangci-lint / clippy (auto-detected)
  Types:    tsc --noEmit / mypy / (auto-detected)

${BOLD}Output:${NC}
  Writes structured report to .planning/REVIEW-GATE.md
  Exit code: 0 = PASS, 1 = FAIL

${BOLD}Examples:${NC}
  $(basename "$0") /home/user/my-app
  $(basename "$0") . --phase review
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
    --phase)
      PHASE="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Error:${NC} Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

PLANNING_DIR="$PROJECT_DIR/.planning"
REPORT_FILE="$PLANNING_DIR/REVIEW-GATE.md"
DATE=$(date +%Y-%m-%d)
OVERALL_STATUS="PASS"
RESULTS=""
FAIL_COUNT=0
PASS_COUNT=0
SKIP_COUNT=0

# --- Validation ---
if [[ ! -d "$PLANNING_DIR" ]]; then
  echo -e "${RED}Error:${NC} No .planning/ directory found in $PROJECT_DIR" >&2
  echo -e "  Run ${BOLD}init-project.sh${NC} first." >&2
  exit 1
fi

echo -e "${BOLD}${CYAN}Review Gate — Phase: ${PHASE}${NC}"
echo -e "  Project: $PROJECT_DIR"
echo ""

# --- Helper: run a check and record result ---
run_check() {
  local name="$1"
  local cmd="$2"
  local output=""
  local status="PASS"

  echo -ne "  ${BOLD}${name}:${NC} "

  if [[ -z "$cmd" ]]; then
    echo -e "${YELLOW}SKIP${NC} (not detected)"
    RESULTS+="| $name | SKIP | Not detected |\n"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return
  fi

  # Run the command, capture output and exit code
  set +e
  output=$(cd "$PROJECT_DIR" && eval "$cmd" 2>&1)
  local exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    RESULTS+="| $name | ${GREEN}PASS${NC} | Clean |\n"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}FAIL${NC}"
    # Truncate output for report (keep last 20 lines)
    local truncated
    truncated=$(echo "$output" | tail -20)
    RESULTS+="| $name | FAIL | See details below |\n"
    RESULTS+="\n<details><summary>${name} output</summary>\n\n\`\`\`\n${truncated}\n\`\`\`\n</details>\n\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    OVERALL_STATUS="FAIL"
  fi
}

# --- Auto-detect test framework ---
detect_test_cmd() {
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    # Check for test script in package.json
    if grep -q '"test"' "$PROJECT_DIR/package.json" 2>/dev/null; then
      echo "npm test"
      return
    fi
  fi
  if [[ -f "$PROJECT_DIR/pytest.ini" || -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" || -f "$PROJECT_DIR/setup.cfg" ]]; then
    if command -v pytest &>/dev/null; then
      echo "pytest"
      return
    fi
  fi
  if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    echo "go test ./..."
    return
  fi
  if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    echo "cargo test"
    return
  fi
  if [[ -f "$PROJECT_DIR/Makefile" ]] && grep -q '^test:' "$PROJECT_DIR/Makefile" 2>/dev/null; then
    echo "make test"
    return
  fi
  echo ""
}

# --- Auto-detect linter ---
detect_lint_cmd() {
  if [[ -f "$PROJECT_DIR/.eslintrc.js" || -f "$PROJECT_DIR/.eslintrc.json" || -f "$PROJECT_DIR/.eslintrc.yml" || -f "$PROJECT_DIR/eslint.config.js" || -f "$PROJECT_DIR/eslint.config.mjs" ]]; then
    echo "npx eslint . --max-warnings 0"
    return
  fi
  if [[ -f "$PROJECT_DIR/package.json" ]] && grep -q '"lint"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    echo "npm run lint"
    return
  fi
  if [[ -f "$PROJECT_DIR/pyproject.toml" ]] && grep -q 'ruff' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    echo "ruff check ."
    return
  fi
  if command -v ruff &>/dev/null && [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" ]]; then
    echo "ruff check ."
    return
  fi
  if [[ -f "$PROJECT_DIR/go.mod" ]] && command -v golangci-lint &>/dev/null; then
    echo "golangci-lint run"
    return
  fi
  if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    echo "cargo clippy -- -D warnings"
    return
  fi
  echo ""
}

# --- Auto-detect type checker ---
detect_type_cmd() {
  if [[ -f "$PROJECT_DIR/tsconfig.json" ]]; then
    echo "npx tsc --noEmit"
    return
  fi
  if [[ -f "$PROJECT_DIR/pyproject.toml" ]] && grep -q 'mypy' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    echo "mypy ."
    return
  fi
  if command -v mypy &>/dev/null && [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" ]]; then
    echo "mypy ."
    return
  fi
  echo ""
}

# --- Run checks ---
TEST_CMD=$(detect_test_cmd)
LINT_CMD=$(detect_lint_cmd)
TYPE_CMD=$(detect_type_cmd)

echo -e "${BOLD}Detected tools:${NC}"
echo -e "  Tests: ${TEST_CMD:-"(none)"}"
echo -e "  Lint:  ${LINT_CMD:-"(none)"}"
echo -e "  Types: ${TYPE_CMD:-"(none)"}"
echo ""

echo -e "${BOLD}Running checks:${NC}"
run_check "Tests" "$TEST_CMD"
run_check "Lint" "$LINT_CMD"
run_check "Type Check" "$TYPE_CMD"

# Additional checks for review phase
if [[ "$PHASE" == "review" ]]; then
  echo ""
  echo -e "${BOLD}Review-phase checks:${NC}"

  # Check if SPEC.md exists and has content beyond template
  if [[ -f "$PLANNING_DIR/SPEC.md" ]]; then
    spec_todos=$(grep -c "TODO" "$PLANNING_DIR/SPEC.md" || true)
    if [[ $spec_todos -gt 3 ]]; then
      echo -e "  ${BOLD}Spec completeness:${NC} ${YELLOW}WARNING${NC} — SPEC.md has $spec_todos TODO markers"
      RESULTS+="| Spec Completeness | WARN | $spec_todos TODO markers remaining |\n"
    else
      echo -e "  ${BOLD}Spec completeness:${NC} ${GREEN}OK${NC}"
      RESULTS+="| Spec Completeness | PASS | Spec filled in |\n"
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
  fi

  # Check STATE.md for failed tasks
  if [[ -f "$PLANNING_DIR/STATE.md" ]]; then
    failed_tasks=$(grep -c "FAIL" "$PLANNING_DIR/STATE.md" || true)
    if [[ $failed_tasks -gt 0 ]]; then
      echo -e "  ${BOLD}Failed tasks:${NC} ${RED}FAIL${NC} — $failed_tasks task(s) still failing"
      RESULTS+="| Task Status | FAIL | $failed_tasks failed task(s) |\n"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      OVERALL_STATUS="FAIL"
    else
      echo -e "  ${BOLD}Failed tasks:${NC} ${GREEN}NONE${NC}"
      RESULTS+="| Task Status | PASS | No failed tasks |\n"
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
  fi
fi

# --- Write report ---
# Use plain text in the file (no ANSI codes)
CLEAN_RESULTS=$(echo -e "$RESULTS" | sed 's/\x1b\[[0-9;]*m//g')

cat > "$REPORT_FILE" <<EOF
# Review Gate Report

> Generated: $DATE
> Phase: $PHASE
> Project: $PROJECT_DIR

## Results

| Check | Status | Details |
|-------|--------|---------|
$(echo -e "$CLEAN_RESULTS")

## Summary
- Passed: $PASS_COUNT
- Failed: $FAIL_COUNT
- Skipped: $SKIP_COUNT

## Verdict: $OVERALL_STATUS
EOF

echo ""
echo -e "${BOLD}Report written to:${NC} $REPORT_FILE"
echo ""

# --- Final verdict ---
if [[ "$OVERALL_STATUS" == "PASS" ]]; then
  echo -e "${GREEN}${BOLD}GATE: PASS${NC}"
  echo -e "  All checks passed. Proceed to next phase."
  exit 0
else
  echo -e "${RED}${BOLD}GATE: FAIL${NC}"
  echo -e "  $FAIL_COUNT check(s) failed. Fix issues and re-run."
  exit 1
fi
