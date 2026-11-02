"""Generate the Sky Well's ceiling at fixed coordinates, between `// @ceiling-begin` and `// @ceiling-end` in the page.

Plain numbers, not the shader's hash, so every shader program agrees on where things are. Owner, 2026-11-01: the eye and its
perimeter must look clearly separate from the cavern ceiling. Owner, 2026-11-02: the black moat and the glowing lines through
it looked sloppy. So from the middle outward there is a collar of small rocks and crystals round the storm, a crown of carved
stone, two courses of cut rune slabs as the divide, the natural cave ceiling, and a curtain of hanging rock, rune stones,
crystals and vines where the ceiling meets the wall.
Units are the Sky Well concept's: 1 unit = 10 studs.

    python tools/lobby/ceiling_sites.py
"""

import math
import random
import re
from pathlib import Path

PAGE = Path("docs/art/asset-library.html")
WELL_LOW = 26.0
CROWN_N = 26
# Radius, half depth, count, offset in slabs, how far it hangs below the ceiling. The first is paving behind the crown.
COURSES = ((14.85, 2.0, 26, 0.0, 0.16), (17.95, 0.95, 30, 0.0, 0.34), (19.95, 0.87, 36, 0.5, 0.62))
PENDANTS, PENDANT_R, PENDANT_DROP = 12, 27.7, 5.2
CAVE_FROM = 21.5
CAVE_TO = 30.5


def smoothstep(a, b, x):
    t = min(max((x - a)/(b - a), 0.0), 1.0)
    return t*t*(3 - 2*t)


def cave_bump(x, z):
    """The same shape as ceilingBump below, without the moat: how far the natural ceiling rises (+) or hangs (-)."""
    far = smoothstep(20.8, 26.0, math.hypot(x, z))
    b = 1.5*math.sin(x*0.23 + 1.3)*math.sin(z*0.19 - 0.7)
    b += 0.9*math.sin(x*0.47 - z*0.31 + 2.1)*math.sin(z*0.53 + x*0.17)
    b += 0.4*math.sin(x*1.07 + z*0.83)*math.sin(z*1.21 - x*0.59)
    b -= 0.9*abs(math.sin(x*0.37 + z*0.29 + 0.6))
    # The ceiling curves down to meet the wall.
    return b*far - 1.8*smoothstep(25.5, 30.0, math.hypot(x, z))


def crown():
    lines = []
    step = 2*math.pi/CROWN_N
    for k in range(CROWN_N):
        ang = (k + 0.5)*step
        c = (math.cos(ang), math.sin(ang))
        long_slab = k % 2 == 0
        radius, half = (14.7, 2.1) if long_slab else (14.0, 1.45)
        depth = 2.05 if long_slab else 1.15
        wide = radius*step*(0.47 if long_slab else 0.36)
        slant = 0.16*(1 if k % 4 < 2 else -1)
        cut = "1.0" if k % 3 else "-1.0"
        lines.append(f"    b = rockBlock(p, vec2({c[0]*radius:.3f}, {c[1]*radius:.3f}), {ang:.3f}, {half:.2f}, {wide:.2f}, "
                     f"WELL_LOW + 0.7, WELL_LOW - {depth:.2f}, {slant:.2f}, {cut});\n    if (b < res.x) res = vec2(b, 1.05);")
    return "\n".join(lines)


