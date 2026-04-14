#!/usr/bin/env bash
set -euo pipefail

# ── Exclusion list ────────────────────────────────────────────────────────────
# Add or remove entries here to control what gets backed up from ~/.hermes
EXCLUDES=(
  # ── Git / metadata ──
  '.git'

  # ── Large / generated caches ──
  'models_dev_cache.json'
  'audio_cache/'
  'image_cache/'

  # ── Runtime state (regenerated on start) ──
  'gateway.pid'
  'gateway_state.json'
  'auth.lock'
  '.update_check'
  '.tirith-install-failed'

  # ── Database WAL/SHM (transient) ──
  'state.db-shm'
  'state.db-wal'

  # ── Cloned repos (can re-clone) ──
  'botbies.github.io/'
  'hermes-agent/'

  # ── Sandbox / temp ──
  'sandboxes/'

  # ── Binaries (can reinstall) ──
  'bin/'

  # ── Common junk ──
  '.DS_Store'
  'Thumbs.db'
  '*.tmp'
  '*.swp'
  '*~'
  '__pycache__/'
  '*.pyc'
  '*.log'
)

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.sample to .env and fill in credentials."
  exit 1
fi

HERMES_SSH="$(grep '^hermes-ssh=' .env | cut -d= -f2-)"
HERMES_PORT="$(grep '^hermes-ssh-port=' .env | cut -d= -f2-)"
HERMES_PASS="$(grep '^hermes-pass=' .env | cut -d= -f2-)"

if [[ -z "$HERMES_SSH" ]]; then
  echo "ERROR: hermes-ssh not found in .env"
  exit 1
fi
if [[ -z "$HERMES_PORT" ]]; then
  echo "ERROR: hermes-ssh-port not found in .env"
  exit 1
fi
if [[ -z "$HERMES_PASS" ]]; then
  echo "ERROR: hermes-pass not found in .env"
  exit 1
fi

# ── Check dependencies ──────────────────────────────────────────────────────
if ! command -v sshpass &>/dev/null; then
  echo "ERROR: sshpass is required but not installed."
  echo "  macOS:  brew install hudochenkov/sshpass/sshpass"
  echo "  Linux:  apt install sshpass  /  dnf install sshpass"
  exit 1
fi

# ── Config ───────────────────────────────────────────────────────────────────
BACKUP_DIR="./backups/hermes-backup"
REMOTE_DIR="~/.hermes/"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ── Prepare backup directory ─────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"

if [[ ! -d "$BACKUP_DIR/.git" ]]; then
  echo "Initializing git repo in $BACKUP_DIR"
  git init "$BACKUP_DIR"

  # .gitignore mirrors the EXCLUDES list for git tracking
  {
    for item in "${EXCLUDES[@]}"; do
      echo "$item"
    done
  } > "$BACKUP_DIR/.gitignore"
fi

# ── Build rsync exclude flags ───────────────────────────────────────────────
RSYNC_EXCLUDES=()
for item in "${EXCLUDES[@]}"; do
  RSYNC_EXCLUDES+=(--exclude="$item")
done

# ── Sync from remote ────────────────────────────────────────────────────────
echo "Syncing ${HERMES_SSH}:${REMOTE_DIR} (port ${HERMES_PORT}) → $BACKUP_DIR"
SSHPASS="$HERMES_PASS" sshpass -e rsync -avz --delete \
  -e "ssh -p ${HERMES_PORT} -o StrictHostKeyChecking=no" \
  "${RSYNC_EXCLUDES[@]}" \
  "${HERMES_SSH}:${REMOTE_DIR}/" \
  "$BACKUP_DIR/"

# ── Review & commit changes ─────────────────────────────────────────────────
cd "$BACKUP_DIR"
git add -A

if ! git diff --cached --quiet 2>/dev/null; then
  echo ""
  echo "=== Files to commit ==="
  git diff --cached --name-status
  echo ""
  echo "=== Diff summary ==="
  git diff --cached --stat
  echo ""
  read -rp "Commit these changes? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git commit -m "backup: $TIMESTAMP"
    echo "Committed backup: $TIMESTAMP"
  else
    git reset HEAD --quiet 2>/dev/null || true
    echo "Backup skipped."
  fi
elif git rev-parse HEAD &>/dev/null; then
  echo "No changes detected. Backup up to date."
else
  echo "No changes to commit (initial backup, answer y to create first commit)."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Backup complete."
if git rev-parse HEAD &>/dev/null; then
  echo "History:"
  git log --oneline -5
fi
