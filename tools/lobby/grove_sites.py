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
MOUNTAIN_Z, MOUNTAIN_H = 22.0, 27.0
FRONT = 1.5*math.pi


def smoothstep(a, b, x):
    t = min(max((x - a)/(b - a), 0.0), 1.0)
    return t*t*(3 - 2*t)


def base_radius(y):
    return 17.0*(1 - min(max(y/MOUNTAIN_H, 0.0), 1.0))**0.85


def mountain_radius(a, y):
    """The same shape as mtnR in the shader."""
    t = min(max(y/MOUNTAIN_H, 0.0), 1.0)
    phase = a*7.0 + 0.4*math.sin(a*3.0 + 1.0) + 0.2*math.sin(t*8.0 + a*2.0)
    ridge = (1.0 - abs(math.sin(phase*0.5)))**1.6
    return base_radius(y) + (ridge - 0.4)*(4.6 - 3.4*t) + 1.2*math.sin(a*4.0 + t*6.0 + 1.0)*(1.0 - t)


def shoulder_radius(x, y, z, cx, cz, height, r0, seed):
    """How far inside a side peak this point is; positive means inside. The same shape as groveShoulder in the shader."""
    if y > height:
        return -1.0
    qx, qz = x - cx, z - cz
    a = math.atan2(qz, qx)
    t = min(max(y/height, 0.0), 1.0)
    ridge = (1.0 - abs(math.sin((a*6.0 + seed)*0.5)))**1.6
    return r0*(1.0 - t)**0.85 + (ridge - 0.4)*(2.4 - 1.8*t) + 0.6*math.sin(a*3.0 + t*5.0 + seed) - math.hypot(qx, qz)


def surface_radius(a, y):
    """Coming in from outside at this angle and height, where the mountain or a side peak is first met."""
    r = 34.0
    while r > 0.0:
        x, z = r*math.cos(a), MOUNTAIN_Z + r*math.sin(a)
        if r < mountain_radius(a, y) or shoulder_radius(x, y, z, -9.0, 21.0, 17.0, 9.5, 1.1) > 0 or shoulder_radius(x, y, z, 8.5, 24.5, 13.0, 9.0, 3.7) > 0:
            return r
        r -= 0.1
    return 0.0


def on_mountain(a, y, inset=0.2):
    r = surface_radius(a, y) - inset
    return r*math.cos(a), y, MOUNTAIN_Z + r*math.sin(a)


def pond_radius(a):
    return 7.0*(1.0 + 0.07*math.sin(a*3.0 + 1.0) + 0.05*math.sin(a*5.0 + 2.0))


def ground(x, z):
    """The same shape as groveHeight in the shader."""
    r, a = math.hypot(x, z), math.atan2(z, x)
    edge = r - pond_radius(a)
    h = 0.25*math.sin(x*0.31 + 1.0)*math.sin(z*0.27) + 0.12*math.sin(x*0.9 + z*0.7)
    bank = smoothstep(0.0, 3.0, edge)
    return h*bank + 0.35*bank - 0.55*(1.0 - smoothstep(-1.6, 0.0, edge)) + 0.8*smoothstep(8.0, 16.0, z)


def clear_of_falls(x, y):
    return abs(x - 0.3) > 2.6 + 0.09*(14 - y)


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
    for a, y, height, cap, colour in ((3.75, 5.0, 3.6, 1.8, 1), (4.15, 9.5, 2.8, 1.4, 2), (5.3, 6.0, 3.8, 1.9, 0), (5.75, 11.0, 2.6, 1.3, 3), (3.45, 11.5, 2.5, 1.3, 3),
                                          (5.0, 13.5, 2.3, 1.2, 1), (4.4, 16.5, 2.0, 1.0, 0), (0.15, 7.0, 3.0, 1.5, 2), (3.0, 6.5, 3.0, 1.5, 1)):
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


