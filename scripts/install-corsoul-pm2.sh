#!/bin/sh
set -eu

CORSOUL_VERSION=0.1.20
PM2_VERSION=7.0.3
PROCESS_NAME=corsoul-mcp
HEALTH_URL=http://127.0.0.1:3848/health

command -v node >/dev/null 2>&1 || { echo 'Node.js 22 or newer is required.' >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo 'npm is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo 'curl is required for health checks.' >&2; exit 1; }
NODE_MAJOR=$(node --version | sed 's/^v//' | cut -d. -f1)
[ "$NODE_MAJOR" -ge 22 ] || { echo 'Node.js 22 or newer is required.' >&2; exit 1; }

if command -v curl >/dev/null 2>&1 && curl --silent --fail --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
  if command -v pm2 >/dev/null 2>&1 && pm2 describe "$PROCESS_NAME" >/dev/null 2>&1; then
    echo "Corsoul is already healthy and managed as $PROCESS_NAME."
    pm2 save
    echo 'Confirm reboot recovery once with: pm2 startup'
    echo 'Execute the privileged command printed by PM2, then run: pm2 save'
    exit 0
  fi
  echo 'Port 3848 already has a healthy owner that is not the managed corsoul-mcp process. Stop or migrate it explicitly; this installer will not replace it.' >&2
  exit 1
fi

echo "Installing corsoul@$CORSOUL_VERSION and pm2@$PM2_VERSION globally..."
npm install --global --no-audit --no-fund "corsoul@$CORSOUL_VERSION" "pm2@$PM2_VERSION"
GLOBAL_ROOT=$(npm root --global)
SERVER_SCRIPT="$GLOBAL_ROOT/corsoul/bin/corsoul-mcp-local.js"
[ -f "$SERVER_SCRIPT" ] || { echo "Corsoul server entrypoint not found: $SERVER_SCRIPT" >&2; exit 1; }

if pm2 describe "$PROCESS_NAME" >/dev/null 2>&1; then pm2 delete "$PROCESS_NAME"; fi
unset DATABASE_URL || true

# Supervision policy (crash-loop backoff, restart ceiling, and "exit code 78 means stop, do not
# relaunch") comes from the installed client, which asks THIS machine's pm2 what it understands —
# never a second hand-written list in shell. It must sit BEFORE `--`: everything after `--` is
# handed to the app, so flags placed there never bind (measured). An older client, no pm2 or an
# unreadable answer all yield an empty list = exactly the line that shipped before; the list is
# validated and dropped WHOLE, because one unrecognised token makes pm2 reject the entire start.
HARDEN=""
PM2_ARGS_JS="$(dirname "$(dirname "$SERVER_SCRIPT")")/scripts/pm2-args.mjs"
if [ -f "$PM2_ARGS_JS" ]; then
  raw=$(node "$PM2_ARGS_JS" 2>/dev/null | tr -d '\r') || raw=""
  for tok in $raw; do
    case "$tok" in
      --[a-z]?*) ;;      # a flag
      *[!0-9]*)  raw=""; break ;;   # neither a flag nor a numeric value: trust none of it
      *) ;;              # a numeric value
    esac
  done
  HARDEN="$raw"
fi

# shellcheck disable=SC2086  # deliberate word split: $HARDEN is a validated list of pm2 flags
pm2 start "$SERVER_SCRIPT" --name "$PROCESS_NAME" --interpreter node $HARDEN -- --transport=http --host=127.0.0.1 --port=3848
pm2 save

i=0
while [ "$i" -lt 30 ]; do
  if command -v curl >/dev/null 2>&1 && curl --silent --fail --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then break; fi
  i=$((i + 1))
  sleep 1
done
if [ "$i" -ge 30 ]; then
  echo "PM2 started $PROCESS_NAME, but $HEALTH_URL did not become healthy. Run: pm2 logs $PROCESS_NAME" >&2
  exit 1
fi

echo 'Corsoul is supervised by PM2. To restore it after a machine reboot, run:'
echo '  pm2 startup'
echo 'Then execute the privileged command printed by PM2 and run:'
echo '  pm2 save'
echo "Status: pm2 status | Logs: pm2 logs $PROCESS_NAME"
echo 'This installer did not start corsoul-activation-runner.'
