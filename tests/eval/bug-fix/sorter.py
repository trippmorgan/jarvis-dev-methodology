"""Sorting utility module.

BUG: sort_items returns None because list.sort() sorts in-place
and returns None. This module represents the BROKEN version.
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
    # BUG: list.sort() returns None — it sorts in-place
    return items.sort(key=key, reverse=reverse)


def sort_dicts_by_key(dicts, sort_key):
    """Sort a list of dictionaries by a specific key.

    Args:
        dicts: A list of dictionaries.
        sort_key: The dictionary key to sort by.

    Returns:
        A new sorted list of dictionaries.
    """
    # BUG: same issue — .sort() returns None
    return dicts.sort(key=lambda d: d[sort_key])
