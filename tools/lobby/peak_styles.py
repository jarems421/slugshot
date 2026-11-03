"""Write a copy of the asset library for each candidate design of the slug grove's mountain peaks, for render_plaza.py.

Only the upper half differs between them. Each mass starts about half way up the mountain and stays wide until near its top,
so the peaks read from the ground. Only the slopes, falls, ground and water are drawn, so renders are quick.

    python tools/lobby/peak_styles.py OUTDIR
"""

import math
import sys
from pathlib import Path

# Peak order: 0 middle, 1 and 2 the sides. Units are the mountain's authored ones (3.5 studs each once built at 70%); dx, dz are from
# the peak's axis. Horn: (peak, dx, dz, half width, half depth, foot, top, fat, tilt). Slab: (peak, dx, dz, half width, half depth, foot,
# top, yaw, lean, slant). Heights: the middle top is about 40 (140 studs).
HORN, SLAB = "horn", "slab"
STYLES = {
    "broad-crown": ("Broad crown", "A heavy top that stays wide, then breaks into a few sharp points close together.", [
        (HORN, 0, -7, -3, 13, 11, 15, 40, 2.6, 0.06), (HORN, 0, 8, -1, 12, 11, 15, 36, 2.8, -0.08), (HORN, 0, 0, 7, 12, 10, 15, 33, 2.4, 0.05),
        (HORN, 1, -3, 0, 11, 9, 11, 29.5, 2.6, 0.08), (HORN, 1, 6, 2, 8.5, 8, 11, 26, 2.4, -0.08),
        (HORN, 2, -1, 0, 10, 9, 9, 25, 2.5, -0.08), (HORN, 2, 5, 3, 6.5, 6, 9, 21.5, 2.2, 0.08)]),
    "great-horn": ("Great horn", "One huge leaning horn on each peak, with hard ridges running down into the slope.", [
        (HORN, 0, 0, 0, 15, 13, 13, 41, 1.8, 0.14), (HORN, 0, 10, 3, 7, 6, 16, 30, 1.8, -0.1),
        (HORN, 1, 0, 0, 12, 11, 10, 31, 1.8, -0.14), (HORN, 2, 0, 0, 11, 10, 8, 26, 1.8, 0.15)]),
    "saw-ridge": ("Saw ridge", "Each peak is a short ridge of teeth in a line, uneven in height, like an alpine crest.", [
        (HORN, 0, -12, 0, 8, 10, 16, 34, 2.1, 0.04), (HORN, 0, -4, 0, 9, 11, 15, 40, 2.2, -0.04), (HORN, 0, 4.5, 1, 8, 10, 16, 35, 2.0, 0.05), (HORN, 0, 12, 1, 7.5, 9, 16, 37.5, 2.1, -0.06),
        (HORN, 1, -6, 0, 7.5, 9, 11, 28, 2.0, 0.06), (HORN, 1, 2, 0, 8, 9, 11, 31, 2.1, -0.04), (HORN, 1, 8.5, 0, 5.5, 7, 12, 26, 1.9, 0.05),
        (HORN, 2, -3.5, 0, 7, 8, 9, 25.5, 2.0, 0.05), (HORN, 2, 4, 0, 6.5, 8, 9, 23, 2.0, -0.06)]),
    "leaning-slabs": ("Leaning slabs", "Huge tilted rectangular slabs propped against each other, ending in sharp broken corners. Closest to the rock on the slopes.", [
        (SLAB, 0, -9, 0, 6, 8, 12, 40, 0, -0.3, 1.5), (SLAB, 0, 9, 1, 6, 8, 12, 36, 0, -0.32, -1.4), (SLAB, 0, 0, 9, 6, 8, 12, 33, 0, -0.26, 1.3), (SLAB, 0, -1, -9, 5.5, 7, 12, 30, 0, -0.26, -1.2),
        (SLAB, 1, -6, 0, 5, 7, 9, 30.5, 0, -0.3, 1.4), (SLAB, 1, 6, 2, 4.5, 6, 9, 26.5, 0, -0.3, -1.3),
        (SLAB, 2, -5, 0, 4.5, 6, 7, 25.5, 0, -0.3, 1.4), (SLAB, 2, 5, 3, 4, 5, 7, 22, 0, -0.3, -1.2)]),
    "twin-saddle": ("Twin saddle", "Two big horns with a deep saddle between them, which gives a clear V from the pond.", [
        (HORN, 0, -9, 0, 10, 11, 14, 40, 2.0, 0.08), (HORN, 0, 9.5, 1, 9.5, 11, 14, 36, 2.0, -0.1),
        (HORN, 1, -5, 0, 8.5, 8, 10, 30.5, 2.0, 0.1), (HORN, 1, 5, 1, 7.5, 8, 10, 26.5, 2.0, -0.08),
        (HORN, 2, 0, 0, 10, 9, 8, 25.5, 1.9, -0.1)]),
    "chiselled": ("Chiselled block", "One big mass on each peak with its top sliced at steep angles, leaving a wide, sharp, faceted summit.", [
        (HORN, 0, 0, 0, 16, 14, 14, 41, 5.0, 0.04, 1), (HORN, 0, 11, 4, 7.5, 7, 15, 31, 4.0, -0.05, 2),
        (HORN, 1, 0, 0, 12.5, 11, 10, 31, 5.0, -0.04, 3), (HORN, 2, 0, 0, 11, 10, 8, 26, 5.0, 0.05, 4)]),
}

