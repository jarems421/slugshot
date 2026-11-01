"""Anchor the rock wall's dressing (crystals and mushrooms) onto the actual rock surface.

Ray-marches each dressing spot onto the wall's `wallMass` surface on the GPU, using the page's own
shader functions, and rewrites the generated block between `// @wall-dressing-begin` and
`// @wall-dressing-end` in the page. Re-run after changing the wall's rock masses, cracks or spot rules.
Owner, 2026-11-01: no wall mushroom or crystal may hover off the rock.

Two kinds of layout are written:
- v6, the approved anchors, frozen (texture option 1, unchanged);
- walls A-D (owner round 9: "every corner has something"): the wall face is split into six regions and each
  gets a crystal cluster or a mushroom cluster, with tiny mushrooms scattered across all of them. Each wall's
  layout is drawn from its own seed and measured on that wall's cracked surface, so walls never repeat.

    python tools/lobby/wall_sites.py [--page docs/art/asset-library.html]
Requires moderngl and numpy.
"""

import argparse
import random
import re
import sys
from pathlib import Path

import moderngl
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from render_library import dump_renders, extract  # noqa: E402

# v6 as approved: its anchors are frozen exactly as measured for the approved design and the first Roblox build.
# The rock surface moved slightly after they were measured (re-probing shifts some by up to about 0.2 studs), so
# they are kept verbatim rather than re-measured; walls A-D are measured on today's surface.
V6_FROZEN = [
    "wallCrystal(p, vec3(0.950, 0.550, -3.415), vec3(0.787, 0.072, -0.613), 0.0, cr);",
    "wallCrystal(p, vec3(-4.050, 6.450, 0.159), vec3(-0.182, 0.714, -0.676), 2.0, cr);",
    "wallCrystal(p, vec3(-3.800, 6.500, 0.146), vec3(-0.177, 0.720, -0.671), 3.0, cr);",
    "wallCrystal(p, vec3(7.300, 3.800, -1.837), vec3(-0.423, 0.179, -0.888), 4.0, cr);",
    "wallShroom(p, vec3(-6.700, 2.000, -1.835), vec3(0.521, -0.189, -0.832), 5.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-6.300, 2.400, -1.617), vec3(0.655, -0.123, -0.745), 6.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-6.000, 2.000, -1.454), vec3(-0.675, 0.102, -0.730), 7.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(3.550, 5.150, -1.757), vec3(-0.064, 0.829, -0.556), 8.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(5.000, 5.050, -1.646), vec3(0.214, 0.775, -0.595), 10.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-1.500, 9.300, -1.061), vec3(0.141, 0.325, -0.935), 11.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-1.100, 9.600, -0.831), vec3(0.315, 0.429, -0.847), 12.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-0.800, 9.300, -0.836), vec3(0.434, 0.333, -0.837), 13.0, 0.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-2.200, 4.600, -1.227), vec3(-0.089, 0.406, -0.910), 14.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(6.350, 1.600, -0.979), vec3(0.182, -0.130, -0.975), 15.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(2.750, 7.450, -0.440), vec3(0.563, -0.199, -0.802), 16.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-7.600, 8.000, -1.027), vec3(-0.440, -0.009, -0.898), 17.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(0.800, 3.200, -2.304), vec3(0.227, 0.048, -0.973), 18.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-5.050, 9.750, -0.476), vec3(0.485, 0.547, -0.682), 19.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(-1.800, 4.800, -1.462), vec3(-0.575, 0.405, -0.711), 20.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(7.200, 2.150, -1.771), vec3(-0.440, -0.193, -0.877), 21.0, 1.0, stems, caps, capIdx);",
    "wallShroom(p, vec3(3.000, 7.800, -0.359), vec3(0.546, -0.199, -0.814), 22.0, 1.0, stems, caps, capIdx);",
]
# Walls A-D: six regions of the front face (x0, x1, y0, y1), top row first.
REGIONS = [(-9.5, -3.2, 7.0, 11.5), (-3.2, 3.2, 7.5, 12.0), (3.2, 9.5, 7.0, 11.5),
           (-10.0, -3.4, 1.0, 6.5), (-3.4, 3.4, 1.0, 6.5), (3.4, 10.0, 1.0, 6.5)]
