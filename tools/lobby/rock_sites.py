"""Anchor the floating spawn rock's roots, vines and crystals onto its actual rock surface.

Ray-marches each spot onto `rockBody` on the GPU, using the page's own shader functions, and rewrites the
generated block between `// @rock-dressing-begin` and `// @rock-dressing-end` in the page. Re-run after changing
the rock's shape. Same rule as the rock wall (tools/lobby/wall_sites.py): nothing may hover off the rock.

    python tools/lobby/rock_sites.py [--page docs/art/asset-library.html]
Requires moderngl and numpy.
"""

import argparse
import math
import random
import re
import sys
from pathlib import Path

import moderngl
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from render_library import desktop_glsl, extract  # noqa: E402

MAX_PROBES = 256
PROBE_MAIN = """
uniform vec4 uProbeO[256];
uniform vec4 uProbeD[256];
void main() {
  int i = int(gl_FragCoord.x);
  vec3 o = uProbeO[i].xyz, d = uProbeD[i].xyz;
  float t = 0.0, hit = 0.0;
  for (int s = 0; s < 120; s++) {
    float h = rockBody(o + d*t);
    if (h < 0.004) { hit = 1.0; break; }
    t += h*0.8;
    if (t > 28.0) break;
  }
  fragColor = vec4(o + d*t, hit);
}
"""

# Fourteen crystal designs from the library as cluster shapes: length, radius, spread, downward pull.
CRYSTAL_STYLES = [
    (2.2, 0.42, 0.5, 0.0),   # Cyan cluster
    (3.1, 0.34, 0.2, 0.3),   # Violet spire
    (1.8, 0.30, 0.95, 0.0),  # Amber fan
    (1.6, 0.32, 0.7, 0.0),   # Rose crown
    (1.9, 0.22, 0.85, 0.0),  # Emerald spray
    (3.0, 0.27, 0.16, 0.6),  # Frost spires
    (1.1, 0.24, 1.1, 0.0),   # Crimson shard field
    (1.5, 0.50, 0.6, 0.0),   # Sapphire
    (1.5, 0.36, 0.5, 0.0),   # Magenta
    (2.3, 0.30, 0.6, 0.2),   # Jade
    (2.1, 0.28, 0.45, 0.0),  # Gold
    (1.4, 0.45, 0.8, 0.0),   # Molten
    (2.7, 0.30, 0.28, 0.9),  # Pearl, hanging straight down
    (1.4, 0.14, 1.3, 0.0),   # Aurora urchin
]


def vec(v):
    return "vec3(" + ", ".join(f"{x:.3f}" for x in v) + ")"


def norm(v):
    length = math.sqrt(sum(x*x for x in v))
    return [x/length for x in v]


class Prober:
    def __init__(self, vs, fs):
        self.ctx = moderngl.create_standalone_context()
        fs = fs.replace("void main() {", "void unusedMain() {", 1) + PROBE_MAIN
        vs, fs = desktop_glsl(vs, fs, 4)
        self.prog = self.ctx.program(vs, fs)
        self.vao = self.ctx.vertex_array(
            self.prog, [(self.ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes()), "2f", "aPos")]
        )
        self.rays = []

    def add(self, origin, direction):
        self.rays.append((origin, direction))
        return len(self.rays) - 1

    def run(self):
        assert len(self.rays) <= MAX_PROBES, len(self.rays)
        data_o = np.zeros((MAX_PROBES, 4), dtype="f4")
        data_d = np.zeros((MAX_PROBES, 4), dtype="f4")
        for i, (o, d) in enumerate(self.rays):
            data_o[i, :3], data_d[i, :3] = o, d
        self.prog["uProbeO"].write(data_o.tobytes())
        self.prog["uProbeD"].write(data_d.tobytes())
        tex = self.ctx.texture((len(self.rays), 1), 4, dtype="f4")
        fbo = self.ctx.framebuffer(color_attachments=[tex])
        fbo.use()
        self.vao.render()
        return np.frombuffer(fbo.read(components=4, dtype="f4"), dtype="f4").reshape(-1, 4)


def radial(prober, angle, y):
    """A ray from outside the rock straight in toward its axis at height y."""
    return prober.add([math.cos(angle)*14, y, math.sin(angle)*14], [-math.cos(angle), 0.0, -math.sin(angle)])


