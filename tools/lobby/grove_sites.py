"""Place the slug grove's dressing at fixed coordinates, between `// @grove-begin` and `// @grove-end` in the page.

Plain numbers, not the shader's hash, so every shader program agrees on where things are. Owner, 2026-11-02: a green, teal,
crystal area full of life, with Floppies as the standout, so the clearing round the pond stays open. Mushrooms are the trees.
Units are the concept's: 1 unit = 5 studs. The pond is centred on the origin and the mountain stands at +z.

    python tools/lobby/grove_sites.py
"""

import json
import math
import random
import re
import struct
from pathlib import Path

import numpy as np

PAGE = Path("docs/art/asset-library.html")
SITES = Path("experiments/lobby/scale/shared/grove_slugs.json")
FEET = Path("experiments/lobby/scale/shared/grove_feet.json")
# As MTN_S and MTN_Z in the shader: the mountain is built at this share of its authored size, about this point.
MTN_S, MTN_Z = 0.85, 8.6
MOUNTAIN_Z = MTN_Z + (30.0 - MTN_Z)*MTN_S
TREES = Path("experiments/lobby/scale/shared/grove_trees.json")


def fall_z(y):
    """The same as groveFallZ in the shader."""
    return MTN_Z + (30.0 - 0.94*22.5*(1.0 - min(max((y/MTN_S + 0.8)/39.0, 0.0), 1.0)**(1.0/1.3)) - MTN_Z)*MTN_S
FRONT = 1.5*math.pi


def smoothstep(a, b, x):
    t = min(max((x - a)/(b - a), 0.0), 1.0)
    return t*t*(3 - 2*t)


def read_glb(path):
    """Every solid triangle in an exported piece, ink left out, in concept units."""
    data = path.read_bytes()
    size = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + size])
    blob = data[20 + size + 8:]

    def accessor(index):
        item = doc["accessors"][index]
        view = doc["bufferViews"][item["bufferView"]]
        kind = {5126: "f4", 5125: "u4", 5123: "u2"}[item["componentType"]]
        parts = 3 if item["type"] == "VEC3" else 1
        return np.frombuffer(blob, kind, item["count"]*parts, view.get("byteOffset", 0) + item.get("byteOffset", 0)).reshape(-1, parts)

    tris = []
    for mesh in doc["meshes"]:
        if mesh["name"].endswith("_Ink"):
            continue
        for primitive in mesh["primitives"]:
            verts = accessor(primitive["attributes"]["POSITION"])
            tris.append(verts[accessor(primitive["indices"]).reshape(-1, 3)])
    return np.concatenate(tris).astype("f8")/5.0


# The game's actual meshes differ from the ideal shapes, so what stands on them is placed on them (owner: floating). Build
# hub-grove-ground and hub-grove-mountain first, then this.
EXPORT = Path("build/lobby/export")
MOUNTAIN_TRIS = read_glb(EXPORT/"hub-grove-mountain/hub-grove-mountain.glb") if (EXPORT/"hub-grove-mountain/hub-grove-mountain.glb").exists() else None
GROUND_STEP = 0.05
GROUND_LO = (-50.0, -22.0)