FUNCTIONS = """// A candidate peak mass: full width to the point where fat says it starts narrowing, then straight to a sharp tip, with unequal faces, hard ridges and broken shelves.
float bigMass(vec3 q, vec2 c, float hw, float hd, float bottom, float top, float fat, float tilt, float chisel, float kk) {
  vec3 l = q - vec3(c.x, 0.0, c.y);
  float reach = max(hw, hd)*1.8;
  float away = length(l.xz);
  if (away > reach + 2.0) return max(away - reach, max(bottom - l.y, l.y - top));
  float k1 = hash1(kk + 470.0)*6.28, k2 = hash1(kk + 471.0)*6.28;
  l.xz = rot(k1)*l.xz;
  float h = clamp((l.y - bottom)/(top - bottom), 0.0, 1.0);
  l.xz += (l.y - bottom)*vec2(tilt, 0.5*tilt);
  vec2 f = l.xz/vec2(hw, hd);
  float a = atan(f.y, f.x), r = length(f);
  float faces = 5.0 + floor(3.0*hash1(kk + 473.0));
  float warped = a + 0.4*sin(a*2.0 + k1) + 0.2*sin(a*3.0 + k2);
  float facet = abs(fract(warped*faces/6.28318 + k1) - 0.5)*2.0;
  float shelf = h + 0.05*sin(a*2.0 + k2);
  float stepped = mix(shelf, (floor(shelf*6.0) + smoothstep(0.6, 1.0, fract(shelf*6.0)))/6.0, 0.4);
  float rad = (0.76 + 0.34*facet)*(1.0 + 0.1*sin(a*3.0 + k2 + h*5.0));
  rad *= clamp((1.0 - clamp(stepped, 0.0, 1.0))*fat, 0.012, 1.0);
  float d = (r - rad)*min(hw, hd)*0.3;
  if (chisel > 0.5) {
    // Steep cuts across the top, meeting in sharp edges.
    vec3 m = q - vec3(c.x, top, c.y);
    vec3 n1 = normalize(vec3(cos(k1), 0.42, sin(k1))), n2 = normalize(vec3(cos(k1 + 2.2), 0.36, sin(k1 + 2.2))), n3 = normalize(vec3(cos(k1 + 4.3), 0.5, sin(k1 + 4.3)));
    d = max(d, max(dot(m, n1), max(dot(m, n2), dot(m, n3))));
  }
  return max(d*0.9, max(bottom - l.y, l.y - top));
}
"""


def crown(rows):
    lines = ["    // Candidate peak masses.", "    if (i < 3) {", "      vec2 at = c + lean + peakWander(1.0, sd, R, isMain);"]
    for index, row in enumerate(rows):
        kind, peak, dx, dz, hw, hd, foot, top = row[:8]
        kk = 300.0 + index*7.3
        pos = f"at + vec2({dx:.2f}, {dz:.2f})"
        if kind == HORN:
            fat, tilt = row[8:10]
            chisel = 1.0 if len(row) > 10 else 0.0
            call = f"bigMass(p, {pos}, {hw:.2f}, {hd:.2f}, {foot:.2f}, {top:.2f}, {fat:.2f}, {tilt:.3f}, {chisel:.1f}, {kk:.1f})"
        else:
            yaw, lean, slant = row[8:11]
            outward = math.atan2(dz, dx) if dx or dz else yaw
            call = f"cragBlock(p, {pos}, {outward:.3f}, {hw:.2f}, {hd:.2f}, {top:.2f}, {foot:.2f}, {lean:.2f}, {slant:.2f}, 1.0)"
        lines.append(f"      if (i == {peak}) {{ float b = {call}; if (b < best) {{ best = b; seed = {kk:.1f}; }} tips = min(tips, b); }}")
    lines += ["    }", "  }", ""]
    return "\n".join(lines)


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    page = Path("docs/art/asset-library.html").read_text(encoding="utf-8").replace("\r\n", "\n")
    start = page.index("    // Each big peak ends in one to three wide, sharp tips")
    end = page.index("  return best;", start)
    anchor = "// Rock layers tilt and wave round each mass"
    # Everything further up the mountain now reaches well above its old limit.
    limit = "p.y > H + 3.0*tierH + 0.13*R"
    assert page.count(limit) == 1 and page.count(anchor) == 1
    early = "  // Churned water heaped up where the falls land"
    assert page.count(early) == 1
    # From where a player stands by the pond, and level with the upper half.
    views = {'{ name: "Whole area", bright: [0.3, 0.95, 0.75], figure: [-3.5, 0.15, -9.5], camera: { target: [0, 15, 12], dist: 54, pitch: 0.11 } }':
             '{ name: "Whole area", bright: [0.3, 0.95, 0.75], figure: [0, -100, 0], camera: { target: [0, 18, 20], dist: 38, pitch: 0.04 } }',
             '{ name: "Arriving", bright: [0.3, 0.95, 0.75], figure: [0, -100, 0], camera: { target: [0, 12, 4], dist: 31, pitch: -0.26 } }':
             '{ name: "Arriving", bright: [0.3, 0.95, 0.75], figure: [0, -100, 0], camera: { target: [0, 14, 6], dist: 30, pitch: -0.3 } }'}
    for old, new in views.items():
        assert page.count(old) == 1, old
    for key, (_name, _about, rows) in STYLES.items():
        text = page[:start] + crown(rows) + page[end:]
        text = text.replace(limit, "p.y > H + 18.0").replace(anchor, FUNCTIONS + anchor).replace(early, "  return res;\n" + early)
        for old, new in views.items():
            text = text.replace(old, new)
        (out/f"{key}.html").write_text(text, encoding="utf-8")
        print(key)


if __name__ == "__main__":
    main()
