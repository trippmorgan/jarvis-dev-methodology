"""User store module — base version without search functionality."""


class UserStore:
    """In-memory user storage with basic CRUD operations."""

    def __init__(self):
        self._users = {}
        self._next_id = 1

    def add_user(self, name, email, age):
        """Add a new user and return their assigned ID.

        Args:
            name: The user's full name.
            email: The user's email address.
            age: The user's age (int).

        Returns:
            The integer ID assigned to the new user.
        """
        user_id = self._next_id
        self._users[user_id] = {
            "id": user_id,
            "name": name,
            "email": email,
            "age": age,
        }
        self._next_id += 1
        return user_id

    def get_user(self, user_id):
        """Retrieve a user by ID.

        Args:
            user_id: The integer ID of the user.

        Returns:
            A dict with user data, or None if not found.
        """
        return self._users.get(user_id)

    def remove_user(self, user_id):
        """Remove a user by ID.

        Args:
            user_id: The integer ID of the user to remove.

        Returns:
            True if the user was removed, False if not found.
        """
        if user_id in self._users:
            del self._users[user_id]
            return True
        return False

    def list_users(self):
        """Return all users as a list of dicts.

        Returns:
            A list of user dicts, ordered by ID.
        """
        return [self._users[uid] for uid in sorted(self._users.keys())]
