"""Tests for the data processor module.

These tests work with both the original monolithic processor.py and
the refactored processor_refactored.py — verifying behavior preservation.

To run against the refactored version (default):
    pytest test_processor.py

The import below targets the refactored module. To test the original,
change the import to: from processor import process_data
"""

import pytest
from processor_refactored import process_data


# ── Test Fixtures ───────────────────────────────────────────────────────────


@pytest.fixture
def sample_records():
    return [
        {"name": "Alice Johnson", "age": 28, "score": 92, "department": "Engineering"},
        {"name": "Bob Smith", "age": "35", "score": "78", "department": "Marketing"},
        {"name": "Charlie Brown", "age": 17, "score": 55, "department": "Engineering"},
        {"name": "Diana Prince", "age": 45, "score": 88, "department": "Marketing"},
        {"name": "Eve Wilson", "age": 67, "score": 95, "department": "Engineering"},
    ]


@pytest.fixture
def invalid_records():
    return [
        "not a dict",
        {"name": "No Age", "score": 50},
        {"name": "", "age": 25, "score": 50},
        {"name": "Negative Age", "age": -5, "score": 50},
        {"name": "Bad Score", "age": 25, "score": 150},
        {"name": "Bad Age Type", "age": "old", "score": 50},
        None,
        {"age": 25, "score": 50},
    ]


# ── Basic Processing Tests ──────────────────────────────────────────────────


class TestProcessDataBasic:
    def test_returns_expected_keys(self, sample_records):
        result = process_data(sample_records)
        assert "valid_count" in result
        assert "invalid_count" in result
        assert "records" in result
        assert "summary" in result

    def test_valid_count(self, sample_records):
        result = process_data(sample_records)
        assert result["valid_count"] == 5

    def test_invalid_count_zero_for_good_data(self, sample_records):
        result = process_data(sample_records)
        assert result["invalid_count"] == 0

    def test_records_list_length(self, sample_records):
        result = process_data(sample_records)
        assert len(result["records"]) == 5

    def test_empty_input(self):
        result = process_data([])
        assert result["valid_count"] == 0
        assert result["invalid_count"] == 0
        assert result["records"] == []
        assert result["summary"] == {}


# ── Validation Tests ────────────────────────────────────────────────────────


