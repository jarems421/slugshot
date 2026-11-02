"""Place the slug grove's dressing at fixed coordinates, between `// @grove-begin` and `// @grove-end` in the page.

Plain numbers, not the shader's hash, so every shader program agrees on where things are. Owner, 2026-11-02: a green, teal,
crystal area full of life, with Floppies as the standout, so the clearing round the pond stays open. Mushrooms are the trees.
Units are the concept's: 1 unit = 5 studs. The pond is centred on the origin and the mountain stands at +z.

    python tools/lobby/grove_sites.py
"""

import math
import random
import re
from pathlib import Path

PAGE = Path("docs/art/asset-library.html")
MOUNTAIN_Z = 26.0
# The same as peakInfo in the shader: centre x, centre z, height, radius, profile, lean x, lean z, ridges.
PEAKS = ((0.0, 26.0, 32.0, 18.5, 1.05, 0.0, 0.0, 5.0), (-21.0, 26.0, 24.0, 13.0, 0.95, -1.2, 0.0, 4.0), (21.5, 27.0, 19.0, 12.0, 1.2, 3.2, -0.4, 3.0),
         (0.0, 32.0, 14.0, 20.0, 1.0, 0.0, 0.0, 6.0), (-9.5, 19.5, 17.0, 7.5, 0.95, 0.0, 0.0, 3.0), (10.0, 20.0, 13.5, 7.0, 1.0, 0.0, 0.0, 3.0),
         (-29.0, 29.0, 13.0, 9.0, 0.9, 0.0, 0.0, 3.0), (30.0, 30.0, 10.5, 8.0, 1.0, 0.0, 0.0, 3.0))
# The same as peakTop in the shader.
PEAK_TOPS = (0.34, 0.42, 0.44, 0.3, 0.12, 0.12, 0.12, 0.12)
FRONT = 1.5*math.pi


def smoothstep(a, b, x):
    t = min(max((x - a)/(b - a), 0.0), 1.0)
    return t*t*(3 - 2*t)


def peak_r(y, height, radius, profile):
    return radius*max(1.0 - y/height, 0.0)**profile


def inside(x, y, z):
    """The same shape as peakRad and peakWander in the shader."""
    for index, (cx, cz, height, radius, profile, lx, lz, ridges) in enumerate(PEAKS):
        if y >= height:
            continue
        t = min(max(y/height, 0.0), 1.0)
        seed = index*1.7 + 0.6
        if index == 0:
            wx, wz = 0.05*radius*t*math.sin(t*4.7 + seed), 0.0
        else:
            wx, wz = 0.1*radius*t*math.sin(t*4.7 + seed), 0.1*radius*t*math.cos(t*3.9 + seed*1.6)
        qx, qz = x - cx - lx*t*t - wx, z - cz - lz*t*t - wz
        a = math.atan2(qz, qx) % (2*math.pi)
        gully = smoothstep(0.2, 0.8, abs(math.atan2(math.sin(a - 4.71239), math.cos(a - 4.71239)))) if index in (0, 3) else 1.0
        brk = (0.05*math.sin(t*17.0 + a*1.5 + seed) + 0.03*math.sin(t*31.0 - a*2.2 + seed*1.3))*gully
        top = PEAK_TOPS[index]
        body = radius*(top + (1.0 - top)*max(1.0 - min(max(t + brk, 0.0), 1.0), 0.0)**profile)
        bulge = 0.28*math.sin(t*math.pi*(1.0 + 0.35*math.sin(a + seed)))*gully
        ridge = (1.0 - abs(math.sin((a + 0.12*math.sin(t*5.0 + seed) - 4.71239)*ridges*0.5 + 1.5708)))**1.6
        lump = 0.18*math.sin(a*2.0 + seed*1.7) + 0.12*math.sin(a*3.0 + t*4.0 + seed*2.9) + 0.08*math.sin(t*13.0 + a*2.0 + seed)
        if math.hypot(qx, qz) < body*(1.0 + bulge)*(0.92 + 0.36*ridge*(1.0 - 0.35*t) + lump*gully):
            return True
    return False