def ground_grid():
    path = EXPORT/"hub-grove-ground/hub-grove-ground.glb"
    if not path.exists():
        return None
    grid = np.full((int(100/GROUND_STEP), int(56/GROUND_STEP)), np.nan)
    for tri in read_glb(path):
        ax, ay, az = tri[0]
        bx, by, bz = tri[1]
        cx, cy, cz = tri[2]
        area = (bx - ax)*(cz - az) - (cx - ax)*(bz - az)
        if abs(area) < 1e-9:
            continue
        i0 = max(int((min(ax, bx, cx) - GROUND_LO[0])/GROUND_STEP), 0)
        i1 = min(int((max(ax, bx, cx) - GROUND_LO[0])/GROUND_STEP) + 1, grid.shape[0] - 1)
        j0 = max(int((min(az, bz, cz) - GROUND_LO[1])/GROUND_STEP), 0)
        j1 = min(int((max(az, bz, cz) - GROUND_LO[1])/GROUND_STEP) + 1, grid.shape[1] - 1)
        if i1 < i0 or j1 < j0:
            continue
        xs = GROUND_LO[0] + np.arange(i0, i1 + 1)[:, None]*GROUND_STEP
        zs = GROUND_LO[1] + np.arange(j0, j1 + 1)[None, :]*GROUND_STEP
        u = ((xs - cx)*(bz - cz) - (zs - cz)*(bx - cx))/((ax - cx)*(bz - cz) - (az - cz)*(bx - cx))
        v = ((xs - ax)*(cz - az) - (zs - az)*(cx - ax))/((bx - ax)*(cz - az) - (bz - az)*(cx - ax))
        w = 1.0 - u - v
        hit = (u >= -0.001) & (v >= -0.001) & (w >= -0.001)
        y = u*ay + v*by + w*cy
        cell = grid[i0:i1 + 1, j0:j1 + 1]
        cell[hit] = np.where(np.isnan(cell[hit]), y[hit], np.maximum(cell[hit], y[hit]))
    return grid


GROUND_GRID = ground_grid()


def surface_radius(a, y):
    """Coming in from outside at this angle and height, where the rock's mass is first met."""
    assert MOUNTAIN_TRIS is not None, "build hub-grove-mountain first"
    if MOUNTAIN_TRIS is not None:
        ys = MOUNTAIN_TRIS[:, :, 1]
        near = MOUNTAIN_TRIS[(ys.min(axis=1) <= y) & (ys.max(axis=1) >= y)]
        origin = np.array((0.0, y, MOUNTAIN_Z))
        direction = np.array((math.cos(a), 0.0, math.sin(a)))
        e1, e2 = near[:, 1] - near[:, 0], near[:, 2] - near[:, 0]
        h = np.cross(direction, e2)
        det = (e1*h).sum(axis=1)
        safe = np.abs(det) > 1e-9
        e1, e2, h, det, corner = e1[safe], e2[safe], h[safe], det[safe], near[safe, 0]
        s = origin - corner
        u = (s*h).sum(axis=1)/det
        q = np.cross(s, e1)
        v = (q*direction).sum(axis=1)/det
        t = (e2*q).sum(axis=1)/det
        hits = t[(u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)]
        return float(hits.max()) if hits.size else 0.0


def on_mountain(a, y, inset=0.2):
    y *= MTN_S
    r = surface_radius(a, y) - inset
    return r*math.cos(a), y, MOUNTAIN_Z + r*math.sin(a)


def pond_radius(a):
    return 7.0*(1.0 + 0.07*math.sin(a*3.0 + 1.0) + 0.05*math.sin(a*5.0 + 2.0) + 0.035*math.sin(a*9.0 + 0.7))


def smin(a, b, k):
    h = min(max(0.5 + 0.5*(b - a)/k, 0.0), 1.0)
    return b + (a - b)*h - k*h*(1.0 - h)


def pond_edge(x, z):
    """The same as pondEdge in the shader: negative in the water."""
    base = math.hypot(x, z) - pond_radius(math.atan2(z, x))
    return smin(base, math.hypot(x - 0.4, (z - 7.6)/0.85) - 2.9, 1.2)


def ground(x, z):
    """Where the game's ground mesh actually is, or the ideal shape where it has none."""
    if GROUND_GRID is not None:
        i, j = int((x - GROUND_LO[0])/GROUND_STEP), int((z - GROUND_LO[1])/GROUND_STEP)
        if 0 <= i < GROUND_GRID.shape[0] and 0 <= j < GROUND_GRID.shape[1] and not math.isnan(GROUND_GRID[i, j]):
            return float(GROUND_GRID[i, j])
    return ground_shape(x, z)


