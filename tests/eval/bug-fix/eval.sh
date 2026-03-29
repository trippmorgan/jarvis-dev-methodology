#!/usr/bin/env bash
set -euo pipefail

# Eval: bug-fix — Fix sort function that returns None
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
    echo "Evaluate the bug-fix (Sorter) eval scenario."
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

if [[ -f "$SCRIPT_DIR/sorter.py" ]]; then
    pass "sorter.py exists (buggy original)"
    file_score=$((file_score + 8))
else
    fail "sorter.py not found"
fi

if [[ -f "$SCRIPT_DIR/sorter_fixed.py" ]]; then
    pass "sorter_fixed.py exists (fixed version)"
    file_score=$((file_score + 9))
else
    fail "sorter_fixed.py not found"
fi

if [[ -f "$SCRIPT_DIR/test_sorter.py" ]]; then
    pass "test_sorter.py exists"
    file_score=$((file_score + 8))
else
    fail "test_sorter.py not found"
fi

SCORE=$((SCORE + file_score))
echo -e "  ${YELLOW}Section score: ${file_score}/25${RESET}"

# ── Section 2: Tests Exist (25 pts) ─────────────────────────────────────────

header "Section 2: Test Definitions (25 pts)"

test_def_score=0

if [[ -f "$SCRIPT_DIR/test_sorter.py" ]]; then
    test_count=$(grep -c "def test_" "$SCRIPT_DIR/test_sorter.py" || true)
    if (( test_count >= 8 )); then
        pass "Found $test_count test functions (>= 8)"
        test_def_score=$((test_def_score + 15))
    elif (( test_count >= 4 )); then
        pass "Found $test_count test functions (>= 4)"
        test_def_score=$((test_def_score + 10))
    elif (( test_count >= 1 )); then
        pass "Found $test_count test function(s)"
        test_def_score=$((test_def_score + 5))
    else
        fail "No test functions found"
    fi

    # Regression test: must explicitly check for None
    if grep -q "is not None\|!= None\|assert.*not.*None\|returned None" "$SCRIPT_DIR/test_sorter.py"; then
        pass "Regression test for None-return bug exists"
        test_def_score=$((test_def_score + 10))
    else
        fail "No regression test checking for None return"
    fi
else
    fail "test_sorter.py not found — skipping test definition checks"
fi

SCORE=$((SCORE + test_def_score))
echo -e "  ${YELLOW}Section score: ${test_def_score}/25${RESET}"

# ── Section 3: Tests Pass (25 pts) ──────────────────────────────────────────

header "Section 3: Tests Pass (25 pts)"

test_pass_score=0

if [[ -f "$SCRIPT_DIR/test_sorter.py" && -f "$SCRIPT_DIR/sorter_fixed.py" ]]; then
    pushd "$SCRIPT_DIR" > /dev/null
    if python3 -m pytest test_sorter.py -v --tb=short 2>&1; then
        pass "All tests pass"
        test_pass_score=25
    else
        fail "Some tests failed"
        passed=$(python3 -m pytest test_sorter.py --tb=no -q 2>&1 | grep -oP '^\d+(?= passed)' || echo "0")
        total_line=$(python3 -m pytest test_sorter.py --tb=no -q 2>&1 | tail -1)
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

if [[ -f "$SCRIPT_DIR/sorter_fixed.py" ]]; then
    # Fixed version should use sorted() instead of .sort()
    if grep -q "sorted(" "$SCRIPT_DIR/sorter_fixed.py"; then
        pass "Fixed version uses sorted() builtin"
        pattern_score=$((pattern_score + 10))
    else
        fail "Fixed version does not use sorted()"
    fi

    # Should still have both functions
    if grep -q "def sort_items" "$SCRIPT_DIR/sorter_fixed.py"; then
        pass "sort_items function present in fix"
        pattern_score=$((pattern_score + 5))
    else
        fail "sort_items function missing from fix"
    fi

    if grep -q "def sort_dicts_by_key" "$SCRIPT_DIR/sorter_fixed.py"; then
        pass "sort_dicts_by_key function present in fix"
        pattern_score=$((pattern_score + 5))
    else
        fail "sort_dicts_by_key function missing from fix"
    fi
else
    fail "sorter_fixed.py not found — skipping pattern checks"
fi

# Verify the original is actually buggy
if [[ -f "$SCRIPT_DIR/sorter.py" ]]; then
    if grep -q "\.sort(" "$SCRIPT_DIR/sorter.py"; then
        pass "Original sorter.py contains the .sort() bug"
        pattern_score=$((pattern_score + 5))
    else
        fail "Original sorter.py does not contain the expected bug"
    fi
else
    fail "sorter.py not found"
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
