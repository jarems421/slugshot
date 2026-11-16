"""Particle sprites for the slugs' flight trails (owner, 2026-11-14: "it's like a 3D trail of something resembling fire
... molten lava / rock for Ramstone ... something like water for Aquabeak"), drawn in the slugs' comic style: one hard-
edged shape in a few flat grey bands, so the trail's colour over time tints it (white takes the colour, grey a darker
shade of it).

- lava: a lumpy molten blob with dark crust patches.
- blaze: the same round mass in fire's bands, no crust: Inferno's trail.
- flow: the same round mass in water's bands: Aquabeek's trail.
- water: a lumpy splash blob with a white highlight and two flicked droplets: her spray.

The trails' bodies are round masses (owner, 2026-11-14: Rammstone's "is perfect ... the ideal trail"): overlapped, they
merge into one smooth body. Flame tongues read as "individual fireballs ... like PNGs", and splashes with droplets in them
as spraying.

Writes build/slugs/trails/{name}.png; with --upload, uploads them privately on the owner's account (the key comes from the
existing private client and is never printed) and writes private-assets/trails/TrailArt.luau, which stays out of Git.

`python tools/slugs/build_trail_art.py [--upload]`
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"build/slugs/trails"
SIZE = 256
EDGE = 1.5/SIZE  # anti-aliasing width, in the sprite's -1..1 units


def coords():
    y, x = np.mgrid[1.0:-1.0:SIZE*1j, -1.0:1.0:SIZE*1j]
    return x, y


def cover(inside):
    """Alpha from a signed inside distance (positive inside), anti-aliased over a pixel."""
    return np.clip(inside/EDGE*0.5 + 0.5, 0.0, 1.0)


def bands(depth, steps):
    """Flat grey from how deep inside a point is, 0 at the edge: steps are (depth, grey) from the outside in."""
    grey = np.zeros_like(depth)
    for at, value in steps:
        grey[depth >= at] = value
    return grey


def lumpy(x, y, radius, lumps, seed):
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    rng = np.random.default_rng(seed)
    edge = radius + sum(amp*np.sin(k*a + rng.random()*6.28) for k, amp in lumps)
    return edge - r, edge


def lava():
    x, y = coords()
    inside, edge = lumpy(x, y, 0.78, ((3, 0.05), (5, 0.06), (9, 0.025)), 3)
    depth = np.clip(inside/edge, 0, 1)
    grey = bands(depth, ((0.0, 0.5), (0.18, 0.78), (0.5, 1.0)))
    # Crust: dark patches cooling round the outside.
    rng = np.random.default_rng(11)
    for _ in range(5):
        a, d, s = rng.random()*6.28, 0.5 + 0.2*rng.random(), 0.06 + 0.05*rng.random()
        cx, cy = d*np.cos(a), d*np.sin(a)
        patch = np.hypot(x - cx, (y - cy)*1.3) < s
        grey = np.where(patch & (depth > 0.04), 0.32, grey)
    return grey, cover(inside)


def blaze():
    x, y = coords()
    inside, edge = lumpy(x, y, 0.78, ((4, 0.05), (6, 0.05), (11, 0.025)), 7)
    depth = np.clip(inside/edge, 0, 1)
    return bands(depth, ((0.0, 0.55), (0.2, 0.8), (0.5, 1.0))), cover(inside)


def flow():
    x, y = coords()
    inside, edge = lumpy(x, y, 0.78, ((3, 0.04), (5, 0.05), (9, 0.02)), 13)
    depth = np.clip(inside/edge, 0, 1)
    return bands(depth, ((0.0, 0.6), (0.2, 0.82), (0.55, 1.0))), cover(inside)


def water():
    x, y = coords()
    inside, edge = lumpy(x, y + 0.08, 0.66, ((4, 0.06), (7, 0.04), (11, 0.02)), 5)
    depth = np.clip(inside/edge, 0, 1)
    grey = bands(depth, ((0.0, 0.6), (0.16, 0.82)))
    shape = inside
    # Two droplets flicked off the top.
    for cx, cy, r in ((0.52, 0.66, 0.13), (0.78, 0.38, 0.08)):
        drop = r - np.hypot(x - cx, y - cy)
        grey = np.where(drop > 0, np.where(drop > r*0.35, 0.82, 0.6), grey)
        shape = np.maximum(shape, drop)
    # A white highlight crescent, upper left.
    arc = np.hypot(x + 0.05, y + 0.02)
    crescent = (arc < 0.5) & (arc > 0.41) & (x < -0.05) & (y > 0.0) & (inside > 0.04)
    grey = np.where(crescent, 1.0, grey)
    return grey, cover(shape)


SPRITES = {"lava": lava, "blaze": blaze, "flow": flow, "water": water}


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    paths = {}
    for name, draw in SPRITES.items():
        grey, alpha = draw()
        rgba = np.dstack([grey, grey, grey, alpha])
        path = OUT/f"{name}.png"
        Image.fromarray((np.clip(rgba, 0, 1)*255).round().astype(np.uint8), "RGBA").save(path)
        paths[name] = path
    print("built", ", ".join(str(p.relative_to(ROOT)) for p in paths.values()))
    return paths


def upload(paths):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import upload_rammstone as ur
    ur.PRIVATE = ROOT/"private-assets/trails"
    ur.BUILD = ROOT/"build/slugs/aquabeek/roblox"  # any built model: the private client only checks one exists
    send = ur.private_uploader("Trail ")
    # Sprites already uploaded keep their ids; only new ones are sent.
    have = {}
    old = ur.PRIVATE/"TrailArt.luau"
    if old.exists():
        for line in old.read_text(encoding="utf-8").splitlines():
            name, _, value = line.strip().rstrip(",").partition(" = ")
            if value.isdigit():
                have[name] = int(value)
    lines = ["--!strict", "-- Private image ids for the flight trail sprites (tools/slugs/build_trail_art.py); never commit.",
             "return {"]
    for name, path in paths.items():
        lines.append(f"\t{name} = {have[name] if name in have else send(name, path, 'Image', 'image/png')},")
    lines += ["}", ""]
    (ur.PRIVATE/"TrailArt.luau").write_text("\n".join(lines), encoding="utf-8")
    print("PASS: trail sprites written privately")


if __name__ == "__main__":
    built = build()
    if "--upload" in sys.argv:
        upload(built)
