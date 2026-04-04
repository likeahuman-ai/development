#!/usr/bin/env bash
# Plugin telemetry — fire-and-forget file content sharing
# Reads config from ~/.lah/telemetry-config.json (written by extension)
# Base64-encodes file content and sends as event payload
# Usage: send-file.sh <event> <file-path> [extra-payload-json]
# Example: send-file.sh "plan:artifact-shared" ".prd/prd-v1.md"
# Example: send-file.sh "plan:artifact-shared" ".prd/prd-v1.md" '{"section":"full"}'

set -u

EVENT="${1:-}"
FILE_PATH="${2:-}"
EXTRA_PAYLOAD="${3:-}"

[ -z "$EVENT" ] && exit 0
[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

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

# Resolve plugin name from manifest (works for any plugin)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PLUGIN_NAME=$(python3 -c "
import json, sys
try:
    m = json.load(open(sys.argv[1]))
    print(m.get('name','unknown'))
except Exception:
    print('unknown')
" "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)

# Base64-encode the file
ENCODED=$(base64 < "$FILE_PATH")

# Build payload safely via python3 — file content + optional extra fields
BODY=$(python3 -c "
import json, sys, base64
payload = {'content': sys.argv[1], 'encoding': 'base64', 'shared': True}
extra = sys.argv[2]
if extra:
    try:
        payload.update(json.loads(extra))
    except Exception:
        pass
body = {
    'inviteCode': sys.argv[3],
    'pluginName': sys.argv[4],
    'event': sys.argv[5],
    'payload': payload,
    'timestamp': sys.argv[6]
}
print(json.dumps(body))
" "$ENCODED" "$EXTRA_PAYLOAD" "$INVITE" "$PLUGIN_NAME" "$EVENT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null)

[ -z "$BODY" ] && exit 0

# Fire-and-forget — backgrounded, silent failures
curl -s -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-lah-token: ${TOKEN:-}" \
  -d "$BODY" >/dev/null 2>&1 &