def cliffs(rnd):
    """Angular blocks of uneven length breaking the slope, the same language as the spawn rock's cliffs."""
    first, second = [], []
    for level, y in enumerate((2.5, 6.0, 9.5, 13.0, 16.5, 20.0, 23.0)):
        count = 13 - level
        for k in range(count):
            a = (k + rnd.uniform(-0.25, 0.25))*2*math.pi/count + level*0.4
            a %= 2*math.pi
            length = rnd.uniform(1.8, 3.8)*(1.1 - y/40)
            hw, hd = rnd.uniform(1.0, 1.9)*(1.1 - y/36), rnd.uniform(1.1, 2.4)*(1.1 - y/36)
            # Well bedded in, standing out as a crag.
            r = surface_radius(a, y) - hw*0.55
            x, z = r*math.cos(a), MOUNTAIN_Z + r*math.sin(a)
            if not clear_of_falls(x, y) and z < MOUNTAIN_Z:
                continue
            first.append((x, z, a + rnd.uniform(-0.3, 0.3), hw))
            second.append((hd, y + length*0.45, y - length*1.9, rnd.uniform(-0.45, 0.45)))
    return first, second


def bushes(rnd, first, second):
    rows = []
    # Greenery spilling off the tops of the cliffs, and in low mats between them.
    for (x, z, yaw, hw), (hd, top, bottom, slant) in zip(first, second):
        for _ in range(2):
            if rnd.random() < 0.8:
                ox, oz = rnd.uniform(-1, 1)*hd*0.7, rnd.uniform(-1, 1)*hd*0.7
                rows.append((x + ox, top + 0.05, z + oz, rnd.uniform(0.5, 1.15)*(1.2 - top/34)))
    tries = 0
    while len(rows) < 150 and tries < 4000:
        tries += 1
        a, y = rnd.uniform(2.4, 7.0) % (2*math.pi), 20.0*rnd.random()**1.3 + 0.3
        x, y0, z = on_mountain(a, y, -0.05)
        if not clear_of_falls(x, y) and z < MOUNTAIN_Z:
            continue
        rows.append((x, y0 + 0.1, z, rnd.uniform(0.55, 1.35)*(1.15 - y/28)))
    return rows


def boulders(rnd):
    rows = []
    # Stepping out across the pond, near the falls, for the slugs to sit on.
    for x, z, size in ((-3.6, 2.2, 0.85), (-1.8, 3.9, 0.6), (2.6, 3.0, 0.95), (4.2, 0.8, 0.6), (-4.6, -0.8, 0.7), (1.0, -2.4, 0.55), (-1.6, -3.6, 0.45)):
        rows.append((x, -0.2, z, size))
    # Rough rock round the two basins the falls land in.
    for x, y, z, size in ((-1.2, 13.8, 13.5, 0.75), (1.9, 13.7, 13.5, 0.85), (-1.9, 7.2, 10.2, 1.0), (2.4, 7.1, 10.2, 0.95)):
        rows.append((x, y, z, size))
    for _ in range(9):
        a = rnd.uniform(0, 2*math.pi)
        r = pond_radius(a) + rnd.uniform(-0.1, 0.9)
        x, z = r*math.cos(a), r*math.sin(a)
        rows.append((x, ground(x, z) - 0.05, z, rnd.uniform(0.45, 1.0)))
    return rows


def flora(rnd):
    flowers, ferns = [], []
    # Drifts rather than an even scatter, which leaves open ground between them.
    for degrees, far in ((175, 2.4), (215, 2.0), (250, 3.4), (292, 3.2), (328, 2.0), (5, 2.6), (140, 2.2), (42, 1.8)):
        a0 = math.radians(degrees)
        r0 = pond_radius(a0) + far
        cx, cz = r0*math.cos(a0), r0*math.sin(a0)
        for _ in range(rnd.randint(4, 6)):
            x, z = cx + rnd.gauss(0, 1.1), cz + rnd.gauss(0, 1.1)
            if math.hypot(x, z) < pond_radius(math.atan2(z, x)) + 0.4:
                continue
            flowers.append((x, ground(x, z) - 0.03, z, rnd.randrange(3) + rnd.uniform(0.75, 1.3)*0.1 + rnd.random()*0.0))
    for a, far in ((3.3, 6.5), (3.9, 7.5), (5.6, 6.0), (6.05, 7.0), (0.5, 5.0), (2.5, 5.5), (2.0, 3.2), (1.15, 3.0), (4.3, 9.0), (5.15, 9.5)):
        r = pond_radius(a) + far
        x, z = r*math.cos(a), r*math.sin(a)
        ferns.append((x, ground(x, z) - 0.03, z, rnd.uniform(0.75, 1.1)))
    return flowers, ferns


