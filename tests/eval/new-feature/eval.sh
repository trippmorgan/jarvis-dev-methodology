#!/usr/bin/env bash
set -euo pipefail

# Eval: new-feature — Add search_by_name to UserStore
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
    echo "Evaluate the new-feature (UserStore search) eval scenario."
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

if [[ -f "$SCRIPT_DIR/user_store.py" ]]; then
    pass "user_store.py exists (base class)"
    file_score=$((file_score + 7))
else
    fail "user_store.py not found"
fi

if [[ -f "$SCRIPT_DIR/user_store_complete.py" ]]; then
    pass "user_store_complete.py exists (with search)"
    file_score=$((file_score + 9))
else
    fail "user_store_complete.py not found"
fi

if [[ -f "$SCRIPT_DIR/test_user_store.py" ]]; then
    pass "test_user_store.py exists"
    file_score=$((file_score + 9))
else
    fail "test_user_store.py not found"
fi

SCORE=$((SCORE + file_score))
echo -e "  ${YELLOW}Section score: ${file_score}/25${RESET}"

# ── Section 2: Tests Exist (25 pts) ─────────────────────────────────────────

header "Section 2: Test Definitions (25 pts)"

test_def_score=0

if [[ -f "$SCRIPT_DIR/test_user_store.py" ]]; then
    test_count=$(grep -c "def test_" "$SCRIPT_DIR/test_user_store.py" || true)
    if (( test_count >= 12 )); then
        pass "Found $test_count test functions (>= 12)"
        test_def_score=$((test_def_score + 10))
    elif (( test_count >= 6 )); then
        pass "Found $test_count test functions (>= 6)"
        test_def_score=$((test_def_score + 7))
    elif (( test_count >= 1 )); then
        pass "Found $test_count test function(s)"
        test_def_score=$((test_def_score + 3))
    else
        fail "No test functions found"
    fi

    # Search-specific tests
    search_tests=$(grep -c "def test_search" "$SCRIPT_DIR/test_user_store.py" || true)
    if (( search_tests >= 5 )); then
        pass "Found $search_tests search-specific tests (>= 5)"
        test_def_score=$((test_def_score + 10))
    elif (( search_tests >= 1 )); then
        pass "Found $search_tests search-specific test(s)"
        test_def_score=$((test_def_score + 5))
    else
        fail "No search-specific tests found"
    fi

    # Check for case-insensitive test
    if grep -qi "case.insensitive\|ALICE\|lower()\|upper()" "$SCRIPT_DIR/test_user_store.py"; then
        pass "Case-insensitivity test present"
        test_def_score=$((test_def_score + 5))
    else
        fail "No case-insensitivity test found"
    fi
else
    fail "test_user_store.py not found — skipping test definition checks"
fi

SCORE=$((SCORE + test_def_score))
echo -e "  ${YELLOW}Section score: ${test_def_score}/25${RESET}"

# ── Section 3: Tests Pass (25 pts) ──────────────────────────────────────────

header "Section 3: Tests Pass (25 pts)"

test_pass_score=0

if [[ -f "$SCRIPT_DIR/test_user_store.py" && -f "$SCRIPT_DIR/user_store_complete.py" ]]; then
    pushd "$SCRIPT_DIR" > /dev/null
    if python3 -m pytest test_user_store.py -v --tb=short 2>&1; then
        pass "All tests pass"
        test_pass_score=25
    else
        fail "Some tests failed"
        passed=$(python3 -m pytest test_user_store.py --tb=no -q 2>&1 | grep -oP '^\d+(?= passed)' || echo "0")
        total_line=$(python3 -m pytest test_user_store.py --tb=no -q 2>&1 | tail -1)
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

# Base class should NOT have search_by_name
if [[ -f "$SCRIPT_DIR/user_store.py" ]]; then
    if ! grep -q "def search_by_name" "$SCRIPT_DIR/user_store.py"; then
        pass "Base user_store.py does NOT have search_by_name"
        pattern_score=$((pattern_score + 5))
    else
        fail "Base user_store.py should not have search_by_name"
    fi
fi

# Complete class SHOULD have search_by_name
if [[ -f "$SCRIPT_DIR/user_store_complete.py" ]]; then
    if grep -q "def search_by_name" "$SCRIPT_DIR/user_store_complete.py"; then
        pass "Complete version has search_by_name method"
        pattern_score=$((pattern_score + 5))
    else
        fail "search_by_name not found in complete version"
    fi

    if grep -q "class UserStore" "$SCRIPT_DIR/user_store_complete.py"; then
        pass "UserStore class defined in complete version"
        pattern_score=$((pattern_score + 5))
    else
        fail "UserStore class missing from complete version"
    fi

    # Case-insensitive implementation (should use .lower() or casefold())
    if grep -q "\.lower()\|\.casefold()\|re\.IGNORECASE" "$SCRIPT_DIR/user_store_complete.py"; then
        pass "Case-insensitive implementation detected"
        pattern_score=$((pattern_score + 5))
    else
        fail "No case-insensitive handling in implementation"
    fi

    # Original CRUD methods preserved
    preserved=0
    for method in add_user get_user remove_user list_users; do
        if grep -q "def ${method}" "$SCRIPT_DIR/user_store_complete.py"; then
            preserved=$((preserved + 1))
        fi
    done
    if (( preserved == 4 )); then
        pass "All 4 original CRUD methods preserved"
        pattern_score=$((pattern_score + 5))
    else
        fail "Only $preserved/4 original methods preserved"
    fi
else
    fail "user_store_complete.py not found — skipping pattern checks"
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
