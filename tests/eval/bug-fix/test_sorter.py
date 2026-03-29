"""Tests for the sorter module, including regression tests for the None-return bug."""

import pytest
from sorter_fixed import sort_items, sort_dicts_by_key


# ── Regression Tests: The None Bug ──────────────────────────────────────────


class TestNoneReturnRegression:
    """Regression tests: sort functions must never return None."""

    def test_sort_items_does_not_return_none(self):
        result = sort_items([3, 1, 2])
        assert result is not None, "sort_items returned None — the original bug"

    def test_sort_items_returns_a_list(self):
        result = sort_items([3, 1, 2])
        assert isinstance(result, list), f"Expected list, got {type(result)}"

    def test_sort_dicts_does_not_return_none(self):
        data = [{"name": "b"}, {"name": "a"}]
        result = sort_dicts_by_key(data, "name")
        assert result is not None, "sort_dicts_by_key returned None — the original bug"


# ── sort_items Tests ────────────────────────────────────────────────────────


class TestSortItems:
    def test_sort_ascending(self):
        assert sort_items([3, 1, 4, 1, 5]) == [1, 1, 3, 4, 5]

    def test_sort_descending(self):
        assert sort_items([3, 1, 4, 1, 5], reverse=True) == [5, 4, 3, 1, 1]

    def test_sort_with_key_function(self):
        words = ["banana", "apple", "cherry"]
        result = sort_items(words, key=len)
        assert result == ["apple", "banana", "cherry"]

    def test_sort_with_key_and_reverse(self):
        words = ["banana", "apple", "cherry"]
        result = sort_items(words, key=len, reverse=True)
        assert result == ["banana", "cherry", "apple"]

    def test_sort_empty_list(self):
        assert sort_items([]) == []

    def test_sort_single_element(self):
        assert sort_items([42]) == [42]

    def test_sort_already_sorted(self):
        assert sort_items([1, 2, 3, 4]) == [1, 2, 3, 4]

    def test_sort_strings(self):
        assert sort_items(["c", "a", "b"]) == ["a", "b", "c"]

    def test_sort_does_not_mutate_original(self):
        original = [3, 1, 2]
        copy = original.copy()
        sort_items(original)
        assert original == copy, "Original list was mutated"


# ── sort_dicts_by_key Tests ─────────────────────────────────────────────────


class TestSortDictsByKey:
    def test_sort_by_name(self):
        data = [
            {"name": "Charlie", "age": 30},
            {"name": "Alice", "age": 25},
            {"name": "Bob", "age": 35},
        ]
        result = sort_dicts_by_key(data, "name")
        assert [d["name"] for d in result] == ["Alice", "Bob", "Charlie"]

    def test_sort_by_age(self):
        data = [
            {"name": "Charlie", "age": 30},
            {"name": "Alice", "age": 25},
            {"name": "Bob", "age": 35},
        ]
        result = sort_dicts_by_key(data, "age")
        assert [d["age"] for d in result] == [25, 30, 35]

    def test_sort_empty_dicts_list(self):
        assert sort_dicts_by_key([], "name") == []