def rest(x, z, reach):
    """The lowest ground under something this wide, so no side of its foot hangs over a dip."""
    return min([ground(x, z)] + [ground(x + reach*math.cos(k*0.785), z + reach*math.sin(k*0.785)) for k in range(8)])


def ground_shape(x, z):
    """The same shape as groveHeight in the shader."""
    edge = pond_edge(x, z)
    h = 0.25*math.sin(x*0.31 + 1.0)*math.sin(z*0.27) + 0.12*math.sin(x*0.9 + z*0.7)
    bank = smoothstep(0.0, 3.0, edge)
    return h*bank + 0.35*bank - 0.55*(1.0 - smoothstep(-1.6, 0.0, edge)) + 0.8*smoothstep(10.0, 16.0, z)


def clear_of_falls(x, y):
    return abs(x - 0.3) > 3.0 + 0.09*(14 - y)


def vec4s(name, rows):
    body = ",".join(f"vec4({a:.3f},{b:.3f},{c:.3f},{d:.3f})" for a, b, c, d in rows)
    return f"const vec4 {name}[{len(rows)}] = vec4[{len(rows)}]({body});\n"


def shrooms(rnd):
    top, more = [], []
    # Round the lake, with the side facing the hub left open so the mountain and the slugs can be seen.
    for degrees, far, height, cap, colour in ((200, 3.0, 8.0, 3.6, 0), (232, 5.0, 5.5, 2.4, 2), (312, 4.5, 6.0, 2.7, 1), (345, 3.0, 8.8, 4.0, 3),
                                              (22, 4.0, 6.6, 2.9, 2), (158, 3.6, 7.2, 3.2, 1)):
        a = math.radians(degrees)
        r = pond_radius(a) + far
        x, z = r*math.cos(a), r*math.sin(a)
        top.append((x, rest(x, z, 0.25*height) - 0.1, z, height))
        more.append((cap, -0.08*height*math.cos(a), -0.08*height*math.sin(a), colour))
    # Standing out from the mountain's ledges.
    for a, y, height, cap, colour in ((3.75, 5.0, 3.6, 1.8, 1), (4.0, 10.5, 2.8, 1.4, 2), (5.4, 6.0, 3.8, 1.9, 0), (5.75, 12.0, 2.6, 1.3, 3), (3.4, 13.5, 2.5, 1.3, 3),
                                          (5.05, 16.0, 2.3, 1.2, 1), (4.35, 20.0, 2.0, 1.0, 0), (0.1, 7.0, 3.0, 1.5, 2), (3.05, 7.0, 3.0, 1.5, 1)):
        x, y0, z = on_mountain(a, y, 0.5)
        top.append((x, y0, z, height))
        more.append((cap, 0.35*height*math.cos(a), 0.35*height*math.sin(a), colour))
    # Little ones on the banks.
    for _ in range(14):
        a = rnd.uniform(0, 2*math.pi)
        if abs(a - FRONT) < 0.5:
            continue
        r = pond_radius(a) + rnd.uniform(0.6, 6.0)
        x, z = r*math.cos(a), r*math.sin(a)
        height = rnd.uniform(0.5, 1.2)
        top.append((x, rest(x, z, 0.2*height) - 0.06, z, height))
        more.append((height*rnd.uniform(0.45, 0.65), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), rnd.choice((0, 1, 2, 3))))
    return top, more


def bushes(rnd):
    """Clumps sitting on the ledges, more of them low down, leaving plenty of the rock showing."""
    rows = []
    tries = 0
    while len(rows) < 100 and tries < 4000:
        tries += 1
        a, y = rnd.uniform(2.3, 7.1) % (2*math.pi), 26.0*rnd.random()**1.5 + 0.4
        x, y0, z = on_mountain(a, y, 0.3)
        if (not clear_of_falls(x, y) and z < MOUNTAIN_Z) or any(math.dist((x, y0, z), row[:3]) < 1.5 for row in rows):
            continue
        rows.append((x, y0, z, rnd.uniform(0.55, 1.25)*(1.15 - y/36)))
    return rows


