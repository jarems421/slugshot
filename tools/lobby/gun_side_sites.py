"""Lay out the gun side: the mushroom knoll, the canopy hole in it, the big bridge and the shop's platform.

Owner, 2026-11-03 (docs/art/general-shop.md, docs/art/gun-side-plan.html): the knoll fills the whole gun side and wraps
round an uneven hole full of mushroom canopy. A big bridge crosses it to the shop in the middle. The hole can't be
entered. Everything is placed from approved assets: giant mushroom v2 in the grove's four colours, the grove's
plants and crystals, and Floppies.

    python tools/lobby/gun_side_sites.py

Writes experiments/lobby/scale/shared/gun_side.json in world studs (the hub's centre at the origin, gun side at -x).
The block-out (Arena.luau) builds its floor, walls and barriers from the same hole, and HubArt places the props.
The hole's crystals are set onto the exported rock (build/lobby/meshes/hub-gun-ground), so mesh that first.
"""

import json
import math
import random
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

OUT = Path("experiments/lobby/scale/shared/gun_side.json")
LAYOUT = json.loads(Path("experiments/lobby/scale/shared/layout.json").read_text(encoding="utf-8"))

# The gun side, in the layout's angles (clockwise from above, 0 toward PvP). The ravine is gone, so it reaches the portals.
FROM, TO = -135.0, -40.0
INNER, WALL = LAYOUT["shore"]["innerRadius"], LAYOUT["shore"]["wallRadius"]
ANGLE = -90.0
HOLE_AT = 200.0
HOLE_MEAN = 78.0
HOLE_POINTS = 96
HOLE_FLOOR = -120.0
MARGIN_WALL, MARGIN_SIDE, KNOLL_FRONT = 16.0, 18.0, 40.0
PLATFORM = 26.0
BRIDGE_WIDTH = 16.0
SPAWN_BRIDGE = LAYOUT["bridges"]["width"]

rng = random.Random(20261103)


def polar(angle, radius):
    a = math.radians(angle)
    return (radius*math.sin(a), -radius*math.cos(a))


def to_polar(x, z):
    return math.degrees(math.atan2(x, -z)), math.hypot(x, z)


CX, CZ = polar(ANGLE, HOLE_AT)
OUT_DIR = (CX/HOLE_AT, CZ/HOLE_AT)  # away from the hub


def allowed(x, z):
    """Ground must surround the hole: a margin to the wall, the zone's sides and the knoll's front."""
    a, r = to_polar(x, z)
    if r > WALL - MARGIN_WALL or r < INNER + KNOLL_FRONT:
        return False
    side = min(math.radians(a - FROM), math.radians(TO - a))
    return side > 0 and r*math.sin(min(side, math.pi/2)) > MARGIN_SIDE


def hole_shape():
    """Radii round the hole's centre, by angle t from the hub-ward direction. Wider across than deep, never round."""
    radii = []
    for i in range(HOLE_POINTS):
        t = i/HOLE_POINTS*2*math.pi
        r = HOLE_MEAN*(1.0 - 0.14*math.cos(2*t) + 0.11*math.sin(3*t + 0.7) + 0.07*math.sin(5*t + 2.1)
                       + 0.045*math.sin(8*t + 0.3) + 0.03*math.sin(13*t + 1.9))
        dx, dz = hole_dir(t)
        while r > 20 and not allowed(CX + dx*r, CZ + dz*r):
            r -= 0.5
        radii.append(round(r, 2))
    # Clamping leaves straight runs; ease them so the edge stays organic.
    for _ in range(2):
        radii = [round((radii[i - 1] + 2*radii[i] + radii[(i + 1) % HOLE_POINTS])/4, 2) for i in range(HOLE_POINTS)]
    return radii


def hole_dir(t):
    # t = 0 points at the hub, so the bridge leaves the near edge at t = 0.
    ux, uz = -OUT_DIR[0], -OUT_DIR[1]
    vx, vz = -uz, ux
    return ux*math.cos(t) + vx*math.sin(t), uz*math.cos(t) + vz*math.sin(t)


RADII = hole_shape()


