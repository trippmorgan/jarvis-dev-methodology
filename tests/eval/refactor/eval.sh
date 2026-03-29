#!/usr/bin/env bash
set -euo pipefail

# Eval: refactor — Break a ~100-line function into 3+ smaller functions
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
    echo "Evaluate the refactor (Processor) eval scenario."
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

if [[ -f "$SCRIPT_DIR/processor.py" ]]; then
    pass "processor.py exists (original monolith)"
    file_score=$((file_score + 8))
else
    fail "processor.py not found"
fi

if [[ -f "$SCRIPT_DIR/processor_refactored.py" ]]; then
    pass "processor_refactored.py exists (refactored)"
    file_score=$((file_score + 9))
else
    fail "processor_refactored.py not found"
fi

if [[ -f "$SCRIPT_DIR/test_processor.py" ]]; then
    pass "test_processor.py exists"
    file_score=$((file_score + 8))
else
    fail "test_processor.py not found"
fi

SCORE=$((SCORE + file_score))
echo -e "  ${YELLOW}Section score: ${file_score}/25${RESET}"

# ── Section 2: Tests Exist (25 pts) ─────────────────────────────────────────

header "Section 2: Test Definitions (25 pts)"

test_def_score=0

if [[ -f "$SCRIPT_DIR/test_processor.py" ]]; then
    test_count=$(grep -c "def test_" "$SCRIPT_DIR/test_processor.py" || true)
    if (( test_count >= 15 )); then
        pass "Found $test_count test functions (>= 15)"
        test_def_score=$((test_def_score + 15))
    elif (( test_count >= 8 )); then
        pass "Found $test_count test functions (>= 8)"
        test_def_score=$((test_def_score + 10))
    elif (( test_count >= 1 )); then
        pass "Found $test_count test function(s)"
        test_def_score=$((test_def_score + 5))
    else
        fail "No test functions found"
    fi

    # Test classes covering different concerns
    class_count=$(grep -c "class Test" "$SCRIPT_DIR/test_processor.py" || true)
    if (( class_count >= 3 )); then
        pass "Found $class_count test classes (>= 3 concerns covered)"
        test_def_score=$((test_def_score + 10))
    elif (( class_count >= 1 )); then
        pass "Found $class_count test class(es)"
        test_def_score=$((test_def_score + 5))
    else
        fail "No test classes found"
    fi
else
    fail "test_processor.py not found — skipping test definition checks"
fi

SCORE=$((SCORE + test_def_score))
echo -e "  ${YELLOW}Section score: ${test_def_score}/25${RESET}"

# ── Section 3: Tests Pass (25 pts) ──────────────────────────────────────────

header "Section 3: Tests Pass (25 pts)"

test_pass_score=0

if [[ -f "$SCRIPT_DIR/test_processor.py" && -f "$SCRIPT_DIR/processor_refactored.py" ]]; then
    pushd "$SCRIPT_DIR" > /dev/null
    if python3 -m pytest test_processor.py -v --tb=short 2>&1; then
        pass "All tests pass against refactored version"
        test_pass_score=25
    else
        fail "Some tests failed"
        passed=$(python3 -m pytest test_processor.py --tb=no -q 2>&1 | grep -oP '^\d+(?= passed)' || echo "0")
        total_line=$(python3 -m pytest test_processor.py --tb=no -q 2>&1 | tail -1)
        total=$(echo "$total_line" | grep -oP '\d+' | head -1 || echo "0")
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

if [[ -f "$SCRIPT_DIR/processor_refactored.py" ]]; then
    # Count defined functions (excluding process_data itself)
    func_count=$(grep -c "^def \|^    def " "$SCRIPT_DIR/processor_refactored.py" || true)
    non_main_funcs=$((func_count - 1))  # subtract process_data

    if (( non_main_funcs >= 3 )); then
        pass "Refactored into $non_main_funcs helper functions (>= 3)"
        pattern_score=$((pattern_score + 10))
    elif (( non_main_funcs >= 2 )); then
        pass "Refactored into $non_main_funcs helper functions (partial)"
        pattern_score=$((pattern_score + 5))
    else
        fail "Only $non_main_funcs helper functions found (need >= 3)"
    fi

    # Main entry point still exists
    if grep -q "def process_data" "$SCRIPT_DIR/processor_refactored.py"; then
        pass "process_data entry point preserved"
        pattern_score=$((pattern_score + 5))
    else
        fail "process_data entry point missing"
    fi

    # Docstrings on helper functions
    docstring_count=$(grep -c '"""' "$SCRIPT_DIR/processor_refactored.py" || true)
    if (( docstring_count >= 6 )); then
        pass "Functions have docstrings ($docstring_count triple-quote blocks)"
        pattern_score=$((pattern_score + 5))
    else
        fail "Insufficient docstrings ($docstring_count found, expected >= 6)"
    fi

    # Original monolith should have only 1 function
    if [[ -f "$SCRIPT_DIR/processor.py" ]]; then
        orig_func_count=$(grep -c "^def " "$SCRIPT_DIR/processor.py" || true)
        if (( orig_func_count == 1 )); then
            pass "Original processor.py has single monolithic function"
            pattern_score=$((pattern_score + 5))
        else
            fail "Original processor.py has $orig_func_count functions (expected 1)"
        fi
    fi
else
    fail "processor_refactored.py not found — skipping pattern checks"
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