def polar(angle, radius, y):
    return [math.cos(angle)*radius, y, math.sin(angle)*radius]


def chain(points, radii, seed):
    """Smooth quadratic Bezier calls through a list of points, with a radius at each point of the list."""
    calls = []
    n = len(points) - 2
    for i in range(n):
        a = points[0] if i == 0 else [(p + q)/2 for p, q in zip(points[i], points[i + 1])]
        c = points[-1] if i == n - 1 else [(p + q)/2 for p, q in zip(points[i + 1], points[i + 2])]
        r0 = radii[0] if i == 0 else (radii[i] + radii[i + 1])/2
        r1 = radii[-1] if i == n - 1 else (radii[i + 1] + radii[i + 2])/2
        calls.append(f"rootSeg(q, {vec(a)}, {vec(points[i + 1])}, {vec(c)}, {r0:.3f}, {r1:.3f}, {seed + i*1.7:.2f})")
    return calls


def build(prober):
    rnd = random.Random(27)
    # Roots: thick where they grip the top of the rim, then flowing down the real rock surface, forking as they go.
    root_angles = [0.5, 2.1, 3.7, 5.2]
    root_probes = []
    for a0 in root_angles:
        heights = [-0.05, -1.6, -3.6, -5.8]
        drift = [0.0] + [rnd.uniform(-0.1, 0.1) + 0.1*i for i in range(1, 4)]
        root_probes.append((a0, [(a0 + d, y, radial(prober, a0 + d, y)) for d, y in zip(drift, heights)]))
    # Vines: hang from the rim in loose groups, clear of the roots.
    vine_angles = [1.05, 1.28, 3.0, 4.45, 4.68]
    vine_probes = [(a, radial(prober, a, -0.05)) for a in vine_angles]
    # Crystals: a golden-angle scatter over the underside, using every design and colour.
    crystal_probes = []
    order = [0, 1, 2, 3, 4, 7, 8, 10]  # eight designs in clearly different colours
    rnd.shuffle(order)
    for i in range(8):
        a = i*2.39996 + 0.7
        rad = 2.6 + 3.4*math.sqrt((i + 0.5)/8)
        k = order[i]
        pull = CRYSTAL_STYLES[k][3]
        direction = norm([math.cos(a)*(0.8 - 0.6*pull), -0.62 - 0.4*pull, math.sin(a)*(0.8 - 0.6*pull)])
        target = polar(a, rad, (rad/7 - 1)*9.5)
        origin = [t + d*13 for t, d in zip(target, direction)]
        crystal_probes.append((k, direction, prober.add(origin, [-d for d in direction])))
    # Small mushrooms on the rock's sides, as on the wall: a few little clusters, not a scatter everywhere.
    shroom_probes = []
    for c, a in enumerate((0.15, 1.75, 2.75, 4.05, 5.65)):
        for j in range(3):
            aj = a + (j - 1)*0.09
            shroom_probes.append((aj, radial(prober, aj, -1.2 - 1.3*rnd.random() - 0.9*(c % 2)), c*7.0 + j*3.0, j > 0))

    hits = prober.run()

    def surface(index):
        return hits[index][:3].tolist() if hits[index][3] > 0.5 else None

    roots = []
    for r, (a0, probes) in enumerate(root_probes):
        pts = [surface(i) for _, _, i in probes]
        if any(p is None for p in pts):
            print(f"root {r}: a probe missed the rock, skipped")
            continue
        # Sit proud of the rock: the root's centre stands off the surface by most of its radius, so it reads as a form.
        widths = [0.34, 0.44, 0.4]
        pts = [[p[0] + math.cos(math.atan2(p[2], p[0]))*w*0.6, p[1], p[2] + math.sin(math.atan2(p[2], p[0]))*w*0.6]
               for p, w in zip(pts, widths + [0.3])]
        rim_r = math.hypot(pts[0][0], pts[0][2])
        last_a, last_y = probes[-1][0], probes[-1][1]
        last_r = math.hypot(pts[-1][0], pts[-1][2])
        # A low, spreading ridge starts on the top of the rim, so the root grips the edge rather than poking out of it.
        path = [polar(a0 - 0.08, rim_r - 2.8, -0.1), polar(a0 - 0.03, rim_r - 1.3, -0.1)] + pts + [
            polar(last_a + 0.14, last_r + 0.8, last_y - 1.0), polar(last_a + 0.34, last_r + 1.1, last_y - 1.7)]
        calls = chain(path, [0.1, 0.22] + widths + [0.3, 0.16, 0.05], r*3.1)
        # Two forks leave the main root and wander across the rock, some nearly meeting the next root.
        forks = []
        for f, (start, side) in enumerate(((3, 1.0 if r % 2 else -1.0),)):
            s = pts[start - 1]
            a1 = math.atan2(s[2], s[0])
            r1 = math.hypot(s[0], s[2])
            fork = [s,
                    polar(a1 + side*0.28, r1 + 0.1, s[1] - 1.0),
                    polar(a1 + side*0.55, r1 - 0.1, s[1] - 2.2),
                    polar(a1 + side*0.78, r1 + 0.5, s[1] - 3.6),
                    polar(a1 + side*1.05, r1 + 1.0, s[1] - 4.6)]
            forks += chain(fork, [0.28, 0.25, 0.2, 0.12, 0.05], r*2.3 + f*5.0)
        all_calls = calls + forks
        cx = sum(p[0] for p in path)/len(path)
        cy = sum(p[1] for p in path)/len(path)
        cz = sum(p[2] for p in path)/len(path)
        lines = "\n".join(f"    d = smin(d, {c}, 0.1);" for c in all_calls)
        roots.append(f"  bs = length(q - {vec([cx, cy, cz])}) - 7.5;\n  if (bs > 0.6) d = min(d, bs);\n  else {{\n{lines}\n  }}")

    vines = []
    for i, (a, probe) in enumerate(vine_probes):
        p = surface(probe)
        if p is None:
            print(f"vine {i}: probe missed the rock, skipped")
            continue
        rr = math.hypot(p[0], p[2])
        length = rnd.uniform(2.4, 4.8)
        vines.append(f"  rockStrand(q, {vec(polar(a, rr + 0.22, -0.2))}, {vec(polar(a, rr - 0.5, 0.03))}, {length:.2f}, {rnd.uniform(0, 6.28):.2f}, res);")

    crystals = []
    for i, (k, direction, probe) in enumerate(crystal_probes):
        p = surface(probe)
        if p is None:
            print(f"crystal {i}: probe missed the rock, skipped")
            continue
        length, radius, spread, _ = CRYSTAL_STYLES[k]
        size = rnd.uniform(0.85, 1.2)
        crystals.append(f"  crystalCluster(q, {vec(p)}, {vec(direction)}, {k:.1f}, {length*size*1.3:.2f}, {radius*size*1.15:.2f}, {spread:.2f}, res);")

    shrooms = []
    for a, probe, seed, tiny in shroom_probes:
        p = surface(probe)
        if p is None:
            continue
        normal = norm([math.cos(a), 0.15, math.sin(a)])
        shrooms.append(f"  wallShroom(q, {vec(p)}, {vec(normal)}, {seed:.1f}, {1.0 if tiny else 0.0}, stems, caps, capIdx);")
    print(f"{len(roots)} roots, {len(vines)} vines, {len(crystals)} crystal clusters, {len(shrooms)} mushrooms anchored")
    return ("float rootField(vec3 q) {\n  float d = 1e3, bs;\n" + "\n".join(roots) + "\n  return d;\n}\n"
            "void rockVines(vec3 q, inout vec2 res) {\n" + "\n".join(vines) + "\n}\n"
            "void rockCrystals(vec3 q, inout vec2 res) {\n" + "\n".join(crystals) + "\n}\n"
            "void rockShrooms(vec3 q, inout vec2 res) {\n  float stems = 1e5, caps = 1e5, capIdx = 0.0;\n"
            + "\n".join(shrooms)
            + "\n  if (stems < res.x) res = vec2(stems, 6.0);\n  if (caps < res.x) res = vec2(caps, 15.0 + capIdx*0.05);\n}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="docs/art/asset-library.html")
    args = ap.parse_args()
    path = Path(args.page)
    page = path.read_text(encoding="utf-8")
    vs = extract(page, r'<script id="vs" type="x-shader/x-vertex">(.*?)</script>')
    fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
    code = build(Prober(vs, fs))
    updated, count = re.subn(r"(// @rock-dressing-begin\n).*?(// @rock-dressing-end)",
                             lambda m: m.group(1) + code + m.group(2), page, flags=re.S)
    assert count == 1
    path.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
