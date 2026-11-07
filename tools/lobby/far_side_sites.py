"""Place the cavern wall's and the far side cave's dressing on the real rock, all of it approved pieces (owner, 2026-11-04).

Reads the dense surfaces hub_mesh.py sampled (build/lobby/meshes/hub-cavern-*, hub-roof-*, hub-cave-*, hub-far-ground,
hub-well-rock), so run after meshing them:

    python tools/lobby/far_side_sites.py

Writes experiments/lobby/scale/shared/far_side.json in world studs: crystals in eight of the library's designs, each growing
straight out of the rock with its base sunk in (owner, 2026-11-05: all the same two, perched on corners); sideways mushrooms on
the wall and, scaled up, sprouting out of the cave's spires; the Sky Well's leafy green vines and some bead vines on the wall and
roof, and bead vines in the cave hanging only from rock above them; the ring of crystals round the storm on the Sky Well's rim;
the ring of warm crystals hanging from the roof over the volcano; and the lantern posts either side of the far side's cobble path.

    python tools/lobby/far_side_sites.py --volcano-roof
    python tools/lobby/far_side_sites.py --dressing

add (or replace) only the volcano's ring, or the crystals among the path's rocks and the side mushrooms on the grove
mountain, in the current far_side.json, as rerunning the whole placement against today's meshes reshuffles the far side.
"""

import json
import math
import random
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

OUT = Path("experiments/lobby/scale/shared/far_side.json")
MESHES = Path("build/lobby/meshes")
STUDS = 5.0
ARCH_HALF, ARCH_TOP = 28.0, 37.0
SLAB_FILE = Path("build/lobby/mouth_slabs.json")
SLABS = json.loads(SLAB_FILE.read_text()) if SLAB_FILE.exists() else []
# Spire index, height, the direction it grows (radians round y, 4.71 faces the hub), scale. FC_SPROUTS in the library's far cave.
SPROUTS = ((0, -6.0, 5.72, 3.2), (1, -1.0, 3.79, 3.8), (2, 5.0, 5.87, 4.4), (4, 6.0, 3.56, 4.4), (5, 13.0, 5.36, 4.6),
           (5, 2.0, 3.70, 3.8), (6, -1.0, 5.50, 4.0), (7, -3.0, 5.84, 4.0), (8, 14.0, 3.29, 4.8),
           (9, -2.0, 4.10, 3.6), (10, 4.0, 5.60, 4.2), (11, 8.0, 4.71, 4.4), (12, -4.0, 5.20, 3.8))
SPIRES = ((-14.0, 76.0, 4.0, 3.6), (17.0, 81.0, 13.0, 4.2), (-31.0, 90.0, 21.0, 4.8), (3.0, 95.0, -3.0, 3.2), (29.0, 99.0, 25.0, 5.0),
          (-11.0, 106.0, 31.0, 5.0), (13.0, 115.0, 17.0, 4.2), (-37.0, 114.0, 9.0, 4.6), (38.0, 122.0, 34.0, 5.6),
          (34.0, 84.0, 8.0, 3.8), (-42.0, 100.0, 15.0, 4.4), (-2.0, 127.0, 22.0, 5.4), (-24.0, 125.0, 2.0, 4.0), (8.0, 72.0, -10.0, 3.0))
DRIPS = ((-6.0, 70.0, 24.0), (22.0, 74.0, 28.0), (-24.0, 82.0, 30.0), (7.0, 88.0, 27.0), (-38.0, 98.0, 34.0), (25.0, 108.0, 36.0), (-3.0, 121.0, 38.0))
# The Sky Well (1 unit = 10 studs, origin y 1), lowered 25 studs in the game (CEILING_DROP in HubArt). The storm's rim is at 10.
WELL_STUDS, WELL_ORIGIN_Y, WELL_DROP = 10.0, 1.0, 25.0
EYE_COUNT, EYE_R = 16, 10.45
# The library's crystal designs as light copies: Cyan cluster, Amber fan, Violet spire, Rose crown, Frost spires, Aurora urchin,
# Emerald spray; and for ceilings the Pearl hanging cluster, which hangs from its own rock lid, among the others turned over.
UPRIGHT = ("crystals-1-s", "crystals-3-s", "crystals-2-s", "crystals-4-s", "crystals-6-s", "crystals-14-s", "crystals-5-s")
HANGING = ("crystals-13-s", "crystals-1-s", "crystals-4-s", "crystals-2-s", "crystals-13-s", "crystals-6-s", "crystals-3-s", "crystals-14-s")
PEARL = "crystals-13-s"
# The volcano's crater in world studs (x, z; HubArt's volcCentre at its top), and the warm designs hung round it from the roof:
# design, height, and how far out from the smoke's way up, in studs.
VOLCANO_AXIS = (-0.8, -263.7)
VOLCANO_RING = (("crystals-3-s", 26.0, 52.0), ("crystals-13-s", 30.0, 66.0), ("crystals-4-s", 24.0, 56.0), ("crystals-3-s", 22.0, 70.0),
                ("crystals-4-s", 28.0, 50.0), ("crystals-13-s", 26.0, 64.0), ("crystals-3-s", 24.0, 58.0), ("crystals-4-s", 22.0, 68.0))
# The cobble path's line (FC_PATH_A, FC_PATH_B in the library) and where its lantern posts stand, in units.
LANTERN_Z, LANTERN_X = (25.5, 33.5, 41.5, 49.5), 2.7


def vine(index, rng, roof=False):
    """Three in four wall vines, and half the roof's, are the Sky Well's leafy green vine; the rest stay bead vines."""
    green = index % 2 == 0 if roof else index % 4 != 3
    if green:
        return f"hub-green-vine-{'ab'[(index // 2) % 2]}", 0.8 + 0.4*rng.random()
    return f"hub-gun-vine-{'ab'[(index // 2) % 2]}", 1.3 + 0.9*rng.random()


