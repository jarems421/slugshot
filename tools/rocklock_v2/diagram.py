"""Top-down SVG diagrams of Rocklock v2 from layout.py: routes and destructible interactions.

python tools/rocklock_v2/diagram.py -> docs/diagrams/rocklock-v2-routes.svg, rocklock-v2-interactions.svg
"""
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import layout as L  # noqa: E402

S, PAD = 6.0, 40.0
W, H = L.WIDTH * S + 2 * PAD + 260, L.DEPTH * S + 2 * PAD


def X(x): return PAD + (x - L.X0) * S
def Y(z): return PAD + (z - L.Z0) * S


def tier_colour(top):
    if top < -1:
        return "#6b4f3a"
    if top < 5:
        return "#a08a74"
    if top < 15:
        return "#c2ab8f"
    return "#e2cfb2"


def base(title):
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" viewBox="0 0 {W:.0f} {H:.0f}" '
           'font-family="Segoe UI, Arial, sans-serif">',
           f'<rect width="100%" height="100%" fill="#2b241f"/>',
           f'<text x="{PAD}" y="26" fill="#f0e6d6" font-size="18" font-weight="600">{title}</text>']
    for s in sorted(L.STATIC, key=lambda s: s["pos"][1] + s["size"][1] / 2):
        if s["kind"] in ("bedrock", "roof", "boundary"):
            continue
        if s["kind"] == "ramp":
            (ax, _, az), (bx, _, bz) = s["start"], s["end"]
            out.append(f'<line x1="{X(ax):.1f}" y1="{Y(az):.1f}" x2="{X(bx):.1f}" y2="{Y(bz):.1f}" '
                       f'stroke="#d9c7a8" stroke-width="{s["size"][0] * S:.1f}" stroke-opacity="0.75"/>')
            continue
        (cx, cy, cz), (sx, sy, sz) = s["pos"], s["size"]
        top = cy + sy / 2
        fill = "#4a403a" if s["kind"] == "cliff" else tier_colour(top)
        out.append(f'<rect x="{X(cx - sx / 2):.1f}" y="{Y(cz - sz / 2):.1f}" width="{sx * S:.1f}" height="{sz * S:.1f}" '
                   f'fill="{fill}" stroke="#2b241f" stroke-width="1"/>')
    for z in L.TERRAIN:
        (x0, _, z0), (x1, _, z1) = z["min"], z["max"]
        out.append(f'<rect x="{X(x0):.1f}" y="{Y(z0):.1f}" width="{(x1 - x0) * S:.1f}" height="{(z1 - z0) * S:.1f}" '
                   'fill="#7a6248" fill-opacity="0.55" stroke="#c9a77c" stroke-dasharray="4 3"/>')
    return out


def legend(out, items, y=60):
    lx = PAD + L.WIDTH * S + 30
    for colour, label, dash in items:
        out.append(f'<line x1="{lx}" y1="{y}" x2="{lx + 30}" y2="{y}" stroke="{colour}" stroke-width="4"'
                   + (f' stroke-dasharray="{dash}"' if dash else "") + "/>")
        out.append(f'<text x="{lx + 40}" y="{y + 5}" fill="#f0e6d6" font-size="13">{label}</text>')
        y += 24
    return y