def crystals():
    rows, more = [], []
    for a, y, colour, scale in ((3.55, 3.0, 0, 1.3), (4.0, 7.0, 1, 1.1), (5.45, 3.5, 1, 1.4), (5.9, 8.5, 0, 1.0), (4.55, 11.5, 2, 0.9), (5.1, 17.0, 1, 0.75), (4.3, 19.5, 2, 0.7), (3.15, 12.0, 0, 0.9)):
        x, y0, z = on_mountain(a, y, 0.1)
        rows.append((x, y0, z, colour))
        more.append((0.55*math.cos(a), 0.65, 0.55*math.sin(a), scale))
    for x, z, colour, scale in ((-9.5, -3.8, 1, 0.55), (9.6, -1.2, 0, 0.6), (8.4, 4.8, 2, 0.5), (-8.2, 5.4, 0, 0.55)):
        rows.append((x, ground(x, z) - 0.05, z, colour))
        more.append((0.0, 1.0, 0.0, scale))
    return rows, more


def vines(rnd):
    rows = []
    while len(rows) < 16:
        a, y = rnd.uniform(3.3, 6.1), rnd.uniform(5.0, 20.0)
        x, y0, z = on_mountain(a, y, -0.15)
        if clear_of_falls(x, y):
            rows.append((x, y0, z, rnd.uniform(2.0, 5.5)))
    return rows


def slugs(rnd, stones):
    rows = []
    for index in (0, 1, 2, 3, 4, 5, 6, 12, 15):
        x, y, z, size = stones[index]
        rows.append((x + rnd.uniform(-0.2, 0.2)*size, y + 0.72*size, z + rnd.uniform(-0.2, 0.2)*size, rnd.uniform(0, 6.28)))
    tries = 0
    while len(rows) < 30 and tries < 500:
        tries += 1
        a = rnd.uniform(0, 2*math.pi)
        r = pond_radius(a) + rnd.uniform(0.15, 4.5)
        x, z = r*math.cos(a), r*math.sin(a)
        if any(math.hypot(x - row[0], z - row[2]) < 0.8 for row in rows):
            continue
        # A few in mid hop.
        hop = rnd.uniform(0.18, 0.4) if len(rows) % 6 == 0 else 0.0
        rows.append((x, ground(x, z) + hop, z, rnd.uniform(0, 6.28)))
    return rows


def main():
    rnd = random.Random(29)
    top, more = shrooms(rnd)
    stones = boulders(rnd)
    cliff_a, cliff_b = cliffs(rnd)
    flowers, ferns = flora(rnd)
    gems, gem_more = crystals()
    block = "// @grove-begin\n// Generated by tools/lobby/grove_sites.py. See there before editing.\n"
    block += vec4s("GROVE_SHROOM", top) + vec4s("GROVE_CAP", more) + vec4s("GROVE_BUSH", bushes(rnd, cliff_a, cliff_b)) + vec4s("GROVE_STONE", stones)
    block += vec4s("GROVE_CLIFF_A", cliff_a) + vec4s("GROVE_CLIFF_B", cliff_b)
    block += vec4s("GROVE_FLOWER", flowers) + vec4s("GROVE_FERN", ferns) + vec4s("GROVE_GEM", gems) + vec4s("GROVE_GEM_DIR", gem_more)
    block += vec4s("GROVE_VINE", vines(rnd)) + vec4s("GROVE_SLUG", slugs(rnd, stones)) + "// @grove-end\n"
    text = PAGE.read_text(encoding="utf-8")
    text, count = re.subn(r"// @grove-begin\n.*?// @grove-end\n", lambda _: block, text, flags=re.S)
    assert count == 1, "the page needs its generated block"
    PAGE.write_text(text, encoding="utf-8")
    print(f"grove: {len(top)} mushrooms, {len(flowers)} flowers, {len(ferns)} ferns, {len(stones)} stones, 30 slugs")


if __name__ == "__main__":
    main()