def surface(key):
    """Face centres and unit normals (out of the rock) of one piece's dense surface, and a tree to find neighbours."""
    centres, normals = [], []
    for path in sorted((MESHES/key).glob("*.npz")):
        data = np.load(path)
        v, f = data["verts"], data["faces"]
        a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
        n = np.cross(b - a, c - a)
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
        centres.append((a + b + c)/3.0)
        normals.append(n)
    return np.concatenate(centres), np.concatenate(normals)


def shares():
    """How tall each design is shown for the size it's given: HubArt makes a wide one smaller, so no side runs past the size
    by more than a tenth (owner, 2026-11-05: the Amber fan came out huge)."""
    out = {}
    for key in set(UPRIGHT + HANGING):
        meta = json.loads((MESHES/key/"meta.json").read_text())
        v = np.concatenate([np.load(MESHES/key/f"{g['name']}.npz")["verts"] for g in meta["groups"]])
        size = v.max(axis=0) - v.min(axis=0)
        out[key] = min(1.0, size[1]*1.1/max(size[0], size[2]))
    return out


SHARE = shares()


def clear_of_rock(tree, root, n, size):
    """Whether rock stays out of the crystal's body: points up its middle, in units, are all at least a fifth of its size
    from the rock (owner, 2026-11-05: rocks poked through them)."""
    axis = n/np.linalg.norm(n)
    for f in (0.45, 0.75, 1.0):
        d, _ = tree.query((root + axis*size*f)/STUDS)
        if d*STUDS < 0.2*size:
            return False
    return True


def clear_of(pieces, centre, radius):
    """Whether nothing else placed (mushrooms, vines, other crystals) is within reach (owner, 2026-11-05: crystals cut into
    them)."""
    return all(np.linalg.norm(centre - q) > radius + r for q, r in pieces)


def flat(tree, normals, centre, n, radius):
    """Whether the rock round a point is broad and even enough for a crystal's base: no corner or edge within its reach."""
    near = tree.query_ball_point(centre, radius)
    if len(near) < 6:
        return False
    d = normals[near] @ n
    return d.min() > 0.55 and d.mean() > 0.88


def grow(world, n, key, height, down_lean=None):
    """A crystal growing straight out of the rock along its surface, its rock base sunk a fifth of its height in, so none of it
    hangs off (owner, 2026-11-05). The Pearl cluster hangs from its own rock lid, so it stays upright with the lid sunk in. A
    turned-over crystal can be leant a little (down_lean, outward) to clear what's beside it."""
    n = n/np.linalg.norm(n)
    height_shown = height*SHARE[key]
    if key == PEARL:
        root, lean, tilt = world - np.array([0.0, height_shown*0.85, 0.0]), np.array([1.0, 0.0]), 0.0
    else:
        if down_lean is not None:
            n = np.array([0.0, -1.0, 0.0]) + 0.25*np.array([down_lean[0], 0.0, down_lean[1]])
            n /= np.linalg.norm(n)
        side = np.array([n[0], n[2]])
        lean = side/np.linalg.norm(side) if np.linalg.norm(side) > 0.05 else np.array([1.0, 0.0])
        tilt = math.acos(float(np.clip(n[1], -1.0, 1.0)))
        root = world - n*0.2*height_shown
    return {"x": round(float(root[0]), 2), "y": round(float(root[1]), 2), "z": round(float(root[2]), 2), "height": round(height, 1),
            "key": key, "lx": round(float(lean[0]), 4), "lz": round(float(lean[1]), 4), "tilt": round(tilt, 3)}


def angle_of(p):
    return math.degrees(math.atan2(p[0], -p[2])) % 360.0


def in_opening(p):
    return p[2] > 0 and abs(p[0]) < ARCH_HALF + 5.0 and p[1] < ARCH_TOP + 5.0


def spaced(p, taken, gap):
    return all(np.linalg.norm(p - q) > gap for q in taken)


def in_slabs(site, margin=2.0):
    """Whether a crystal or wall piece (world studs) stands within a few units of one of the mouth's slabs."""
    if not SLABS:
        return False
    at = np.array([site["x"], site["y"], site["z"]])/STUDS
    for slab in SLABS:
        (cx, cy, cz, yaw), roll, half = slab["p"], slab["r"][0], np.array(slab["s"][:3])
        q = at - np.array([cx, cy, cz])
        ez = np.array([math.sin(yaw), 0.0, math.cos(yaw)])
        ex0 = np.array([math.cos(yaw), 0.0, -math.sin(yaw)])
        ex = math.cos(roll)*ex0 + np.array([0.0, math.sin(roll), 0.0])
        ey = -math.sin(roll)*ex0 + np.array([0.0, math.cos(roll), 0.0])
        local = np.abs(np.array([q @ ex, q @ ey, q @ ez])) - half
        if np.linalg.norm(np.maximum(local, 0.0)) < margin:
            return True
    return False


def eye_ring():
    """Crystals evenly round the storm, hanging from the Sky Well's rim where its old crystals were, now with no rocks between
    them (owner, 2026-11-05), each a different design in turn, pointing down and a little out from the storm."""
    c, n = surface("hub-well-rock")
    tree = cKDTree(c)
    world = np.stack([c[:, 0]*WELL_STUDS, (c[:, 1] - WELL_ORIGIN_Y)*WELL_STUDS - WELL_DROP, c[:, 2]*WELL_STUDS], axis=1)
    rock = cKDTree(world)
    r = np.hypot(c[:, 0], c[:, 2])
    ang = np.degrees(np.arctan2(c[:, 2], c[:, 0]))
    down = (n[:, 1] < -0.6) & (r > 10.1) & (r < 10.9)
    out = []
    for k in range(EYE_COUNT):
        a = (k + 0.5)*360.0/EYE_COUNT
        near = np.flatnonzero(down & (np.abs((ang - a + 180.0) % 360.0 - 180.0) < 4.0))
        near = [i for i in near if flat(tree, n, c[i], n[i], 0.9)] or list(near)
        if not near:
            continue
        i = min(near, key=lambda j: abs((ang[j] - a + 180.0) % 360.0 - 180.0) + 20.0*abs(r[j] - EYE_R))
        rad = math.radians(a)
        # The design in turn, or the next that keeps clear of the rim's rock (owner, 2026-11-05: one poked through).
        for attempt in range(len(HANGING)):
            key = HANGING[(k + attempt) % len(HANGING)]
            height = 34.0 if key == PEARL else 28.0 + 4.0*((k*7) % 3)/2.0
            site = grow(world[i], n[i], key, height, down_lean=(math.cos(rad), math.sin(rad)))
            size = height*SHARE[key]
            low = np.array([site["x"], site["y"], site["z"]]) - np.array([0.0, size*(0.75 if key != PEARL else 0.4), 0.0])
            if rock.query(low)[0] > 0.2*size:
                out.append(site)
                break
    return out


