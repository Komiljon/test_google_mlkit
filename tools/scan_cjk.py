import base64
import os
import re

pat = re.compile(r"[\u4e00-\u9fff]")
b64_pat = re.compile(r"['\"]([A-Za-z0-9+/=]{12,})['\"]")

roots = [
    r"g:\AKA\Flutter_VS_Projects\test_google_mlkit",
    r"C:\Users\komil\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_3d_controller-2.3.0",
]

for root in roots:
    for dirpath, _, files in os.walk(root):
        if any(x in dirpath for x in [".git", "build", ".dart_tool"]):
            continue
        for name in files:
            if not name.endswith((".dart", ".html", ".js")):
                continue
            path = os.path.join(dirpath, name)
            try:
                text = open(path, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            for match in b64_pat.findall(text):
                pad = "=" * ((4 - len(match) % 4) % 4)
                try:
                    decoded = base64.b64decode(match + pad).decode("utf-8")
                except Exception:
                    continue
                if pat.search(decoded):
                    print(f"B64 {path}: {decoded}")
            for i, line in enumerate(text.splitlines(), 1):
                if pat.search(line):
                    print(f"{path}:{i}: {line[:120]}")
