# Task: Refactor a Monolithic Function

The `process_data` function in `processor.py` is a ~100-line monolithic function that does too much. Refactor it into 3 or more smaller, focused functions while preserving all existing behavior.

## Current State

`processor.py` contains a single `process_data(raw_records)` function that:
1. Validates and cleans input records
2. Transforms and enriches the data
3. Aggregates and summarizes results

## Requirements

1. Break `process_data` into at least 3 smaller functions
2. Each function should have a single, clear responsibility
3. The main `process_data` function should orchestrate the smaller ones
4. All existing tests in `test_processor.py` must continue to pass
5. No behavior changes — same inputs must produce same outputs

## Deliverables

- `processor_refactored.py` - the refactored version with 3+ functions
- `test_processor.py` - all existing tests must pass against the refactored version
