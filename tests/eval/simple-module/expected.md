# Acceptance Criteria: Calculator Module

## File Structure
- [ ] `calculator.py` exists
- [ ] `test_calculator.py` exists

## Class Requirements
- [ ] `Calculator` class is defined in `calculator.py`
- [ ] Class has `add` method
- [ ] Class has `subtract` method
- [ ] Class has `multiply` method
- [ ] Class has `divide` method

## Test Requirements
- [ ] At least 4 test functions (one per operation minimum)
- [ ] Tests use `pytest` conventions (`def test_*` or `class Test*`)
- [ ] Division by zero test exists
- [ ] Tests cover positive and negative numbers
- [ ] All tests pass when run with `pytest`

## Behavior
- [ ] `add(2, 3)` returns `5`
- [ ] `subtract(10, 4)` returns `6`
- [ ] `multiply(3, 7)` returns `21`
- [ ] `divide(15, 3)` returns `5.0`
- [ ] `divide(1, 0)` raises `ZeroDivisionError`