def volcano_roof(pieces):
    """Over the volcano no crags hang (owner, 2026-11-05: two spikes crowded it), and the roof looked blank there (owner,
    2026-11-06): a loose ring of the warm designs hangs round the smoke's way up, each pointing down and a little away from it,
    lit from below by the lava (HubArt). `pieces` is what is already placed, as spheres in studs."""
    cs, ns = [], []
    for path in sorted(MESHES.glob("hub-roof-*")):
        c, n = surface(path.name)
        keep = np.abs((np.degrees(np.arctan2(c[:, 0], -c[:, 2])) + 180.0) % 360.0 - 180.0) < 32.0
        cs.append(c[keep])
        ns.append(n[keep])
    c, n = np.concatenate(cs), np.concatenate(ns)
    tree = cKDTree(c)
    world = c*STUDS
    dx, dz = world[:, 0] - VOLCANO_AXIS[0], world[:, 2] - VOLCANO_AXIS[1]
    off, bearing = np.hypot(dx, dz), np.degrees(np.arctan2(dz, dx))
    down = n[:, 1] < -0.75
    out = []
    for k, (key, height, reach) in enumerate(VOLCANO_RING):
        a = k*360.0/len(VOLCANO_RING) + 15.0
        near = np.flatnonzero(down & (np.abs((bearing - a + 180.0) % 360.0 - 180.0) < 16.0) & (np.abs(off - reach) < 14.0))
        size = height*SHARE[key]
        for i in sorted(near, key=lambda j: abs(off[j] - reach) + 0.3*abs((bearing[j] - a + 180.0) % 360.0 - 180.0)):
            if not flat(tree, n, c[i], n[i], 0.3*height/STUDS):
                continue
            away = np.array([dx[i], dz[i]])/max(off[i], 1e-6)
            site = grow(world[i], n[i], key, height, down_lean=(away[0], away[1]))
            root = np.array([site["x"], site["y"], site["z"]])
            centre = root + np.array([0.0, -size*0.45, 0.0])
            ok_rock = key == PEARL or clear_of_rock(tree, root, np.array([0.0, -1.0, 0.0]), size)
            if ok_rock and clear_of(pieces, centre, 0.55*size):
                site["volcano"] = True
                out.append(site)
                pieces.append((centre, 0.55*size))
                break
    return out


def add_volcano_roof():
    """Adds the ring over the volcano to the current far_side.json, replacing any earlier one, without placing anything else
    again: rerunning main() against today's meshes reshuffles the whole far side (see docs/art/lobby-hub.md, round 6)."""
    data = json.loads(OUT.read_text(encoding="utf-8"))
    data["crystals"] = [s for s in data["crystals"] if not s.get("volcano")]
    pieces = []
    for s in data["crystals"]:
        size = s["height"]*SHARE.get(s["key"], 1.0)
        pieces.append((np.array([s["x"], s["y"], s["z"]]), 0.55*size))
    for w in data["wall"]:
        pieces.append((np.array([w["x"], w["y"], w["z"]]), 6.0*w["s"]))
    ring = volcano_roof(pieces)
    data["crystals"] += ring
    OUT.write_text(json.dumps(data, indent=0), encoding="utf-8", newline="\n")
    for s in ring:
        print(f"  {s['key']} {s['height']} at ({s['x']}, {s['y']}, {s['z']})")
    print(f"{len(ring)} crystals over the volcano, {len(data['crystals'])} in all")


# The rock outcrops beside the cobble path, as FC_PATH_ROCKS in the library (units: x, z, tip height, radius; base at -1).
PATH_ROCKS = ((-5.6, 23.5, 2.2, 1.2), (-7.2, 24.6, 4.4, 1.9), (-9.6, 23.0, 1.8, 1.0), (-6.4, 30.0, 1.6, 0.9), (-8.6, 31.0, 5.2, 2.3),
              (-11.2, 29.6, 2.6, 1.4), (-5.8, 37.6, 2.8, 1.4), (-8.0, 38.6, 1.6, 1.0), (-10.4, 37.0, 4.0, 1.9), (-6.6, 45.2, 3.6, 1.7),
              (-9.2, 46.4, 2.0, 1.1), (-11.6, 44.8, 5.6, 2.4), (5.8, 22.4, 3.4, 1.6), (8.4, 23.8, 1.8, 1.0), (10.8, 22.2, 4.8, 2.1),
              (6.0, 29.4, 2.0, 1.1), (8.2, 30.6, 4.2, 1.9), (10.6, 31.4, 1.6, 0.9), (6.4, 36.6, 4.6, 2.0), (9.0, 37.8, 2.4, 1.2),
              (11.4, 36.4, 3.0, 1.5), (5.8, 44.0, 1.8, 1.0), (8.0, 45.0, 3.8, 1.8), (10.6, 46.2, 2.2, 1.2))