def hole_rock():
    """The hole's walls, spire and floor as exported (concept units round the hole's centre, the hub toward -z), as face
    centres in world studs with their normals out of the rock, and a tree to find the nearest."""
    centres, normals = [], []
    for name in ("WallsA", "WallsB", "WallsC", "Spire", "HoleFloor"):
        data = np.load(Path("build/lobby/meshes/hub-gun-ground")/f"{name}.npz")
        v, f = data["verts"], data["faces"]
        a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
        n = np.cross(b - a, c - a)
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
        m = (a + b + c)/3.0
        # HubArt's frame: the hole's centre, turned a quarter so the concept's -z faces the hub (+x here).
        centres.append(np.stack([CX - m[:, 2]*5.0, m[:, 1]*5.0, CZ + m[:, 0]*5.0], axis=1))
        normals.append(np.stack([-n[:, 2], n[:, 1], n[:, 0]], axis=1))
    centres, normals = np.concatenate(centres), np.concatenate(normals)
    return centres, normals, cKDTree(centres)


def hole_radius(t):
    f = (t % (2*math.pi))/(2*math.pi)*HOLE_POINTS
    i = int(f)
    return RADII[i] + (RADII[(i + 1) % HOLE_POINTS] - RADII[i])*(f - i)


def hole_local(x, z):
    """Angle t and distance from the hole's centre."""
    dx, dz = x - CX, z - CZ
    ux, uz = -OUT_DIR[0], -OUT_DIR[1]
    vx, vz = -uz, ux
    return math.atan2(dx*vx + dz*vz, dx*ux + dz*uz) % (2*math.pi), math.hypot(dx, dz)


def in_hole(x, z, pad=0.0):
    t, d = hole_local(x, z)
    return d < hole_radius(t) + pad


def on_knoll(x, z):
    a, r = to_polar(x, z)
    if r < INNER + 4 or r > WALL - 4:
        return False
    return FROM + 1.5 < a < TO - 1.5


# The walk: spawn bridge landing to the hole's near edge, then the big bridge to the platform.
NEAR_EDGE = HOLE_AT - hole_radius(0.0)
BRIDGE = {"angle": ANGLE, "from": round(NEAR_EDGE - 3.0, 2), "to": round(HOLE_AT - PLATFORM + 2.0, 2), "width": BRIDGE_WIDTH}


def on_path(x, z, pad):
    a, r = to_polar(x, z)
    half = math.degrees(math.atan2(BRIDGE_WIDTH/2 + pad, max(r, 1.0)))
    return abs(a - ANGLE) < half and r < NEAR_EDGE + 6


def scatter(count, spacing, test, tries=6000):
    taken = []
    for _ in range(tries):
        if len(taken) >= count:
            break
        a, r = rng.uniform(FROM, TO), math.sqrt(rng.uniform(INNER**2, WALL**2))
        x, z = polar(a, r)
        if not test(x, z) or any(math.hypot(x - p[0], z - p[1]) < spacing for p in taken):
            continue
        taken.append((x, z))
    return taken


# The lines between lobby zones, where the stone slabs stand (owner, 2026-11-04): kept clear of props.
BORDERS = (-41.0, -135.0)


def near_border(x, z, pad):
    a, r = to_polar(x, z)
    return any(abs(math.radians(a - b))*r < pad for b in BORDERS)


def knoll_ok(pad):
    return lambda x, z: on_knoll(x, z) and not in_hole(x, z, pad) and not on_path(x, z, pad)


CH_FLOOR, CH_PLAT = -24.0, 5.2  # the composite's hole floor and platform, in its units of 5 studs


def spire_radius(y):
    """chSpireR, in studs, at a height in studs."""
    yu = y/5.0
    def ease(a, b, v):
        t = min(max((v - a)/(b - a), 0.0), 1.0)
        return t*t*(3 - 2*t)
    r = CH_PLAT + (3.4 - CH_PLAT)*ease(0.0, -10.0, yu) + 0.25*math.sin(yu*0.7)
    return 5.0*(r + 2.4*ease(CH_FLOOR + 3.0, CH_FLOOR, yu))