def surface_radius(a, y):
    """Coming in from outside at this angle and height, where the rock's mass is first met."""
    r = 56.0
    while r > 0.0:
        if inside(r*math.cos(a), y, MOUNTAIN_Z + r*math.sin(a)):
            return r
        r -= 0.1
    return 0.0


def on_mountain(a, y, inset=0.2):
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
        top.append((x, ground(x, z) - 0.2, z, height))
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
        top.append((x, ground(x, z) - 0.05, z, height))
        more.append((height*rnd.uniform(0.45, 0.65), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), rnd.choice((0, 1, 2, 3))))
    return top, more


def bushes(rnd):
    """Clumps sitting on the ledges, more of them low down, leaving plenty of the rock showing."""
    rows = []
    tries = 0
    while len(rows) < 100 and tries < 4000:
        tries += 1
        a, y = rnd.uniform(2.3, 7.1) % (2*math.pi), 26.0*rnd.random()**1.5 + 0.4
        x, y0, z = on_mountain(a, y, 0.15)
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
    for x, y, z, size in ((-1.5, 15.9, 17.1, 0.75), (2.0, 15.8, 17.1, 0.85), (-2.0, 7.9, 12.9, 1.0), (2.6, 7.8, 12.9, 0.95)):
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
            flowers.append((x, ground(x, z) - 0.03, z, rnd.randrange(3) + rnd.uniform(0.75, 1.3)*0.1 + rnd.random()*0.0))
    for a, far in ((3.3, 6.5), (3.9, 7.5), (5.6, 6.0), (6.05, 7.0), (0.5, 5.0), (2.5, 5.5), (2.0, 3.2), (1.15, 3.0), (4.3, 9.0), (5.15, 9.5)):
        r = pond_radius(a) + far
        x, z = r*math.cos(a), r*math.sin(a)
        ferns.append((x, ground(x, z) - 0.03, z, rnd.uniform(0.75, 1.1)))
    return flowers, ferns


def crystals():
    rows, more = [], []
    for a, y, colour, scale in ((3.55, 3.0, 0, 1.3), (4.05, 8.0, 1, 1.1), (5.45, 3.5, 1, 1.4), (5.9, 9.5, 0, 1.0), (4.45, 14.0, 2, 0.9), (5.0, 21.0, 1, 0.75), (4.3, 24.5, 2, 0.7), (3.2, 14.0, 0, 0.9)):
        x, y0, z = on_mountain(a, y, 0.1)
        rows.append((x, y0, z, colour))
        more.append((0.55*math.cos(a), 0.65, 0.55*math.sin(a), scale))
    for x, z, colour, scale in ((-9.5, -3.8, 1, 0.55), (9.6, -1.2, 0, 0.6), (8.4, 4.8, 2, 0.5), (-8.2, 5.4, 0, 0.55)):
        rows.append((x, ground(x, z) - 0.05, z, colour))
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
        x, y0, z = on_mountain(a, y, -0.15)
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
    stones = boulders(rnd)
    flowers, ferns = flora(rnd, stones)
    gems, gem_more = crystals()
    block = "// @grove-begin\n// Generated by tools/lobby/grove_sites.py. See there before editing.\n"
    block += vec4s("GROVE_SHROOM", top) + vec4s("GROVE_CAP", more) + vec4s("GROVE_BUSH", bushes(rnd)) + vec4s("GROVE_STONE", stones)
    block += vec4s("GROVE_FLOWER", flowers) + vec4s("GROVE_FERN", ferns) + vec4s("GROVE_GEM", gems) + vec4s("GROVE_GEM_DIR", gem_more)
    block += vec4s("GROVE_VINE", vines(rnd)) + vec4s("GROVE_PAD", lily_pads()) + vec4s("GROVE_SLUG", slugs(stones)) + "// @grove-end\n"
    text = PAGE.read_text(encoding="utf-8")
    text, count = re.subn(r"// @grove-begin\n.*?// @grove-end\n", lambda _: block, text, flags=re.S)
    assert count == 1, "the page needs its generated block"
    PAGE.write_text(text, encoding="utf-8")
    print(f"grove: {len(top)} mushrooms, {len(flowers)} flowers, {len(ferns)} ferns, {len(stones)} stones, 30 slugs")


if __name__ == "__main__":
    main()