def path_crystals(pieces):
    """Crystals growing among the rock outcrops either side of the cobble path (owner, 2026-11-07: plain there), off the
    path and its lanterns and clear of the rocks."""
    c, n = surface("hub-far-ground")
    tree = cKDTree(c)
    for x, z, h, r in PATH_ROCKS:
        for f in (0.2, 0.5, 0.8):
            pieces.append((np.array([x, -1.0 + (h + 1.0)*f, z])*STUDS, r*(1.0 - 0.6*f)*STUDS + 2.0))
    ax = np.abs(c[:, 0])
    near = np.flatnonzero((n[:, 1] > 0.8) & (ax > 4.0) & (ax < 12.5) & (c[:, 2] > 21.0) & (c[:, 2] < 48.0) & (c[:, 1] > -0.6) & (c[:, 1] < 1.5))
    rng = random.Random(9)
    order = list(near)
    rng.shuffle(order)
    out, taken, kinds = [], [], 0
    for i in order:
        p = c[i]
        if not spaced(p, taken, 3.2):
            continue
        height = 10.0 + 12.0*rng.random()
        if not flat(tree, n, p, n[i], 0.3*height/STUDS):
            continue
        key = UPRIGHT[kinds % len(UPRIGHT)]
        site = grow(p*STUDS, n[i], key, height)
        size = height*SHARE[key]
        centre = np.array([site["x"], site["y"], site["z"]]) + n[i]*size*0.5
        if not clear_of(pieces, centre, 0.55*size):
            continue
        site["path"] = True
        out.append(site)
        pieces.append((centre, 0.55*size))
        taken.append(p)
        kinds += 1
        if len(out) >= 14:
            break
    return out


def mountain_shrooms(pieces):
    """The grove mountain bare but for sideways mushrooms growing out of its faces and curving up (owner, 2026-11-07: plain,
    with only the mushrooms that come out then go up; round 9's crystals there went). The approved side mushroom, on steep
    faces turned toward the hub, between 20 and 150 studs up, off the stream and its falls, its cap clear of the rock."""
    c, n = surface("hub-grove-mountain")
    world = np.stack([c[:, 2]*STUDS + 155.0, c[:, 1]*STUDS, -c[:, 0]*STUDS], 1)
    normal = np.stack([n[:, 2], n[:, 1], -n[:, 0]], 1)
    tree = cKDTree(world)
    stream = np.array([[155.0 + r[2]*STUDS, r[1]*STUDS, -r[0]*STUDS] for r in
                       json.loads(Path("experiments/lobby/scale/shared/grove_stream.json").read_text())])
    for t in json.loads(Path("experiments/lobby/scale/shared/grove_trees.json").read_text()):
        if t["y"] <= 10.0:  # HubArt's ON_MOUNTAIN: the grove's own, round the pond
            base = np.array([155.0 + t["z"], t["y"], -t["x"]])
            pieces.append((base + np.array([0.0, 0.85*t["height"], 0.0]), 0.45*t["height"]))
    flat_n = normal*np.array([1.0, 0.0, 1.0])
    reach = np.linalg.norm(flat_n, axis=1)
    out_dir = flat_n/np.maximum(reach, 1e-9)[:, None]
    inward = -world*np.array([1.0, 0.0, 1.0])
    inward /= np.maximum(np.linalg.norm(inward, axis=1, keepdims=True), 1e-9)
    facing = (out_dir*inward).sum(axis=1)
    ok = (normal[:, 1] > -0.25) & (normal[:, 1] < 0.5) & (reach > 0.8) & (facing > 0.2)
    ok &= (world[:, 1] > 20.0) & (world[:, 1] < 150.0) & (np.hypot(world[:, 0], world[:, 2]) < 285.0)
    ok &= ~((np.abs(world[:, 2]) < 22.0) & (world[:, 1] < 110.0))
    rng = random.Random(12)
    order = list(np.flatnonzero(ok))
    rng.shuffle(order)
    out, taken = [], []
    up = np.array([0.0, 1.0, 0.0])
    for i in order:
        p, o = world[i], out_dir[i]
        if not spaced(p, taken, 34.0) or np.min(np.hypot(stream[:, 0] - p[0], stream[:, 2] - p[2])) < 26.0:
            continue
        s = 1.3 + 0.7*rng.random()
        root = p - normal[i]*1.5*s
        # The piece reaches about 19 studs out and 16 up at full size, its cap some 10 across round 13 out and 13 up.
        cap, stem = root + (o*13.0 + up*13.0)*s, root + (o*7.0 + up*3.0)*s
        if tree.query(cap)[0] < 9.0*s or tree.query(stem)[0] < 2.5*s:
            continue
        if not clear_of(pieces, cap, 10.0*s):
            continue
        key = f"hub-gun-sideshroom-{'ab'[len(out) % 2]}"
        out.append({"key": key, "x": round(float(root[0]), 2), "y": round(float(root[1]), 2), "z": round(float(root[2]), 2),
                    "ox": round(float(-o[0]), 4), "oz": round(float(-o[2]), 4), "s": round(s, 3), "mountain": True})
        pieces.append((cap, 10.0*s))
        taken.append(p)
        if len(out) >= 16:
            break
    return out


# The pit under the spawn island (owner, 2026-11-07: basic, its mushrooms old designs). The concept's five tree mushrooms, as
# treeShroom in the library: the angle round the pit (radians, atan(z, x)), where the stem leaves the cliff and the cap's
# radius, in units; then three lower and smaller in the gaps between the falls and the bridges.
PIT_SHROOMS = ((0.38, -5.2, 2.0), (1.08, -6.9, 2.3), (2.72, -4.6, 1.7), (3.45, -6.2, 2.3), (5.05, -5.5, 1.9),
               (2.42, -8.2, 1.6), (4.35, -8.6, 1.7), (5.98, -7.8, 1.5))
FALL_ANGLES = (0.73, 2.1, 4.0, 5.6)  # fallAngle in the library
BRIDGE_ANGLES = (0.0, math.pi/2, math.pi, 3*math.pi/2)
# The concept's crystal clusters under the spawn rock (rockCrystals: site, growing direction, length, in units from its top)
# and some of its small ones (rockSmallCrystals), now the approved designs at the same spots.
ISLAND_CLUSTERS = (((3.346, -3.912, 2.818), (0.605, -0.613, 0.509), 2.17), ((-3.811, -2.435, 0.159), (-0.790, -0.613, 0.033), 2.87),
                   ((3.784, -2.900, -3.768), (0.560, -0.613, -0.558), 1.87), ((-0.213, -1.772, 4.633), (-0.036, -0.613, 0.790), 2.09),
                   ((-3.465, -1.863, -4.149), (-0.507, -0.613, -0.607), 1.93), ((5.879, -1.820, 0.789), (0.783, -0.613, 0.105), 1.83),
                   ((-5.060, -1.590, 3.523), (-0.649, -0.613, 0.452), 3.20), ((1.402, -1.599, -6.241), (0.141, -0.767, -0.627), 3.66))