def spires(rnd):
    lines = []
    placed = []
    tries = 0
    while len(placed) < 66 and tries < 6000:
        tries += 1
        r = math.sqrt(rnd.uniform(CAVE_FROM**2, CAVE_TO**2))
        ang = rnd.uniform(0, 2*math.pi)
        x, z = r*math.cos(ang), r*math.sin(ang)
        size = rnd.random()**2.4
        length = 1.0 + 4.6*size
        if any(math.hypot(x - a, z - b) < 0.9 + 0.5*(length + other)*0.35 for a, b, other in placed):
            continue
        placed.append((x, z, length))
        base = WELL_LOW + cave_bump(x, z) + 0.5
        width = length*rnd.uniform(0.2, 0.36)
        clear = r - width*1.5 > 21.1
        if rnd.random() < 0.62:
            dx, dz = rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2)
            n = math.sqrt(dx*dx + dz*dz + 1)
            (lines if clear else []).append(f"    b = sharpShard(p, vec3({x:.3f}, {base:.3f}, {z:.3f}), vec3({dx/n:.3f}, {-1/n:.3f}, {dz/n:.3f}), "
                         f"{length:.2f}, {width:.2f}, {rnd.uniform(0, 6.28):.2f});\n    if (b < res.x) res = vec2(b, 1.1);")
        else:
            reach = length + width + 1.0
            (lines if clear else []).append(f"    if (length(p.xz - vec2({x:.3f}, {z:.3f})) < {reach:.2f}) {{\n"
                         f"      b = rockBlock(p, vec2({x:.3f}, {z:.3f}), {rnd.uniform(0, 3.14):.2f}, {width:.2f}, {width*rnd.uniform(0.6, 1.1):.2f}, "
                         f"{base:.3f}, {base - length:.3f}, {rnd.uniform(-0.5, 0.5):.2f}, {rnd.choice(('1.0', '-1.0'))});\n"
                         f"      if (b < res.x) res = vec2(b, 1.1);\n    }}")
    return "\n".join(lines), placed


def crystals(rnd, taken):
    # Clusters in the library's own crystal colours: cyan, violet, amber, rose, emerald, frost.
    lines = []
    centres = []
    design = 0
    tries = 0
    order = [2, 3, 4, 0, 1, 5]
    while len(centres) < 15 and tries < 4000:
        tries += 1
        r = math.sqrt(rnd.uniform((CAVE_FROM + 0.8)**2, CAVE_TO**2))
        ang = rnd.uniform(0, 2*math.pi)
        x, z = r*math.cos(ang), r*math.sin(ang)
        if any(math.hypot(x - a, z - b) < 7.0 for a, b in centres):
            continue
        if any(math.hypot(x - a, z - b) < 1.6 + other*0.3 for a, b, other in taken):
            continue
        centres.append((x, z))
        colour = order[design % len(order)]
        design += 1
        scale = rnd.uniform(0.7, 1.25)
        guard = 7.5*scale
        lines.append(f"  if (length(p.xz - vec2({x:.3f}, {z:.3f})) < {guard:.2f}) {{")
        for i in range(rnd.randint(4, 6)):
            ox, oz = rnd.uniform(-0.9, 0.9)*scale, rnd.uniform(-0.9, 0.9)*scale
            base = WELL_LOW + cave_bump(x + ox, z + oz) + 0.35
            dx, dz = ox*0.5 + rnd.uniform(-0.2, 0.2), oz*0.5 + rnd.uniform(-0.2, 0.2)
            n = math.sqrt(dx*dx + dz*dz + 1)
            size = rnd.random()**1.6
            lines.append(f"    d = crystalDir(p, vec3({x + ox:.3f}, {base:.3f}, {z + oz:.3f}), vec3({dx/n:.3f}, {-1/n:.3f}, {dz/n:.3f}), "
                         f"{(1.1 + 2.9*size)*scale:.2f}, {(0.26 + 0.42*size)*scale:.2f});\n    if (d < res.x) res = vec2(d, {18.0 + colour*0.05:.2f});")
        lines.append("  }")
    return "\n".join(lines)


