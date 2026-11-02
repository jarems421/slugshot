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

from scipy import ndimage
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


def fissure_map(vs, fs, ctx):
    """The top's fissures as a grid of signed distances, read from the page's own topFissure."""
    size = 400
    fs = fs.replace("void main() {", "void unusedMain() {", 1) + """
void main() {
  vec2 x = (gl_FragCoord.xy/400.0*2.0 - 1.0)*8.0;
  vec2 fc = topFissure(x);
  fragColor = vec4(fc.x, fc.y, 0.0, 1.0);
}
"""
    vs, fs = desktop_glsl(vs, fs, 4)
    prog = ctx.program(vs, fs)
    vao = ctx.vertex_array(prog, [(ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes()), "2f", "aPos")])
    tex = ctx.texture((size, size), 4, dtype="f4")
    fbo = ctx.framebuffer(color_attachments=[tex])
    fbo.use()
    vao.render()
    data = np.frombuffer(fbo.read(components=4, dtype="f4"), dtype="f4").reshape(size, size, 4)
    return data[:, :, 0], data[:, :, 1], size


def crack_sites(data, size, count, spacing, inner, outer, rnd, taken, band=(-1.0, -0.02), per_sector=99):
    """Spots a chosen distance from the cracks, spaced apart, clear of the middle and the bridge mouths."""
    ys, xs = np.nonzero((data > band[0]) & (data < band[1]))
    order = list(range(len(xs)))
    rnd.shuffle(order)
    sites = []
    used = {}
    for i in order:
        x = (xs[i] + 0.5)/size*16 - 8
        z = (ys[i] + 0.5)/size*16 - 8
        r = math.hypot(x, z)
        if not inner < r < outer or (min(abs(x), abs(z)) < 1.3 and r > 4.0):
            continue
        if any(math.hypot(x - a, z - b) < spacing for a, b in taken):
            continue
        # One sector per crack, roughly, so no crack collects more than its share.
        sector = int((math.atan2(z, x) + math.pi)/0.698)
        if used.get(sector, 0) >= per_sector:
            continue
        used[sector] = used.get(sector, 0) + 1
        taken.append((x, z))
        sites.append((x, z))
        if len(sites) == count:
            break
    return sites


