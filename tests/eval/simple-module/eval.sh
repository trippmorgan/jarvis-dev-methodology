#!/usr/bin/env bash
set -euo pipefail

# Eval: simple-module — Calculator class with TDD
# Scores file existence, test presence, test passing, and pattern checks (25 pts each)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORE=0

usage() {
    echo -e "${BOLD}Usage:${RESET} $(basename "$0") [OPTIONS]"
    echo ""
    echo "Evaluate the simple-module (Calculator) eval scenario."
    echo ""
    echo "Options:"
    echo "  --help    Show this help message and exit"
    echo ""
    echo "Scoring (0-100):"
    echo "  File existence .... 25 pts"
    echo "  Tests exist ....... 25 pts"
    echo "  Tests pass ........ 25 pts"
    echo "  Pattern checks .... 25 pts"
    exit 0
}

[[ "${1:-}" == "--help" ]] && usage

header() {
    echo -e "\n${BLUE}${BOLD}=== $1 ===${RESET}"
}

pass() {
    echo -e "  ${GREEN}PASS${RESET} $1"
}

fail() {
    echo -e "  ${RED}FAIL${RESET} $1"
}

# ── Section 1: File Existence (25 pts) ──────────────────────────────────────

header "Section 1: File Existence (25 pts)"

file_score=0

if [[ -f "$SCRIPT_DIR/calculator.py" ]]; then
    pass "calculator.py exists"
    file_score=$((file_score + 13))
else
    fail "calculator.py not found"
fi

if [[ -f "$SCRIPT_DIR/test_calculator.py" ]]; then
    pass "test_calculator.py exists"
    file_score=$((file_score + 12))
else
    fail "test_calculator.py not found"
fi

SCORE=$((SCORE + file_score))
echo -e "  ${YELLOW}Section score: ${file_score}/25${RESET}"

# ── Section 2: Tests Exist (25 pts) ─────────────────────────────────────────

header "Section 2: Test Definitions (25 pts)"

test_def_score=0

if [[ -f "$SCRIPT_DIR/test_calculator.py" ]]; then
    test_count=$(grep -c "def test_" "$SCRIPT_DIR/test_calculator.py" || true)
    if (( test_count >= 8 )); then
        pass "Found $test_count test functions (>= 8)"
        test_def_score=$((test_def_score + 15))
    elif (( test_count >= 4 )); then
        pass "Found $test_count test functions (>= 4, bonus for 8+)"
        test_def_score=$((test_def_score + 10))
    elif (( test_count >= 1 )); then
        pass "Found $test_count test function(s) (minimum met)"
        test_def_score=$((test_def_score + 5))
    else
        fail "No test functions found"
    fi

    if grep -q "ZeroDivisionError\|divide.*zero\|zero.*divide" "$SCRIPT_DIR/test_calculator.py"; then
        pass "Division by zero test exists"
        test_def_score=$((test_def_score + 10))
    else
        fail "No division by zero test found"
    fi
else
    fail "test_calculator.py not found — skipping test definition checks"
fi

SCORE=$((SCORE + test_def_score))
echo -e "  ${YELLOW}Section score: ${test_def_score}/25${RESET}"

# ── Section 3: Tests Pass (25 pts) ──────────────────────────────────────────

header "Section 3: Tests Pass (25 pts)"

test_pass_score=0

if [[ -f "$SCRIPT_DIR/test_calculator.py" && -f "$SCRIPT_DIR/calculator.py" ]]; then
    pushd "$SCRIPT_DIR" > /dev/null
    if python3 -m pytest test_calculator.py -v --tb=short 2>&1; then
        pass "All tests pass"
        test_pass_score=25
    else
        fail "Some tests failed"
        # Partial credit: count passed vs total
        passed=$(python3 -m pytest test_calculator.py --tb=no -q 2>&1 | grep -oP '^\d+(?= passed)' || echo "0")
        total=$(python3 -m pytest test_calculator.py --tb=no -q 2>&1 | grep -oP '\d+(?= (passed|failed))' | head -1 || echo "0")
        if (( total > 0 )); then
            test_pass_score=$(( 25 * passed / total ))
            echo -e "  ${YELLOW}Partial: ${passed}/${total} passed${RESET}"
        fi
    fi
    popd > /dev/null
else
    fail "Required files missing — cannot run tests"
fi

SCORE=$((SCORE + test_pass_score))
echo -e "  ${YELLOW}Section score: ${test_pass_score}/25${RESET}"

# ── Section 4: Pattern Checks (25 pts) ──────────────────────────────────────

header "Section 4: Pattern Checks (25 pts)"

pattern_score=0

if [[ -f "$SCRIPT_DIR/calculator.py" ]]; then
    if grep -q "class Calculator" "$SCRIPT_DIR/calculator.py"; then
        pass "Calculator class defined"
        pattern_score=$((pattern_score + 7))
    else
        fail "Calculator class not found"
    fi

    for method in add subtract multiply divide; do
        if grep -q "def ${method}" "$SCRIPT_DIR/calculator.py"; then
            pass "Method '${method}' defined"
            pattern_score=$((pattern_score + 4))
        else
            fail "Method '${method}' not found"
        fi
    done

    if grep -q "ZeroDivisionError\|raise.*Zero\|b == 0\|b != 0" "$SCRIPT_DIR/calculator.py"; then
        pass "Zero-division guard present"
        pattern_score=$((pattern_score + 2))
    else
        fail "No zero-division guard found"
    fi
else
    fail "calculator.py not found — skipping pattern checks"
fi

SCORE=$((SCORE + pattern_score))
echo -e "  ${YELLOW}Section score: ${pattern_score}/25${RESET}"

# ── Final Score ──────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}════════════════════════════════════${RESET}"
if (( SCORE >= 90 )); then
    echo -e "${GREEN}${BOLD}  SCORE: ${SCORE}/100  — PASS${RESET}"
elif (( SCORE >= 60 )); then
    echo -e "${YELLOW}${BOLD}  SCORE: ${SCORE}/100  — PARTIAL${RESET}"
else
    echo -e "${RED}${BOLD}  SCORE: ${SCORE}/100  — FAIL${RESET}"
fi
echo -e "${BOLD}════════════════════════════════════${RESET}"
echo ""

if (( SCORE >= 90 )); then
    exit 0
else
    exit 1
fi
