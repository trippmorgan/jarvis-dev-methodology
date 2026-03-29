"""Tests for the Calculator class — written first per TDD methodology."""

import pytest
from calculator import Calculator


@pytest.fixture
def calc():
    """Provide a Calculator instance for each test."""
    return Calculator()


class TestAdd:
    def test_add_positive_numbers(self, calc):
        assert calc.add(2, 3) == 5

    def test_add_negative_numbers(self, calc):
        assert calc.add(-1, -1) == -2

    def test_add_mixed_signs(self, calc):
        assert calc.add(-1, 5) == 4

    def test_add_zeros(self, calc):
        assert calc.add(0, 0) == 0

    def test_add_floats(self, calc):
        assert calc.add(1.5, 2.5) == 4.0


class TestSubtract:
    def test_subtract_positive_numbers(self, calc):
        assert calc.subtract(10, 4) == 6

    def test_subtract_negative_result(self, calc):
        assert calc.subtract(3, 7) == -4

    def test_subtract_from_zero(self, calc):
        assert calc.subtract(0, 5) == -5

    def test_subtract_floats(self, calc):
        assert calc.subtract(5.5, 2.3) == pytest.approx(3.2)


class TestMultiply:
    def test_multiply_positive_numbers(self, calc):
        assert calc.multiply(3, 7) == 21

    def test_multiply_by_zero(self, calc):
        assert calc.multiply(100, 0) == 0

    def test_multiply_negative_numbers(self, calc):
        assert calc.multiply(-3, -4) == 12

    def test_multiply_mixed_signs(self, calc):
        assert calc.multiply(-2, 5) == -10

    def test_multiply_floats(self, calc):
        assert calc.multiply(2.5, 4.0) == 10.0


class TestDivide:
    def test_divide_evenly(self, calc):
        assert calc.divide(15, 3) == 5.0

    def test_divide_with_remainder(self, calc):
        assert calc.divide(7, 2) == 3.5

    def test_divide_negative_numbers(self, calc):
        assert calc.divide(-10, 2) == -5.0

    def test_divide_by_zero_raises(self, calc):
        with pytest.raises(ZeroDivisionError, match="Cannot divide by zero"):
            calc.divide(1, 0)

    def test_divide_zero_by_number(self, calc):
        assert calc.divide(0, 5) == 0.0

    def test_divide_floats(self, calc):
        assert calc.divide(7.5, 2.5) == 3.0
