"""Lay out the gun side: the mushroom knoll, the canopy hole in it, the big bridge and the shop's platform.

Owner, 2026-11-03 (docs/art/general-shop.md, docs/art/gun-side-plan.html): the knoll fills the whole gun side and wraps
round an uneven hole full of mushroom canopy. A big bridge crosses it to the shop in the middle. The hole can't be
entered. Everything is placed from approved assets: giant mushroom v2 in the grove's four colours, the grove's
plants and crystals, and Floppies.

    python tools/lobby/gun_side_sites.py

Writes experiments/lobby/scale/shared/gun_side.json in world studs (the hub's centre at the origin, gun side at -x).
The block-out (Arena.luau) builds its floor, walls and barriers from the same hole, and HubArt places the props.
"""

import json
import math
import random
from pathlib import Path

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


def knoll_ok(pad):
    return lambda x, z: on_knoll(x, z) and not in_hole(x, z, pad) and not on_path(x, z, pad)


def main():
    trees, canopy, flora, crystals, slugs = [], [], [], [], []
    # The knoll's forest: big trees at the back and sides, smaller ones near the paths.
    for x, z in scatter(30, 22.0, knoll_ok(10.0)):
        _, r = to_polar(x, z)
        tall = rng.uniform(16, 26) if r < 150 else rng.uniform(22, 42)
        trees.append({"x": round(x, 2), "y": 0.0, "z": round(z, 2), "height": round(tall, 1), "colour": rng.randrange(4)})
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
            canopy.append({"x": round(x, 2), "y": HOLE_FLOOR, "z": round(z, 2), "height": round(tall, 1), "colour": rng.randrange(4)})
            placed += 1
    # Plants in clumps round the trees and along the rim, the way the grove has them.
    for x, z in scatter(48, 9.0, knoll_ok(3.0)):
        kind = rng.choices([4, 3, 2, 1, 0], [5, 3, 2, 2, 1])[0]
        for _ in range(rng.randint(3, 6)):
            px, pz = x + rng.uniform(-4, 4), z + rng.uniform(-4, 4)
            if knoll_ok(1.5)(px, pz):
                flora.append([kind, round(px, 2), 0.0, round(pz, 2), round(rng.uniform(0.85, 1.35), 2), round(rng.uniform(0, 6.28), 2)])
    for x, z in scatter(9, 30.0, knoll_ok(4.0)):
        crystals.append({"x": round(x, 2), "y": 0.0, "z": round(z, 2), "height": round(rng.uniform(5, 9), 1),
                         "key": rng.choice(["crystals-1", "crystals-5", "crystals-10", "crystals-11"])})
    for x, z in scatter(8, 12.0, knoll_ok(6.0)):
        slugs.append({"x": round(x, 2), "y": 0.0, "z": round(z, 2), "heading": round(rng.uniform(0, 6.28), 3)})
    data = {
        "note": "Generated by tools/lobby/gun_side_sites.py. World studs; the hole's radii run round its centre from the hub-ward side.",
        "from": FROM, "to": TO,
        "hole": {"centre": [round(CX, 2), round(CZ, 2)], "out": [round(OUT_DIR[0], 4), round(OUT_DIR[1], 4)],
                 "radii": RADII, "floor": HOLE_FLOOR, "barrier": 60.0},
        "bridge": BRIDGE, "platform": PLATFORM, "spawnBridge": SPAWN_BRIDGE,
        "trees": trees, "canopy": canopy, "flora": flora, "crystals": crystals, "slugs": slugs,
    }
    OUT.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print(f"hole {min(RADII):.0f} to {max(RADII):.0f} studs from its centre; near edge at {NEAR_EDGE:.0f}; "
          f"bridge {BRIDGE['to'] - BRIDGE['from']:.0f} long")
    print(f"{len(trees)} knoll trees, {len(canopy)} canopy trees, {len(flora)} plants, {len(crystals)} crystals, {len(slugs)} Floppies")


if __name__ == "__main__":
    main()
