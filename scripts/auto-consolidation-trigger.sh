#!/bin/bash
# Auto-consolidation trigger for agent-context-system
#
# Checks time gate, session gate, and lock gate.
# Spawns consolidation when all gates pass.
#
# Usage:
#   ./scripts/auto-consolidation-trigger.sh [--check|--force]

set -euo pipefail

# Configuration
MIN_HOURS=24
MIN_SESSIONS=5
LOCK_TIMEOUT_MINUTES=30
AGENTS_DIR="${AGENTS_DIR:-.agents}"
LOCK_FILE="$AGENTS_DIR/.consolidation-lock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

current_timestamp_ms() {
  date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000))
}

# Read lock file
read_lock() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    echo '{"last_consolidated_at":0,"locked_by":null,"locked_at":null}'
    return
  fi
  cat "$LOCK_FILE"
}

# Write lock file
write_lock() {
  local lock_json="$1"
  mkdir -p "$(dirname "$LOCK_FILE")"
  echo "$lock_json" > "$LOCK_FILE"
}

# Time gate: Check if enough time has passed since last consolidation
check_time_gate() {
  local lock_json
  lock_json=$(read_lock)
  local last_at
  last_at=$(echo "$lock_json" | grep -o '"last_consolidated_at":[0-9]*' | cut -d: -f2)
  local now_ms
  now_ms=$(current_timestamp_ms)
  
  # Calculate hours since (integer arithmetic)
  local ms_diff=$((now_ms - last_at))
  local hours_since=$((ms_diff / 3600000))
  
  if (( hours_since >= MIN_HOURS )); then
    echo "PASS:$hours_since"
  else
    echo "FAIL:$hours_since"
  fi
}

# Session gate: Count sessions since last consolidation
check_session_gate() {
  local lock_json
  lock_json=$(read_lock)
  local last_at
  last_at=$(echo "$lock_json" | grep -o '"last_consolidated_at":[0-9]*' | cut -d: -f2)
  
  # Count daily log files modified since last consolidation
  local session_count=0
  if [[ -d "$AGENTS_DIR/logs" ]]; then
    local cutoff_seconds=$((last_at / 1000))
    while IFS= read -r log_file; do
      local mtime
      mtime=$(stat -c %Y "$log_file" 2>/dev/null || stat -f %m "$log_file" 2>/dev/null || echo 0)
      if (( mtime > cutoff_seconds )); then
        ((session_count++))
      fi
    done < <(find "$AGENTS_DIR/logs" -name "*.md" 2>/dev/null || true)
  fi
  
  if (( session_count >= MIN_SESSIONS )); then
    echo "PASS:$session_count"
  else
    echo "FAIL:$session_count"
  fi
}

# Lock gate: Check if consolidation lock is available
check_lock_gate() {
  local lock_json
  lock_json=$(read_lock)
  local locked_by
  locked_by=$(echo "$lock_json" | grep -o '"locked_by":"[^"]*"' | cut -d'"' -f4)
  local locked_at
  locked_at=$(echo "$lock_json" | grep -o '"locked_at":[0-9]*' | cut -d: -f2)
  
  if [[ "$locked_by" == "null" || -z "$locked_by" ]]; then
    echo "PASS:available"
    return
  fi
  
  # Check if lock is stale
  local now_ms
  now_ms=$(current_timestamp_ms)
  
  # Calculate age in minutes (integer arithmetic)
  local ms_diff=$((now_ms - locked_at))
  local age_minutes=$((ms_diff / 60000))
  
  if (( age_minutes > LOCK_TIMEOUT_MINUTES )); then
    echo "PASS:stale:$age_minutes"
  else
    echo "FAIL:locked_by=$locked_by:age=$age_minutes"
  fi
}

# Acquire lock
acquire_lock() {
  local session_id="${1:-manual-consolidation}"
  local lock_json
  lock_json=$(read_lock)
  local last_at
  last_at=$(echo "$lock_json" | grep -o '"last_consolidated_at":[0-9]*' | cut -d: -f2)
  local now_ms
  now_ms=$(current_timestamp_ms)
  
  local new_lock
  new_lock=$(cat <<EOF
{
  "last_consolidated_at": $last_at,
  "locked_by": "$session_id",
  "locked_at": $now_ms
}
EOF
)
  
  write_lock "$new_lock"
  log_info "Lock acquired by $session_id"
}

# Release lock
# shellcheck disable=SC2329  # Function reserved for future use
release_lock() {
  local lock_json
  lock_json=$(read_lock)
  local now_ms
  now_ms=$(current_timestamp_ms)
  
  local new_lock
  new_lock=$(cat <<EOF
{
  "last_consolidated_at": $now_ms,
  "locked_by": null,
  "locked_at": null
}
EOF
)
  
  write_lock "$new_lock"
  log_info "Lock released, last_consolidated_at updated"
}

# Check all gates
should_trigger() {
  local time_result
  time_result=$(check_time_gate)
  local time_status
  time_status=$(echo "$time_result" | cut -d: -f1)
  local hours_since
  hours_since=$(echo "$time_result" | cut -d: -f2)
  
  if [[ "$time_status" == "FAIL" ]]; then
    log_warn "Time gate failed: ${hours_since}h < ${MIN_HOURS}h"
    return 1
  fi
  
  local session_result
  session_result=$(check_session_gate)
  local session_status
  session_status=$(echo "$session_result" | cut -d: -f1)
  local session_count
  session_count=$(echo "$session_result" | cut -d: -f2)
  
  if [[ "$session_status" == "FAIL" ]]; then
    log_warn "Session gate failed: ${session_count} < ${MIN_SESSIONS}"
    return 1
  fi
  
  local lock_result
  lock_result=$(check_lock_gate)
  local lock_status
  lock_status=$(echo "$lock_result" | cut -d: -f1)
  
  if [[ "$lock_status" == "FAIL" ]]; then
    local lock_info
    lock_info=$(echo "$lock_result" | cut -d: -f2-)
    log_warn "Lock gate failed: $lock_info"
    return 1
  fi
  
  log_info "All gates passed:"
  log_info "  Time: ${hours_since}h since last consolidation"
  log_info "  Sessions: ${session_count} accumulated"
  log_info "  Lock: available"
  
  return 0
}

# Main
main() {
  local mode="${1:-trigger}"
  
  case "$mode" in
    --check)
      if should_trigger; then
        echo "Should trigger: YES"
        exit 0
      else
        echo "Should trigger: NO"
        exit 1
      fi
      ;;
    --force)
      log_info "Force mode: bypassing time and session gates"
      local lock_result
      lock_result=$(check_lock_gate)
      local lock_status
      lock_status=$(echo "$lock_result" | cut -d: -f1)
      
      if [[ "$lock_status" == "FAIL" ]]; then
        log_error "Lock is busy, cannot force trigger"
        exit 1
      fi
      
      acquire_lock "force-consolidation"
      log_info "Ready to spawn consolidation session"
      log_info "Run: ./scripts/consolidate-memory.sh"
      exit 0
      ;;
    *)
      if should_trigger; then
        acquire_lock "auto-consolidation"
        log_info "Ready to spawn consolidation session"
        log_info "Run: ./scripts/consolidate-memory.sh"
        exit 0
      else
        log_warn "Consolidation not triggered"
        exit 1
      fi
      ;;
  esac
}

main "$@"