ISLAND_SMALL = (((1.547, -4.348, 2.940), (0.779, -0.115, 0.617), 1.26), ((-2.882, -3.633, 1.190), (-0.634, 0.103, 0.767), 0.96),
                ((-6.770, -0.977, -0.741), (-0.746, -0.544, -0.384), 1.29), ((6.545, -1.590, 4.237), (0.624, -0.276, 0.731), 1.29),
                ((-4.975, -3.061, -1.823), (-0.786, -0.412, -0.460), 0.71), ((4.460, -3.041, -3.481), (0.749, -0.053, -0.660), 0.71),
                ((2.008, -1.429, -6.581), (0.379, -0.310, -0.872), 1.27))


def off_angle(a, angles, gap):
    return all(abs(math.atan2(math.sin(a - b), math.cos(a - b))) > gap for b in angles)


def pit_shrooms(pieces):
    """The approved side mushroom out of the pit's cliff, each where the concept's stem left it, curving up over the juice."""
    c, n = surface("hub-cliff")
    world, tree = c*STUDS, cKDTree(c*STUDS)
    angle = np.arctan2(world[:, 2], world[:, 0])
    flat_n = n*np.array([1.0, 0.0, 1.0])
    reach = np.linalg.norm(flat_n, axis=1)
    out_dir = flat_n/np.maximum(reach, 1e-9)[:, None]
    radial = world*np.array([1.0, 0.0, 1.0])
    radial /= np.maximum(np.linalg.norm(radial, axis=1, keepdims=True), 1e-9)
    facing = -(out_dir*radial).sum(axis=1)
    up = np.array([0.0, 1.0, 0.0])
    out = []
    for k, (a, y0, cap_r) in enumerate(PIT_SHROOMS):
        placed = False
        # A size smaller where the cap would reach the crystals under the spawn rock.
        for s, dy in [(round(0.75*cap_r*f, 3), dy) for f in (1.0, 0.85) for dy in (0.0, 2.5, -2.5, 5.0, -5.0)]:
            near = (np.abs(np.arctan2(np.sin(angle - a), np.cos(angle - a))) < 0.06) & (np.abs(world[:, 1] - (y0*STUDS + dy)) < 3.0)
            near &= (facing > 0.6) & (reach > 0.8)
            if not near.any():
                continue
            i = np.flatnonzero(near)[np.argmin(np.hypot(world[near][:, 0], world[near][:, 2]))]
            root = world[i] - n[i]*1.5*s
            o = out_dir[i]
            cap, stem = root + (o*13.0 + up*13.0)*s, root + (o*7.0 + up*3.0)*s
            if tree.query(cap)[0] < 9.0*s or tree.query(stem)[0] < 2.5*s or not clear_of(pieces, cap, 10.0*s):
                continue
            out.append({"key": f"hub-gun-sideshroom-{'ab'[k % 2]}", "x": round(float(root[0]), 2), "y": round(float(root[1]), 2),
                        "z": round(float(root[2]), 2), "ox": round(float(-o[0]), 4), "oz": round(float(-o[2]), 4), "s": s, "pit": True})
            pieces.append((cap, 10.0*s))
            placed = True
            break
        if not placed:
            print(f"  pit mushroom {k} at {a} found no clear spot")
    return out


def pit_crystals(pieces):
    """Crystals growing out of the pit's cliff below the rim, off the falls and bridges and clear of its mushrooms."""
    c, n = surface("hub-cliff")
    tree = cKDTree(c)
    world = c*STUDS
    angle = np.arctan2(world[:, 2], world[:, 0])
    radial = world*np.array([1.0, 0.0, 1.0])
    radial /= np.maximum(np.linalg.norm(radial, axis=1, keepdims=True), 1e-9)
    facing = -(n*radial).sum(axis=1)
    ok = (facing > 0.55) & (np.abs(n[:, 1]) < 0.6) & (world[:, 1] < -10.0) & (world[:, 1] > -46.0)
    ok &= np.array([off_angle(a, FALL_ANGLES, 0.36) and off_angle(a, BRIDGE_ANGLES, 0.22) for a in angle])
    rng = random.Random(13)
    order = list(np.flatnonzero(ok))
    rng.shuffle(order)
    out, taken, kinds = [], [], 0
    for i in order:
        p = world[i]
        if not spaced(p, taken, 30.0):
            continue
        height = 14.0 + 8.0*rng.random()
        if not flat(tree, n, c[i], n[i], 0.3*height/STUDS):
            continue
        key = UPRIGHT[(kinds + 2) % len(UPRIGHT)]
        site = grow(p, n[i], key, height)
        size = height*SHARE[key]
        root = np.array([site["x"], site["y"], site["z"]])
        axis = n[i]/np.linalg.norm(n[i])
        if not clear_of_rock(tree, root, axis, size):
            continue
        centre = root + axis*size*0.5
        if not clear_of(pieces, centre, 0.55*size):
            continue
        site["pit"] = True
        out.append(site)
        pieces.append((centre, 0.55*size))
        taken.append(p)
        kinds += 1
        if len(out) >= 9:
            break
    return out


def island_crystals(pieces):
    """The approved crystals under the spawn rock, at the concept's clusters and some of its small ones, growing the same way."""
    out = []
    for k, (site, direction, length) in enumerate(ISLAND_CLUSTERS + ISLAND_SMALL):
        small = k >= len(ISLAND_CLUSTERS)
        key = UPRIGHT[(k + 4) % len(UPRIGHT)]
        height = length*STUDS*(1.5 if small else 1.3)
        n = np.array(direction)/np.linalg.norm(direction)
        placed = grow(np.array(site)*STUDS, n, key, height)
        placed["island"] = True
        # Fifteen soft pools so close together washed the rock out: half for the clusters, none for the small ones.
        placed["glow"] = 0.0 if small else 0.5
        out.append(placed)
        pieces.append((np.array(site)*STUDS + n*height*SHARE[key]*0.5, 0.55*height*SHARE[key]))
    return out