WALL_KEYS = ["rock-wall-4", "rock-wall-5", "rock-wall-6", "rock-wall-7"]  # library options A-D (cracks + texture)

PROBE_MAIN = """
uniform vec2 uSpots[%d];
out vec4 fragColor;
void main() {
  int i = int(gl_FragCoord.x);
  int row = int(gl_FragCoord.y);
  vec2 s = uSpots[i];
  float z = -8.0, hit = 0.0;
  for (int k = 0; k < 400; k++) {
    float d = wallMass(vec3(s, z));
    if (d < 0.0005) { hit = 1.0; break; }
    z += max(d*0.6, 0.004);
    if (z > 5.0) break;
  }
  vec3 p = vec3(s, z);
  const float e = 0.01;
  vec3 n = normalize(vec3(wallMass(p + vec3(e, 0, 0)) - wallMass(p - vec3(e, 0, 0)),
                          wallMass(p + vec3(0, e, 0)) - wallMass(p - vec3(0, e, 0)),
                          wallMass(p + vec3(0, 0, e)) - wallMass(p - vec3(0, 0, e))));
  fragColor = row == 0 ? vec4(p, hit) : vec4(n, 0.0);
}
"""
BATCH = 200


class Prober:
    def __init__(self, page: str):
        fs = re.search(r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>', page, re.S).group(1)
        prefix = fs[:fs.rindex("\nvoid main() {")]
        prefix = prefix.replace("precision highp float;", "precision highp float;\n#define ASSET 0", 1)
        self.ctx = moderngl.create_standalone_context()
        self.prog = self.ctx.program(
            vertex_shader="#version 330\nin vec2 aPos; void main(){ gl_Position = vec4(aPos, 0.0, 1.0); }",
            fragment_shader="#version 330\n" + prefix + PROBE_MAIN % BATCH)
        vbo = self.ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
        self.vao = self.ctx.vertex_array(self.prog, [(vbo, "2f", "aPos")])
        self.fbo = self.ctx.framebuffer(color_attachments=[self.ctx.texture((BATCH, 2), 4, dtype="f4")])
        offsets = [(dx*0.15, dy*0.15) for dx in range(-5, 6) for dy in range(-5, 6)]
        self.offsets = sorted(offsets, key=lambda o: o[0]**2 + o[1]**2)

    def wall(self, layers, seed, mask):
        """Measure on one wall variant's surface (its cracks change the rock)."""
        for name, value in (("uRockLayers", tuple(layers)), ("uWallSeed", float(seed)), ("uCrackMask", float(mask))):
            if name in self.prog:
                self.prog[name].value = value

    def probe(self, points):
        out = []
        for k in range(0, len(points), BATCH):
            chunk = points[k:k + BATCH]
            padded = chunk + [(0.0, 0.0)]*(BATCH - len(chunk))
            self.prog["uSpots"].write(np.array(padded, dtype="f4").tobytes())
            self.fbo.use()
            self.vao.render()
            res = np.frombuffer(self.fbo.read(components=4, dtype="f4"), dtype="f4").reshape(2, BATCH, 4)
            out += [(res[0, j], res[1, j]) for j in range(len(chunk))]
        return out

    def anchor(self, x, y):
        """Nearest point around (x, y) that faces forward and is not an overhang underside, so dressing never
        lands in a gap between rock masses or hangs upside down. None if there is no such surface."""
        cands = [(x + dx, y + dy) for dx, dy in self.offsets]
        for p, n in self.probe(cands):
            if p[3] > 0.5 and n[2] < -0.55 and n[1] > -0.2 and p[2] < 0.2:
                return p, n
        return None


def call(kind, p, n, seed):
    sv = f"vec3({p[0]:.3f}, {p[1]:.3f}, {p[2]:.3f})"
    nv = f"vec3({n[0]:.3f}, {n[1]:.3f}, {n[2]:.3f})"
    if kind == "crystal":
        return f"wallCrystal(p, {sv}, {nv}, {seed:.1f}, cr);"
    tiny = "1.0" if kind == "tiny" else "0.0"
    return f"wallShroom(p, {sv}, {nv}, {seed:.1f}, {tiny}, stems, caps, capIdx);"


def wall_layout(prober, seed):
    """Every region gets a crystal or mushroom cluster (three of each, shuffled), plus tiny mushrooms everywhere."""
    rng = random.Random(seed*7919)
    kinds = ["crystal"]*3 + ["shroom"]*3
    rng.shuffle(kinds)
    placed, lines = [], []
    n_seed = seed*100.0

    def free(x, y, gap):
        return all((x - px)**2 + (y - py)**2 >= gap*gap for px, py in placed)

    def put(kind, x, y, gap):
        nonlocal n_seed
        if not free(x, y, gap):
            return None
        hit = prober.anchor(x, y)
        if hit is None or not free(float(hit[0][0]), float(hit[0][1]), gap):
            return None
        p, n = hit
        placed.append((float(p[0]), float(p[1])))
        lines.append(call(kind, p, n, n_seed))
        n_seed += 1.0
        return p

    for (x0, x1, y0, y1), kind in zip(REGIONS, kinds):
        for _ in range(16):
            x = rng.uniform(x0 + 0.15*(x1 - x0), x1 - 0.15*(x1 - x0))
            y = rng.uniform(y0 + 0.15*(y1 - y0), y1 - 0.15*(y1 - y0))
            first = put(kind, x, y, 1.6)
            if first is None:
                continue
            if kind == "crystal":
                for _ in range(rng.choice([1, 2])):  # clusters of two or three crystals
                    for _ in range(8):
                        a = rng.uniform(0, 2*np.pi)
                        if put("crystal", first[0] + 0.45*np.cos(a), first[1] + 0.45*np.sin(a), 0.32) is not None:
                            break
            else:
                for a in (2.1, 4.2):  # three mushrooms in a loose triangle
                    put("shroom", first[0] + 0.4*np.cos(a + rng.uniform(-0.3, 0.3)),
                        first[1] + 0.4*np.sin(a + rng.uniform(-0.3, 0.3)), 0.3)
            break
        else:
            print(f"wall {seed}: region {(x0, x1, y0, y1)} found no surface for its {kind} cluster")
    for x0, x1, y0, y1 in REGIONS + [rng.choice(REGIONS), rng.choice(REGIONS)]:
        for _ in range(12):
            if put("tiny", rng.uniform(x0, x1), rng.uniform(y0, y1), 0.9) is not None:
                break
    crystals = sum(1 for ln in lines if ln.startswith("wallCrystal"))
    print(f"wall {seed}: {crystals} crystals, {len(lines) - crystals} mushrooms (clusters and tiny)")
    return lines


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="docs/art/asset-library.html")
    args = ap.parse_args()
    path = Path(args.page)
    page = path.read_text(encoding="utf-8")
    prober = Prober(page)
    _, items = dump_renders(extract(page, r'<script id="lib">(.*?)</script>'), set(WALL_KEYS))
    walls = {it["key"]: it["frames"][0] for it in items}

    out = ["  // Generated by tools/lobby/wall_sites.py: each spot sits on the measured rock surface.",
           "  if (uRockLayers.x + uRockLayers.y < 0.5) {",
           "    // v6 as approved."]
    out += ["    " + ln for ln in V6_FROZEN]
    for i, key in enumerate(WALL_KEYS):
        u = walls[key]
        seed = int(u["uWallSeed"][0])
        prober.wall(u["uRockLayers"], seed, u["uCrackMask"][0])
        out.append("  } else if (uWallSeed < %.1f) {" % (seed + 0.5) if i < len(WALL_KEYS) - 1 else "  } else {")
        out.append(f"    // Wall {'ABCD'[i]}: one cluster per region, tiny mushrooms everywhere.")
        out += ["    " + ln for ln in wall_layout(prober, seed)]
    out.append("  }")
    block = "\n".join(out)
    page = re.sub(r"(  // @wall-dressing-begin\n).*?(  // @wall-dressing-end)", lambda m: m.group(1) + block + "\n" + m.group(2),
                  page, count=1, flags=re.S)
    path.write_text(page, encoding="utf-8", newline="")


if __name__ == "__main__":
    main()