def boulders(rnd):
    rows = []
    # Stepping out across the pond, near the falls, for the slugs to sit on.
    for x, z, size in ((-3.6, 2.2, 0.85), (-1.8, 3.9, 0.6), (2.6, 3.0, 0.95), (4.2, 0.8, 0.6), (-4.6, -0.8, 0.7), (1.0, -2.4, 0.55), (-1.6, -3.6, 0.45)):
        rows.append((x, -0.2, z, size))
    # Rough rock round the two basins the falls land in.
    for x, y, z, size in ((-1.5, 12.72, fall_z(12.75), 0.75), (2.0, 12.65, fall_z(12.75), 0.85), (-2.0, 6.33, fall_z(6.35), 1.0), (2.6, 6.26, fall_z(6.35), 0.95)):
        rows.append((x, y, z, size))
    for _ in range(9):
        a = rnd.uniform(0, 2*math.pi)
        r = pond_radius(a) + rnd.uniform(-0.1, 0.9)
        x, z = r*math.cos(a), r*math.sin(a)
        rows.append((x, ground(x, z) - 0.05, z, rnd.uniform(0.45, 1.0)))
    # Big rocks framing the falls where they land, then a rough shore in clusters of mixed sizes. Their own random stream, so nothing
    # else moves.
    shore = random.Random(77)
    rows += [(-3.6, 0.0, 8.4, 1.25), (4.2, 0.0, 8.2, 1.35), (-2.9, -0.1, 6.5, 0.7), (3.6, -0.1, 6.2, 0.65), (-4.9, 0.1, 9.6, 1.0), (5.5, 0.1, 9.4, 0.9)]
    for degrees in (12, 48, 118, 150, 186, 214, 244, 268, 296, 322, 348):
        a0 = math.radians(degrees)
        for _ in range(shore.randint(2, 4)):
            a = a0 + shore.uniform(-0.1, 0.1)
            r = pond_radius(a) + shore.uniform(-0.25, 0.5)
            x, z = r*math.cos(a), r*math.sin(a)
            size = shore.choice((0.18, 0.25, 0.32, 0.45, 0.65))
            rows.append((x, ground(x, z) - 0.03*size, z, size))
    return rows


def lily_pads():
    rnd = random.Random(53)
    rows = []
    for cx, cz, count in ((-5.2, 3.6, 5), (5.1, 3.2, 4), (-3.2, -4.9, 4), (4.3, -4.1, 3)):
        tries = 0
        placed = 0
        while placed < count and tries < 60:
            tries += 1
            x, z = cx + rnd.gauss(0, 0.8), cz + rnd.gauss(0, 0.8)
            size = rnd.uniform(0.28, 0.5)
            if pond_edge(x, z) > -0.5 or any(math.hypot(x - p[0], z - p[1]) < size + p[2] + 0.05 for p in rows):
                continue
            rows.append((x, z, size, 1.0 if rnd.random() < 0.3 else 0.0))
            placed += 1
    return rows


def flora(rnd, stones):
    flowers, ferns = [], []
    # Drifts rather than an even scatter, which leaves open ground between them.
    for degrees, far in ((175, 2.4), (215, 2.0), (250, 3.4), (292, 3.2), (328, 2.0), (5, 2.6), (140, 2.2), (42, 1.8)):
        a0 = math.radians(degrees)
        r0 = pond_radius(a0) + far
        cx, cz = r0*math.cos(a0), r0*math.sin(a0)
        for _ in range(rnd.randint(4, 6)):
            x, z = cx + rnd.gauss(0, 1.1), cz + rnd.gauss(0, 1.1)
            if pond_edge(x, z) < 0.4 or any(math.hypot(x - s[0], z - s[2]) < s[3] + 0.5 for s in stones):
                continue
            flowers.append((x, rest(x, z, 0.12) - 0.1, z, rnd.randrange(3) + rnd.uniform(0.75, 1.3)*0.1 + rnd.random()*0.0))
    for a, far in ((3.3, 6.5), (3.9, 7.5), (5.6, 6.0), (6.05, 7.0), (0.5, 5.0), (2.5, 5.5), (2.0, 3.2), (1.15, 3.0), (4.3, 9.0), (5.15, 9.5)):
        r = pond_radius(a) + far
        x, z = r*math.cos(a), r*math.sin(a)
        ferns.append((x, rest(x, z, 0.5) - 0.42, z, rnd.uniform(0.75, 1.1)))
    return flowers, ferns


