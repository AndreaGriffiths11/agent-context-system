#!/bin/bash
# run-tests.sh
# Integration tests for agent-context-system scripts.
#
# Creates a temporary git repo, exercises each script, and verifies behavior.
# Exits with code 0 if all tests pass, 1 if any fail.
#
# Usage: ./tests/run-tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
ERRORS=""

# --- Helpers ---

setup_temp_repo() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    git init -q
    # Copy project files into the temp repo
    cp "$PROJECT_ROOT/AGENTS.md" .
    cp -r "$PROJECT_ROOT/agent_docs" .
    cp -r "$PROJECT_ROOT/scripts" .
    mkdir -p docs
    # Make scripts executable
    chmod +x scripts/*.sh
}

teardown_temp_repo() {
    cd "$PROJECT_ROOT"
    rm -rf "$TEST_DIR"
}

pass() {
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $1"
    echo "  FAIL: $1"
}

assert_file_exists() {
    if [ -f "$1" ]; then
        pass "$2"
    else
        fail "$2 (file not found: $1)"
    fi
}

assert_file_not_exists() {
    if [ ! -f "$1" ]; then
        pass "$2"
    else
        fail "$2 (file should not exist: $1)"
    fi
}

assert_file_contains() {
    if grep -qF "$2" "$1" 2>/dev/null; then
        pass "$3"
    else
        fail "$3 (pattern '$2' not found in $1)"
    fi
}

assert_output_contains() {
    if echo "$1" | grep -qF "$2"; then
        pass "$3"
    else
        fail "$3 (expected '$2' in output)"
    fi
}

assert_exit_code() {
    if [ "$1" -eq "$2" ]; then
        pass "$3"
    else
        fail "$3 (expected exit code $2, got $1)"
    fi
}

# ============================================================
# TEST SUITE: init-agent-context.sh
# ============================================================

echo ""
echo "== init-agent-context.sh ================================="
echo ""

# Test: Creates .agents.local.md from template
setup_temp_repo
output=$(./scripts/init-agent-context.sh 2>&1)
assert_file_exists ".agents.local.md" "Creates .agents.local.md"
assert_file_contains ".agents.local.md" "Local Agent Scratchpad" "Scratchpad has expected content"
teardown_temp_repo

# Test: Creates CLAUDE.md symlink
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
if [ -L "CLAUDE.md" ]; then
    target=$(readlink CLAUDE.md)
    if [ "$target" = "AGENTS.md" ]; then
        pass "CLAUDE.md is a symlink to AGENTS.md"
    else
        fail "CLAUDE.md symlink points to '$target' instead of AGENTS.md"
    fi
else
    fail "CLAUDE.md is not a symlink"
fi
teardown_temp_repo

# Test: Adds .agents.local.md to .gitignore
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
assert_file_contains ".gitignore" ".agents.local.md" ".gitignore covers .agents.local.md"
teardown_temp_repo

# Test: Idempotent — safe to re-run
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
echo "custom content" >> .agents.local.md
./scripts/init-agent-context.sh >/dev/null 2>&1
assert_file_contains ".agents.local.md" "custom content" "Re-run does not overwrite existing .agents.local.md"
teardown_temp_repo

# Test: Handles existing non-symlink CLAUDE.md
setup_temp_repo
echo "# My existing CLAUDE.md" > CLAUDE.md
output=$(./scripts/init-agent-context.sh 2>&1)
assert_file_contains "CLAUDE.md" "My existing CLAUDE.md" "Preserves existing CLAUDE.md content"
assert_file_contains "CLAUDE.md" "AGENTS.md" "Adds AGENTS.md pointer to existing CLAUDE.md"
teardown_temp_repo

# Test: Works without existing .gitignore
setup_temp_repo
rm -f .gitignore
./scripts/init-agent-context.sh >/dev/null 2>&1
assert_file_exists ".gitignore" "Creates .gitignore if missing"
assert_file_contains ".gitignore" ".agents.local.md" "New .gitignore contains .agents.local.md"
teardown_temp_repo

# Test: Fallback when template file is missing (manual copy scenario)
setup_temp_repo
rm -f scripts/agents-local-template.md
rm -f .agents.local.md
output=$(./scripts/init-agent-context.sh 2>&1)
assert_file_exists ".agents.local.md" "Creates fallback .agents.local.md when template missing"
assert_file_contains ".agents.local.md" "Session Log" "Fallback scratchpad has Session Log section"
assert_output_contains "$output" "fallback" "Reports fallback was used"
teardown_temp_repo

# ============================================================
# TEST SUITE: validate.sh
# ============================================================

echo ""
echo "== validate.sh ==========================================="
echo ""

# Test: Detects placeholders in unmodified AGENTS.md
setup_temp_repo
exit_code=0
output=$(./scripts/validate.sh 2>&1) || exit_code=$?
assert_exit_code "$exit_code" 1 "Exits 1 when placeholders found"
assert_output_contains "$output" "placeholder(s) found" "Reports placeholder count"
teardown_temp_repo

# Test: Passes with cleaned-up AGENTS.md
setup_temp_repo
cat > AGENTS.md << 'CLEAN_EOF'
# AGENTS.md

## Project

- **Name:** My Real Project
- **Stack:** TypeScript, Node.js, PostgreSQL
- **Package manager:** pnpm

## Commands

```bash
pnpm build
pnpm test
pnpm lint
pnpm dev
```

## Architecture

```
src/           → Application source code
tests/         → Test files
agent_docs/    → Deep-dive references (read only when needed)
```

## Project Knowledge (Compressed)

### Patterns

```
named exports    | src/components/ — all components use named exports
```

### Boundaries

```
never edit migrations | auto-generated by Prisma
```

### Gotchas

```
dev server caches aggressively | restart after config changes
```

## Rules

1. Read this file first.
CLEAN_EOF
# Also clean up agent_docs
rm -rf agent_docs
mkdir agent_docs
echo "# Architecture" > agent_docs/architecture.md
echo "Real architecture docs here." >> agent_docs/architecture.md
echo "# Conventions" > agent_docs/conventions.md
echo "Real conventions docs here." >> agent_docs/conventions.md
echo "# Gotchas" > agent_docs/gotchas.md
echo "Real gotchas docs here." >> agent_docs/gotchas.md
exit_code=0
output=$(./scripts/validate.sh 2>&1) || exit_code=$?
assert_exit_code "$exit_code" 0 "Exits 0 when no placeholders"
assert_output_contains "$output" "Validation passed" "Reports clean validation"
teardown_temp_repo

# Test: --quiet mode
setup_temp_repo
exit_code=0
output=$(./scripts/validate.sh --quiet 2>&1) || exit_code=$?
assert_exit_code "$exit_code" 1 "Quiet mode still exits 1 for placeholders"
# In quiet mode, should still show summary but not individual matches
assert_output_contains "$output" "placeholder(s) found" "Quiet mode shows summary"
teardown_temp_repo

# ============================================================
# TEST SUITE: promote.sh
# ============================================================

echo ""
echo "== promote.sh ============================================"
echo ""

# Test: Handles missing .agents.local.md gracefully
setup_temp_repo
output=$(./scripts/promote.sh 2>&1)
assert_output_contains "$output" "No .agents.local.md found" "Graceful message when scratchpad missing"
teardown_temp_repo

# Test: Reports session count
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
# Add some sessions
cat >> .agents.local.md << 'SESSIONS_EOF'

### 2025-01-10 — Setup
- **Done:** Initial project setup
- **Learned:** pnpm is faster than npm for this project

### 2025-01-11 — Feature A
- **Done:** Added user authentication
- **Learned:** pnpm workspace requires special config
- **Worked:** Using Zod for validation

### 2025-01-12 — Feature B
- **Done:** Added API routes
- **Learned:** pnpm install needs --frozen-lockfile in CI
SESSIONS_EOF
output=$(./scripts/promote.sh 2>&1)
assert_output_contains "$output" "Sessions logged: 3" "Counts sessions correctly"
teardown_temp_repo

# Test: Shows Ready to Promote items
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
# Add a ready-to-promote item
cat >> .agents.local.md << 'PROMOTE_EOF'

## Ready to Promote

- pnpm workspace | requires special config for monorepo
PROMOTE_EOF
# Need to re-add the section since we appended at the end; let's just create a clean file
cat > .agents.local.md << 'FULL_EOF'
# .agents.local.md — Local Agent Scratchpad

## Preferences

## Patterns

## Gotchas

## Dead Ends

## Ready to Promote

- pnpm workspace | requires special config for monorepo

## Session Log

## Compression Log
FULL_EOF
output=$(./scripts/promote.sh 2>&1)
assert_output_contains "$output" "pnpm workspace" "Shows Ready to Promote items"
teardown_temp_repo

# Test: Shows recurring themes when enough sessions exist
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
cat > .agents.local.md << 'THEMES_EOF'
# .agents.local.md

## Preferences

## Patterns

## Gotchas

## Dead Ends

## Ready to Promote

## Session Log

### 2025-01-10 — Session 1
- **Learned:** Database migrations require restart
- **Worked:** Using connection pooling

### 2025-01-11 — Session 2
- **Learned:** Database connection pooling is essential
- **Worked:** Migrations work after restart

### 2025-01-12 — Session 3
- **Learned:** Database schema changes need migration
- **Decided:** Always use connection pooling

## Compression Log
THEMES_EOF
output=$(./scripts/promote.sh 2>&1)
# Should find "database" as a recurring theme
assert_output_contains "$output" "database" "Finds recurring theme 'database'"
teardown_temp_repo

# Test: Flexible session header matching (em dash, single-digit months)
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
cat > .agents.local.md << 'FLEX_EOF'
# .agents.local.md

## Preferences

## Patterns

## Gotchas

## Dead Ends

## Ready to Promote

## Session Log

### 2025-1-5 — January session
- **Learned:** Flexible dates work

### 2025-01-10 - Hyphen separator
- **Learned:** Hyphens work too

### 2025-02-15 — Em dash separator
- **Learned:** Em dashes work

## Compression Log
FLEX_EOF
output=$(./scripts/promote.sh 2>&1)
assert_output_contains "$output" "Sessions logged: 3" "Flexible session header matching works"
teardown_temp_repo

# ============================================================
# TEST SUITE: compress.sh
# ============================================================

echo ""
echo "== compress.sh ==========================================="
echo ""

# Test: Handles missing .agents.local.md
setup_temp_repo
output=$(./scripts/compress.sh 2>&1)
assert_output_contains "$output" "No .agents.local.md found" "Graceful message when scratchpad missing"
teardown_temp_repo

# Test: Reports line count and section sizes
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
output=$(./scripts/compress.sh 2>&1)
assert_output_contains "$output" "Total lines:" "Reports total line count"
assert_output_contains "$output" "No compression needed" "Reports no compression needed for small file"
teardown_temp_repo

# Test: Creates backup with --backup flag
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
output=$(./scripts/compress.sh --backup 2>&1)
assert_output_contains "$output" "Backup created" "Reports backup creation"
backup_count=$(ls .agents.local.md.backup.* 2>/dev/null | wc -l)
if [ "$backup_count" -ge 1 ]; then
    pass "Backup file exists on disk"
else
    fail "Backup file not found on disk"
fi
teardown_temp_repo

# Test: Reports COMPRESSION RECOMMENDED for large files
setup_temp_repo
./scripts/init-agent-context.sh >/dev/null 2>&1
# Pad the file to over 300 lines
for i in $(seq 1 250); do
    echo "- Line $i of padding content" >> .agents.local.md
done
output=$(./scripts/compress.sh 2>&1)
assert_output_contains "$output" "COMPRESSION RECOMMENDED" "Recommends compression for large files"
teardown_temp_repo

# ============================================================
# RESULTS
# ============================================================

echo ""
echo "=========================================================="
echo ""
total=$((PASS + FAIL))
echo "Results: $PASS/$total passed"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Failures:"
    echo -e "$ERRORS"
    echo ""
    exit 1
fi

echo ""
echo "All tests passed."
exit 0
