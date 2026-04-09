#!/usr/bin/env bash
set -euo pipefail

# Show the last N lines, then keep streaming new logs.
# Usage:
#   scripts/tail-logs.sh            # defaults to 100 lines
#   scripts/tail-logs.sh 200        # show 200 recent lines, then follow

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.sample to .env and fill in credentials."
  exit 1
fi

SSH_URL="$(grep '^ssh-url=' .env | cut -d= -f2- || true)"
SERVICE="$(grep '^nanobot-service=' .env | cut -d= -f2- || true)"
LINES="${1:-100}"

for var in SSH_URL SERVICE; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: $var not found in .env"
    exit 1
  fi
done

if ! [[ "$LINES" =~ ^[0-9]+$ ]]; then
  echo "ERROR: lines must be a positive integer"
  exit 1
fi

echo "Tailing ${SERVICE} from ${SSH_URL} (last ${LINES} lines, then live). Ctrl+C to stop."
ssh -t "$SSH_URL" "journalctl --user -u $SERVICE -n $LINES -f --no-pager"
