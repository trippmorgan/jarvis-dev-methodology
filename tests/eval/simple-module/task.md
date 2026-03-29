# Task: Create a Calculator Module

Create a Python module with a `Calculator` class that supports basic arithmetic operations.

## Requirements

1. Write tests first (TDD approach)
2. Implement a `Calculator` class with the following methods:
   - `add(a, b)` - returns the sum of two numbers
   - `subtract(a, b)` - returns the difference of two numbers
   - `multiply(a, b)` - returns the product of two numbers
   - `divide(a, b)` - returns the quotient of two numbers, raises `ZeroDivisionError` if `b` is zero

## Constraints

- All methods should handle integers and floats
- Division by zero must raise `ZeroDivisionError` with a descriptive message
- Tests must cover normal cases and edge cases (negative numbers, zero, floats)

## Deliverables

- `test_calculator.py` - test file written first
- `calculator.py` - implementation that passes all tests
