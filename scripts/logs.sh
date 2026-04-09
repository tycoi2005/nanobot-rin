#!/usr/bin/env bash
set -euo pipefail

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.sample to .env and fill in credentials."
  exit 1
fi
SSH_URL="$(grep '^ssh-url=' .env | cut -d= -f2- || true)"
SERVICE="$(grep '^nanobot-service=' .env | cut -d= -f2- || true)"

for var in SSH_URL SERVICE; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: $var not found in .env"
    exit 1
  fi
done

# ── Choose log mode ──────────────────────────────────────────────────────────
echo "Log mode:"
echo "  1) Follow logs (live)"
echo "  2) Show recent logs"
echo ""
read -rp "Select mode [1/2]: " mode

if [[ "$mode" == "1" ]]; then
  echo "Following logs from ${SSH_URL} (Ctrl+C to stop)..."
  ssh -t "$SSH_URL" "journalctl --user -u $SERVICE -f --no-pager"
else
  read -rp "Number of lines to show [100]: " lines
  lines="${lines:-100}"
  echo "=== Last $lines lines of $SERVICE logs ==="
  ssh "$SSH_URL" "journalctl --user -u $SERVICE -n $lines --no-pager"
fi
