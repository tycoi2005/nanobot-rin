#!/usr/bin/env bash
set -euo pipefail

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.sample to .env and fill in credentials."
  exit 1
fi
SSH_URL="$(grep '^ssh-url=' .env | cut -d= -f2- || true)"

for var in SSH_URL; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: $var not found in .env"
    exit 1
  fi
done

# ── Config ───────────────────────────────────────────────────────────────────
BACKUP_DIR="./backups/nanobot-backup"
CONFIG_FILE="$BACKUP_DIR/config.json"
REMOTE_CONFIG="~/.nanobot/config.json"

# ── Check backup exists ─────────────────────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found in backup."
  echo "Run 'bash scripts/backup.sh' first."
  exit 1
fi

# ── Validate JSON ────────────────────────────────────────────────────────────
if ! python3 -m json.tool "$CONFIG_FILE" > /dev/null 2>&1; then
  echo "ERROR: Invalid JSON in $CONFIG_FILE"
  exit 1
fi
echo "JSON validation passed."
echo ""

# ── Show current config ─────────────────────────────────────────────────────
echo "=== Current remote config ==="
ssh "$SSH_URL" "cat $REMOTE_CONFIG 2>/dev/null || echo '(not found)'"
echo ""
echo "=== Backup config ==="
cat "$CONFIG_FILE"
echo ""

# ── Confirm ──────────────────────────────────────────────────────────────────
read -rp "Upload this config to ${SSH_URL}:${REMOTE_CONFIG}? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# ── Upload ───────────────────────────────────────────────────────────────────
scp "$CONFIG_FILE" "${SSH_URL}:${REMOTE_CONFIG}"
echo ""
echo "Config uploaded successfully."
