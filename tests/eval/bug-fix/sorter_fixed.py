"""Sorting utility module — fixed version.

Uses sorted() which returns a new list instead of list.sort()
which mutates in-place and returns None.
"""


def sort_items(items, key=None, reverse=False):
    """Sort a list of items and return the sorted list.

    Args:
        items: A list of comparable items.
        key: Optional function to extract a comparison key.
        reverse: If True, sort in descending order.

    Returns:
        A new sorted list.
    """
    return sorted(items, key=key, reverse=reverse)


def sort_dicts_by_key(dicts, sort_key):
    """Sort a list of dictionaries by a specific key.

    Args:
        dicts: A list of dictionaries.
        sort_key: The dictionary key to sort by.

    Returns:
        A new sorted list of dictionaries.
    """
    return sorted(dicts, key=lambda d: d[sort_key])
