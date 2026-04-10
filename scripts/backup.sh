#!/usr/bin/env bash
set -euo pipefail

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.sample to .env and fill in credentials."
  exit 1
fi
SSH_URL="$(grep '^ssh-url=' .env | cut -d= -f2-)"
if [[ -z "$SSH_URL" ]]; then
  echo "ERROR: ssh-url not found in .env"
  exit 1
fi

# ── Config ───────────────────────────────────────────────────────────────────
BACKUP_DIR="./backups/nanobot-backup"
REMOTE_DIR="~/.nanobot/"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ── Prepare backup directory ─────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"

if [[ ! -d "$BACKUP_DIR/.git" ]]; then
  echo "Initializing git repo in $BACKUP_DIR"
  git init "$BACKUP_DIR"
  cat > "$BACKUP_DIR/.gitignore" << 'EOF'
.git
.env
node_modules/
whatsapp-auth/
bridge/
workspace/nanobot/
workspace/botbies.github.io/
workspace/botbies-log/
workspace/projects/
*.log
.DS_Store
Thumbs.db
*.tmp
*.swp
*~
.cache/
dist/
build/
__pycache__/
*.pyc
EOF
fi

# ── Sync from remote ────────────────────────────────────────────────────────
echo "Syncing ${SSH_URL}:${REMOTE_DIR} → $BACKUP_DIR"
rsync -avz --delete \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='node_modules/' \
  --exclude='whatsapp-auth/' \
  --exclude='bridge/' \
  --exclude='workspace/nanobot/' \
  --exclude='workspace/botbies.github.io/' \
  --exclude='workspace/botbies-log/' \
  --exclude='workspace/projects/' \
  --exclude='*.log' \
  --exclude='.DS_Store' \
  --exclude='Thumbs.db' \
  --exclude='*.tmp' \
  --exclude='*.swp' \
  --exclude='*~' \
  --exclude='.cache/' \
  --exclude='dist/' \
  --exclude='build/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  "${SSH_URL}:${REMOTE_DIR}/" \
  "$BACKUP_DIR/"

# ── Review & commit changes ──────────────────────────────────────────────────
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
