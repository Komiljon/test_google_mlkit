import re

path = r"C:\Users\komil\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_3d_controller-2.3.0\assets\model_viewer.min.js"
data = open(path, encoding="utf-8", errors="ignore").read()
cjk = re.findall(r"[\u4e00-\u9fff]+", data)
print("cjk chunks:", cjk[:30] or "none")
for pat in ["Loading", "Failed", "Error", "status", "poster", "progress"]:
    idx = 0
    hits = []
    while True:
        i = data.find(pat, idx)
        if i == -1:
            break
        hits.append(data[max(0, i - 40) : i + 80].replace("\n", " "))
        idx = i + len(pat)
        if len(hits) >= 5:
            break
    if hits:
        print(f"\n--- {pat} ---")
        for h in hits:
            print(h)