def hole_lip():
    """Where the drawn ground actually ends round the hole, at each of its radii, from the exported velvet (owner,
    2026-11-05: you could fall through the barrier; it stood a little past the recorded edge, which the drawn lip doesn't
    follow exactly)."""
    tops = []
    for name in ("VelvetA", "VelvetB", "VelvetC"):
        v = np.load(Path("build/lobby/meshes/hub-gun-ground")/f"{name}.npz")["verts"]
        tops.append(v[v[:, 1] > -0.15])
    v = np.concatenate(tops)
    d = np.stack([-v[:, 2]*5.0, v[:, 0]*5.0], axis=1)
    ux, uz = -OUT_DIR[0], -OUT_DIR[1]
    t = np.arctan2(d[:, 0]*-uz + d[:, 1]*ux, d[:, 0]*ux + d[:, 1]*uz) % (2*math.pi)
    r = np.hypot(d[:, 0], d[:, 1])
    lip = []
    for i, radius in enumerate(RADII):
        ti = i/len(RADII)*2*math.pi
        near = (np.abs((t - ti + math.pi) % (2*math.pi) - math.pi) < math.pi/len(RADII)) & (r > radius - 25.0)
        lip.append(round(float(r[near].min()), 2) if near.any() else radius)
    return lip


def crystal_share(key):
    """How tall a design is shown for the size it's given: HubArt makes a wide one smaller, so no side runs past the size by
    more than a tenth (owner, 2026-11-05: the Amber fan came out huge)."""
    folder = Path("build/lobby/meshes")/key
    meta = json.loads((folder/"meta.json").read_text())
    v = np.concatenate([np.load(folder/f"{g['name']}.npz")["verts"] for g in meta["groups"]])
    size = v.max(axis=0) - v.min(axis=0)
    return min(1.0, size[1]*1.1/max(size[0], size[2]))


