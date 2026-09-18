# 통짜 모델을 부위별로 자른다 — 삼각형 무게중심이 어느 구역에 있는지로.
# 출력: ../Resources/<이름>.json (부위마다 관절 위치와 그 관절 기준 꼭짓점) + 텍스처
import json, sys, shutil
from glb import load

CFG = {
  "corgi": dict(src="corgi.glb", scale=100,
    head=dict(z=0.40, y=0.46, pivot=[0, 0.5, 0.42]),
    tail=dict(z=-0.36, y=0.2, pivot=[0, 0.36, -0.36]),
    legs=dict(y=0.13, front=(0.30, 0.62), hind=(-0.52, -0.12), top=0.2),
    hip=[0, 0.3, -0.32]),
}

def part_of(c, k):
    x, y, z = c
    L = k["legs"]
    if y < L["y"]:
        if L["front"][0] < z < L["front"][1]: return "legF" + ("L" if x < 0 else "R")
        if L["hind"][0] < z < L["hind"][1]: return "legH" + ("L" if x < 0 else "R")
    if z > k["head"]["z"] and y > k["head"]["y"]: return "head"
    if z < k["tail"]["z"] and y > k["tail"]["y"]: return "tail"
    return "body"

def run(name):
    k = CFG[name]
    pos, nor, uv, idx, png, mt = load(k["src"])
    s = k["scale"]
    P = [(a * s, b * s, c * s) for a, b, c in pos]
    parts = {}
    for i in range(0, len(idx), 3):
        t = idx[i:i + 3]
        c = [sum(P[v][d] for v in t) / 3 for d in range(3)]
        parts.setdefault(part_of(c, k), []).append(t)
    L = k["legs"]
    def pivot(pn, tris):
        if pn.startswith("leg"):
            xs = [P[v][0] for t in tris for v in t]; zs = [P[v][2] for t in tris for v in t]
            return [sum(xs) / len(xs), L["top"], sum(zs) / len(zs)]
        if pn == "head": return k["head"]["pivot"]
        if pn == "tail": return k["tail"]["pivot"]
        return k["hip"]
    out = {"parts": {}, "texture": name + "_tex.jpg"}
    allp = [P[v] for t in parts["head"] for v in t]
    nose = max(allp, key=lambda p: p[2])
    out["nose"] = list(nose)
    out["size"] = [max(p[d] for p in P) - min(p[d] for p in P) for d in range(3)]
    for pn, tris in parts.items():
        pv = pivot(pn, tris)
        vs, ns, us = [], [], []
        for t in tris:
            for v in t:
                vs += [round(P[v][d] - pv[d], 5) for d in range(3)]
                ns += [round(x, 4) for x in nor[v]]
                us += [round(x, 5) for x in uv[v]]
        out["parts"][pn] = dict(pivot=pv, v=vs, n=ns, uv=us, tris=len(tris))
        print(pn, len(tris), [round(x, 2) for x in pv])
    json.dump(out, open(f"../Resources/{name}.json", "w"), separators=(",", ":"))
    open(f"../Resources/{name}_tex.jpg", "wb").write(png)
    return P, idx, parts, uv, png

if __name__ == "__main__":
    import os; os.makedirs("../Resources", exist_ok=True)
    name = sys.argv[1] if len(sys.argv) > 1 else "corgi"
    P, idx, parts, uv, png = run(name)
    # 확인용 그림 — 부위마다 다른 색
    from PIL import Image, ImageDraw
    col = {"body": (200, 170, 120), "head": (230, 90, 90), "tail": (90, 90, 230), "legFL": (60, 180, 60),
           "legFR": (20, 120, 20), "legHL": (200, 120, 220), "legHR": (140, 60, 160)}
    S = 500
    im = Image.new("RGB", (S * 2, S), (235, 235, 242)); d = ImageDraw.Draw(im)
    for ox, a1, flip in ((0, 2, 1), (S, 0, 1)):
        items = [(pn, t) for pn, ts in parts.items() for t in ts]
        other = 0 if a1 == 2 else 2
        items.sort(key=lambda it: sum(P[v][other] for v in it[1]) * (1 if a1 == 2 else -1))
        for pn, t in items:
            pts = [(ox + P[v][a1] * 300 * flip + S / 2, S - 60 - P[v][1] * 300) for v in t]
            d.polygon(pts, fill=col[pn], outline=(50, 50, 50))
    im.save(f"{name}_parts.png")