def crystals():
    rows, more = [], []
    for a, y, colour, scale in ((3.55, 3.0, 0, 1.3), (4.05, 8.0, 1, 1.1), (5.45, 3.5, 1, 1.4), (5.9, 9.5, 0, 1.0), (4.45, 14.0, 2, 0.9), (5.0, 21.0, 1, 0.75), (4.3, 24.5, 2, 0.7), (3.2, 14.0, 0, 0.9)):
        x, y0, z = on_mountain(a, y, 0.35)
        rows.append((x, y0, z, colour))
        more.append((0.55*math.cos(a), 0.65, 0.55*math.sin(a), scale))
    for x, z, colour, scale in ((-9.5, -3.8, 1, 0.55), (9.6, -1.2, 0, 0.6), (8.4, 4.8, 2, 0.5), (-8.2, 5.4, 0, 0.55)):
        rows.append((x, rest(x, z, 0.4*scale) - 0.12, z, colour))
        more.append((0.0, 1.0, 0.0, scale))
    # A few growing up out of the shallows.
    for x, z, colour, scale in ((-5.6, 1.4, 1, 0.3), (5.6, 0.9, 0, 0.26), (2.3, -5.4, 2, 0.24)):
        rows.append((x, -0.35, z, colour))
        more.append((0.1, 1.0, 0.05, scale))
    return rows, more


def vines(rnd):
    rows = []
    while len(rows) < 16:
        a, y = rnd.uniform(3.3, 6.1), rnd.uniform(6.0, 25.0)
        x, y0, z = on_mountain(a, y, 0.1)
        if clear_of_falls(x, y):
            rows.append((x, y0, z, rnd.uniform(2.0, 5.5)))
    return rows


def slugs(stones):
    """On the stones and the banks, in small groups, mostly on the side players arrive from. Their own random stream, so changes
    to anything else can't move them."""
    rnd = random.Random(41)
    rows = []
    for index in (0, 1, 2, 3, 4, 5, 6, 12, 15):
        x, y, z, size = stones[index]
        rows.append((x + rnd.uniform(-0.2, 0.2)*size, y + 0.72*size, z + rnd.uniform(-0.2, 0.2)*size, rnd.uniform(0, 6.28)))
    # The group the close-up looks at.
    for x, z, heading in ((-1.62, -8.37, 0.4), (-1.78, -7.44, -0.5), (-0.67, -8.21, 2.6)):
        rows.append((x, ground(x, z), z, heading))
    tries = 0
    while len(rows) < 30 and tries < 800:
        tries += 1
        a = rnd.uniform(math.pi, 2*math.pi) if rnd.random() < 0.72 else rnd.uniform(0, math.pi)
        r = pond_radius(a) + rnd.uniform(0.15, 4.5)
        x, z = r*math.cos(a), r*math.sin(a)
        for step in range(rnd.choice((1, 2, 2, 3))):
            sx, sz = x + rnd.uniform(-1.1, 1.1)*min(step, 1), z + rnd.uniform(-1.1, 1.1)*min(step, 1)
            if len(rows) >= 30 or any(math.hypot(sx - row[0], sz - row[2]) < 0.8 for row in rows):
                continue
            if pond_edge(sx, sz) < 0.15:
                continue
            # A few in mid hop.
            hop = rnd.uniform(0.18, 0.4) if len(rows) % 6 == 0 else 0.0
            rows.append((sx, ground(sx, sz) + hop, sz, rnd.uniform(0, 6.28)))
    # Those on the ground step clear of any rock that landed on them; the first nine sit on stones on purpose.
    moved = 0
    for index in range(9, len(rows)):
        x, y, z, heading = rows[index]
        for stone in stones:
            gap = math.hypot(x - stone[0], z - stone[2])
            clear = stone[3] + 0.4
            if gap < clear and abs(y - stone[1]) < 2.0:
                push = clear/max(gap, 0.01)
                x, z = stone[0] + (x - stone[0])*push, stone[2] + (z - stone[2])*push
                moved += 1
        if pond_edge(x, z) < 0.15:
            continue
        rows[index] = (x, ground(x, z) + max(y - ground(rows[index][0], rows[index][2]), 0.0), z, heading)
    print(f"moved {moved} Floppies clear of rocks")
    return rows


