#!/usr/bin/env bash
set -euo pipefail

# ── Load .env ────────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.sample to .env and fill in credentials."
  exit 1
fi
SSH_URL="$(grep '^ssh-url=' .env | cut -d= -f2- || true)"
REPO="$(grep '^nanobot-repo=' .env | cut -d= -f2- || true)"
REMOTE_DIR="$(grep '^nanobot-remote-dir=' .env | cut -d= -f2- || true)"
VENV="$(grep '^nanobot-venv=' .env | cut -d= -f2- || true)"
SERVICE="$(grep '^nanobot-service=' .env | cut -d= -f2- || true)"

for var in SSH_URL REPO REMOTE_DIR VENV SERVICE; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: $var not found in .env"
    exit 1
  fi
done

# ── Choose deploy mode ───────────────────────────────────────────────────────
echo "Deploy mode:"
echo "  1) Latest code (main branch)"
echo "  2) Specific tag"
echo ""
read -rp "Select mode [1/2]: " mode

if [[ "$mode" == "1" ]]; then
  TARGET="main"
  echo ""
  echo "Deploying latest code from: $TARGET"
else
  # ── Fetch tags ───────────────────────────────────────────────────────────
  echo "Fetching tags from $REPO ..."
  TAGS=()
  while IFS= read -r tag; do
    TAGS+=("$tag")
  done < <(git ls-remote --tags --refs "$REPO" | awk -F'/' '{print $NF}' | sort -V)

  if [[ ${#TAGS[@]} -eq 0 ]]; then
    echo "ERROR: No tags found in $REPO"
    exit 1
  fi

  echo ""
  echo "Available tags:"
  for i in "${!TAGS[@]}"; do
    echo "  $((i+1))) ${TAGS[$i]}"
  done
  echo ""

  read -rp "Select a tag (number or name): " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#TAGS[@]} )); then
    TARGET="${TAGS[$((choice-1))]}"
  else
    TARGET="$choice"
  fi

  echo ""
  echo "Deploying tag: $TARGET"
fi
echo ""

# ── Deploy on remote ────────────────────────────────────────────────────────
ssh "$SSH_URL" bash -s -- "$REPO" "$REMOTE_DIR" "$TARGET" "$VENV" "$SERVICE" << 'REMOTE_SCRIPT'
set -euo pipefail

REPO="$1"
REMOTE_DIR="$2"
TARGET="$3"
VENV="$4"
SERVICE="$5"

echo "=== Stopping service ==="
systemctl --user stop "$SERVICE" 2>/dev/null || true

if [[ -d "$REMOTE_DIR" ]]; then
  echo "=== Updating existing repo ==="
  cd "$REMOTE_DIR"
  git fetch --all
else
  echo "=== Cloning repo ==="
  git clone "$REPO" "$REMOTE_DIR"
  cd "$REMOTE_DIR"
fi

echo "=== Checking out $TARGET ==="
git checkout "$TARGET"
git pull

echo "=== Installing ==="
source "$VENV/bin/activate"
pip install -e .

echo "=== Starting service ==="
systemctl --user daemon-reload
systemctl --user start "$SERVICE"

echo ""
echo "=== Status ==="
systemctl --user status "$SERVICE" --no-pager
REMOTE_SCRIPT

echo ""
echo "Deploy complete."
