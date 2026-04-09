#!/usr/bin/env bash
set -euo pipefail

DEFAULT_DIR="./backups/nanobot-backup/workspace/sessions"

TARGET_DIR="${DEFAULT_DIR}"
TARGET_FILE=""
OUTPUT_FILE=""
OUTPUT_DIR=""
ASSUME_YES="false"

usage() {
  cat << 'EOF'
Usage:
  bash scripts/check-fix-json.sh [options]

Options:
  --dir <path>         Directory to scan recursively (default: backups/nanobot-backup/workspace/sessions)
  --file <path>        Check one file only
  --output <path>      Write fixed result to another file (only with --file)
  --output-dir <path>  Write fixed files to another directory (mirrors structure from --dir)
  --yes                Fix without interactive prompt
  -h, --help           Show help

Behavior:
  1) Scan all target files and show corrupted ones.
  2) Ask whether to fix corrupted files (unless --yes).
  3) By default, fixes files in place.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      [[ $# -ge 2 ]] || { echo "ERROR: --dir needs a value"; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --file)
      [[ $# -ge 2 ]] || { echo "ERROR: --file needs a value"; exit 1; }
      TARGET_FILE="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "ERROR: --output needs a value"; exit 1; }
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { echo "ERROR: --output-dir needs a value"; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --yes)
      ASSUME_YES="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$TARGET_FILE" && -n "$OUTPUT_DIR" ]]; then
  echo "ERROR: --output-dir cannot be used with --file"
  exit 1
fi

if [[ -n "$TARGET_FILE" && -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
fi

if [[ -z "$TARGET_FILE" && -n "$OUTPUT_FILE" ]]; then
  echo "ERROR: --output can only be used with --file"
  exit 1
fi

FILES=()
if [[ -n "$TARGET_FILE" ]]; then
  [[ -f "$TARGET_FILE" ]] || { echo "ERROR: File not found: $TARGET_FILE"; exit 1; }
  FILES+=("$TARGET_FILE")
  ROOT_BASE=""
else
  [[ -d "$TARGET_DIR" ]] || { echo "ERROR: Directory not found: $TARGET_DIR"; exit 1; }
  while IFS= read -r -d '' file; do
    FILES+=("$file")
  done < <(find "$TARGET_DIR" -type f -print0)
  ROOT_BASE="$TARGET_DIR"
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No files found."
  exit 0
fi

SCAN_TMP="$(mktemp)"
trap 'rm -f "$SCAN_TMP"' EXIT

validate_file() {
  local file="$1"
  python3 - "$file" << 'PY'
import json
import sys

path = sys.argv[1]

try:
    raw = open(path, "rb").read()
except Exception as exc:
    print(f"STATUS:ERROR")
    print(f"DETAIL:cannot read file: {exc}")
    sys.exit(3)

try:
    text = raw.decode("utf-8-sig")
except UnicodeDecodeError as exc:
    print("STATUS:INVALID")
    print("TYPE:binary-or-non-utf8")
    print(f"DETAIL:{exc}")
    sys.exit(2)

def try_json(full_text: str):
    try:
        json.loads(full_text)
        return True, ""
    except json.JSONDecodeError as e:
        return False, f"line {e.lineno}, col {e.colno}: {e.msg}"

ok_json, err_json = try_json(text)
if ok_json:
    print("STATUS:VALID")
    print("TYPE:json")
    sys.exit(0)

invalid = []
valid_count = 0
for i, line in enumerate(text.splitlines(), start=1):
    s = line.strip()
    if not s:
        continue
    try:
        json.loads(s)
        valid_count += 1
    except json.JSONDecodeError as e:
        invalid.append((i, e.msg))

if valid_count > 0:
    if invalid:
        print("STATUS:INVALID")
        print("TYPE:jsonl")
        print(f"DETAIL:invalid lines {len(invalid)}")
        for line_no, msg in invalid[:10]:
            print(f"INVALID_LINE:{line_no}:{msg}")
        sys.exit(2)
    print("STATUS:VALID")
    print("TYPE:jsonl")
    sys.exit(0)

print("STATUS:INVALID")
print("TYPE:unknown")
print(f"DETAIL:json parse failed ({err_json})")
sys.exit(2)
PY
}

fix_file() {
  local src="$1"
  local dest="$2"

  python3 - "$src" "$dest" << 'PY'
import json
import os
import re
import sys

src = sys.argv[1]
dest = sys.argv[2]

raw = open(src, "rb").read()
text = raw.decode("utf-8-sig")

def write_text(path: str, value: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True) if os.path.dirname(path) else None
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(value)

def try_parse_json(value: str):
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return None

obj = try_parse_json(text)
if obj is None:
    cleaned = re.sub(r",\s*([}\]])", r"\1", text)
    obj = try_parse_json(cleaned)

if obj is not None:
    out = json.dumps(obj, ensure_ascii=False, indent=2) + "\n"
    write_text(dest, out)
    print("FIXED_TYPE:json")
    print("DROPPED_LINES:0")
    sys.exit(0)

kept = []
dropped = []
for i, line in enumerate(text.splitlines(), start=1):
    s = line.strip()
    if not s:
        continue
    candidate = s.rstrip(",")
    try:
        obj = json.loads(candidate)
        kept.append(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))
    except json.JSONDecodeError:
        dropped.append(i)

if not kept:
    print("ERROR:unable to repair file safely")
    sys.exit(4)

out = "\n".join(kept) + "\n"
write_text(dest, out)
print("FIXED_TYPE:jsonl")
print(f"DROPPED_LINES:{len(dropped)}")
if dropped:
    sample = ",".join(str(x) for x in dropped[:20])
    print(f"DROPPED_LINE_NUMBERS:{sample}")
sys.exit(0)
PY
}

echo "Scanning ${#FILES[@]} file(s)..."
echo ""

VALID_COUNT=0
INVALID_COUNT=0

for file in "${FILES[@]}"; do
  set +e
  result="$(validate_file "$file")"
  code=$?
  set -e

  status="$(printf '%s\n' "$result" | awk -F: '/^STATUS:/{print $2; exit}')"
  ftype="$(printf '%s\n' "$result" | awk -F: '/^TYPE:/{print $2; exit}')"
  detail="$(printf '%s\n' "$result" | sed -n 's/^DETAIL://p' | head -n1)"

  if [[ $code -eq 0 && "$status" == "VALID" ]]; then
    ((VALID_COUNT+=1))
    continue
  fi

  ((INVALID_COUNT+=1))
  echo "[CORRUPTED] $file"
  [[ -n "$ftype" ]] && echo "  Type: $ftype"
  [[ -n "$detail" ]] && echo "  Detail: $detail"

  while IFS= read -r line; do
    echo "  $line"
  done < <(printf '%s\n' "$result" | grep '^INVALID_LINE:' || true)
  echo ""

  printf '%s|%s\n' "$file" "${ftype:-unknown}" >> "$SCAN_TMP"
done

echo "Scan complete."
echo "Valid: $VALID_COUNT"
echo "Corrupted: $INVALID_COUNT"

if [[ "$INVALID_COUNT" -eq 0 ]]; then
  exit 0
fi

if [[ "$ASSUME_YES" != "true" ]]; then
  echo ""
  read -rp "Fix corrupted files now? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "No files changed."
    exit 0
  fi
fi

echo ""
echo "Fixing corrupted files..."

FIX_OK=0
FIX_FAIL=0

while IFS='|' read -r src _; do
  if [[ -z "$src" ]]; then
    continue
  fi

  dest="$src"
  if [[ -n "$OUTPUT_FILE" ]]; then
    dest="$OUTPUT_FILE"
  elif [[ -n "$OUTPUT_DIR" ]]; then
    rel="${src#$ROOT_BASE/}"
    dest="$OUTPUT_DIR/$rel"
  fi

  set +e
  out="$(fix_file "$src" "$dest")"
  code=$?
  set -e

  if [[ $code -eq 0 ]]; then
    ((FIX_OK+=1))
    fixed_type="$(printf '%s\n' "$out" | sed -n 's/^FIXED_TYPE://p' | head -n1)"
    dropped="$(printf '%s\n' "$out" | sed -n 's/^DROPPED_LINES://p' | head -n1)"
    dropped_lines="$(printf '%s\n' "$out" | sed -n 's/^DROPPED_LINE_NUMBERS://p' | head -n1)"
    echo "[FIXED] $src -> $dest ($fixed_type, dropped_lines=${dropped:-0})"
    [[ -n "$dropped_lines" ]] && echo "  Dropped line numbers: $dropped_lines"
  else
    ((FIX_FAIL+=1))
    echo "[FAILED] $src"
    [[ -n "$out" ]] && printf '%s\n' "$out" | sed 's/^/  /'
  fi
done < "$SCAN_TMP"

echo ""
echo "Fix complete. Success: $FIX_OK, Failed: $FIX_FAIL"
