# Task: Add Search to UserStore

Add a `search_by_name` method to the existing `UserStore` class. The method should filter users by a case-insensitive name substring match.

## Existing Code

`user_store.py` contains a `UserStore` class with:
- `add_user(name, email, age)` - adds a user
- `get_user(user_id)` - retrieves a user by ID
- `remove_user(user_id)` - removes a user by ID
- `list_users()` - returns all users

## Requirements

1. Write tests first (TDD approach)
2. Add `search_by_name(query)` method that:
   - Accepts a string query
   - Returns a list of user dicts whose `name` contains the query (case-insensitive)
   - Returns an empty list if no matches
   - Returns all users if query is empty string

## Deliverables

- `test_user_store.py` - tests written first, covering search functionality
- `user_store_complete.py` - the UserStore with search_by_name added