def sprouts(vs, fs, ctx):
    rnd = random.Random(53)
    data, widths, size = fissure_map(vs, fs, ctx)
    taken = []
    crystals = []
    # Mini copies of the standard cyan cluster, alternating with indigo (owner, 2026-11-01). Each is rooted into one of the
    # crack's walls and leans up and out from it. A site is only used if the cluster clears the opposite wall and its neighbours.
    grad_z, grad_x = np.gradient(data)
    cell = 16/size

    def solid(x, y, z):
        if y >= 0:
            return False
        ix, iz = int(np.clip((x + 8)/cell, 0, size - 1)), int(np.clip((z + 8)/cell, 0, size - 1))
        width = widths[iz, ix]
        deep = min(0.25 + width*3, 1.0)
        return data[iz, ix] + width*min(-y/deep, 1.0) >= 0 or -y > deep*0.9

    labels, count = ndimage.label(data < -0.008)
    colour = 0
    for crack in range(1, count + 1):
        zs, xs = np.nonzero((labels == crack) & (data > -0.07) & (data < -0.012))
        chosen = 0
        for i in rnd.sample(range(len(xs)), len(xs)):
            iz, ix = zs[i], xs[i]
            x, z = (ix + 0.5)/size*16 - 8, (iz + 0.5)/size*16 - 8
            if min(abs(x), abs(z)) < 1.3 and math.hypot(x, z) > 4.0:
                continue
            if any(math.hypot(x - a, z - b) < 0.8 for a, b in taken):
                continue
            gx, gz = grad_x[iz, ix], grad_z[iz, ix]
            length = math.hypot(gx, gz)
            if length < 1e-5:
                continue
            gx, gz = gx/length, gz/length
            width = widths[iz, ix]
            wall = -data[iz, ix]/width*min(0.25 + width*3, 1.0)
            # High on the wall, so the crystal stands up out of the crack and can be seen.
            if not 0.05 < wall < 0.17:
                continue
            # The base sits inside the rock, so the wall visibly holds it.
            site = [x + gx*0.05, -wall - 0.045, z + gz*0.05]
            direction = norm([-gx*0.55 + rnd.uniform(-0.1, 0.1), 1.0, -gz*0.55 + rnd.uniform(-0.1, 0.1)])
            s = rnd.uniform(0.05, 0.072)
            reach = 4.7*s
            if any(solid(*[site[k] + direction[k]*reach*f for k in range(3)]) for f in (0.4, 0.55, 0.7, 0.85, 1.0)):
                continue
            taken.append((x, z))
            crystals.append(f"  crackCluster(q, {vec(site)}, {vec(direction)}, {s:.3f}, {rnd.uniform(0, 6.28):.2f}, {19.0 if colour % 2 else 0.0}, res);")
            colour += 1
            chosen += 1
            if chosen == 5:
                break
        if len(xs):
            print(f"crack {crack}: {chosen} crystals")
    lines = []
    seed = 300.0
    # Eight single mushrooms along crack edges, spread around the island and out of the middle so they never clump
    # (owner, 2026-11-01).
    mushrooms = []  # spacing is measured between mushrooms only, not from the crack crystals
    for x, z in crack_sites(data, size, 8, 2.2, 3.3, 7.0, rnd, mushrooms, band=(0.07, 0.24), per_sector=1):
        lines.append(f"  wallShroom(q, {vec([x, -0.06, z])}, vec3(0.0, 1.0, 0.0), {seed:.1f}, 2.0, stems, caps, capIdx);")
        seed += 1.0
    print(f"{seed - 300:.0f} crack mushrooms, {len(crystals)} crack crystals anchored")
    return ("void rockSprouts(vec3 q, inout vec2 res) {\n  float stems = 1e5, caps = 1e5, capIdx = 0.0;\n"
            + "\n".join(lines)
            + "\n  if (stems < res.x) res = vec2(stems, 13.0);\n  if (caps < res.x) res = vec2(caps, 15.0 + capIdx*0.05);\n"
            + "\n".join(crystals) + "\n}\n")


def standoff(p, amount):
    """Move a surface point straight out from the rock's axis."""
    a = math.atan2(p[2], p[0])
    return [p[0] + math.cos(a)*amount, p[1], p[2] + math.sin(a)*amount]


def lie_over(points):
    """Let a root lie across the rock like a real one: ignore hits on spike tips and bridge over deep dents."""
    radii = [math.hypot(p[0], p[2]) for p in points]
    smoothed = list(radii)
    for i in range(1, len(radii) - 1):
        around = (radii[i - 1] + radii[i + 1])/2
        smoothed[i] = max(min(radii[i], around + 0.6), around - 0.25)
    return [standoff(p, s - r) for p, r, s in zip(points, radii, smoothed)]


