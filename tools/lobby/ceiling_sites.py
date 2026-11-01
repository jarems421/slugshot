"""Generate the Sky Well's ceiling at fixed coordinates, between `// @ceiling-begin` and `// @ceiling-end` in the page.

Plain numbers, not the shader's hash, so every shader program agrees on where things are. Owner, 2026-11-01: the eye and its
perimeter must look clearly separate from the cavern ceiling. So from the middle outward there is a crown of carved stone, a
glowing ring, a dark recessed moat that nothing crosses, and only then the natural cave ceiling with its spires and crystals.
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
MOAT_R, RING_R = 18.4, 20.3
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
    return b*far


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
        if rnd.random() < 0.62:
            dx, dz = rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2)
            n = math.sqrt(dx*dx + dz*dz + 1)
            lines.append(f"    b = sharpShard(p, vec3({x:.3f}, {base:.3f}, {z:.3f}), vec3({dx/n:.3f}, {-1/n:.3f}, {dz/n:.3f}), "
                         f"{length:.2f}, {width:.2f}, {rnd.uniform(0, 6.28):.2f});\n    if (b < res.x) res = vec2(b, 1.1);")
        else:
            reach = length + width + 1.0
            lines.append(f"    if (length(p.xz - vec2({x:.3f}, {z:.3f})) < {reach:.2f}) {{\n"
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
    # A few trailing from the crown's slabs. The moat between stays bare, which keeps the eye separate.
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
    return "\n".join(lines), count


def main():
    rnd = random.Random(71)
    spire_code, placed = spires(rnd)
    vine_code, vine_count = vines(placed)
    block = f"""// @ceiling-begin
// Generated by tools/lobby/ceiling_sites.py. See there before editing.
const float CROWN_N = {CROWN_N}.0, MOAT_R = {MOAT_R}, RING_R = {RING_R};
float ceilingBump(vec2 x, float rr) {{
  float far = smoothstep(20.8, 26.0, rr);
  float b = 1.5*sin(x.x*0.23 + 1.3)*sin(x.y*0.19 - 0.7);
  b += 0.9*sin(x.x*0.47 - x.y*0.31 + 2.1)*sin(x.y*0.53 + x.x*0.17);
  b += 0.4*sin(x.x*1.07 + x.y*0.83)*sin(x.y*1.21 - x.x*0.59);
  b -= 0.9*abs(sin(x.x*0.37 + x.y*0.29 + 0.6));
  // The moat: the ceiling rises away into a dark recess around the crown.
  float m = (rr - MOAT_R)/1.5;
  return b*far + 1.6*exp(-m*m);
}}
void ceilingFeatures(vec3 p, float rr, float ang, inout vec2 res) {{
  if (p.y < 17.0) return;
  float b;
  if (rr > 11.0 && rr < 18.5 && p.y > WELL_LOW - 3.5) {{
{crown()}
    // A glowing circlet round the crown's underside, which can be seen from anywhere below.
    b = length(vec2(rr - 14.1, p.y - WELL_LOW + 1.12)) - 0.12;
    if (b < res.x) res = vec2(b, 1.17);
  }}
  // The glowing ring on the moat's outer lip: the line between the eye's perimeter and the cavern.
  if (rr > 18.5 && rr < 22.0 && p.y > WELL_LOW - 2.0) {{
    float ringR = RING_R + 0.3*sin(ang*7.0 + 0.6) + 0.14*sin(ang*17.0);
    float m = (ringR - MOAT_R)/1.5;
    float breaks = sin(ang*5.0 + 1.0) + 0.7*sin(ang*11.0 + 0.3) + 0.4*sin(ang*23.0);
    b = length(vec2(rr - ringR, p.y - WELL_LOW - 1.6*exp(-m*m))) - 0.17*smoothstep(-0.9, -0.2, breaks);
    if (b < res.x) res = vec2(b, 1.17);
  }}
  if (rr > {CAVE_FROM - 2.5}) {{
{spire_code}
  }}
}}
void ceilingCrystals(vec3 p, inout vec2 res) {{
  float d;
{crystals(rnd, placed)}
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
    print(f"ceiling: {len(placed)} spires, {block.count('crystalDir(')} crystals, {vine_count} vines")


if __name__ == "__main__":
    main()