def vines(placed):
    rnd = random.Random(97)
    lines = []
    groups = []
    count = 0
    tries = 0
    while len(groups) < 17 and tries < 8000:
        tries += 1
        r = math.sqrt(rnd.uniform(21.3**2, 30.6**2))
        ang = rnd.uniform(0, 2*math.pi)
        x, z = r*math.cos(ang), r*math.sin(ang)
        if any(math.hypot(x - a, z - b) < 5.6 for a, b in groups):
            continue
        groups.append((x, z))
        for _ in range(rnd.randint(2, 3)):
            vx, vz = x + rnd.uniform(-1.6, 1.6), z + rnd.uniform(-1.6, 1.6)
            if any(math.hypot(vx - a, vz - b) < 0.5 + other*0.28 for a, b, other in placed):
                continue
            top = WELL_LOW + cave_bump(vx, vz) + 0.15
            lines.append(f"  rockStrand(p, vec3({vx:.3f}, {top:.3f}, {vz:.3f}), vec3({vx:.3f}, {top + 0.5:.3f}, {vz:.3f}), "
                         f"{rnd.uniform(2.6, 7.0):.2f}, {rnd.uniform(0, 6.28):.2f}, res);")
            count += 1
    # A few trailing from the crown's slabs. The rune slabs beyond stay bare, which keeps the eye separate.
    step = 2*math.pi/CROWN_N
    for k in range(0, CROWN_N, 2):
        if rnd.random() < 0.45:
            continue
        ang, radius = (k + 0.5)*step, rnd.uniform(13.4, 16.2)
        vx, vz = radius*math.cos(ang), radius*math.sin(ang)
        top = WELL_LOW - 1.55
        lines.append(f"  rockStrand(p, vec3({vx:.3f}, {top:.3f}, {vz:.3f}), vec3({vx:.3f}, {top + 0.5:.3f}, {vz:.3f}), "
                     f"{rnd.uniform(1.8, 4.2):.2f}, {rnd.uniform(0, 6.28):.2f}, res);")
        count += 1
    # Thick along the wall, in among the hanging rock.
    ang = 0.05
    while ang < 2*math.pi - 0.1:
        for _ in range(rnd.randint(2, 3)):
            a, r = ang + rnd.uniform(-0.04, 0.04), rnd.uniform(26.9, 29.4)
            vx, vz = r*math.cos(a), r*math.sin(a)
            top = WELL_LOW + cave_bump(vx, vz) + 0.15
            lines.append(f"  rockStrand(p, vec3({vx:.3f}, {top:.3f}, {vz:.3f}), vec3({vx:.3f}, {top + 0.5:.3f}, {vz:.3f}), "
                         f"{rnd.uniform(2.8, 7.2):.2f}, {rnd.uniform(0, 6.28):.2f}, res);")
            count += 1
        ang += rnd.uniform(0.5, 0.8)
    return "\n".join(lines), count


def pendant_angle(k):
    return (k + 0.5)*2*math.pi/PENDANTS


def pendants():
    """Big stones hanging at even spacing round the border, each with a rune facing the hub: the new thing that makes it pop."""
    lines = []
    for k in range(PENDANTS):
        ang = pendant_angle(k)
        x, z = PENDANT_R*math.cos(ang), PENDANT_R*math.sin(ang)
        top = WELL_LOW + cave_bump(x, z) + 0.8
        lines.append(f"    if (length(p.xz - vec2({x:.3f}, {z:.3f})) < 4.0) {{\n"
                     f"      b = rockBlock(p, vec2({x:.3f}, {z:.3f}), {ang:.3f}, 0.8, 1.45, {top:.3f}, WELL_LOW - {PENDANT_DROP}, "
                     f"{0.14 if k % 2 else -0.14}, {'1.0' if k % 3 else '-1.0'});\n"
                     f"      if (b < res.x) res = vec2(b, 1.18);\n    }}")
    return "\n".join(lines)


def curtain():
    """Groups of hanging rock along the wall, breaking up the line where the ceiling ends. Clear of the rune stones."""
    rnd = random.Random(211)
    lines = []
    count = 0
    ang = rnd.uniform(0, 0.2)
    while ang < 2*math.pi - 0.1:
        members = rnd.randint(3, 6)
        heavy = rnd.uniform(0.65, 1.2)
        for i in range(members):
            a, r = ang + i*0.04 + rnd.uniform(-0.012, 0.012), rnd.uniform(27.3, 30.0)
            if any(abs(math.atan2(math.sin(a - pendant_angle(k)), math.cos(a - pendant_angle(k))))*r < 2.7 for k in range(PENDANTS)):
                continue
            x, z = r*math.cos(a), r*math.sin(a)
            base = WELL_LOW + cave_bump(x, z) + 0.6
            length = (1.4 + 3.8*rnd.random()**1.5)*heavy
            width = length*rnd.uniform(0.24, 0.38)
            if rnd.random() < 0.6:
                dx, dz = rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15)
                n = math.sqrt(dx*dx + dz*dz + 1)
                lines.append(f"    b = sharpShard(p, vec3({x:.3f}, {base:.3f}, {z:.3f}), vec3({dx/n:.3f}, {-1/n:.3f}, {dz/n:.3f}), "
                             f"{length:.2f}, {width:.2f}, {rnd.uniform(0, 6.28):.2f});\n    if (b < res.x) res = vec2(b, 1.12);")
            else:
                reach = length + width + 1.0
                lines.append(f"    if (length(p.xz - vec2({x:.3f}, {z:.3f})) < {reach:.2f}) {{\n"
                             f"      b = rockBlock(p, vec2({x:.3f}, {z:.3f}), {rnd.uniform(0, 3.14):.2f}, {width:.2f}, {width*rnd.uniform(0.6, 1.1):.2f}, "
                             f"{base:.3f}, {base - length:.3f}, {rnd.uniform(-0.5, 0.5):.2f}, {rnd.choice(('1.0', '-1.0'))});\n"
                             f"      if (b < res.x) res = vec2(b, 1.12);\n    }}")
            count += 1
        ang += members*0.04 + rnd.uniform(0.03, 0.11)
    return "\n".join(lines), count


