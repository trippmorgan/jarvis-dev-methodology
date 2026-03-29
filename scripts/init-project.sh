#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# init-project.sh — Initialize .planning/ directory with template files
# Part of the Jarvis Development Methodology
# =============================================================================

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") /path/to/project [project-name]

Initialize a project's .planning/ directory with template files for the
Jarvis Development Methodology.

${BOLD}Creates:${NC}
  .planning/SPEC.md    — Requirements and specification
  .planning/PLAN.md    — Task decomposition and wave structure
  .planning/STATE.md   — Current phase, completed tasks, blockers
  .planning/TRACES.md  — Execution trace log

${BOLD}Arguments:${NC}
  /path/to/project   Path to the target project directory
  project-name       Optional project name (defaults to directory name)

${BOLD}Options:${NC}
  --help, -h         Show this help message

${BOLD}Examples:${NC}
  $(basename "$0") /home/user/my-app
  $(basename "$0") /home/user/my-app "My Cool App"
  $(basename "$0") .                          # current directory
EOF
}

# --- Argument parsing ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo -e "${RED}Error:${NC} Missing required argument: project path"
  echo ""
  usage
  exit 1
fi

PROJECT_DIR="$(realpath "$1")"
PROJECT_NAME="${2:-$(basename "$PROJECT_DIR")}"
PLANNING_DIR="$PROJECT_DIR/.planning"
DATE=$(date +%Y-%m-%d)

# Validate project directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo -e "${RED}Error:${NC} Directory does not exist: $PROJECT_DIR"
  exit 1
fi

# Check if .planning/ already exists (idempotent — skip existing files)
if [[ -d "$PLANNING_DIR" ]]; then
  echo -e "${YELLOW}Warning:${NC} .planning/ already exists in $PROJECT_DIR"
  echo -e "  Will create only missing template files."
fi

# --- Create .planning/ directory ---
mkdir -p "$PLANNING_DIR"
echo -e "${GREEN}Created${NC} $PLANNING_DIR/"

# --- Helper: write file only if it doesn't exist ---
write_template() {
  local filepath="$1"
  local content="$2"
  local filename
  filename=$(basename "$filepath")

  if [[ -f "$filepath" ]]; then
    echo -e "  ${YELLOW}Skipped${NC} $filename (already exists)"
  else
    echo "$content" > "$filepath"
    echo -e "  ${GREEN}Created${NC} $filename"
  fi
}

# --- SPEC.md template ---
write_template "$PLANNING_DIR/SPEC.md" "# Specification: $PROJECT_NAME

> Generated $(date +%Y-%m-%d) by Jarvis Development Methodology

## Project Goal
<!-- TODO: What are we building and why? One paragraph. -->

## Requirements
<!-- TODO: Numbered list of concrete requirements -->
1.

## Constraints
<!-- TODO: Tech stack, performance budgets, compatibility, etc. -->
-

## Edge Cases
<!-- TODO: What could go wrong? What are the boundary conditions? -->
-

## Non-Goals
<!-- TODO: What are we explicitly NOT doing? -->
-

## Architecture Decisions
<!-- TODO: Key technical choices and rationale -->
-

## Acceptance Criteria
<!-- TODO: How do we know we're done? -->
- [ ]

---
**Status:** DRAFT
**Approved:** <!-- TODO: Date when human approves -->"

# --- PLAN.md template ---
write_template "$PLANNING_DIR/PLAN.md" "# Implementation Plan: $PROJECT_NAME

> Generated $DATE by Jarvis Development Methodology

## Summary
<!-- TODO: Fill after task decomposition -->
- Total tasks:
- Total waves:
- Estimated time (parallel):
- Estimated time (sequential):

## Global Context
<!-- TODO: ~500 token summary for sub-agent context packets -->
**Project:** $PROJECT_NAME
**Tech Stack:** <!-- TODO -->
**Goal:** <!-- TODO: one-line goal -->

---

## Wave 1 (parallel)

### Task 1: <!-- TODO: Title -->
- **Files:** <!-- TODO: exact paths to create/modify -->
- **Depends on:** none
- **Acceptance Criteria:**
  - [ ] <!-- TODO -->
- **Test Requirements:**
  - <!-- TODO: Write test for [behavior] BEFORE implementation -->
- **Context Needed:** <!-- TODO: what the sub-agent needs to know -->

---

## Wave 2 (parallel, depends on Wave 1)

### Task 2: <!-- TODO: Title -->
- **Files:** <!-- TODO -->
- **Depends on:** Task 1
- **Acceptance Criteria:**
  - [ ] <!-- TODO -->
- **Test Requirements:**
  - <!-- TODO -->
- **Context Needed:** <!-- TODO -->

---
**Status:** DRAFT
**Approved:** <!-- TODO: Date when human approves -->"

# --- STATE.md template ---
write_template "$PLANNING_DIR/STATE.md" "# Project State: $PROJECT_NAME

> Last updated: $DATE

## Current Phase
<!-- Phases: spec | plan | execute | review | verify | ship | improve -->
**Phase:** spec
**Started:** $DATE

## Progress
| Wave | Task | Status | Retries | Notes |
|------|------|--------|---------|-------|
<!-- TODO: Populated during execution -->

## Completed Phases
<!-- TODO: Log completed phases with dates -->

## Blockers
<!-- TODO: List any blocking issues -->
- None

## Decisions Log
<!-- TODO: Architectural or process decisions made during execution -->
| Date | Decision | Rationale |
|------|----------|-----------|"

# --- TRACES.md template ---
write_template "$PLANNING_DIR/TRACES.md" "# Execution Traces: $PROJECT_NAME

> Captured by Jarvis Development Methodology

## Trace: $PROJECT_NAME — $DATE

### Tasks
| Task | Status | Retries | Time | Model | Tokens | Notes |
|------|--------|---------|------|-------|--------|-------|
<!-- TODO: Populated by trace-logger.sh -->

### Failures
<!-- TODO: Document failures and root causes -->

### Review Issues
<!-- TODO: Issues found during review gate -->

### Human Verification
<!-- TODO: Fixes needed after human walkthrough -->"

# --- Summary ---
echo ""
echo -e "${GREEN}${BOLD}Project initialized!${NC}"
echo -e "  Project:  ${CYAN}$PROJECT_NAME${NC}"
echo -e "  Location: ${CYAN}$PLANNING_DIR/${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Fill in ${BOLD}SPEC.md${NC} (Phase 0: brainstorm + requirements)"
echo -e "  2. Get human approval on spec"
echo -e "  3. Fill in ${BOLD}PLAN.md${NC} (Phase 1: decompose + DAG)"
echo -e "  4. Run ${BOLD}wave-executor.sh${NC} to execute"