def on_mountain_outline(crystals):
    """The alcove's crystals that, seen from the hub or the grove, sit just over the mountain's outline, so they read as
    perched on a peak (owner, 2026-11-07: the flower on the very tip; the mountain plain): a clear line of sight to it
    that passes the rock less than 1.5 degrees below. One the rock hides from an eye is fine from there."""
    tree = mountain_tree()
    eyes = (np.array([60.0, 15.0, 0.0]), np.array([155.0, 12.0, 0.0]), np.array([120.0, 12.0, -40.0]), np.array([120.0, 12.0, 40.0]))
    perched = []
    for s in crystals:
        p = np.array([s["x"], s["y"], s["z"]])
        for eye in eyes:
            length = np.linalg.norm(p - eye)
            t = np.arange(10.0, length - 10.0, 1.5)
            if not len(t):
                continue
            points = eye + np.outer(t/length, p - eye)
            gap, nearest = tree.query(points)
            if gap.min() < 1.5:
                continue
            i = np.argmin(gap/t)
            if tree.data[nearest[i]][1] < points[i][1] and math.degrees(gap[i]/t[i]) < 1.5:
                perched.append(s)
                break
    return perched


def add_dressing():
    """Adds (or replaces) the path's crystals and the mountain's mushrooms in the current far_side.json, placing nothing else
    again."""
    data = json.loads(OUT.read_text(encoding="utf-8"))
    data["crystals"] = [s for s in data["crystals"] if not (s.get("path") or s.get("mountain") or s.get("pit") or s.get("island"))]
    data["wall"] = [w for w in data["wall"] if not (w.get("mountain") or w.get("pit"))]
    pieces = []
    for s in data["crystals"]:
        pieces.append((np.array([s["x"], s["y"], s["z"]]), 0.55*s["height"]*SHARE.get(s["key"], 1.0)))
    for w in data["wall"]:
        pieces.append((np.array([w["x"], w["y"], w["z"]]), 6.0*w["s"]))
    path = path_crystals(pieces)
    mountain = mountain_shrooms(pieces)
    island = island_crystals(pieces)
    shrooms = pit_shrooms(pieces)
    pit = pit_crystals(pieces)
    data["crystals"] += path + island + pit
    data["wall"] += mountain + shrooms
    print(f"{len(shrooms)} side mushrooms and {len(pit)} crystals in the pit, {len(island)} crystals under the spawn rock")
    perched = on_mountain_outline(data["crystals"])
    data["crystals"] = [s for s in data["crystals"] if s not in perched]
    OUT.write_text(json.dumps(data, indent=0), encoding="utf-8", newline="\n")
    print(f"{len(path)} crystals beside the path, {len(mountain)} mushrooms on the mountain, {len(perched)} left out over its "
          f"peaks {[(s['key'], s['x'], s['y'], s['z']) for s in perched]}, {len(data['crystals'])} crystals in all")


def lanterns():
    """Lantern posts either side of the cobble path, their foot on the floor beside it and the arm reaching over it."""
    c, n = surface("hub-far-ground")
    out = []
    for z in LANTERN_Z:
        for side in (-1.0, 1.0):
            x = side*LANTERN_X
            near = (np.hypot(c[:, 0] - x, c[:, 2] - z) < 0.6) & (n[:, 1] > 0.5) & (c[:, 1] > -0.5)
            y = float(c[near][:, 1].min()) if near.any() else 0.0
            out.append({"x": round(x*STUDS, 2), "y": round(y*STUDS, 2), "z": round(z*STUDS, 2), "yaw": 0.0 if side < 0 else round(math.pi, 4)})
    return out


def mountain_tree():
    """The grove mountain in world studs (HubArt's GROVE frame: the pond 155 studs out at +x, the grove's +z toward +x)."""
    v = np.concatenate([np.load(f)["verts"] for f in sorted(Path("build/lobby/meshes/hub-grove-mountain").glob("*.npz"))])*STUDS
    return cKDTree(np.stack([v[:, 2] + 155.0, v[:, 1], -v[:, 0]], axis=1))