def collar_rocks():
    """Small rocks packed round the storm's edge, under its rim, so they never poke through it."""
    rnd = random.Random(313)
    lines = []
    for k in range(56):
        ang = (k + rnd.uniform(-0.3, 0.3))*2*math.pi/56
        r = rnd.uniform(9.2, 10.7)
        x, z = r*math.cos(ang), r*math.sin(ang)
        size = 0.26 + 0.34*rnd.random()**1.5
        y = rnd.uniform(25.7, 27.2)
        lines.append(f"    b = rockBlock(p, vec2({x:.3f}, {z:.3f}), {rnd.uniform(0, 3.14):.2f}, {size:.2f}, {size*rnd.uniform(0.7, 1.0):.2f}, "
                     f"{y + size*1.1:.3f}, {y - size:.3f}, {rnd.uniform(-0.5, 0.5):.2f}, {rnd.choice(('1.0', '-1.0'))});\n"
                     f"    if (b < res.x) res = vec2(b, 1.0);")
    return "\n".join(lines)


def collar_crystals():
    """Small crystals in the storm's own colours, growing out of the collar and down."""
    rnd = random.Random(419)
    lines = []
    for k in range(46):
        ang = (k + rnd.uniform(-0.35, 0.35))*2*math.pi/46
        r = rnd.uniform(9.5, 10.5)
        lean, side = rnd.uniform(0.35, 1.0), rnd.uniform(-0.4, 0.4)
        dx, dz = -math.cos(ang)*lean - math.sin(ang)*side, -math.sin(ang)*lean + math.cos(ang)*side
        n = math.sqrt(dx*dx + dz*dz + 1)
        colour = (0, 1, 5, 0, 1)[k % 5]
        size = rnd.random()**1.5
        lines.append(f"  if (length(p.xz) < 12.5) {{\n    d = crystalDir(p, vec3({r*math.cos(ang):.3f}, {rnd.uniform(26.2, 27.3):.3f}, {r*math.sin(ang):.3f}), "
                     f"vec3({dx/n:.3f}, {-1/n:.3f}, {dz/n:.3f}), {0.8 + 1.0*size:.2f}, {0.11 + 0.11*size:.2f});\n"
                     f"    if (d < res.x) res = vec2(d, {18.0 + colour*0.05:.2f});\n  }}")
    return "\n".join(lines)


def border_crystals():
    """Clusters of small crystals along the wall, in all the cavern's colours."""
    rnd = random.Random(523)
    lines = []
    order = [0, 3, 2, 1, 4, 5]
    ang = 0.2
    index = 0
    while ang < 2*math.pi - 0.1:
        r = rnd.uniform(26.4, 29.0)
        x, z = r*math.cos(ang), r*math.sin(ang)
        colour = order[index % len(order)]
        index += 1
        lines.append(f"  if (length(p.xz - vec2({x:.3f}, {z:.3f})) < 5.5) {{")
        for _ in range(rnd.randint(4, 6)):
            ox, oz = rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8)
            base = WELL_LOW + cave_bump(x + ox, z + oz) + 0.3
            dx, dz = ox*0.5 + rnd.uniform(-0.2, 0.2), oz*0.5 + rnd.uniform(-0.2, 0.2)
            n = math.sqrt(dx*dx + dz*dz + 1)
            size = rnd.random()**1.5
            lines.append(f"    d = crystalDir(p, vec3({x + ox:.3f}, {base:.3f}, {z + oz:.3f}), vec3({dx/n:.3f}, {-1/n:.3f}, {dz/n:.3f}), "
                         f"{1.0 + 1.5*size:.2f}, {0.15 + 0.17*size:.2f});\n    if (d < res.x) res = vec2(d, {18.0 + colour*0.05:.2f});")
        lines.append("  }")
        ang += rnd.uniform(0.2, 0.36)
    return "\n".join(lines)


