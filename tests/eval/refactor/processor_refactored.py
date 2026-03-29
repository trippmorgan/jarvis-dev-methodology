"""Data processor module — refactored version.

The monolithic process_data function has been broken into three stages:
  1. validate_and_clean  — input validation and normalization
  2. transform_and_enrich — add derived fields (age bracket, grade, display name)
  3. aggregate_summary    — per-department aggregation

The main process_data function orchestrates these three stages.
"""


def validate_and_clean(raw_records):
    """Validate raw records and return cleaned versions.

    Checks required fields, parses types, enforces value ranges,
    and normalizes department names.

    Args:
        raw_records: List of raw dicts with name, age, score, department.

    Returns:
        Tuple of (valid_records list, invalid_count int).
    """
    valid_records = []
    invalid_count = 0

    for record in raw_records:
        if not isinstance(record, dict):
            invalid_count += 1
            continue

        if "name" not in record or "age" not in record or "score" not in record:
            invalid_count += 1
            continue

        name = str(record["name"]).strip()
        if not name:
            invalid_count += 1
            continue

        try:
            age = int(record["age"])
        except (ValueError, TypeError):
            invalid_count += 1
            continue

        if age < 0 or age > 150:
            invalid_count += 1
            continue

        try:
            score = float(record["score"])
        except (ValueError, TypeError):
            invalid_count += 1
            continue

        if score < 0 or score > 100:
            invalid_count += 1
            continue

        department = str(record.get("department", "General")).strip()
        if not department:
            department = "General"

        valid_records.append({
            "name": name,
            "age": age,
            "score": score,
            "department": department,
        })

    return valid_records, invalid_count


def transform_and_enrich(valid_records):
    """Add derived fields to each validated record.

    Adds age_bracket, grade, and display_name based on the record's
    age and score values.

    Args:
        valid_records: List of cleaned record dicts.

    Returns:
        List of enriched record dicts.
    """
    enriched_records = []

    for record in valid_records:
        enriched = dict(record)

        age = record["age"]
        if age < 18:
            enriched["age_bracket"] = "minor"
        elif age < 30:
            enriched["age_bracket"] = "young_adult"
        elif age < 50:
            enriched["age_bracket"] = "adult"
        elif age < 65:
            enriched["age_bracket"] = "senior"
        else:
            enriched["age_bracket"] = "elder"

        score = record["score"]
        if score >= 90:
            enriched["grade"] = "A"
        elif score >= 80:
            enriched["grade"] = "B"
        elif score >= 70:
            enriched["grade"] = "C"
        elif score >= 60:
            enriched["grade"] = "D"
        else:
            enriched["grade"] = "F"

        enriched["display_name"] = record["name"].title()

        enriched_records.append(enriched)

    return enriched_records


def aggregate_summary(enriched_records):
    """Build per-department summary statistics.

    Counts records, totals scores and ages, tallies grade distribution,
    and computes averages for each department.

    Args:
        enriched_records: List of enriched record dicts.

    Returns:
        Dict mapping department name to summary stats.
    """
    summary = {}

    for record in enriched_records:
        dept = record["department"]

        if dept not in summary:
            summary[dept] = {
                "count": 0,
                "total_score": 0.0,
                "total_age": 0,
                "grades": {"A": 0, "B": 0, "C": 0, "D": 0, "F": 0},
            }

        summary[dept]["count"] += 1
        summary[dept]["total_score"] += record["score"]
        summary[dept]["total_age"] += record["age"]
        summary[dept]["grades"][record["grade"]] += 1

    for dept in summary:
        count = summary[dept]["count"]
        if count > 0:
            summary[dept]["avg_score"] = round(
                summary[dept]["total_score"] / count, 2
            )
            summary[dept]["avg_age"] = round(
                summary[dept]["total_age"] / count, 2
            )

    return summary


def process_data(raw_records):
    """Process raw data records: validate, transform, and aggregate.

    Orchestrates three stages:
      1. validate_and_clean — filter and normalize input
      2. transform_and_enrich — add derived fields
      3. aggregate_summary — per-department stats

    Args:
        raw_records: A list of dicts with name, age, score, department keys.

    Returns:
        A dict with valid_count, invalid_count, records, and summary.
    """
    valid_records, invalid_count = validate_and_clean(raw_records)
    enriched_records = transform_and_enrich(valid_records)
    summary = aggregate_summary(enriched_records)

    return {
        "valid_count": len(enriched_records),
        "invalid_count": invalid_count,
        "records": enriched_records,
        "summary": summary,
    }