def cavern(hash1, crystals, trees, canopy=()):
    """The cavern's pieces round the hole (owner, 2026-11-04): roots, shelves, side mushrooms and hanging vines on the
    wall, each with the direction into the rock; and the approved cyan and violet crystals on the wall, the spire and the
    floor, leaning out from what they grow on. The wall's face is taken a stud or so inside the hole's edge."""
    wall = []
    cells = 56

    def on_wall(t, y, key, s, inset=1.25):
        dx, dz = hole_dir(t)
        r = hole_radius(t) - inset
        wall.append({"key": key, "x": round(CX + dx*r, 2), "y": round(y, 2), "z": round(CZ + dz*r, 2),
                     "ox": round(dx, 4), "oz": round(dz, 4), "s": round(s, 3)})

    for c in range(cells):
        if hash1(c*8.8) < 0.3:
            continue
        t = (c + 0.5)/cells*2*math.pi + (hash1(c*1.31) - 0.5)*0.05
        kind = "b" if c % 2 else ("c" if hash1(c*3.9) < 0.3 else "a")
        y = -2.0 if kind != "c" else -(15.0 + 40.0*hash1(c*4.1))
        on_wall(t, y, f"hub-gun-root-{kind}", 0.9 + 0.25*hash1(c*6.1))
    for c in range(cells):
        if hash1(c*5.1 + 1.0) > 0.72:
            continue
        t = (c + 1.0)/cells*2*math.pi
        on_wall(t, -(12.0 + 72.0*hash1(c*2.2)), "hub-gun-shelves-" + ("b" if hash1(c*2.7) < 0.45 else "a"), 0.9 + 0.4*hash1(c*3.3))
    for k, c in enumerate(range(3, cells, 7)):
        on_wall((c + 0.25)/cells*2*math.pi, -(20.0 + 55.0*hash1(c*4.4)), "hub-gun-sideshroom-" + "ab"[k % 2], 1.0)
    # A few on the spire too, smaller, filling its bare stretches (owner, 2026-11-04). Their back runs into the spire.
    for k in range(5):
        t = (k + 0.3)/5*2*math.pi + 0.4*hash1(k*4.9)
        y = -(18.0 + 62.0*hash1(k*7.3 + 2.0))
        dx, dz = hole_dir(t)
        r = spire_radius(y) - 0.4
        wall.append({"key": "hub-gun-sideshroom-" + "ba"[k % 2], "x": round(CX + dx*r, 2), "y": round(y, 2), "z": round(CZ + dz*r, 2),
                     "ox": round(-dx, 4), "oz": round(-dz, 4), "s": 0.72})
    # More high up, under the platform, where the spire was bare (owner, 2026-11-04); low enough that no cap reaches the
    # platform's edge.
    for k in range(6):
        t = (k + 0.8)/6*2*math.pi + 0.3*hash1(k*3.1 + 7.0)
        y = -(14.0 + 18.0*hash1(k*5.9 + 3.0))
        dx, dz = hole_dir(t)
        r = spire_radius(y) - 0.4
        wall.append({"key": "hub-gun-sideshroom-" + "ab"[k % 2], "x": round(CX + dx*r, 2), "y": round(y, 2), "z": round(CZ + dz*r, 2),
                     "ox": round(-dx, 4), "oz": round(-dz, 4), "s": round(0.6 + 0.12*hash1(k*2.3), 3)})
    for k in range(44):
        t = hash1(k*17.3 + 3.0)*2*math.pi
        on_wall(t, -(4.0 + 76.0*hash1(k*5.9 + 1.0)), "hub-gun-vine-" + ("a" if k % 3 == 0 else "b"), 0.9 + 0.4*hash1(k*7.7))

    # The library's designs in turn (owner, 2026-11-05: a wider variety, not the same two): Cyan cluster, Amber fan, Violet
    # spire, Rose crown, Frost spires, Aurora urchin, Emerald spray.
    keys = ("crystals-1-s", "crystals-3-s", "crystals-2-s", "crystals-4-s", "crystals-6-s", "crystals-14-s", "crystals-5-s")
    share = {key: crystal_share(key) for key in keys}
    rock, normals, tree = hole_rock()
    pieces = []

    def occupied():
        """What's already in the hole, as spheres in studs: the wall's pieces, and the mushrooms' caps and stems."""
        if pieces:
            return pieces
        for w in wall:
            s, key = w["s"], w["key"]
            at, out = np.array([w["x"], w["y"], w["z"]]), -np.array([w["ox"], 0.0, w["oz"]])
            if "sideshroom" in key:
                pieces.append((at + out*5.0*s, 7.0*s))
            elif "shelves" in key:
                pieces.append((at + out*3.0*s, 6.0*s))
            elif "root" in key:
                pieces.extend((at - np.array([0.0, f*s, 0.0]), 5.0*s) for f in (0.0, 12.0, 24.0, 36.0))
            else:
                pieces.extend((at - np.array([0.0, f*20.0*s, 0.0]), 3.5) for f in (0.2, 0.5, 0.8))
        for m in list(trees) + list(canopy):
            h, base = m["height"], np.array([m["x"], m["y"], m["z"]])
            pieces.append((base + np.array([0.0, 0.85*h, 0.0]), 0.45*h))
            pieces.append((base + np.array([0.0, 0.4*h, 0.0]), 0.12*h))
        return pieces

    why = {"stones": 0, "rock": 0, "pieces": 0, "placed": 0}

    def crystal(x, y, z, lean, tilt, k, tall):
        """Set onto the real rock near the planned spot, growing straight out of it along the rock's average facing over the
        base's width, the base sunk a fifth of its shown height in (owner, 2026-11-05: they perched on corners). Where it would
        cut into another piece or the rock, the nearest clear spot along the wall is taken, a size smaller if need be; none by
        the stepping stones (one poked up under the first)."""
        key = keys[k % len(keys)]
        ox, oz = x - CX, z - CZ
        for dt, dy, scale in ((0.0, 0.0, 1.0), (0.03, 0.0, 1.0), (-0.03, 0.0, 1.0), (0.0, -6.0, 1.0), (0.06, -3.0, 1.0),
                              (-0.06, -3.0, 1.0), (0.0, 6.0, 0.8), (0.09, 0.0, 0.8), (-0.09, 0.0, 0.8), (0.0, -12.0, 0.8)):
            c, s = math.cos(dt), math.sin(dt)
            px, pz, py = CX + ox*c - oz*s, CZ + ox*s + oz*c, y + dy
            d = math.hypot(px - CX, pz - CZ)
            if py > -45.0 and ((px - CX)*-OUT_DIR[0] + (pz - CZ)*-OUT_DIR[1])/max(d, 1e-6) > math.cos(0.5):
                why["stones"] += 1
                continue
            shown = tall*scale*share[key]
            _, i = tree.query([px, py, pz])
            near = tree.query_ball_point(rock[i], max(0.3*shown, 1.5))
            n = normals[near].mean(axis=0)
            n /= np.linalg.norm(n)
            root = rock[i] - n*0.2*shown
            if any(tree.query(root + n*shown*f)[0] < 0.2*shown for f in (0.45, 0.75, 1.0)):
                why["rock"] += 1
                continue
            centre = root + n*0.5*shown
            if any(np.linalg.norm(centre - q) < 0.55*shown + r for q, r in occupied()):
                why["pieces"] += 1
                continue
            side = np.array([n[0], n[2]])
            lean = side/np.linalg.norm(side) if np.linalg.norm(side) > 0.05 else np.array(lean)
            pieces.append((centre, 0.55*shown))
            why["placed"] += 1
            crystals.append({"x": round(float(root[0]), 2), "y": round(float(root[1]), 2), "z": round(float(root[2]), 2), "height": round(tall*scale, 1),
                             "key": key, "lx": round(float(lean[0]), 4), "lz": round(float(lean[1]), 4),
                             "tilt": round(math.acos(float(np.clip(n[1], -1.0, 1.0))), 3)})
            return

    # On the wall, growing out over the hole.
    for k in range(12):
        t = hash1(k*23.1 + 5.0)*2*math.pi
        dx, dz = hole_dir(t)
        r = hole_radius(t) - 1.0
        crystal(CX + dx*r, -(10.0 + 92.0*hash1(k*4.3 + 2.0)), CZ + dz*r, (-dx, -dz), 0.95, k, 6.0 + 6.0*hash1(k*8.1))
    # Along the top of the wall, under the rim, where the roots haven't started (owner, 2026-11-04: the edge looked
    # bland): clusters at uneven spacing and heights, a few in twos, never a neat row.
    t = 0.0
    k = 0
    while t < 2*math.pi - 0.05:
        t += 0.13 + 0.16*hash1(k*3.7 + 11.0)
        dx, dz = hole_dir(t)
        r = hole_radius(t) - 0.8
        y = -(3.0 + 11.0*hash1(k*5.3 + 12.0))
        crystal(CX + dx*r, y, CZ + dz*r, (-dx, -dz), 0.75 + 0.5*hash1(k*2.9), k, 4.0 + 5.0*hash1(k*6.1 + 1.0))
        if hash1(k*8.3) < 0.3:
            t2 = t + 0.035
            dx, dz = hole_dir(t2)
            crystal(CX + dx*(hole_radius(t2) - 0.8), y - 2.5, CZ + dz*(hole_radius(t2) - 0.8), (-dx, -dz), 1.1, k + 1, 3.0 + 2.0*hash1(k))
        k += 1
    # On the spire, growing out toward the wall.
    for k in range(8):
        t = (k + 0.5)/8*2*math.pi + 0.3*hash1(k*2.9)
        y = -(10.0 + 90.0*hash1(k*6.7 + 4.0))
        dx, dz = hole_dir(t)
        r = spire_radius(y) - 0.5
        crystal(CX + dx*r, y, CZ + dz*r, (dx, dz), 0.9, k + 1, 5.0 + 4.0*hash1(k*3.7))
    # On the floor: crystals and small mushrooms between the spire's roots and the wall, set a little into the rock.
    floor_y = HOLE_FLOOR - 0.5
    taken = []
    for k in range(400):
        if len(taken) >= 34:
            break
        t = hash1(k*13.7 + 9.0)*2*math.pi
        f = hash1(k*7.3 + 1.0)
        r = spire_radius(floor_y) + 10.0 + f*(hole_radius(t) - 10.0 - spire_radius(floor_y) - 10.0)
        dx, dz = hole_dir(t)
        x, z = CX + dx*r, CZ + dz*r
        if any(math.hypot(x - a, z - b) < 13.0 for a, b in taken):
            continue
        taken.append((x, z))
        if len(taken) % 2:
            crystal(x, floor_y, z, (dx, dz), 0.15, len(taken), 5.0 + 5.0*hash1(k*2.1))
        else:
            trees.append({"x": round(x, 2), "y": floor_y, "z": round(z, 2), "height": round(6.0 + 8.0*hash1(k*3.3), 1), "colour": int(hash1(k*5.5)*4)})
    print(f"hole crystals: {why}")
    return wall


