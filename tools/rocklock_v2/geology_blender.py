"""Headless Blender: seeded, original rock skins for Rocklock v2 (layout.py).

blender -b --factory-startup -P geology_blender.py -- <layout_dir> <out_json>
Each skinned collision box becomes layered convex rock hulls (split into overlapping
segments and bands so big faces read as strata). Walkable tops stay exactly flat and
wall-run faces never protrude past their collision plane. Columns, stalactites and a
ceiling with daylight holes are added. Output triangles are in Roblox coordinates.
"""
import hashlib
import json
import math
import os
import random
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
sys.path.insert(0, argv[0])
import layout as L  # noqa: E402

OUT = argv[1]
SEGMENT, BAND = 30.0, 24.0


def hull(points):
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    result = bmesh.ops.convex_hull(bm, input=verts)
    loose = {g for g in result["geom_interior"] + result["geom_unused"] if isinstance(g, bmesh.types.BMVert)}
    if loose:
        bmesh.ops.delete(bm, geom=list(loose), context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    tris = [[tuple(round(c, 3) for c in v.co) for v in f.verts] for f in bm.faces]
    bm.free()
    return tris


def rotate(local, yaw):
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    x, y, z = local
    return (x * c + z * s, y, -x * s + z * c)


def rock_box(rng, center, size, yaw=0.0, run_faces=(), flat_top=True, jitter=0.8):
    """Jittered points on a box; outward bulges on the sides, flat exact top."""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = []
    out = {"east": (1, 0), "west": (-1, 0), "south": (0, 1), "north": (0, -1)}

    def push(x, y, z, side_x, side_z, top):
        face = None
        if side_x > 0:
            face = "east"
        elif side_x < 0:
            face = "west"
        elif side_z > 0:
            face = "south"
        elif side_z < 0:
            face = "north"
        lo, hi = (-0.55, 0.05) if face in run_faces else (0.05, jitter)
        d = rng.uniform(lo, hi)
        x2 = x + side_x * d + rng.uniform(-0.3, 0.3) * (side_x == 0)
        z2 = z + side_z * d + rng.uniform(-0.3, 0.3) * (side_z == 0)
        y2 = y if top and flat_top else y + rng.uniform(-0.5, 0.5)
        pts.append(rotate((x2, y2, z2), yaw))

    for sx in (-1, 1):
        for sz in (-1, 1):
            push(sx * hx, hy, sz * hz, sx, sz, True)
            push(sx * hx, -hy, sz * hz, sx, sz, False)
            # A mid-height bulge on each vertical edge breaks the box outline.
            push(sx * hx * rng.uniform(0.8, 1.0), rng.uniform(-0.6, 0.4) * hy, sz * hz * rng.uniform(0.8, 1.0),
                 sx, sz, False)
    for (sx, sz) in out.values():
        for _ in range(2):
            x = sx * hx if sx else rng.uniform(-0.7, 0.7) * hx
            z = sz * hz if sz else rng.uniform(-0.7, 0.7) * hz
            push(x, rng.uniform(-0.7, 0.6) * hy, z, sx, sz, False)
    return [(center[0] + p[0], center[1] + p[1], center[2] + p[2]) for p in pts]


def split(lo, hi, step):
    n = max(1, round((hi - lo) / step))
    edges = [lo + (hi - lo) * i / n for i in range(n + 1)]
    return [(edges[i] - (0.6 if i else 0), edges[i + 1] + (0.6 if i + 1 < n else 0)) for i in range(n)]


meshes = []


def emit(name, color, tris):
    meshes.append({"name": name, "color": color, "triangles": tris})


for item in L.STATIC:
    if not item["skin"]:
        continue
    rng = random.Random(f"{L.SEED}:{item['name']}")
    cx, cy, cz = item["pos"]
    sx, sy, sz = item["size"]
    color = L.PALETTE[item["color"]]
    # Boundary and cliff masses are deep; only their faces toward the arena are seen.
    x0, x1, z0, z1 = cx - sx / 2, cx + sx / 2, cz - sz / 2, cz + sz / 2
    y0, y1 = cy - sy / 2, cy + sy / 2
    if item["kind"] == "boundary":
        if item["name"] == "BoundaryEast":
            x0, x1, z0, z1 = L.X1, L.X1 + 7, L.Z0, L.Z1
        elif item["name"] == "BoundaryNorth":
            x0, x1, z0, z1 = L.X0 - 16, L.X1 + 2, L.Z0 - 7, L.Z0
        else:
            x0, x1, z0, z1 = L.X0 - 16, L.X1 + 2, L.Z1, L.Z1 + 7
        y0 = -2
    elif item["kind"] == "cliff" and x1 - x0 > 10:
        x0 = x1 - 8
    xs = split(x0, x1, SEGMENT) if x1 - x0 > SEGMENT * 1.3 else [(x0, x1)]
    zs = split(z0, z1, SEGMENT) if z1 - z0 > SEGMENT * 1.3 else [(z0, z1)]
    ys = split(y0, y1, BAND) if y1 - y0 > BAND * 1.3 else [(y0, y1)]
    for i, (ax, bx) in enumerate(xs):
        for j, (az, bz) in enumerate(zs):
            for k, (ay, by) in enumerate(ys):
                top_band = k == len(ys) - 1
                pts = rock_box(rng, ((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2),
                               (bx - ax, by - ay, bz - az), item.get("yaw", 0.0), item["run_faces"],
                               flat_top=top_band, jitter=0.9 if item["kind"] != "column" else 1.2)
                emit(f"{item['name']}_{i}{j}{k}", color, hull(pts))

# Columns: tapered, fluted drums so the two monuments read as natural pillars, not boxes.
for column in [c for c in L.STATIC if c["kind"] == "column"]:
    rng = random.Random(f"{L.SEED}:Drums{column['name']}")
    cx, _, cz = column["pos"]
    radius = column["size"][0] / 2 * 1.22
    levels = [-2 + i * 12 for i in range(int((L.CEILING + 8) // 12) + 1)]
    for k in range(len(levels) - 1):
        pts = []
        for y, r in ((levels[k], radius - k * 0.15), (levels[k + 1], radius * 0.96 - k * 0.15)):
            for n in range(10):
                a = 2 * math.pi * n / 10 + rng.uniform(-0.15, 0.15)
                rr = r * rng.uniform(0.92, 1.12)
                pts.append((cx + math.cos(a) * rr, y + rng.uniform(-0.8, 0.8), cz + math.sin(a) * rr))
        emit(f"Drum{column['name']}{k}", L.PALETTE["column"], hull(pts))

for d in L.DECOR:
    rng = random.Random(f"{L.SEED}:{d['name']}")
    if d["type"] == "stalactite":
        x, y, z = d["pos"]
        r = d["radius"]
        pts = [(x + math.cos(a) * r * rng.uniform(0.8, 1.2), y, z + math.sin(a) * r * rng.uniform(0.8, 1.2))
               for a in [2 * math.pi * n / 6 for n in range(6)]]
        mid = y - d["length"] * 0.45
        pts += [(x + math.cos(a) * r * 0.6, mid, z + math.sin(a) * r * 0.6) for a in [1, 3, 5]]
        pts.append((x + rng.uniform(-0.4, 0.4), y - d["length"], z + rng.uniform(-0.4, 0.4)))
        emit(d["name"], L.PALETTE["ceiling"], hull(pts))
    elif d["type"] == "ceiling":
        cell = L.CEILING_CELL
        for i, x in enumerate(range(int(L.X0), int(L.X1), int(cell))):
            for j, z in enumerate(range(int(L.Z0), int(L.Z1), int(cell))):
                cx, cz = x + cell / 2, z + cell / 2
                if any(math.hypot(cx - hx, cz - hz) < cell * 0.55 for hx, hz, _ in d["holes"]):
                    continue
                depth = rng.uniform(3, 9)
                pts = rock_box(rng, (cx, d["y"] + 4 - depth / 2 + 2, cz), (cell + 2, depth + 4, cell + 2),
                               rng.uniform(-8, 8), flat_top=False, jitter=1.6)
                emit(f"Ceiling{i}{j}", L.PALETTE["ceiling"], hull(pts))

here = os.path.dirname(os.path.abspath(__file__))
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
data = {"layout_sha256": sha(os.path.join(here, "layout.py")),
        "generator_sha256": sha(os.path.abspath(__file__)),
        "blender": bpy.app.version_string, "meshes": meshes}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    json.dump(data, f, separators=(",", ":"))
print("GEOLOGY_DONE", len(meshes), "meshes", sum(len(m["triangles"]) for m in meshes), "triangles")
