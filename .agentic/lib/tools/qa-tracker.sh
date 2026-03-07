#!/usr/bin/env bash
# qa-tracker.sh — QA state machine for verification and propagation tracking
#
# Usage:
#   bash qa-tracker.sh status                   # One-liner for dashboards
#   bash qa-tracker.sh pending                  # List open propagation items
#   bash qa-tracker.sh add-propagation "source" "change" "F-0042,F-0067"
#   bash qa-tracker.sh resolve PQ-001           # Mark resolved
#   bash qa-tracker.sh defer PQ-001 "reason"    # Defer with documented reason
#   bash qa-tracker.sh check-escalation         # Used by periodic-checks.sh
#
# State: .agentic/session/.qa-tracker.json (gitignored, session-persistent)
# Exit code: always 0 (advisory tool)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"

TRACKER_FILE="$ROOT_DIR/.agentic/session/.qa-tracker.json"
SESSION_DIR="$ROOT_DIR/.agentic/session"

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' DIM='' NC=''
fi

# Ensure state dir exists
mkdir -p "$SESSION_DIR"

# Initialize tracker if missing
_ensure_tracker() {
    if [ ! -f "$TRACKER_FILE" ]; then
        python3 -c "
import json, os
data = {
    'verification': {
        'last_full_audit': None,
        'last_audit_commit': None,
        'audit_freshness_days': 30,
        'features': {}
    },
    'propagation': {
        'pending': [],
        'resolved': []
    },
    'summary': {
        'features_total': 0,
        'features_verified': 0,
        'features_never_verified': 0,
        'pending_propagation_items': 0,
        'days_since_full_audit': None,
        'audit_overdue': False
    }
}
os.makedirs(os.path.dirname('$TRACKER_FILE'), exist_ok=True)
with open('$TRACKER_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || {
            echo '{}' > "$TRACKER_FILE"
        }
    fi
}

# --- Commands ---

cmd_status() {
    if [ ! -f "$TRACKER_FILE" ]; then
        echo "QA: not initialized (run ag audit)"
        return
    fi

    python3 -c "
import json
with open('$TRACKER_FILE') as f:
    data = json.load(f)
s = data.get('summary', {})
v = s.get('features_verified', 0)
t = s.get('features_total', 0)
p = s.get('pending_propagation_items', 0)
overdue = s.get('audit_overdue', False)
suffix = ' OVERDUE' if overdue else ''
print(f'QA: {v}/{t} verified, {p} pending{suffix}')
" 2>/dev/null || echo "QA: tracker error"
}

cmd_pending() {
    _ensure_tracker
    python3 -c "
import json
with open('$TRACKER_FILE') as f:
    data = json.load(f)
pending = data.get('propagation', {}).get('pending', [])
if not pending:
    print('No pending propagation items.')
else:
    for item in pending:
        pq_id = item.get('id', '?')
        source = item.get('source', '?')
        change = item.get('change', '?')
        items = item.get('items', [])
        open_count = sum(1 for i in items if i.get('status') == 'open')
        print(f'{pq_id}: {source} — {change} ({open_count} open)')
        for sub in items:
            status_mark = '✓' if sub['status'] == 'resolved' else '○'
            print(f'  {status_mark} {sub[\"feature\"]} ({sub[\"artifact\"]}): {sub[\"detail\"]}')
" 2>/dev/null
}

cmd_add_propagation() {
    local source="$1"
    local change="$2"
    local features_csv="$3"

    _ensure_tracker

    python3 -c "
import json
from datetime import datetime, timezone

with open('$TRACKER_FILE') as f:
    data = json.load(f)

# Generate next PQ ID
pending = data.get('propagation', {}).get('pending', [])
resolved = data.get('propagation', {}).get('resolved', [])
max_id = 0
for item in pending + resolved:
    try:
        num = int(item.get('id', 'PQ-000').split('-')[1])
        if num > max_id:
            max_id = num
    except (ValueError, IndexError):
        pass
next_id = f'PQ-{max_id + 1:03d}'

features = [f.strip() for f in '$features_csv'.split(',') if f.strip()]
items = [{'feature': f, 'artifact': 'acceptance', 'status': 'open', 'detail': 'Needs review after $source change'} for f in features]

entry = {
    'id': next_id,
    'created': datetime.now(timezone.utc).isoformat(),
    'source': '$source',
    'change': '$change',
    'affected_features': features,
    'items': items
}

data.setdefault('propagation', {}).setdefault('pending', []).append(entry)
data['summary']['pending_propagation_items'] = sum(
    sum(1 for i in p.get('items', []) if i.get('status') == 'open')
    for p in data['propagation']['pending']
)

with open('$TRACKER_FILE', 'w') as f:
    json.dump(data, f, indent=2)

print(f'Created {next_id}: {len(features)} feature(s) affected')
" 2>/dev/null
}