def main():
    trees, canopy, flora, crystals, slugs = [], [], [], [], []
    # As in the canopy hole composite (owner-approved, 2026-11-03): a ring of normal-sized giant mushrooms round the rim,
    # clear of the bridge's landing, and a few more out on the wider knoll so it isn't bare.
    def hash1(n):
        return (math.sin(n*127.1 + 3.7)*43758.5453) % 1.0

    tree_spots = []
    for i in range(16):
        tt = (i + 0.5)/16*2*math.pi + 0.25*(hash1(i*3.3) - 0.5)
        if abs((tt + math.pi) % (2*math.pi) - math.pi) < 0.4:
            continue
        dx, dz = hole_dir(tt)
        d = hole_radius(tt) + 15.0 + 30.0*hash1(i*5.7)
        x, z = CX + dx*d, CZ + dz*d
        if knoll_ok(4.0)(x, z) and not near_border(x, z, 14.0):
            tall = 17.0 + 19.0*hash1(i*7.1)
            trees.append({"x": round(x, 2), "y": 0.0, "z": round(z, 2), "height": round(tall, 1), "colour": i % 4})
            tree_spots.append((x, z))
    far = lambda x, z: knoll_ok(10.0)(x, z) and not in_hole(x, z, 60.0) and not near_border(x, z, 14.0)
    for x, z in scatter(12, 40.0, far):
        trees.append({"x": round(x, 2), "y": 0.0, "z": round(z, 2), "height": round(rng.uniform(20, 38), 1), "colour": rng.randrange(4)})
        tree_spots.append((x, z))
    # Round each tree's foot and scattered over the knoll: a third the approved grove plants (kinds 0 to 3), half the gun
    # side's star flowers (5 magenta, 6 cyan), the rest small mushrooms (giant mushroom copies a few studs tall).
    def plant_at(x, z, seed):
        pick = hash1(seed*13.0)
        if pick < 0.33:
            flora.append([int(hash1(seed*7.0)*4), round(x, 2), 0.3, round(z, 2), round(0.9 + 0.35*hash1(seed), 2), round(6.28*hash1(seed*3.0), 2)])
        elif pick < 0.83:
            flora.append([5 if hash1(seed*5.0) < 0.5 else 6, round(x, 2), 0.3, round(z, 2), round(0.85 + 0.4*hash1(seed*2.0), 2), round(6.28*hash1(seed*9.0), 2)])
        else:
            trees.append({"x": round(x, 2), "y": 0.0, "z": round(z, 2), "height": round(2.0 + 2.5*hash1(seed*4.0), 1), "colour": int(hash1(seed*8.0)*4)})

    ok = lambda x, z: knoll_ok(2.0)(x, z) and not near_border(x, z, 8.0)
    for i, (tx, tz) in enumerate(tree_spots):
        for k in range(6):
            a = k*1.047 + i
            r = 5.0 + 6.5*hash1(i*9.0 + k)
            x, z = tx + math.cos(a)*r, tz + math.sin(a)*r
            if ok(x, z):
                plant_at(x, z, i*17.0 + k)
    for n, (x, z) in enumerate(scatter(140, 9.0, ok)):
        plant_at(x, z, 500.0 + n)
    # Along both sides of the cobble path (owner, 2026-11-04): a mushroom tree each side, flowers and small mushrooms
    # lining it, the path itself kept clear.
    ux, uz = -OUT_DIR[0], -OUT_DIR[1]
    vx, vz = -uz, ux
    path_mid = (INNER + NEAR_EDGE)/2
    for side in (-1.0, 1.0):
        bx, bz = polar(ANGLE, path_mid)
        trees.append({"x": round(bx + vx*side*25.0, 2), "y": 0.0, "z": round(bz + vz*side*25.0, 2), "height": 24.0 if side < 0 else 21.0,
                      "colour": 0 if side < 0 else 2})
        for k in range(9):
            r = INNER + 3.0 + (NEAR_EDGE - INNER - 5.0)*(k + 0.5)/9
            off = 11.5 + 4.5*hash1(k*3.1 + side)
            x, z = polar(ANGLE, r)
            x, z = x + vx*side*off, z + vz*side*off
            seed = 900.0 + k*7.0 + side*50.0
            if k % 3 == 1:
                trees.append({"x": round(x, 2), "y": 0.0, "z": round(z, 2), "height": round(2.5 + 2.0*hash1(seed), 1), "colour": int(hash1(seed*8.0)*4)})
            elif k % 3 == 2:
                flora.append([int(hash1(seed*7.0)*4), round(x, 2), 0.3, round(z, 2), round(1.0 + 0.3*hash1(seed), 2), round(6.28*hash1(seed*3.0), 2)])
            else:
                flora.append([5 if k % 2 == 0 else 6, round(x, 2), 0.3, round(z, 2), round(1.0 + 0.3*hash1(seed*2.0), 2), round(6.28*hash1(seed*9.0), 2)])
    # The canopy: tall stems from the hole's floor, caps layered at several depths, all below the rim.
    levels = [(76, 86, 5), (58, 70, 9), (40, 52, 12), (22, 34, 16)]
    taken = []
    for lo, hi, count in levels:
        placed = 0
        for _ in range(4000):
            if placed >= count:
                break
            t, d = rng.uniform(0, 2*math.pi), math.sqrt(rng.uniform(0, 1))
            tall = rng.uniform(lo, hi)
            cap = tall*0.45
            reach = hole_radius(t) - cap*0.85
            if reach < PLATFORM + 4:
                continue
            d = PLATFORM + 4 + d*(reach - PLATFORM - 4)
            dx, dz = hole_dir(t)
            x, z = CX + dx*d, CZ + dz*d
            if any(math.hypot(x - p[0], z - p[1]) < (cap + p[2])*0.42 for p in taken):
                continue
            taken.append((x, z, cap))
            canopy.append({"x": round(x, 2), "y": HOLE_FLOOR, "z": round(z, 2), "height": round(tall*0.75, 1), "colour": rng.randrange(4)})
            placed += 1
    wall = cavern(hash1, crystals, trees, canopy)
    data = {
        "note": "Generated by tools/lobby/gun_side_sites.py. World studs; the hole's radii run round its centre from the hub-ward side.",
        "from": FROM, "to": TO,
        "hole": {"centre": [round(CX, 2), round(CZ, 2)], "out": [round(OUT_DIR[0], 4), round(OUT_DIR[1], 4)],
                 "radii": RADII, "lip": hole_lip(), "floor": HOLE_FLOOR, "barrier": 60.0},
        "bridge": BRIDGE, "platform": PLATFORM, "spawnBridge": SPAWN_BRIDGE,
        "trees": trees, "canopy": canopy, "flora": flora, "crystals": crystals, "slugs": slugs, "wall": wall,
    }
    OUT.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print(f"hole {min(RADII):.0f} to {max(RADII):.0f} studs from its centre; near edge at {NEAR_EDGE:.0f}; "
          f"bridge {BRIDGE['to'] - BRIDGE['from']:.0f} long")
    print(f"{len(trees)} knoll trees and small mushrooms, {len(canopy)} canopy trees, {len(flora)} plants")


if __name__ == "__main__":
    main()
