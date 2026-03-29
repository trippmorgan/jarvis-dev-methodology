"""Data processor module — monolithic version.

This module processes raw data records through validation, transformation,
and aggregation. The process_data function handles all three stages in a
single ~100-line function.
"""


def process_data(raw_records):
    """Process raw data records: validate, transform, and aggregate.

    Args:
        raw_records: A list of dicts, each with keys:
            - name (str): person's name
            - age (str or int): person's age
            - score (str or float): person's score
            - department (str): department name

    Returns:
        A dict with:
            - valid_count (int): number of valid records processed
            - invalid_count (int): number of records skipped
            - records (list): cleaned and enriched records
            - summary (dict): per-department aggregations
    """
    # ── Stage 1: Validate and clean ─────────────────────────────────────
    valid_records = []
    invalid_count = 0

    for record in raw_records:
        # Check required fields
        if not isinstance(record, dict):
            invalid_count += 1
            continue

        if "name" not in record or "age" not in record or "score" not in record:
            invalid_count += 1
            continue

        # Clean name
        name = str(record["name"]).strip()
        if not name:
            invalid_count += 1
            continue

        # Parse and validate age
        try:
            age = int(record["age"])
        except (ValueError, TypeError):
            invalid_count += 1
            continue

        if age < 0 or age > 150:
            invalid_count += 1
            continue

        # Parse and validate score
        try:
            score = float(record["score"])
        except (ValueError, TypeError):
            invalid_count += 1
            continue

        if score < 0 or score > 100:
            invalid_count += 1
            continue

        # Get department with default
        department = str(record.get("department", "General")).strip()
        if not department:
            department = "General"

        valid_records.append({
            "name": name,
            "age": age,
            "score": score,
            "department": department,
        })

    # ── Stage 2: Transform and enrich ───────────────────────────────────
    enriched_records = []

    for record in valid_records:
        enriched = dict(record)

        # Age bracket
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

        # Score grade
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

        # Normalized name
        enriched["display_name"] = record["name"].title()

        enriched_records.append(enriched)

    # ── Stage 3: Aggregate and summarize ────────────────────────────────
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

    # Calculate averages
    for dept in summary:
        count = summary[dept]["count"]
        if count > 0:
            summary[dept]["avg_score"] = round(
                summary[dept]["total_score"] / count, 2
            )
            summary[dept]["avg_age"] = round(
                summary[dept]["total_age"] / count, 2
            )

    return {
        "valid_count": len(enriched_records),
        "invalid_count": invalid_count,
        "records": enriched_records,
        "summary": summary,
    }