def routes():
    out = base("Rocklock v2 - routes (lower 0 / collapse -6 / middle 10 / high 20)")
    styles = {"walk": ("#f0e6d6", None), "ramp": ("#f0e6d6", "6 4"), "drop": ("#8fa3b8", "2 4"),
              "jump": ("#ffb347", None), "jumpmantle": ("#ffd27a", "8 3"), "climb": ("#c792ea", None),
              "wallrun": ("#ff6ad5", None), "tunnel": ("#c9a77c", "3 3")}
    for e in L.EDGES:
        a, b = L.NODES[e["a"]], L.NODES[e["b"]]
        colour, dash = styles[e["kind"]]
        if e["requires"]:
            colour = "#7fd17f"
        if e["opens"]:
            colour, dash = "#ff7b7b", "5 4"
        out.append(f'<line x1="{X(a[0]):.1f}" y1="{Y(a[2]):.1f}" x2="{X(b[0]):.1f}" y2="{Y(b[2]):.1f}" stroke="{colour}" '
                   f'stroke-width="2.4"' + (f' stroke-dasharray="{dash}"' if dash else "") + ' stroke-opacity="0.9"/>')
    for name, (x, y, z) in L.NODES.items():
        out.append(f'<circle cx="{X(x):.1f}" cy="{Y(z):.1f}" r="6" fill="{tier_colour(y)}" stroke="#2b241f" stroke-width="2"/>')
        out.append(f'<text x="{X(x) + 8:.1f}" y="{Y(z) - 6:.1f}" fill="#fff6e6" font-size="11">{name} ({y:+.0f})</text>')
    legend(out, [("#f0e6d6", "walk", None), ("#f0e6d6", "ramp", "6 4"), ("#8fa3b8", "drop (one way)", "2 4"),
                 ("#ffb347", "jump", None), ("#ffd27a", "jump + mantle", "8 3"), ("#c792ea", "wall climb", None),
                 ("#ff6ad5", "wall-run", None), ("#c9a77c", "tunnel", "3 3"),
                 ("#7fd17f", "needs a destructible intact", None), ("#ff7b7b", "opened by destruction", "5 4")])
    out.append("</svg>")
    (ROOT / "docs/diagrams/rocklock-v2-routes.svg").write_text("\n".join(out), encoding="utf-8")


def interactions():
    out = base("Rocklock v2 - destructible interactions")
    colours = {"Full": "#7fd17f", "Partial": "#ffb347", "Landmark": "#c792ea"}
    for d in L.DESTRUCTIBLES:
        colour = "#ff5c5c" if d["kind"] == "Hanging" else colours[d["category"]]
        xs = [c["pos"][0] for c in d["chunks"]]
        zs = [c["pos"][2] for c in d["chunks"]]
        cx, cz = sum(xs) / len(xs), sum(zs) / len(zs)
        for c in d["chunks"]:
            (x, _, z), (sx, _, sz) = c["pos"], c["size"]
            out.append(f'<rect x="{X(x - sx / 2):.1f}" y="{Y(z - sz / 2):.1f}" width="{sx * S:.1f}" height="{sz * S:.1f}" '
                       f'fill="{colour}" fill-opacity="0.8" stroke="#2b241f"/>')
        if d["hazard"]:
            out.append(f'<circle cx="{X(cx):.1f}" cy="{Y(cz):.1f}" r="{d["hazard"]["radius"] * S:.1f}" fill="none" '
                       'stroke="#ff5c5c" stroke-width="2" stroke-dasharray="6 4"/>')
        out.append(f'<text x="{X(cx) + 6:.1f}" y="{Y(cz) + 4:.1f}" fill="#fff6e6" font-size="10">{d["id"]} {d["health"]}HP</text>')
    y = legend(out, [("#7fd17f", "fully destructible", None), ("#ffb347", "partially destructible", None),
                     ("#c792ea", "landmark outer layer", None), ("#ff5c5c", "suspended (drop zone)", "6 4"),
                     ("#c9a77c", "excavatable earth", "4 3")])
    lx = PAD + L.WIDTH * S + 30
    out.append(f'<text x="{lx}" y="{y + 10}" fill="#d9c7a8" font-size="12">Everything else: essential</text>')
    out.append(f'<text x="{lx}" y="{y + 28}" fill="#d9c7a8" font-size="12">(hit effects only)</text>')
    out.append("</svg>")
    (ROOT / "docs/diagrams/rocklock-v2-interactions.svg").write_text("\n".join(out), encoding="utf-8")


if __name__ == "__main__":
    routes()
    interactions()
    print("diagrams written")
