import json
from pathlib import Path

base = Path("backups/nanobot-backup/workspace/sessions")
issues = []

for p in sorted(base.glob("*.jsonl")):
    with p.open("r", encoding="utf-8") as f:
        for i, line in enumerate(f, start=1):
            line = line.rstrip("\n")
            if not line.strip():
                continue
            try:
                obj = json.loads(line)
            except Exception as e:
                issues.append((str(p), i, "line_json_invalid", str(e)))
                continue

            tcs = obj.get("tool_calls")
            if not isinstance(tcs, list):
                continue

            for idx, tc in enumerate(tcs, start=1):
                if not isinstance(tc, dict):
                    issues.append((str(p), i, f"tool_call[{idx}]_not_object", type(tc).__name__))
                    continue

                fn = tc.get("function")
                if not isinstance(fn, dict):
                    issues.append((str(p), i, f"tool_call[{idx}]_function_not_object", type(fn).__name__))
                    continue

                args = fn.get("arguments")
                if args is None:
                    issues.append((str(p), i, f"tool_call[{idx}]_arguments_missing", "missing"))
                    continue

                if isinstance(args, dict):
                    continue

                if not isinstance(args, str):
                    issues.append((str(p), i, f"tool_call[{idx}]_arguments_bad_type", type(args).__name__))
                    continue

                try:
                    json.loads(args)
                except Exception as e:
                    issues.append((str(p), i, f"tool_call[{idx}]_arguments_invalid_json", str(e)))

print(f"issues={len(issues)}")
for path, line, kind, detail in issues:
    print(f"{path}:{line}|{kind}|{detail}")