def main():
    rnd = random.Random(29)
    top, more = shrooms(rnd)
    bush_rows = bushes(rnd)
    stones = boulders(rnd)
    flowers, ferns = flora(rnd, stones)
    gems, gem_more = crystals()
    slug_rows = slugs(stones)
    block = "// @grove-begin\n// Generated by tools/lobby/grove_sites.py. See there before editing.\n"
    block += vec4s("GROVE_SHROOM", top) + vec4s("GROVE_CAP", more) + vec4s("GROVE_BUSH", bush_rows) + vec4s("GROVE_STONE", stones)
    block += vec4s("GROVE_FLOWER", flowers) + vec4s("GROVE_FERN", ferns) + vec4s("GROVE_GEM", gems) + vec4s("GROVE_GEM_DIR", gem_more)
    block += vec4s("GROVE_VINE", vines(rnd)) + vec4s("GROVE_PAD", lily_pads()) + vec4s("GROVE_SLUG", slug_rows) + "// @grove-end\n"
    text = PAGE.read_text(encoding="utf-8")
    text, count = re.subn(r"// @grove-begin\n.*?// @grove-end\n", lambda _: block, text, flags=re.S)
    assert count == 1, "the page needs its generated block"
    PAGE.write_text(text, encoding="utf-8")
    # The game's slugs stand where the concept's do, in studs, resting on the ground rather than in mid hop.
    sites = [{"x": round(x*5, 2), "y": round(y*5, 2) if index < 9 else round(ground(x, z)*5, 2), "z": round(z*5, 2), "heading": round(h, 3)}
             for index, (x, y, z, h) in enumerate(slug_rows)]
    SITES.write_text(json.dumps(sites, indent=1) + "\n", encoding="utf-8")
    # The big mushrooms round the lake are the approved giant mushroom asset, placed by the game.
    TREES.write_text(json.dumps([{"x": round(t[0]*5, 2), "y": round(t[1]*5, 2), "z": round(t[2]*5, 2), "height": round(t[3]*5, 1), "colour": int(c[3])}
                                 for t, c in zip(top[:6], more[:6])], indent=1) + "\n", encoding="utf-8")
    # For the check build: where everything baked into a piece should touch its surface.
    studs = lambda rows: [[round(r[0]*5, 2), round(r[1]*5, 2), round(r[2]*5, 2)] for r in rows]
    FEET.write_text(json.dumps({"ground": studs(flowers + ferns + [t for t in top if t[1] < 1.6]), "mountain": studs([t for t in top if t[1] >= 1.6] + bush_rows + [g for g in gems if g[1] > 1.6]),
                                "axisZ": MOUNTAIN_Z*5}) + "\n", encoding="utf-8")
    if GROUND_GRID is not None:
        off = [abs(ground(f[0], f[2]) - ground_shape(f[0], f[2]))*5 for f in flowers]
        print(f"flowers: game ground differs from the ideal shape by {sum(off)/len(off):.2f} studs on average, {max(off):.2f} at most")
    print(f"grove: {len(top)} mushrooms, {len(flowers)} flowers, {len(ferns)} ferns, {len(stones)} stones, 30 slugs")


if __name__ == "__main__":
    main()