def build(prober):
    rnd = random.Random(27)
    # Roots: thick where they grip the rim, then measured on the rock surface the whole way down, so they stay
    # attached. Only a small tip pokes out at the end (owner, 2026-11-01).
    root_probes = []
    for r, a0 in enumerate([0.5, 2.1, 3.7, 5.2]):
        heights = [-0.05, -0.5, -1.0, -1.5, -2.0, -2.6, -3.2, -3.9, -4.6]
        drift = [0.0, 0.01, 0.02, 0.03, 0.05, 0.07, 0.1, 0.13, 0.16]
        main = [(a0 + d + rnd.uniform(-0.04, 0.04), y) for d, y in zip(drift, heights)]
        side = 1.0 if r % 2 else -1.0
        fa, fy = main[5]
        fork = [(fa + side*0.13*i, fy - 0.6*i) for i in range(1, 5)]
        root_probes.append((a0, [radial(prober, a, y) for a, y in main], [radial(prober, a, y) for a, y in fork]))
    # Vines: hang from the rim in loose groups, clear of the roots.
    vine_probes = [(a, radial(prober, a, -0.05))
                   for a in [0.1, 1.05, 1.28, 1.72, 3.0, 3.25, 4.45, 4.68, 5.75]]
    # More vines growing out of the rock lower down (owner, 2026-11-01), spread around so they don't bunch up.
    low_vine_probes = [(a, y, radial(prober, a, y)) for a, y in
                       [(0.85, -1.6), (1.95, -2.4), (2.75, -1.4), (3.95, -2.2), (5.0, -1.5), (5.95, -2.6)]]
    # Larger crystals: eight designs in clearly different colours.
    crystal_probes = []
    order = [0, 1, 2, 3, 4, 7, 8, 10]
    rnd.shuffle(order)
    for i in range(8):
        a = i*2.39996 + 0.7
        rad = 2.6 + 3.4*math.sqrt((i + 0.5)/8)
        k = order[i]
        pull = CRYSTAL_STYLES[k][3]
        direction = norm([math.cos(a)*(0.8 - 0.6*pull), -0.62 - 0.4*pull, math.sin(a)*(0.8 - 0.6*pull)])
        target = polar(a, rad, (rad/7 - 1)*6.3)
        origin = [t + d*13 for t, d in zip(target, direction)]
        crystal_probes.append((k, direction, prober.add(origin, [-d for d in direction])))
    # Small crystals, in place of the mushrooms and scattered further, in mixed colours.
    small_probes = []
    for i in range(38):
        a = rnd.uniform(0.0, 6.2832)
        y = -0.5 - 4.0*rnd.random()**1.2
        small_probes.append((a, radial(prober, a, y)))

    hits = prober.run()

    def surface(index):
        return hits[index][:3].tolist() if hits[index][3] > 0.5 else None

    roots = []
    for r, (a0, main_probes, fork_probes) in enumerate(root_probes):
        pts = [surface(i) for i in main_probes]
        fork_pts = [surface(i) for i in fork_probes]
        if any(p is None for p in pts):
            print(f"root {r}: a probe missed the rock, skipped")
            continue
        widths = [0.34, 0.42, 0.46, 0.48, 0.46, 0.42, 0.36, 0.28, 0.18]
        hugging = [standoff(p, w*0.85) for p, w in zip(lie_over(pts), widths)]
        rim_r = math.hypot(pts[0][0], pts[0][2])
        last_a = math.atan2(pts[-1][2], pts[-1][0])
        last_r = math.hypot(pts[-1][0], pts[-1][2])
        # A low ridge starts on top of the rim; a short tip pokes out at the very end.
        path = [polar(a0 - 0.08, rim_r - 2.8, -0.1), polar(a0 - 0.03, rim_r - 1.3, -0.1)] + hugging + [
            polar(last_a + 0.04, last_r + 0.42, pts[-1][1] - 0.55)]
        calls = chain(path, [0.1, 0.22] + widths + [0.04], r*3.1)
        if all(p is not None for p in fork_pts):
            fork_widths = [0.28, 0.24, 0.19, 0.12]
            fork = [hugging[5]] + [standoff(p, w*0.85) for p, w in zip(lie_over(fork_pts), fork_widths)]
            tip = fork_pts[-1]
            fork.append(polar(math.atan2(tip[2], tip[0]) + 0.03, math.hypot(tip[0], tip[2]) + 0.3, tip[1] - 0.4))
            calls += chain(fork, [0.26] + fork_widths + [0.03], r*2.3 + 5.0)
        all_pts = path + fork_pts
        valid = [p for p in all_pts if p is not None]
        centre = [sum(p[k] for p in valid)/len(valid) for k in range(3)]
        lines = "\n".join(f"    d = smin(d, {c}, 0.1);" for c in calls)
        roots.append(f"  bs = length(q - {vec(centre)}) - 8.0;\n  if (bs > 0.6) d = min(d, bs);\n  else {{\n{lines}\n  }}")

    # Vines have their own random stream, so changing how many there are leaves the crystals where they were.
    for _ in range(10):
        rnd.random()
    vine_rnd = random.Random(91)
    vines = []
    for i, (a, probe) in enumerate(vine_probes):
        p = surface(probe)
        if p is None:
            print(f"vine {i}: probe missed the rock, skipped")
            continue
        rr = math.hypot(p[0], p[2])
        length = vine_rnd.uniform(2.2, 4.4)
        vines.append(f"  rockStrand(q, {vec(polar(a, rr + 0.22, -0.2))}, {vec(polar(a, rr - 0.5, 0.03))}, {length:.2f}, {vine_rnd.uniform(0, 6.28):.2f}, res);")
    for i, (a, y, probe) in enumerate(low_vine_probes):
        p = surface(probe)
        if p is None:
            print(f"low vine {i}: probe missed the rock, skipped")
            continue
        # The stem starts inside the rock, so it visibly grows out of the surface.
        top = standoff(p, 0.14)
        grip = standoff(p, -0.4)
        grip[1] += 0.2
        length = vine_rnd.uniform(1.7, 3.2)
        vines.append(f"  rockStrand(q, {vec(top)}, {vec(grip)}, {length:.2f}, {vine_rnd.uniform(0, 6.28):.2f}, res);")

    crystals = []
    for i, (k, direction, probe) in enumerate(crystal_probes):
        p = surface(probe)
        if p is None:
            print(f"crystal {i}: probe missed the rock, skipped")
            continue
        length, radius, spread, _ = CRYSTAL_STYLES[k]
        size = rnd.uniform(0.85, 1.2)
        crystals.append(f"  crystalCluster(q, {vec(p)}, {vec(direction)}, {k:.1f}, {length*size*1.3:.2f}, {radius*size*1.15:.2f}, {spread:.2f}, res);")

    small = []
    for a, probe in small_probes:
        p = surface(probe)
        if p is None:
            continue
        direction = norm([math.cos(a) + rnd.uniform(-0.5, 0.5), rnd.uniform(-0.75, 0.2), math.sin(a) + rnd.uniform(-0.5, 0.5)])
        small.append(f"  smallCrystal(q, {vec(p)}, {vec(direction)}, {rnd.uniform(0.65, 1.3):.2f}, {rnd.uniform(0.11, 0.19):.3f}, {float(rnd.randrange(14)):.1f}, res);")

    print(f"{len(roots)} roots, {len(vines)} vines, {len(crystals)} crystal clusters, {len(small)} small crystals anchored")
    return ("float rootField(vec3 q) {\n  float d = 1e3, bs;\n" + "\n".join(roots) + "\n  return d;\n}\n"
            "void rockVines(vec3 q, inout vec2 res) {\n" + "\n".join(vines) + "\n}\n"
            "void rockCrystals(vec3 q, inout vec2 res) {\n" + "\n".join(crystals) + "\n}\n"
            "void rockSmallCrystals(vec3 q, inout vec2 res) {\n" + "\n".join(small) + "\n}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="docs/art/asset-library.html")
    args = ap.parse_args()
    path = Path(args.page)
    page = path.read_text(encoding="utf-8")
    vs = extract(page, r'<script id="vs" type="x-shader/x-vertex">(.*?)</script>')
    fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
    prober = Prober(vs, fs)
    code = build(prober) + sprouts(vs, fs, prober.ctx)
    updated, count = re.subn(r"(// @rock-dressing-begin\n).*?(// @rock-dressing-end)",
                             lambda m: m.group(1) + code + m.group(2), page, flags=re.S)
    assert count == 1
    path.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