cmd_resolve() {
    local pq_id="$1"
    _ensure_tracker

    python3 -c "
import json
from datetime import datetime, timezone

with open('$TRACKER_FILE') as f:
    data = json.load(f)

found = False
pending = data.get('propagation', {}).get('pending', [])
for i, item in enumerate(pending):
    if item.get('id') == '$pq_id':
        # Mark all items resolved
        for sub in item.get('items', []):
            sub['status'] = 'resolved'
            sub['resolved_at'] = datetime.now(timezone.utc).isoformat()
        # Move to resolved
        data['propagation'].setdefault('resolved', []).append({
            'id': item['id'],
            'source': item.get('source'),
            'resolved': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
            'items_count': len(item.get('items', []))
        })
        pending.pop(i)
        found = True
        break

if found:
    data['summary']['pending_propagation_items'] = sum(
        sum(1 for i in p.get('items', []) if i.get('status') == 'open')
        for p in data['propagation']['pending']
    )
    with open('$TRACKER_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print(f'Resolved $pq_id')
else:
    print(f'$pq_id not found in pending items')
" 2>/dev/null
}

cmd_defer() {
    local pq_id="$1"
    local reason="$2"
    _ensure_tracker

    python3 -c "
import json
from datetime import datetime, timezone

with open('$TRACKER_FILE') as f:
    data = json.load(f)

found = False
for item in data.get('propagation', {}).get('pending', []):
    if item.get('id') == '$pq_id':
        item['deferred'] = True
        item['defer_reason'] = '''$reason'''
        item['deferred_at'] = datetime.now(timezone.utc).isoformat()
        found = True
        break

if found:
    with open('$TRACKER_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print(f'Deferred $pq_id: $reason')
else:
    print(f'$pq_id not found in pending items')
" 2>/dev/null
}

cmd_check_escalation() {
    if [ ! -f "$TRACKER_FILE" ]; then
        return
    fi

    local warn_days
    warn_days=$(get_setting "qa_propagation_warn_days" "3")
    local escalate_days
    escalate_days=$(get_setting "qa_propagation_escalate_days" "7")
    local freshness_days
    freshness_days=$(get_setting "qa_audit_freshness_days" "30")

    python3 -c "
import json
from datetime import datetime, timezone, timedelta

with open('$TRACKER_FILE') as f:
    data = json.load(f)

now = datetime.now(timezone.utc)
warnings = []

# Check pending propagation items age
for item in data.get('propagation', {}).get('pending', []):
    if item.get('deferred'):
        continue
    created = item.get('created', '')
    if not created:
        continue
    try:
        created_dt = datetime.fromisoformat(created)
        age_days = (now - created_dt).days
        pq_id = item.get('id', '?')
        open_count = sum(1 for i in item.get('items', []) if i.get('status') == 'open')
        if open_count == 0:
            continue
        if age_days >= $escalate_days:
            warnings.append(f'ESCALATE: {pq_id} open {age_days} days ({open_count} items)')
        elif age_days >= $warn_days:
            warnings.append(f'WARNING: {pq_id} open {age_days} days ({open_count} items)')
    except (ValueError, TypeError):
        pass

# Check audit freshness
last_audit = data.get('verification', {}).get('last_full_audit')
if last_audit:
    try:
        audit_dt = datetime.fromisoformat(last_audit)
        audit_age = (now - audit_dt).days
        data['summary']['days_since_full_audit'] = audit_age
        if audit_age >= $freshness_days:
            data['summary']['audit_overdue'] = True
            warnings.append(f'OVERDUE: Full audit {audit_age} days ago (threshold: $freshness_days)')
        else:
            data['summary']['audit_overdue'] = False
    except (ValueError, TypeError):
        pass

with open('$TRACKER_FILE', 'w') as f:
    json.dump(data, f, indent=2)

for w in warnings:
    print(w)
" 2>/dev/null
}

# --- Main ---

case "${1:-}" in
    status)
        cmd_status
        ;;
    pending)
        cmd_pending
        ;;
    add-propagation)
        cmd_add_propagation "${2:-}" "${3:-}" "${4:-}"
        ;;
    resolve)
        cmd_resolve "${2:-}"
        ;;
    defer)
        cmd_defer "${2:-}" "${3:-}"
        ;;
    check-escalation)
        cmd_check_escalation
        ;;
    --help|-h)
        cat <<'USAGE'
Usage:
  bash qa-tracker.sh status                   # One-liner for dashboards
  bash qa-tracker.sh pending                  # List open propagation items
  bash qa-tracker.sh add-propagation "src" "change" "F-0042,F-0067"
  bash qa-tracker.sh resolve PQ-001           # Mark resolved
  bash qa-tracker.sh defer PQ-001 "reason"    # Defer with documented reason
  bash qa-tracker.sh check-escalation         # Check age-based escalation
USAGE
        ;;
    *)
        echo "Unknown command: ${1:-}"
        echo "Run: bash qa-tracker.sh --help"
        ;;
esac

exit 0