def main():
    rnd = random.Random(71)
    spire_code, placed = spires(rnd)
    curtain_code, curtain_count = curtain()
    vine_code, vine_count = vines(placed)
    block = f"""// @ceiling-begin
// Generated by tools/lobby/ceiling_sites.py. See there before editing.
const float CROWN_N = {CROWN_N}.0;
float ceilingBump(vec2 x, float rr) {{
  float far = smoothstep(20.8, 26.0, rr);
  float b = 1.5*sin(x.x*0.23 + 1.3)*sin(x.y*0.19 - 0.7);
  b += 0.9*sin(x.x*0.47 - x.y*0.31 + 2.1)*sin(x.y*0.53 + x.x*0.17);
  b += 0.4*sin(x.x*1.07 + x.y*0.83)*sin(x.y*1.21 - x.x*0.59);
  b -= 0.9*abs(sin(x.x*0.37 + x.y*0.29 + 0.6));
  // The ceiling curves down to meet the wall.
  return b*far - 1.8*smoothstep(25.5, 30.0, rr);
}}
// One course of cut slabs: fitted stones with a clean joint between them, each hanging a slightly different amount.
float ringCourse(vec3 p, float rr, float ang, float radius, float halfDepth, float count, float offset, float hang) {{
  float each = 6.28318/count, k0 = floor(mod(ang, 6.28318)/each - offset), best = 1e3;
  for (int j = -1; j <= 1; j++) {{
    float k = k0 + float(j), ca = (k + offset + 0.5)*each, da = atan(sin(ang - ca), cos(ang - ca));
    float bottom = WELL_LOW - hang - 0.06*sin(k*2.3), top = WELL_LOW + 0.6;
    vec3 q = vec3(rr*cos(da) - radius, p.y - (top + bottom)*0.5, rr*sin(da));
    best = min(best, sdBox(q, vec3(halfDepth - 0.05, (top - bottom)*0.5 - 0.05, radius*each*0.5 - 0.14)) - 0.05);
  }}
  return best;
}}
void ceilingFeatures(vec3 p, float rr, float ang, inout vec2 res) {{
  if (p.y < 17.0) return;
  float b;
  if (rr > 11.0 && rr < 18.5 && p.y > WELL_LOW - 3.5) {{
{crown()}
  }}
  // Small rocks packed round the storm's edge.
  if (rr > 8.0 && rr < 12.0 && p.y > 24.0 && p.y < 29.0) {{
{collar_rocks()}
  }}
  // The divide between the eye and the cavern: two courses of cut slabs.
  if (rr > 12.4 && rr < 21.2 && p.y > WELL_LOW - 1.4) {{
{"".join(f"    b = ringCourse(p, rr, ang, {r}, {h}, {n}.0, {o}, {d});{chr(10)}    if (b < res.x) res = vec2(b, 1.17);{chr(10)}" for r, h, n, o, d in COURSES)}  }}
  // The border: rune stones and a curtain of hanging rock along the wall.
  if (rr > 25.0) {{
{pendants()}
{curtain_code}
  }}
  if (rr > {CAVE_FROM - 2.5}) {{
{spire_code}
  }}
}}
void ceilingCrystals(vec3 p, inout vec2 res) {{
  float d;
{crystals(rnd, placed)}
{collar_crystals()}
{border_crystals()}
}}
void ceilingVines(vec3 p, inout vec2 res) {{
{vine_code}
}}
// @ceiling-end
"""
    text = PAGE.read_text(encoding="utf-8")
    if "// @ceiling-begin" in text:
        text, count = re.subn(r"// @ceiling-begin\n.*?// @ceiling-end\n", lambda _: block, text, flags=re.S)
        assert count == 1
    else:
        marker = "vec2 skyWell(vec3 p) {"
        assert text.count(marker) == 1
        text = text.replace(marker, block + marker)
    PAGE.write_text(text, encoding="utf-8")
    print(f"ceiling: {len(placed)} spires, {curtain_count} border rocks, {block.count('crystalDir(')} crystals, {vine_count} vines")


if __name__ == "__main__":
    main()
