# Acceptance Criteria: UserStore Search Feature

## Method Exists
- [ ] `search_by_name` method is defined on `UserStore`
- [ ] Method accepts a `query` string parameter
- [ ] Method returns a list

## Search Behavior
- [ ] Matches substring (e.g., "ali" matches "Alice")
- [ ] Case-insensitive matching
- [ ] Returns empty list when no matches
- [ ] Returns all users when query is empty string
- [ ] Returns multiple matches when applicable

## Existing Functionality Preserved
- [ ] `add_user` still works
- [ ] `get_user` still works
- [ ] `remove_user` still works
- [ ] `list_users` still works

## Test Coverage
- [ ] Test for exact name match
- [ ] Test for substring match
- [ ] Test for case-insensitive match
- [ ] Test for no matches
- [ ] Test for empty query
- [ ] Test for multiple matches
- [ ] All tests pass with `pytest`
