"""More life on the grove mountain (owner, 2026-11-05: blank places and plain near the peaks; the mushrooms on it should stand
out from it, not blend in). Adds to what grove_sites.py places, without touching its generated block or files.

Reads the exported mountain (build/lobby/meshes/hub-grove-mountain) and the grove's own sites, and writes
experiments/lobby/scale/shared/grove_mountain.json in grove studs (the GROVE frame in HubArt, as grove_trees.json):
small giant mushrooms in purple and azure, which read against the mountain's green and teal, on its ledges up to the peaks,
and clumps of the grove's approved plants round them and across the bare slopes.

    python tools/lobby/mountain_life.py

Retired (owner, 2026-11-07: the mountain plain, with only the mushrooms that come out of it and go up): HubArt no longer
places this file; the side mushrooms are far_side_sites.py's --dressing.
"""

import json
import random
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

SHARED = Path("experiments/lobby/scale/shared")
MOUNTAIN = Path("build/lobby/meshes/hub-grove-mountain")
OUT = SHARED/"grove_mountain.json"
STUDS = 5.0
# Purple and azure (TREE_COLOURS in HubArt): the mountain is painted green and teal.
COLOURS = (2, 3)
# Grove plants (FLORA_KEYS in HubArt): star lily, moonbells, lanterns, broad plant, grass.
PLANTS = (0, 1, 2, 3, 0, 1, 4)


def mountain():
    centres, normals = [], []
    for path in sorted(MOUNTAIN.glob("Mountain[A-Z]*.npz")):
        if "Buried" in path.name:
            continue
        data = np.load(path)
        v, f = data["verts"]*STUDS, data["faces"]
        a, b, c = v[f[:, 0]], v[f[:, 1]], v[f[:, 2]]
        n = np.cross(b - a, c - a)
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
        centres.append((a + b + c)/3.0)
        normals.append(n)
    return np.concatenate(centres), np.concatenate(normals)


def main():
    rng = random.Random(1105)
    c, n = mountain()
    tree = cKDTree(c)
    # Ledges: faces turned up, on the mountain itself rather than the ground round its foot.
    ledge = np.flatnonzero((n[:, 1] > 0.6) & (c[:, 1] > 9.0))
    stream = np.array([row[:3] for row in json.loads((SHARED/"grove_stream.json").read_text())])*STUDS
    taken = [(t["x"], t["y"], t["z"], 0.45*t["height"]) for t in json.loads((SHARED/"grove_trees.json").read_text())]
    taken += [(x, y, z, 6.0) for x, y, z in json.loads((SHARED/"grove_feet.json").read_text())["mountain"]]

    axis_z = json.loads((SHARED/"grove_feet.json").read_text())["axisZ"]

    def clear(p, reach):
        # Off the stream and its falls, which run down the mountain's front near its middle.
        if np.min(np.hypot(stream[:, 0] - p[0], stream[:, 2] - p[2])) < 16.0 + reach or (abs(p[0]) < 20.0 + reach and p[2] < axis_z):
            return False
        return all(np.linalg.norm(p - np.array(q[:3])) > reach + q[3] for q in taken)

    def flat(i, radius):
        near = tree.query_ball_point(c[i], radius)
        return len(near) >= 4 and (n[near] @ np.array([0.0, 1.0, 0.0])).min() > 0.35

    # More of them high up: a third of each kind in each band of height, the top band near the peaks.
    bands = ((9.0, 55.0), (55.0, 110.0), (110.0, 170.0))
    by_band = [ledge[(c[ledge, 1] >= lo) & (c[ledge, 1] < hi)] for lo, hi in bands]
    trees, plants = [], []
    for band, faces in enumerate(by_band):
        faces = list(faces)
        rng.shuffle(faces)
        want_trees, want_plants = (5, 7, 6)[band], (22, 28, 24)[band]
        for i in faces:
            if len(trees) >= sum((5, 7, 6)[:band + 1]):
                break
            p = c[i]
            height = rng.uniform(9.0, 16.0) if band < 2 else rng.uniform(7.0, 12.0)
            if not flat(i, 0.25*height) or not clear(p, 0.45*height):
                continue
            # Its foot sunk a little, so the downhill side doesn't stand off the slope.
            trees.append({"x": round(float(p[0]), 2), "y": round(float(p[1] - 0.12*height), 2), "z": round(float(p[2]), 2),
                          "height": round(height, 1), "colour": COLOURS[len(trees) % 2], "turn": round(rng.uniform(0, 6.28), 3)})
            taken.append((p[0], p[1], p[2], 0.45*height))
        placed = 0
        for i in faces:
            if placed >= want_plants:
                break
            p = c[i]
            if not clear(p, 2.0):
                continue
            # A clump of two to four, one kind, round the spot.
            kind = PLANTS[rng.randrange(len(PLANTS))]
            size = rng.uniform(1.5, 2.3) if kind != 4 else rng.uniform(1.8, 2.8)
            for _ in range(rng.randint(2, 4)):
                q = p + np.array([rng.gauss(0, 2.2), 0.0, rng.gauss(0, 2.2)])
                _, j = tree.query(q)
                if n[j][1] < 0.45:
                    continue
                plants.append([kind, round(float(c[j][0]), 2), round(float(c[j][1] - 0.3), 2), round(float(c[j][2]), 2),
                               round(size*rng.uniform(0.85, 1.15), 2), round(rng.uniform(0, 6.28), 2)])
            taken.append((p[0], p[1], p[2], 3.0))
            placed += 1
    OUT.write_text(json.dumps({"note": "Generated by tools/lobby/mountain_life.py. Grove studs, as grove_trees.json and grove_flora.json.",
                               "trees": trees, "flora": plants}, indent=1) + "\n", encoding="utf-8")
    print(f"mountain: {len(trees)} mushrooms, {len(plants)} plants")


if __name__ == "__main__":
    main()