def main():
    rng = random.Random(4)
    crystals, wall = [], []
    taken = []
    designs = {"up": 0, "hang": 0}
    # Everything placed so far, as spheres in studs, so nothing new cuts into it (owner, 2026-11-05).
    pieces = []

    def design(kind):
        keys = UPRIGHT if kind == "up" else HANGING
        designs[kind] += 1
        return keys[(designs[kind] - 1) % len(keys)]

    def try_crystal(world, normal, kind, height, rock, **lean):
        """Place a crystal of the next design if rock and other pieces keep clear of it; True if it went in."""
        for _ in range(len(UPRIGHT)):
            key = design(kind)
            site = grow(world, normal, key, height, **lean)
            size = height*SHARE[key]
            root = np.array([site["x"], site["y"], site["z"]])
            axis = np.array([0.0, -1.0, 0.0]) if key == PEARL else normal/np.linalg.norm(normal)
            if key == PEARL:
                centre, ok_rock = root + np.array([0.0, size*0.45, 0.0]), True
            else:
                centre, ok_rock = root + axis*size*0.5, clear_of_rock(rock, root, axis if lean.get("down_lean") is None else np.array([0.0, -1.0, 0.0]), size)
            if ok_rock and clear_of(pieces, centre, 0.55*size):
                crystals.append(site)
                pieces.append((centre, 0.55*size))
                return True
        return False

    def add_piece(key, world, out, s, hanging=False):
        """A wall piece (out: its facing, away from the rock), if nothing is in its way."""
        if key.startswith("hub-gun-sideshroom"):
            spheres = [(world + out*5.0*s, 7.0*s)]
        else:
            length = (44.0 if key.endswith("b") else 32.0)*s if key.startswith("hub-green-vine") else (24.0 if key.endswith("b") else 16.0)*s
            spheres = [(world - np.array([0.0, f*length, 0.0]), 4.0) for f in (0.2, 0.5, 0.8)]
        if not all(clear_of(pieces, centre, r) for centre, r in spheres):
            return False
        pieces.extend(spheres)
        o = -out if not hanging else np.array([0.0, 0.0, 1.0])
        wall.append({"key": key, "x": round(float(world[0]), 2), "y": round(float(world[1]), 2), "z": round(float(world[2]), 2),
                     "ox": round(float(o[0]), 4), "oz": round(float(o[2]), 4), "s": round(s, 3)})
        return True

    mountain = mountain_tree()
    for path in sorted(MESHES.glob("hub-cavern-*")):
        c, n = surface(path.name)
        tree = cKDTree(c)
        inward = -c*np.array([1, 0, 1])
        inward /= np.maximum(np.linalg.norm(inward, axis=1, keepdims=True), 1e-9)
        facing = (n*inward).sum(axis=1)
        order = list(range(len(c)))
        rng.shuffle(order)
        counts = {"crystal": 4, "mushroom": 2, "vine": 8}
        for i in order:
            p = c[i]
            if not 1.2 < p[1] < 38.0 or facing[i] < 0.72 or in_opening(p):
                continue
            a = angle_of(p)
            if a < 15.0 or a > 345.0:
                continue
            # Behind the grove mountain, crystals on the alcove's wall where it shows above the mountain (owner, 2026-11-05:
            # plain there), well clear of the mountain itself.
            behind = 52.0 < a < 118.0
            if behind and (p[1]*STUDS < 60.0 or mountain.query(p*STUDS)[0] < 30.0):
                continue
            kinds = ("crystal",) if behind else ("crystal", "mushroom", "vine")
            kind = next((k for k in kinds if counts[k] > 0), None)
            if kind is None:
                if all(v == 0 for v in counts.values()):
                    break
                continue
            if not spaced(p, taken, 7.0):
                continue
            # Dressing sits low enough to read from the floor, thinning out higher up (not behind the mountain, where only
            # what's high up shows).
            if not behind and rng.random() < p[1]/44.0:
                continue
            height = 16.0 + 14.0*rng.random()
            if kind == "crystal" and not flat(tree, n, p, n[i], 0.3*height/STUDS):
                continue
            world = p*STUDS
            if kind == "crystal":
                placed = try_crystal(world, n[i], "up", height, tree)
            elif kind == "mushroom":
                placed = add_piece(f"hub-gun-sideshroom-{'ab'[len(wall) % 2]}", world, inward[i], 0.75 + 0.5*rng.random())
            else:
                key, s = vine(8 - counts["vine"], rng)
                placed = add_piece(key, world, inward[i], s)
            if placed:
                taken.append(p)
                counts[kind] -= 1
    # The cave's walls: big crystals you can see from the edge and mushrooms on its real surface; bead vines only where rock
    # hangs over them (owner, 2026-11-05: some hung off nothing).
    c, n = surface("hub-cave-hall")
    tree = cKDTree(c)
    mid = np.stack([np.zeros(len(c)), c[:, 1]*0.0 + 5.0, c[:, 2]], axis=1) - c
    mid /= np.maximum(np.linalg.norm(mid, axis=1, keepdims=True), 1e-9)
    facing = (n*mid).sum(axis=1)
    counts = {"crystal": 16, "mushroom": 7, "vine": 14}
    order = list(range(len(c)))
    rng.shuffle(order)
    hall_taken = []
    for i in order:
        p = c[i]
        if not -6.0 < p[1] < 44.0 or p[2] < 72.0 or facing[i] < 0.3:
            continue
        under = n[i][1] < -0.6
        kind = next((k for k in ("crystal", "mushroom", "vine") if counts[k] > 0 and (k == "vine") == under), None)
        if kind is None:
            if all(v == 0 for v in counts.values()):
                break
            continue
        if kind != "vine" and facing[i] < 0.6:
            continue
        if not spaced(p, hall_taken, 11.0):
            continue
        height = 26.0 + 22.0*rng.random()
        if kind == "crystal" and not flat(tree, n, p, n[i], 0.3*height/STUDS):
            continue
        world = p*STUDS
        if kind == "crystal":
            placed = try_crystal(world, n[i], "up", height, tree)
        elif kind == "mushroom":
            placed = add_piece(f"hub-gun-sideshroom-{'ab'[len(wall) % 2]}", world, mid[i], 2.0 + 1.2*rng.random())
        else:
            # Its top a stud up inside the rock it hangs from.
            placed = add_piece(f"hub-gun-vine-{'ab'[len(wall) % 2]}", world + np.array([0.0, 1.0, 0.0]), mid[i], 2.0 + 1.5*rng.random(), hanging=True)
        if placed:
            hall_taken.append(p)
            counts[kind] -= 1
    # The roof's underside: vines hanging from it, and crystals hanging out of it.
    roof_taken = []
    for path in sorted(MESHES.glob("hub-roof-*")):
        c, n = surface(path.name)
        tree = cKDTree(c)
        order = list(range(len(c)))
        rng.shuffle(order)
        counts = {"crystal": 1, "vine": 4}
        for i in order:
            p = c[i]
            if n[i][1] > -0.75 or not 43.0 < math.hypot(p[0], p[2]) < 60.0 or (p[2] > 0 and abs(p[0]) < 36.0 and math.hypot(p[0], p[2]) > 52.0):
                continue
            kind = next((k for k in ("crystal", "vine") if counts[k] > 0), None)
            if kind is None:
                break
            if not spaced(p, roof_taken, 9.0):
                continue
            height = 16.0 + 10.0*rng.random()
            if kind == "crystal" and not flat(tree, n, p, n[i], 0.3*height/STUDS):
                continue
            world = p*STUDS
            if kind == "crystal":
                placed = try_crystal(world, n[i], "hang", height, tree)
            else:
                key, s = vine(4 - counts["vine"], rng, roof=True)
                if key.startswith("hub-gun-vine"):
                    s = 1.4 + 1.0*rng.random()
                # Hanging straight down from the roof, gripping it.
                placed = add_piece(key, world, np.array([0.0, -1.0, 0.0]), s, hanging=True)
            if placed:
                roof_taken.append(p)
                counts[kind] -= 1
    # The far side's floor: a few crystals round its stalagmites, clear of the way to the edge; and the cliff (owner, 2026-11-05:
    # fill it out), crystals along its lip beside the lip rocks and on its face below, and side mushrooms on the face.
    c, n = surface("hub-far-ground")
    tree = cKDTree(c)
    order = list(range(len(c)))
    rng.shuffle(order)
    floor_taken, left = [], 14
    for i in order:
        p = c[i]
        r = math.hypot(p[0], p[2])
        if not 0.05 < p[1] < 1.4 or n[i][1] < 0.8 or not 27.0 < r < 54.0 or abs(p[0]) < 15.0 or abs(math.atan2(p[0], p[2])) > 0.7:
            continue
        if not spaced(p, floor_taken, 12.0):
            continue
        height = 8.0 + 12.0*rng.random()
        if not flat(tree, n, p, n[i], 0.3*height/STUDS):
            continue
        if try_crystal(p*STUDS, n[i], "up", height, tree):
            floor_taken.append(p)
            left -= 1
        if left == 0:
            break
    lip = {"top": 8, "face": 8, "mushroom": 5}
    for i in order:
        p = c[i]
        if not 6.0 < abs(p[0]) < 27.0 or not 48.0 < p[2] < 62.0:
            continue
        top = n[i][1] > 0.75 and -0.2 < p[1] < 1.6 and p[2] > 49.5
        face = n[i][2] > 0.55 and abs(n[i][1]) < 0.5 and -9.0 < p[1] < -1.2
        kind = "top" if top and lip["top"] else "face" if face and lip["face"] else "mushroom" if face and lip["mushroom"] else None
        if kind is None or not spaced(p, floor_taken, 4.5):
            continue
        height = (8.0 + 8.0*rng.random()) if kind == "top" else (12.0 + 10.0*rng.random())
        if kind != "mushroom" and not flat(tree, n, p, n[i], 0.3*height/STUDS):
            continue
        out = np.array([n[i][0], 0.0, n[i][2]])
        out /= max(np.linalg.norm(out), 1e-6)
        placed = try_crystal(p*STUDS, n[i], "up", height, tree) if kind != "mushroom" else \
            add_piece(f"hub-gun-sideshroom-{'ab'[len(wall) % 2]}", p*STUDS, out, 1.3 + 0.6*rng.random())
        if placed:
            floor_taken.append(p)
            lip[kind] -= 1
        if not any(lip.values()):
            break
    # The cave's mushrooms, each rooted on its spire's real surface, on the side it grows from.
    c, n = surface("hub-cave-spires")
    for k, (index, y, angle, scale) in enumerate(SPROUTS):
        sx, sz, _, rad = SPIRES[index]
        d = np.array([math.cos(angle), math.sin(angle)])
        rel = c[:, [0, 2]] - np.array([sx, sz])
        along, across = rel @ d, np.abs(rel @ np.array([-d[1], d[0]]))
        near = (np.abs(c[:, 1] - y) < 1.0) & (across < 1.0) & (along > 0.0) & (along < rad*4.0)
        reach = float(along[near].max()) if near.any() else rad*0.8
        root = np.array([sx + d[0]*reach, y, sz + d[1]*reach])*STUDS
        wall.append({"key": f"hub-gun-sideshroom-{'ab'[k % 2]}", "x": round(float(root[0]), 2), "y": round(float(root[1]), 2), "z": round(float(root[2]), 2),
                     "ox": round(float(-d[0]), 4), "oz": round(float(-d[1]), 4), "s": scale})
    # A vine hanging from each hanging spire's tip, its top up inside the tip.
    for k, (sx, sz, tip) in enumerate(DRIPS):
        rel = np.hypot(c[:, 0] - sx, c[:, 2] - sz)
        near = (rel < 6.0) & (c[:, 1] > tip) & (c[:, 1] < tip + 6.0)
        if not near.any():
            continue
        spot = c[near][np.argmin(c[near][:, 1])]*STUDS
        wall.append({"key": f"hub-gun-vine-{'ab'[k % 2]}", "x": round(float(spot[0]), 2), "y": round(float(spot[1] + 3.0), 2), "z": round(float(spot[2]), 2),
                     "ox": 0.0, "oz": 1.0, "s": round(1.6 + 0.8*rng.random(), 3)})
    # The glowing vines across the head of the arch are gone (owner, 2026-11-06): big slabs frame the mouth instead
    # (hub-mouth-slabs, tools/lobby/mouth_slabs.py), and nothing on the wall may stand in them.
    crystals = [s for s in crystals if not in_slabs(s)]
    wall = [w for w in wall if not in_slabs(w)]
    eye = eye_ring()
    crystals += eye
    crystals += volcano_roof(pieces)
    posts = lanterns()
    OUT.write_text(json.dumps({"note": "Generated by tools/lobby/far_side_sites.py. World studs, the hub's centre at the origin.",
                               "crystals": crystals, "wall": wall, "lanterns": posts}, indent=0), encoding="utf-8")
    green = sum(1 for w in wall if w["key"].startswith("hub-green-vine"))
    kinds = sorted({s["key"] for s in crystals})
    print(f"{len(crystals)} crystals ({len(eye)} round the Sky Well) in {len(kinds)} designs, {len(wall)} wall and cave pieces "
          f"({green} green vines), {len(posts)} lantern posts")


if __name__ == "__main__":
    import sys
    if "--volcano-roof" in sys.argv:
        add_volcano_roof()
    elif "--dressing" in sys.argv:
        add_dressing()
    else:
        main()