class TestValidation:
    def test_all_invalid_records(self, invalid_records):
        result = process_data(invalid_records)
        assert result["valid_count"] == 0
        assert result["invalid_count"] == len(invalid_records)

    def test_mixed_valid_and_invalid(self, sample_records, invalid_records):
        mixed = sample_records + invalid_records
        result = process_data(mixed)
        assert result["valid_count"] == 5
        assert result["invalid_count"] == len(invalid_records)

    def test_string_age_coercion(self):
        records = [{"name": "Test", "age": "25", "score": 80}]
        result = process_data(records)
        assert result["valid_count"] == 1
        assert result["records"][0]["age"] == 25

    def test_string_score_coercion(self):
        records = [{"name": "Test", "age": 25, "score": "85.5"}]
        result = process_data(records)
        assert result["valid_count"] == 1
        assert result["records"][0]["score"] == 85.5

    def test_default_department(self):
        records = [{"name": "Test", "age": 25, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["department"] == "General"

    def test_name_stripped(self):
        records = [{"name": "  Alice  ", "age": 25, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["name"] == "Alice"

    def test_age_boundary_zero(self):
        records = [{"name": "Baby", "age": 0, "score": 50}]
        result = process_data(records)
        assert result["valid_count"] == 1

    def test_age_boundary_150(self):
        records = [{"name": "Ancient", "age": 150, "score": 50}]
        result = process_data(records)
        assert result["valid_count"] == 1

    def test_age_over_150_rejected(self):
        records = [{"name": "TooOld", "age": 151, "score": 50}]
        result = process_data(records)
        assert result["valid_count"] == 0

    def test_score_boundary_zero(self):
        records = [{"name": "Zero", "age": 25, "score": 0}]
        result = process_data(records)
        assert result["valid_count"] == 1

    def test_score_boundary_100(self):
        records = [{"name": "Perfect", "age": 25, "score": 100}]
        result = process_data(records)
        assert result["valid_count"] == 1


# ── Transformation Tests ────────────────────────────────────────────────────


class TestTransformation:
    def test_age_bracket_minor(self):
        records = [{"name": "Kid", "age": 10, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["age_bracket"] == "minor"

    def test_age_bracket_young_adult(self):
        records = [{"name": "Youth", "age": 25, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["age_bracket"] == "young_adult"

    def test_age_bracket_adult(self):
        records = [{"name": "Adult", "age": 40, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["age_bracket"] == "adult"

    def test_age_bracket_senior(self):
        records = [{"name": "Senior", "age": 55, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["age_bracket"] == "senior"

    def test_age_bracket_elder(self):
        records = [{"name": "Elder", "age": 70, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["age_bracket"] == "elder"

    def test_grade_a(self):
        records = [{"name": "A Student", "age": 25, "score": 95}]
        result = process_data(records)
        assert result["records"][0]["grade"] == "A"

    def test_grade_b(self):
        records = [{"name": "B Student", "age": 25, "score": 85}]
        result = process_data(records)
        assert result["records"][0]["grade"] == "B"

    def test_grade_c(self):
        records = [{"name": "C Student", "age": 25, "score": 75}]
        result = process_data(records)
        assert result["records"][0]["grade"] == "C"

    def test_grade_d(self):
        records = [{"name": "D Student", "age": 25, "score": 65}]
        result = process_data(records)
        assert result["records"][0]["grade"] == "D"

    def test_grade_f(self):
        records = [{"name": "F Student", "age": 25, "score": 45}]
        result = process_data(records)
        assert result["records"][0]["grade"] == "F"

    def test_display_name_title_case(self):
        records = [{"name": "alice johnson", "age": 25, "score": 80}]
        result = process_data(records)
        assert result["records"][0]["display_name"] == "Alice Johnson"


# ── Aggregation Tests ───────────────────────────────────────────────────────


class TestAggregation:
    def test_summary_departments(self, sample_records):
        result = process_data(sample_records)
        assert "Engineering" in result["summary"]
        assert "Marketing" in result["summary"]

    def test_summary_counts(self, sample_records):
        result = process_data(sample_records)
        assert result["summary"]["Engineering"]["count"] == 3
        assert result["summary"]["Marketing"]["count"] == 2

    def test_summary_avg_score(self):
        records = [
            {"name": "A", "age": 25, "score": 80, "department": "Dept"},
            {"name": "B", "age": 30, "score": 90, "department": "Dept"},
        ]
        result = process_data(records)
        assert result["summary"]["Dept"]["avg_score"] == 85.0

    def test_summary_avg_age(self):
        records = [
            {"name": "A", "age": 20, "score": 80, "department": "Dept"},
            {"name": "B", "age": 40, "score": 90, "department": "Dept"},
        ]
        result = process_data(records)
        assert result["summary"]["Dept"]["avg_age"] == 30.0

    def test_summary_grade_distribution(self):
        records = [
            {"name": "A", "age": 25, "score": 95, "department": "Dept"},
            {"name": "B", "age": 25, "score": 55, "department": "Dept"},
            {"name": "C", "age": 25, "score": 95, "department": "Dept"},
        ]
        result = process_data(records)
        assert result["summary"]["Dept"]["grades"]["A"] == 2
        assert result["summary"]["Dept"]["grades"]["F"] == 1

    def test_single_record_summary(self):
        records = [{"name": "Solo", "age": 30, "score": 75, "department": "Solo"}]
        result = process_data(records)
        assert result["summary"]["Solo"]["count"] == 1
        assert result["summary"]["Solo"]["avg_score"] == 75.0
        assert result["summary"]["Solo"]["avg_age"] == 30.0
