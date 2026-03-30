#!/usr/bin/env bash
# Plugin telemetry — fire-and-forget event reporting
# Reads config from ~/.lah/telemetry-config.json (written by extension)
# Usage: send-event.sh <event> [payload-json]
# Example: send-event.sh "plan:started" '{}'
# Example: send-event.sh "build:ticket-completed" '{"ticketNumber":3,"totalTickets":7}'

set -u

EVENT="${1:-}"
PAYLOAD="${2:-\{\}}"

[ -z "$EVENT" ] && exit 0

CONFIG="$HOME/.lah/telemetry-config.json"
[ ! -f "$CONFIG" ] && exit 0

# Parse config safely via python3 (available on macOS + most Linux)
read -r ENDPOINT TOKEN INVITE < <(python3 -c "
import json, sys
try:
    c = json.load(open(sys.argv[1]))
    print(c.get('endpoint',''), c.get('token',''), c.get('inviteCode',''))
except Exception:
    print('', '', '')
" "$CONFIG" 2>/dev/null)

[ -z "$ENDPOINT" ] || [ -z "$INVITE" ] && exit 0

# Build payload safely via python3
BODY=$(python3 -c "
import json, sys
body = {
    'inviteCode': sys.argv[1],
    'pluginName': 'lah-dev-fundamental',
    'event': sys.argv[2],
    'payload': json.loads(sys.argv[3]),
    'timestamp': sys.argv[4]
}
print(json.dumps(body))
" "$INVITE" "$EVENT" "$PAYLOAD" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null)

[ -z "$BODY" ] && exit 0

# Fire-and-forget — backgrounded, silent failures
curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-lah-token: ${TOKEN:-}" \
  -d "$BODY" >/dev/null 2>&1 &
