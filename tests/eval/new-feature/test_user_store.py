"""Tests for UserStore, including the new search_by_name feature.

Written test-first per TDD methodology. Tests cover both existing
CRUD operations and the new search functionality.
"""

import pytest
from user_store_complete import UserStore


@pytest.fixture
def store():
    """Provide a UserStore pre-populated with sample users."""
    s = UserStore()
    s.add_user("Alice Johnson", "alice@example.com", 28)
    s.add_user("Bob Smith", "bob@example.com", 35)
    s.add_user("Charlie Brown", "charlie@example.com", 22)
    s.add_user("Alice Wang", "awang@example.com", 31)
    s.add_user("Diana Prince", "diana@example.com", 45)
    return s


@pytest.fixture
def empty_store():
    """Provide an empty UserStore."""
    return UserStore()


# ── Existing CRUD Tests (must still pass) ───────────────────────────────────


class TestAddUser:
    def test_add_returns_id(self, empty_store):
        uid = empty_store.add_user("Test", "test@example.com", 25)
        assert isinstance(uid, int)
        assert uid >= 1

    def test_add_increments_id(self, empty_store):
        id1 = empty_store.add_user("A", "a@example.com", 20)
        id2 = empty_store.add_user("B", "b@example.com", 30)
        assert id2 == id1 + 1

    def test_add_stores_data(self, empty_store):
        uid = empty_store.add_user("Test User", "test@example.com", 25)
        user = empty_store.get_user(uid)
        assert user["name"] == "Test User"
        assert user["email"] == "test@example.com"
        assert user["age"] == 25


class TestGetUser:
    def test_get_existing_user(self, store):
        user = store.get_user(1)
        assert user is not None
        assert user["name"] == "Alice Johnson"

    def test_get_nonexistent_user(self, store):
        assert store.get_user(999) is None


class TestRemoveUser:
    def test_remove_existing_user(self, store):
        assert store.remove_user(1) is True
        assert store.get_user(1) is None

    def test_remove_nonexistent_user(self, store):
        assert store.remove_user(999) is False

    def test_remove_does_not_affect_others(self, store):
        store.remove_user(1)
        assert store.get_user(2) is not None


class TestListUsers:
    def test_list_all_users(self, store):
        users = store.list_users()
        assert len(users) == 5

    def test_list_empty_store(self, empty_store):
        assert empty_store.list_users() == []

    def test_list_ordered_by_id(self, store):
        users = store.list_users()
        ids = [u["id"] for u in users]
        assert ids == sorted(ids)


# ── Search Feature Tests (TDD — written first) ─────────────────────────────


class TestSearchByName:
    def test_search_exact_match(self, store):
        results = store.search_by_name("Alice Johnson")
        assert len(results) == 1
        assert results[0]["name"] == "Alice Johnson"

    def test_search_substring_match(self, store):
        results = store.search_by_name("ali")
        names = [r["name"] for r in results]
        assert "Alice Johnson" in names
        assert "Alice Wang" in names

    def test_search_case_insensitive(self, store):
        results = store.search_by_name("ALICE")
        assert len(results) == 2

    def test_search_case_insensitive_lower(self, store):
        results = store.search_by_name("alice")
        assert len(results) == 2

    def test_search_case_insensitive_mixed(self, store):
        results = store.search_by_name("aLiCe")
        assert len(results) == 2

    def test_search_no_matches(self, store):
        results = store.search_by_name("Zephyr")
        assert results == []

    def test_search_empty_query_returns_all(self, store):
        results = store.search_by_name("")
        assert len(results) == 5

    def test_search_multiple_matches(self, store):
        results = store.search_by_name("a")
        # Alice Johnson, Charlie Brown, Alice Wang, Diana Prince all contain 'a'
        assert len(results) >= 2

    def test_search_single_character(self, store):
        results = store.search_by_name("D")
        names = [r["name"] for r in results]
        assert "Diana Prince" in names

    def test_search_returns_list(self, store):
        results = store.search_by_name("Bob")
        assert isinstance(results, list)

    def test_search_returns_correct_user_data(self, store):
        results = store.search_by_name("Bob Smith")
        assert len(results) == 1
        user = results[0]
        assert user["email"] == "bob@example.com"
        assert user["age"] == 35

    def test_search_on_empty_store(self, empty_store):
        results = empty_store.search_by_name("test")
        assert results == []

    def test_search_after_remove(self, store):
        store.remove_user(1)  # Remove Alice Johnson
        results = store.search_by_name("Alice")
        assert len(results) == 1
        assert results[0]["name"] == "Alice Wang"

    def test_search_after_add(self, store):
        store.add_user("Alice Cooper", "cooper@example.com", 50)
        results = store.search_by_name("Alice")
        assert len(results) == 3
