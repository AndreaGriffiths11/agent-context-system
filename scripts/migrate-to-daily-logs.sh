#!/bin/bash
# Migrate .agents.local.md to daily logs + topic files structure
#
# Usage:
#   ./scripts/migrate-to-daily-logs.sh [--dry-run]

set -euo pipefail

AGENTS_DIR="${AGENTS_DIR:-.agents}"
OLD_LOCAL="$AGENTS_DIR/local.md"
OLD_BACKUP="$AGENTS_DIR/local.md.backup"
NEW_INDEX="$AGENTS_DIR/local.md"
LOGS_DIR="$AGENTS_DIR/logs"
TOPICS_DIR="$AGENTS_DIR/topics"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }

# Check if already migrated
if [[ -d "$LOGS_DIR" ]] || [[ -d "$TOPICS_DIR" ]]; then
  log_warn "Already migrated (logs/ or topics/ exists)"
  exit 0
fi

# Check if .agents.local.md exists (legacy name)
LEGACY_LOCAL=".agents.local.md"
if [[ -f "$LEGACY_LOCAL" ]] && [[ ! -f "$OLD_LOCAL" ]]; then
  log_info "Found legacy .agents.local.md, renaming to .agents/local.md"
  mkdir -p "$AGENTS_DIR"
  mv "$LEGACY_LOCAL" "$OLD_LOCAL"
fi

# Check if local.md exists
if [[ ! -f "$OLD_LOCAL" ]]; then
  log_warn "No local.md found, nothing to migrate"
  log_info "Creating fresh structure..."
  mkdir -p "$LOGS_DIR" "$TOPICS_DIR"
  
  # Create fresh index
  cat > "$NEW_INDEX" <<'EOF'
# Memory Index

## Patterns
<!-- One-line entries, ~150 chars max -->
<!-- Format: - [Title](topics/file.md#anchor) — Description -->

## Gotchas
<!-- One-line entries, ~150 chars max -->

## Preferences
<!-- One-line entries, ~150 chars max -->

## Session Observations (auto)
<!-- Auto-reflect appends here during sessions -->
<!-- Format: - YYYY-MM-DDTHH:MMZ | Observation text -->

## Ready to Promote
<!-- Auto-reflect flags patterns here after 3+ sessions -->
<!-- Format: | Category | Item | Detail | -->
EOF
  
  log_info "Created fresh .agents/ structure"
  exit 0
fi

# Dry run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  log_warn "DRY RUN MODE (no changes will be made)"
fi

# Backup original
if [[ "$DRY_RUN" == false ]]; then
  cp "$OLD_LOCAL" "$OLD_BACKUP"
  log_info "Backed up to $OLD_BACKUP"
fi

# Create directories
if [[ "$DRY_RUN" == false ]]; then
  mkdir -p "$LOGS_DIR" "$TOPICS_DIR"
fi

# Parse sections from old local.md
# This is a simple line-by-line parser
# In production, you'd want something more robust

current_section=""
current_content=""
declare -A sections

while IFS= read -r line; do
  if [[ "$line" =~ ^##\  ]]; then
    # Save previous section
    if [[ -n "$current_section" ]]; then
      sections["$current_section"]="$current_content"
    fi
    
    # Start new section
    current_section="${line#\#\# }"
    current_content=""
  else
    current_content+="$line"$'\n'
  fi
done < "$OLD_LOCAL"

# Save last section
if [[ -n "$current_section" ]]; then
  sections["$current_section"]="$current_content"
fi

# Create today's daily log
TODAY=$(date +%Y-%m-%d)
DAILY_LOG="$LOGS_DIR/$TODAY.md"

if [[ "$DRY_RUN" == false ]]; then
  cat > "$DAILY_LOG" <<EOF
# Daily Log — $TODAY

## Migration from .agents.local.md

Original scratchpad migrated to daily logs + topic files structure.

### Session Observations
${sections["Session Observations (auto)"]:-No observations}

### Notes
${sections["Session Notes"]:-No session notes}
EOF
  log_info "Created daily log: $DAILY_LOG"
else
  log_info "[DRY RUN] Would create: $DAILY_LOG"
fi

# Create topic files
# Patterns
if [[ -n "${sections["Patterns"]:-}" ]] || [[ -n "${sections["Ready to Promote"]:-}" ]]; then
  PATTERNS_FILE="$TOPICS_DIR/patterns.md"
  if [[ "$DRY_RUN" == false ]]; then
    cat > "$PATTERNS_FILE" <<EOF
---
type: pattern
created: $TODAY
updated: $TODAY
---

# Patterns

${sections["Patterns"]:-No patterns yet}

## From Ready to Promote

${sections["Ready to Promote"]:-No patterns ready to promote}
EOF
    log_info "Created: $PATTERNS_FILE"
  else
    log_info "[DRY RUN] Would create: $PATTERNS_FILE"
  fi
fi

# Gotchas
if [[ -n "${sections["Gotchas"]:-}" ]]; then
  GOTCHAS_FILE="$TOPICS_DIR/gotchas.md"
  if [[ "$DRY_RUN" == false ]]; then
    cat > "$GOTCHAS_FILE" <<EOF
---
type: gotcha
created: $TODAY
updated: $TODAY
---

# Gotchas

${sections["Gotchas"]:-No gotchas yet}
EOF
    log_info "Created: $GOTCHAS_FILE"
  else
    log_info "[DRY RUN] Would create: $GOTCHAS_FILE"
  fi
fi

# Preferences
if [[ -n "${sections["Preferences"]:-}" ]]; then
  PREFS_FILE="$TOPICS_DIR/preferences.md"
  if [[ "$DRY_RUN" == false ]]; then
    cat > "$PREFS_FILE" <<EOF
---
type: preference
created: $TODAY
updated: $TODAY
---

# Preferences

${sections["Preferences"]:-No preferences yet}
EOF
    log_info "Created: $PREFS_FILE"
  else
    log_info "[DRY RUN] Would create: $PREFS_FILE"
  fi
fi

# Create new index
if [[ "$DRY_RUN" == false ]]; then
  cat > "$NEW_INDEX" <<'EOF'
# Memory Index

## Patterns
- [Patterns](topics/patterns.md) — Recurring patterns from sessions

## Gotchas
- [Gotchas](topics/gotchas.md) — Traps and fixes

## Preferences
- [Preferences](topics/preferences.md) — Personal preferences

## Session Observations (auto)
<!-- Auto-reflect appends here during sessions -->
<!-- Format: - YYYY-MM-DDTHH:MMZ | Observation text -->

## Ready to Promote
<!-- Auto-reflect flags patterns here after 3+ sessions -->
<!-- Format: | Category | Item | Detail | -->

---

**Migration completed:** '$TODAY'
**Original backup:** local.md.backup
**Daily logs:** logs/YYYY-MM-DD.md (append-only)
**Topic files:** topics/*.md (curated)
EOF
  log_info "Created new index: $NEW_INDEX"
else
  log_info "[DRY RUN] Would create new index: $NEW_INDEX"
fi

# Summary
echo
log_info "Migration summary:"
log_info "  ✅ Backup: $OLD_BACKUP"
log_info "  ✅ Daily log: $DAILY_LOG"
log_info "  ✅ Topic files: $TOPICS_DIR/*.md"
log_info "  ✅ New index: $NEW_INDEX"
echo
log_info "Next steps:"
log_info "  1. Review migrated files"
log_info "  2. Update AGENTS.md (add reference to .agents/ structure)"
log_info "  3. Run: ./scripts/auto-consolidation-trigger.sh --check"
