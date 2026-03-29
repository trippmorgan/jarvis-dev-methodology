"""Calculator module providing basic arithmetic operations."""


class Calculator:
    """A calculator that performs basic arithmetic operations."""

    def add(self, a: float, b: float) -> float:
        """Return the sum of two numbers."""
        return a + b

    def subtract(self, a: float, b: float) -> float:
        """Return the difference of two numbers."""
        return a - b

    def multiply(self, a: float, b: float) -> float:
        """Return the product of two numbers."""
        return a * b

    def divide(self, a: float, b: float) -> float:
        """Return the quotient of two numbers.

        Raises:
            ZeroDivisionError: If b is zero.
        """
        if b == 0:
            raise ZeroDivisionError("Cannot divide by zero")
        return a / b
