"""Turn the final hub concepts (spawn rock, gateways, bridge, Maelstrom, Sky Well) into phone-budget game pieces.

Same idea as tools/lobby/sdf_mesh.py and paint_texels.py: the mesh and every texel come from the asset library's
own shader, so the game piece is the approved concept. The differences are for size and cost:
  - sampling is sparse (only bricks of space near a surface), so a 70-stud rock can use a fine grid in 16 GB;
  - each piece is split into a few parts with their own triangle, texture and ink budgets (see PIECES);
  - shader units convert to studs on export.

    python tools/lobby/hub_mesh.py mesh <key>    sample the shape, writes build/lobby/meshes/<key>/
    blender ... --python tools/lobby/blender_hub_piece.py -- <key>
    python tools/lobby/hub_mesh.py paint <key>   paint colour and glow maps from the baked positions
    python tools/lobby/hub_mesh.py all <key...>  all three
    python tools/lobby/hub_mesh.py list          budgets per piece

Requires Node, moderngl, numpy, scipy and scikit-image.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from skimage.measure import approximate_polygon, find_contours, marching_cubes

sys.path.insert(0, str(Path(__file__).parent))
from paint_texels import dilate, to_srgb  # noqa: E402
from render_library import dump_renders, extract  # noqa: E402
from sdf_mesh import Gpu  # noqa: E402

BLENDER = os.environ.get("BLENDER", "C:/Users/runni/slugshot/.tools/blender-5.2.3-windows-x64/blender.exe")
PAGE = Path("docs/art/asset-library.html")

# Ink widths in studs (look-pack.md): rock 0.077, props 0.119. The hub is seen from further away than the look test.
ROCK_INK, PROP_INK, FINE_INK = 0.1, 0.09, 0.05

NORMAL = """
vec3 assetNormal(vec3 p) {
  const float h = NORMAL_H;
  return normalize(vec3(assetMap(p + vec3(h, 0, 0)).x - assetMap(p - vec3(h, 0, 0)).x,
                        assetMap(p + vec3(0, h, 0)).x - assetMap(p - vec3(0, h, 0)).x,
                        assetMap(p + vec3(0, 0, h)).x - assetMap(p - vec3(0, 0, h)).x));
}
"""

# The library's own ink, line for line, measured against this piece's shape.
PAINT = """
uniform sampler2D uPos;
layout(location = 0) out vec4 o0;
layout(location = 1) out vec4 o1;
void main() {
  vec3 p = texelFetch(uPos, ivec2(gl_FragCoord.xy), 0).xyz;
  for (int k = 0; k < 3; k++) p -= assetNormal(p)*assetMap(p).x;
  vec3 n = assetNormal(p);
  float id = assetMap(p - n*0.01).y;
  vec3 emit; float spec;
  vec3 alb = albedo(id, p, n, emit, spec);
  float e = 0.09*max(creaseScale(id), 0.6);
  float cs = TR(id).y;
  vec2 s1 = assetMap(p + vec3(e, -e, -e)), s2 = assetMap(p + vec3(-e, -e, e));
  vec2 s3 = assetMap(p + vec3(-e, e, -e)), s4 = assetMap(p + vec3(e, e, e));
  float lap = (s1.x + s2.x + s3.x + s4.x - 4.0*assetMap(p).x)/e;
  float convex = uAsset > 3.5 ? 0.1 : 0.5;
  float crease = smoothstep(0.5/cs, 1.0/cs, -lap) + convex*smoothstep(1.4/cs, 2.4/cs, lap);
  float inkClear = 0.0;
#if ASSET >= 4
  if (id < 1.5) {
    crease = smoothstep(1.6/cs, 3.2/cs, -lap) + convex*smoothstep(1.4/cs, 2.4/cs, lap);
    vec3 fl = centreLocal(p);
    if (fl.y > -1.1 && fl.y < 0.06 && length(fl.xz) < 8.2) {
      float fx = topFissure(fl.xz).x;
      if (fx < 0.05) crease = 0.0;
      inkClear = 1.0 - smoothstep(-0.015, 0.012, fx);
    }
  }
#endif
  vec3 t1 = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
  vec3 t2 = cross(n, t1);
  float idEdge = 0.0;
  for (int k = 0; k < 6; k++) {
    float a = float(k)*1.0472;
    vec3 q = p + (t1*cos(a) + t2*sin(a))*0.045;
    for (int j = 0; j < 2; j++) q -= assetNormal(q)*assetMap(q).x;
    if (abs(assetMap(q - assetNormal(q)*0.01).y - id) > 0.5) idEdge = 1.0;
  }
  if (abs(id - 9.0) < 0.5 || abs(id - 17.0) < 0.5 || abs(id - 13.0) < 0.5) { crease = 0.0; idEdge *= 0.6; }
  if (id > 2.3 && id < 2.5) { crease = smoothstep(0.2, 0.7, -lap)*0.85; idEdge *= 0.6; }
  if (abs(id - 12.0) < 0.5) crease = 0.0;
  float ink = max(clamp(crease, 0.0, 1.0)*step(0.01, inkWidth(id)), idEdge)*(1.0 - inkClear);
  alb = mix(alb, INK(id), ink);
  emit *= 1.0 - ink;
  o0 = vec4(alb, id);
  o1 = vec4(emit, ink);
}
"""

GRID = """
uniform vec3 uOrigin;
uniform float uStep, uSliceZ;
layout(location = 0) out vec4 o0;
void main() {
  vec3 p = uOrigin + vec3(floor(gl_FragCoord.x), floor(gl_FragCoord.y), uSliceZ)*uStep;
  o0 = vec4(assetMap(p), 0.0, 1.0);
}
"""

IDS = """
uniform sampler2D uPos;
layout(location = 0) out vec4 o0;
layout(location = 1) out vec4 o1;
void main() {
  vec3 p = texelFetch(uPos, ivec2(gl_FragCoord.xy), 0).xyz;
  vec3 n = assetNormal(p);
  o0 = vec4(assetMap(p - n*0.01).y);
  o1 = vec4(0.0);
}
"""


# The storm can't be a volume on a phone, so it is a stack of thin discs, each painted with the concept's own cloud field
# integrated over the height it stands for. Rotating them at slightly different rates gives the parallax of real depth.
STORM_LEVELS = (21.0, 24.0, 27.0, 31.0, 36.0, 41.0)
STORM_EYE = 45.0
STORM_REACH = 9.25
STORM = """
uniform sampler2D uPos;
layout(location = 0) out vec4 o0;
layout(location = 1) out vec4 o1;
void main() {
  vec3 p = texelFetch(uPos, ivec2(gl_FragCoord.xy), 0).xyz;
  if (p.y > 44.0) {
    // The hollow, lit eye the spiral winds around, behind every layer.
    float r = length(p.xz);
    vec3 eye = mix(vec3(0.012, 0.011, 0.024), vec3(0.2, 0.19, 0.3), exp(-r*r*0.1));
    o0 = vec4(eye, 0.0);
    o1 = vec4(1.0);
    return;
  }
  const int N = 6;
  const float BAND = 3.2;
  vec3 sum = vec3(0.0);
  float alpha = 0.0, dt = BAND/float(N);
  for (int i = 0; i < N; i++) {
    vec3 q = vec3(p.x, p.y + BAND*0.5 - dt*(float(i) + 0.5), p.z);  // nearest the viewer first: they look up from below
    q.y = p.y - BAND*0.5 + dt*(float(i) + 0.5);
    float shade, den = stormCloud(q, 0.0, shade);
    if (den > 0.0) {
      float take = 1.0 - exp(-den*dt*2.2);
      float shade2, near = stormCloud(q + vec3(0.0, -0.75, 0.0), 0.0, shade2);
      float exposed = 1.0 - near;
      vec3 cl = mix(vec3(0.007, 0.0065, 0.012), vec3(0.036, 0.03, 0.062), smoothstep(0.48, 0.6, shade));
      cl = mix(cl, vec3(0.19, 0.162, 0.28), exposed*smoothstep(0.52, 0.72, shade));
      cl += vec3(0.3, 0.28, 0.42)*exp(-length(q.xz)*0.8)*smoothstep(0.0, 8.0, q.y - WELL_LOW);
      sum += (1.0 - alpha)*take*cl;
      alpha += (1.0 - alpha)*take;
    }
  }
  alpha *= 1.0 - smoothstep(5.6, 8.4, length(p.xz));
  o0 = vec4(alpha > 0.0 ? sum/max(alpha, 0.001) : vec3(0.03), 0.0);
  o1 = vec4(alpha);
}
"""


def slice_between(text, start, stop):
    a = text.index(start)
    return text[a:text.index(stop, a)]


def maelstrom_maps(fs):
    """Split the concept's maelstrom() into its layers, so each can be its own game part."""
    body = slice_between(fs, "vec2 maelstrom(vec3 p) {", "// Mist rising off the water")
    head = "  float rr = length(p.xz), a = atan(p.z, p.x);\n"
    solid = slice_between(body, "  float R = 17.6", "  float spin = uT*ORBIT, wy")
    water = slice_between(body, "  float spin = uT*ORBIT, wy", "  // Falls of glowing energy")
    falls = slice_between(body, "  // Falls of glowing energy", "  // Greenery:")
    flora = slice_between(body, "  treeShrooms(p, res);", "  vec2 hb = hookedBridges(p);")
    return {
        # Clipped outward and below the juice: the rest would never be seen.
        "cliff": f"vec2 assetMap(vec3 p) {{\n{head}{solid}  res.x = max(res.x, max(rr - 21.0, -12.0 - p.y));\n  return res;\n}}\n",
        "juice": f"vec2 assetMap(vec3 p) {{\n{head}  vec2 res = vec2(1e3, 17.0);\n{water}  return res;\n}}\n",
        "falls": f"vec2 assetMap(vec3 p) {{\n{head}  float spin = 0.0;\n  vec2 res = vec2(1e3, 17.3);\n{falls}  return res;\n}}\n",
        "flora": f"vec2 assetMap(vec3 p) {{\n{head}  float spin = 0.0;\n  vec2 res = vec2(1e3, 13.0);\n{flora}  return res;\n}}\n",
    }


def well_maps(fs):
    body = slice_between(fs, "vec2 skyWell(vec3 p) {", "// A distant storm wheeling")
    head = "  float rr = length(p.xz), a = atan(p.z, p.x), s, k0;\n"
    solid = slice_between(body, "  float holeR", "  // Crystals line the opening")
    solid = solid.replace("  float s = PI*2.0/20.0, k0 = floor(a/s);", "  s = PI*2.0/20.0; k0 = floor(a/s);")
    glow = slice_between(body, "  // Crystals line the opening", "  // Mini islands")
    isles = slice_between(body, "  // Mini islands", "  // Loose debris")
    bits = slice_between(body, "  // Loose debris", "  // The spawn rock at true scale")
    return {
        # Clipped at the block-out's cavern wall and just above the shaft; the storm covers the top.
        "rock": f"vec2 assetMap(vec3 p) {{\n{head}{solid}  res.x = max(res.x, max(rr - 31.0, p.y - 36.5));\n  return res;\n}}\n",
        "glow": f"vec2 assetMap(vec3 p) {{\n{head}  vec2 res = vec2(1e3, 18.0);\n{glow}  return res;\n}}\n",
        "isles": f"vec2 assetMap(vec3 p) {{\n{head}  vec2 res = vec2(1e3, 1.0);\n{isles}  return res;\n}}\n",
        "bits": f"vec2 assetMap(vec3 p) {{\n{head}  vec2 res = vec2(1e3, 1.0);\n{bits}  return res;\n}}\n",
    }


ROCK_BODY = """vec2 assetMap(vec3 p) { return vec2(rockBody(p - vec3(0.0, ROCK_TOP, 0.0)), 1.0); }
"""
ROCK_DRESS = """vec2 assetMap(vec3 p) {
  vec3 q = p - vec3(0.0, ROCK_TOP, 0.0);
  vec2 res = vec2(1e3, 4.0);
  vec3 w = q + 0.2*(vec3(noise3(q*1.1), noise3(q*1.1 + 11.0), noise3(q*1.1 + 23.0)) - 0.5);
  float rf = rootField(w)*0.85;
  if (rf < res.x) res = vec2(rf, 4.0);
  rockVines(q, res);
  rockCrystals(q, res);
  rockSmallCrystals(q, res);
  rockSprouts(q, res);
  // Nothing buried: it would only spend triangles and texture on what can't be seen.
  res.x = max(res.x, -rockBody(q) - 0.04);
  return res;
}
"""
ROCK_DEBRIS = """vec2 assetMap(vec3 p) {
  vec2 res = vec2(1e3, 1.0);
  rockDebris(p - vec3(0.0, ROCK_TOP, 0.0), res);
  return res;
}
"""
GATE = """vec2 assetMap(vec3 p) {
  vec2 res = vec2(1e3, 1.3);
  bridgeMarkers(p - vec3(0.0, ROCK_TOP, 0.0), res);
  return res;
}
"""
BRIDGE = """vec2 assetMap(vec3 p) { return ropeBridge(p, 0.0, true); }
"""
PORTAL = """vec2 assetMap(vec3 p) { vec2 r = portal(p/GS); r.x *= GS; return r; }
"""


def by_id(*ranges):
    def test(ids, _centres):
        hit = np.zeros(len(ids), dtype=bool)
        for lo, hi in ranges:
            hit |= (ids >= lo) & (ids < hi)
        return hit
    return test


def everything(ids, _centres):
    return np.ones(len(ids), dtype=bool)


def top_only(ids, c):
    return c[:, 1] > 12.9 + 0.0*ids  # within half a stud of the walkable top (shader y 13)


def upper_side(ids, c):
    return c[:, 1] > 13.0 - 2.6


def in_cracks(_ids, c):
    # Below the flat walkable top and inside the rim: only the grooves are there. They keep real geometry (owner:
    # "just painted cracks"), since sharing a budget with the flat top flattened them.
    ang = np.arctan2(c[:, 2], c[:, 0])
    rim = 7.0*(1 + 0.05*np.sin(ang*3 + 1) + 0.035*np.sin(ang*7 + 2.1) + 0.02*np.sin(ang*13))
    return (c[:, 1] < 12.985) & (c[:, 1] > 11.7) & (np.hypot(c[:, 0], c[:, 2]) < rim - 0.2)


def in_sprouts(ids, c):
    # The little mushrooms standing along the cracks: caps, and the stems above the top.
    return ((ids >= 14.5) & (ids < 15.69)) | ((np.abs(ids - 13.0) < 0.5) & (c[:, 1] > 12.9))


def in_rim_bushes(ids, c):
    # The bushes along the rim; crushed in with the vines they had a few triangles each (owner: horrible, low quality).
    return (np.abs(ids - 12.0) < 0.5) & (np.hypot(c[:, 0], c[:, 2]) > 18.0) & (c[:, 1] > -0.4)


def juice_funnel():
    """The juice's smooth funnel. Decimating its folds left hard facets (owner: "a spiral of choppiness"), so the
    shape stays smooth and the folds live in the normal and colour maps, which rotate with it."""
    rings, sides = 34, 96
    def height(r):
        t = np.clip(r/4.0, 0, 1)
        return -10.0 - 20.0*np.clip(1 - r/17.5, 0, 1)**1.8 + 0.62*t*t*(3 - 2*t)
    verts = [(0.0, height(0.0), 0.0)]
    for ring in range(1, rings + 1):
        r = 18.6*(ring/rings)**1.35
        for side in range(sides):
            a = 2*np.pi*side/sides
            verts.append((r*np.cos(a), height(r), r*np.sin(a)))
    faces = []
    for side in range(sides):
        faces.append((0, 1 + (side + 1) % sides, 1 + side))
    for ring in range(rings - 1):
        base = 1 + ring*sides
        for side in range(sides):
            a, b = base + side, base + (side + 1) % sides
            faces += [(a, b, a + sides), (b, b + sides, a + sides)]
    return np.array(verts, "f4"), np.array(faces, "i4")


def in_section(n, count):
    # Seams sit under the bridges, where they don't show.
    def test(_ids, c):
        ang = np.arctan2(c[:, 2], c[:, 0])
        return np.floor(((ang + np.pi)/(2*np.pi/count)) % count) == n
    return test


def inner_ring(_ids, c):
    return np.hypot(c[:, 0], c[:, 2]) < 19.0


def part(name, test, tris, tex, ink=0.0, ink_ratio=1.0, hard=False, cage=None):
    return {"name": name, "test": test, "tris": tris, "tex": tex, "ink": ink, "inkRatio": ink_ratio, "hard": hard, "cage": cage}


def split_components(verts, faces, assign):
    """Label each separate floating lump, then let assign(centre, index) pick its part number."""
    n = len(verts)
    edges = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]]])
    graph = coo_matrix((np.ones(len(edges), dtype="i1"), (edges[:, 0], edges[:, 1])), shape=(n, n))
    count, labels = connected_components(graph, directed=False)
    centres = np.zeros((count, 3))
    np.add.at(centres, labels, verts)
    centres /= np.bincount(labels, minlength=count)[:, None]
    return np.array([assign(centres[i], i) for i in range(count)])[labels[faces[:, 0]]]


def debris_group(count):
    # Well mixed around the rock, so a group's pieces are never neighbours and they read as moving separately.
    def assign(_centre, i):
        return i % count
    return assign


def well_bits_group(centre, i):
    # Inner pieces orbit twice as fast in the concept: three bobbing groups for each speed.
    return (0 if np.hypot(centre[0], centre[2]) < 6.0 else 3) + i % 3


ISLANDS = [(0.52, 8.5), (2.44, 7.5), (3.75, 8.8), (5.24, 6.5), (1.48, 5.5)]


def nearest_island(centre, _i):
    d = [np.hypot(centre[0] - np.cos(a)*r, centre[2] - np.sin(a)*r) for a, r in ISLANDS]
    return int(np.argmin(d))


def storm_discs():
    """One disc for each level, seen from below, in rings so the texture has no long thin triangles."""
    rings, sides = 5, 48
    discs = {}
    for name, y in [(f"Cloud{i}", level) for i, level in enumerate(STORM_LEVELS)] + [("Eye", STORM_EYE)]:
        verts = [(0.0, y, 0.0)]
        for ring in range(1, rings + 1):
            radius = STORM_REACH*ring/rings
            for side in range(sides):
                angle = 2*np.pi*side/sides
                verts.append((radius*np.cos(angle), y, radius*np.sin(angle)))
        faces = []
        for side in range(sides):
            faces.append((0, 1 + side, 1 + (side + 1) % sides))
        for ring in range(rings - 1):
            base = 1 + ring*sides
            for side in range(sides):
                a, b = base + side, base + (side + 1) % sides
                faces += [(a, a + sides, b), (b, a + sides, b + sides)]
        discs[name] = (np.array(verts, "f4"), np.array(faces, "i4"))
    return discs


def gate_piece(direction, r):
    lo, hi = {0: ((-3.7, 11.8, -r - 1.25), (3.7, 16.3, -r + 1.25)), 1: ((r - 1.25, 11.8, -3.7), (r + 1.25, 16.3, 3.7)),
              2: ((-3.7, 11.8, r - 1.25), (3.7, 16.3, r + 1.25)), 3: ((-r - 1.25, 11.8, -3.7), (-r + 1.25, 16.3, 3.7))}[direction]
    return {
        "item": "spawn-rock-1", "map": GATE, "scale": 5.0, "origin": (0.0, 13.0, 0.0), "lo": lo, "hi": hi, "step": 0.022,
        "normalH": 0.004, "gain": 1.45,
        "parts": [
            part("Stone", by_id((0.5, 1.9)), 2000, 512, PROP_INK, 0.6, cage=0.03),
            part("Rope", by_id((1.9, 3.0)), 2600, 1024, 0.0, cage=0.012),
            part("Key", by_id((15.9, 16.5)), 160, 256, FINE_INK, 1.0, hard=True, cage=0.02),
        ],
    }


def portal_piece(item, scale):
    return {
        "item": item, "map": PORTAL, "scale": scale, "origin": (0.0, 0.0, 0.0), "lo": (-12.0, -0.3, -5.5), "hi": (12.0, 22.0, 5.5),
        "step": 0.05, "normalH": 0.004,
        "parts": [
            part("Stone", by_id((5.5, 6.5)), 3600, 1024, ROCK_INK, 0.4, hard=True, cage=0.06),
            part("Iron", by_id((6.5, 7.5)), 1400, 512, PROP_INK, 0.5, cage=0.04),
            part("Gem", by_id((7.5, 8.5)), 500, 256, PROP_INK, 1.0, hard=True, cage=0.04),
            part("Energy", everything, 500, 512, cage=0.05),
        ],
    }


# Budgets are painted triangles. Roblox's automatic LOD lowers distant parts further.
PIECES = {
    "hub-rock": {
        "item": "spawn-rock-1", "map": ROCK_BODY, "scale": 5.0, "origin": (0.0, 13.0, 0.0),
        "lo": (-9.8, 4.4, -9.8), "hi": (9.8, 13.3, 9.8), "step": 0.03, "normalH": 0.006, "overlap": 3,
        "parts": [
            part("Cracks", in_cracks, 9000, 1024, cage=0.04),
            part("Top", top_only, 4500, 1024, cage=0.05),
            part("Upper", upper_side, 7000, 1024, ROCK_INK, 0.5, cage=0.08),
            part("Lower", everything, 5000, 1024, ROCK_INK, 0.5, cage=0.08),
        ],
    },
    "hub-rock-dress": {
        "item": "spawn-rock-1", "map": ROCK_DRESS, "scale": 5.0, "origin": (0.0, 13.0, 0.0),
        "lo": (-10.5, 3.0, -10.5), "hi": (10.5, 14.5, 10.5), "step": 0.022, "normalH": 0.004, "sparkle": "Glow",
        "parts": [
            part("Sprouts", in_sprouts, 2400, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Roots", by_id((3.5, 4.5)), 4500, 1024, PROP_INK*0.7, 0.7, cage=0.02),
            part("Glow", by_id((15.69, 16.0), (17.5, 20.0), (3.0, 3.5)), 4000, 1024, PROP_INK*1.1, 1.0, cage=0.02),
            part("Flora", everything, 4500, 1024, FINE_INK, 1.0, cage=0.015),
        ],
    },
    "hub-rock-debris": {
        "item": "spawn-rock-1", "map": ROCK_DEBRIS, "scale": 5.0, "origin": (0.0, 13.0, 0.0),
        "lo": (-15.0, 3.0, -15.0), "hi": (15.0, 13.0, 15.0), "step": 0.03, "normalH": 0.004,
        "components": debris_group(3), "gain": 1.7,
        "parts": [part(f"Debris{i}", None, 800, 256, PROP_INK, 1.0, hard=True, cage=0.02) for i in range(3)],
    },
    "hub-gate-0": gate_piece(0, 6.6),
    "hub-gate-1": gate_piece(1, 6.85),
    "hub-gate-2": gate_piece(2, 6.25),
    "hub-gate-3": gate_piece(3, 6.3),
    "hub-bridge": {
        "item": "bridge-1", "map": BRIDGE, "scale": 2.55, "origin": (0.0, 0.0, 0.0),
        "lo": (-11.2, -3.0, -4.2), "hi": (11.8, 3.6, 4.2), "step": 0.022, "normalH": 0.004, "rig": "bridge",
        "parts": [
            part("Deck", by_id((1.9, 2.3), (2.5, 3.0), (13.0, 14.0)), 2600, 1024, FINE_INK*1.2, 1.0, cage=0.03),
            part("Rope", everything, 3000, 1024, cage=0.015),
        ],
    },
    "hub-cliff": {
        "item": "maelstrom-1", "map": "cliff", "scale": 5.0, "origin": (0.0, 0.0, 0.0),
        "lo": (-21.5, -12.3, -21.5), "hi": (21.5, 1.0, 21.5), "step": 0.06, "normalH": 0.008, "overlap": 3,
        "parts": [part(f"Cliff{i}", in_section(i, 8), 2800, 1024, ROCK_INK, 1.0, cage=0.1) for i in range(8)],
    },
    "hub-pit-flora": {
        "item": "maelstrom-1", "map": "flora", "scale": 5.0, "origin": (0.0, 0.0, 0.0),
        "lo": (-21.5, -13.0, -21.5), "hi": (21.5, 1.5, 21.5), "step": 0.028, "normalH": 0.004,
        "parts": [
            part("Caps", by_id((15.6, 16.0)), 3000, 1024, PROP_INK, 0.5, cage=0.03),
            part("Bushes", in_rim_bushes, 5500, 1024, FINE_INK*1.2, 0.8, cage=0.02),
            part("Flora", everything, 4500, 1024, FINE_INK, 1.0, cage=0.02),
        ],
    },
    "hub-juice": {
        "item": "maelstrom-1", "map": "juice", "scale": 5.0, "origin": (0.0, 0.0, 0.0), "uRo": (0.0, 30.0, 0.0),
        "lo": (-18.8, -31.0, -18.8), "hi": (18.8, -7.0, 18.8), "step": 0.06, "normalH": 0.01, "smooth": juice_funnel, "bakeEmit": True,
        "parts": [part("Juice", everything, 6500, 1024, cage=1.3)],
    },
    # The block-out's sizes: PvP the largest at about 28 tall, the other two about 23.
    "hub-portal-pvp": portal_piece("gate-pvp-1", 1.35),
    "hub-portal-training": portal_piece("gate-training-1", 1.1),
    "hub-portal-veylume": portal_piece("gate-veylume-1", 1.1),
    "hub-storm": {
        "item": "sky-well-1", "map": "bits", "scale": 10.0, "origin": (0.0, 1.0, 0.0), "normalH": 0.01, "storm": True,
        "parts": [part(f"Cloud{i}", None, 500, 512) for i in range(len(STORM_LEVELS))] + [part("Eye", None, 500, 256)],
    },
    "hub-well-rock": {
        "item": "sky-well-1", "map": "rock", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-31.5, 16.5, -31.5), "hi": (31.5, 37.0, 31.5), "step": 0.08, "normalH": 0.012, "overlap": 4,
        "parts": [
            part("Mouth", inner_ring, 6000, 1024, ROCK_INK*1.2, 0.4, cage=0.1),
            part("Ceiling", everything, 2500, 1024, cage=0.15),
        ],
    },
    "hub-well-glow": {
        "item": "sky-well-1", "map": "glow", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-16.0, 15.0, -16.0), "hi": (16.0, 37.0, 16.0), "step": 0.035, "normalH": 0.005, "sparkle": "WellGlow",
        "parts": [part("WellGlow", everything, 4000, 1024, PROP_INK*1.3, 0.8, cage=0.03)],
    },
    "hub-well-isles": {
        "item": "sky-well-1", "map": "isles", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-13.0, 3.0, -13.0), "hi": (13.0, 26.0, 13.0), "step": 0.022, "normalH": 0.004,
        "components": nearest_island, "gain": 1.5,
        "parts": [part(f"Isle{i}", None, 700, 256, PROP_INK*1.3, 0.8, hard=True, cage=0.02) for i in range(5)],
    },
    "hub-well-bits": {
        "item": "sky-well-1", "map": "bits", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-17.5, 4.0, -17.5), "hi": (17.5, 36.0, 17.5), "step": 0.022, "normalH": 0.004,
        "components": well_bits_group, "gain": 1.5,
        "parts": [part(f"Bits{i}", None, 500, 256, PROP_INK*1.3, 1.0, hard=True, cage=0.02) for i in range(6)],
    },
}


# The library's soft light lifts crack floors and rope that the game has to paint brighter or crisper.
GAME_PAINT = (
    # Cracks: glowing across the floor. In the concept the bright strip was thin and moss grew over the floor, which read
    # as green drawings in the game (owner).
    ("float core = smoothstep(0.34, 0.8, -fq.x/max(fq.y, 0.01));", "float core = smoothstep(0.62, 0.95, -fq.x/max(fq.y, 0.01));"),
    ("s = mix(s, mix(vec3(0.012, 0.016, 0.022), vec3(0.22, 0.75, 0.7), core), inside);",
     "s = mix(s, mix(vec3(0.008, 0.024, 0.05), vec3(0.14, 0.72, 0.7), core), inside);"),
    ("m *= 1.0 - fissureHalo*0.85;", "m *= 1.0 - fissureHalo*0.85; if (fissure > 0.0) m = 0.0;"),
    # Rope: fine dark strands (owner: low quality).
    ("float twist = 0.5 + 0.5*sin((abs(p.x)*2.6 + abs(p.z)*2.6 + p.y*2.2)*17.0);",
     "float twist = smoothstep(-0.35, 0.55, sin((abs(p.x)*2.6 + abs(p.z)*2.6 + p.y*2.2)*34.0));"),
    ("vec3(0.38, 0.3, 0.19), vec3(0.62, 0.52, 0.34), twist", "vec3(0.2, 0.15, 0.09), vec3(0.66, 0.55, 0.37), twist"),
)


class PieceGpu(Gpu):
    def __init__(self, key):
        self.piece = PIECES[key]
        page = PAGE.read_text(encoding="utf-8")
        for old, new in GAME_PAINT:
            assert old in page, old
            page = page.replace(old, new)
        bank, items = dump_renders(extract(page, r'<script id="lib">(.*?)</script>'), {self.piece["item"]})
        fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
        source = self.piece["map"]
        if source in ("cliff", "juice", "falls", "flora"):
            source = maelstrom_maps(fs)[source]
        elif source in ("rock", "glow", "isles", "bits"):
            source = well_maps(fs)[source]
        item = items[0]
        frame = dict(item["frames"][0])
        frame["uT"] = [0.0]
        if "uRo" in self.piece:
            frame["uRo"] = list(self.piece["uRo"])
        item = {**item, "frames": [frame]}
        normal = NORMAL.replace("NORMAL_H", f"{self.piece['normalH']:.4f}")
        super().__init__(page, item, bank, asset_map=source + normal, mains={"grid": GRID, "paint": PAINT, "ids": IDS, "storm": STORM})

    def ids(self, verts):
        return self.paint(verts, program="ids")[0][:, 0]


def sparse_surface(gpu, lo, hi, step, brick=36):
    """Marching cubes only in bricks that the coarse pass finds near a surface. Shared brick faces are welded."""
    lo, hi = np.array(lo, dtype="f8"), np.array(hi, dtype="f8")
    size = step*brick
    shape = tuple(int(v) for v in np.ceil((hi - lo)/size))
    coarse = gpu.grid(lo + size*0.5, size, shape)[..., 0]
    active = np.argwhere(np.abs(coarse) < size*1.05)
    print(f"{np.prod(shape)} bricks, {len(active)} near a surface", flush=True)
    all_v, all_f, base = [], [], 0
    started = time.time()
    for n, index in enumerate(active):
        origin = lo + index*size
        cells = gpu.grid(origin, step, (brick + 1,)*3)[..., 0]
        if cells.min() >= 0 or cells.max() <= 0:
            continue
        v, f, _, _ = marching_cubes(cells, level=0.0, spacing=(step,)*3, allow_degenerate=False)
        all_v.append(v + origin)
        all_f.append(f + base)
        base += len(v)
        if n % 500 == 499:
            print(f"  {n + 1}/{len(active)} bricks, {base} verts, {time.time() - started:.0f}s", flush=True)
    verts, faces = np.concatenate(all_v), np.concatenate(all_f)
    keys = np.round((verts - lo)/(step*0.04)).astype(np.int64)
    _, first, inverse = np.unique(keys, axis=0, return_index=True, return_inverse=True)
    verts, faces = verts[first].astype("f4"), inverse.ravel()[faces].astype("i4")
    keep = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])
    return verts, faces[keep]


def storm_mesh(key):
    out = Path("build/lobby/meshes")/key
    out.mkdir(parents=True, exist_ok=True)
    groups = []
    for name, (verts, faces) in storm_discs().items():
        np.savez_compressed(out/f"{name}.npz", verts=verts, faces=faces)
        groups.append({"name": name, "faces": len(faces), "tris": len(faces), "tex": 256 if name == "Eye" else 512, "ink": 0.0,
                       "inkRatio": 1.0, "hard": False, "cage": 0.1, "flat": True})
    (out/"meta.json").write_text(json.dumps({"key": key, "scale": 10.0, "origin": [0.0, 1.0, 0.0], "groups": groups, "rig": None}, indent=1))


def storm_paint(key):
    out = Path("build/lobby/export")/key
    report = json.loads((out/"build.json").read_text())
    gpu = PieceGpu(key)
    for g in report["groups"]:
        px = np.load(out/g["positions"])[::-1]
        valid = np.abs(px[..., :3]).sum(axis=2) > 0
        bpos = px[..., :3][valid]
        pos = np.stack([bpos[:, 0], bpos[:, 2], -bpos[:, 1]], axis=1).astype("f4")
        a0, a1 = gpu.paint(pos, program="storm")
        h, w = valid.shape
        rgb, alpha = np.zeros((h, w, 3), "f4"), np.zeros((h, w, 3), "f4")
        rgb[valid], alpha[valid] = a0[:, :3], a1[:, :3]
        rgb, alpha = dilate(rgb, valid), dilate(alpha, valid)
        # The concept's tone mapping lifts these dark values a lot, so the map is lifted the same way.
        shown = to_srgb(np.clip(rgb*1.25, 0, 1))
        rgba = np.dstack([shown, np.clip(alpha[..., 0], 0, 1)])
        Image.fromarray((rgba*255 + 0.5).astype("u1"), "RGBA").save(out/"textures"/f"{g['name']}-color.png")
        g["color"] = f"textures/{g['name']}-color.png"
        g["alpha"] = g["name"] != "Eye"
        Image.fromarray(np.full((16, 16), 255, "u1")).save(out/"textures"/f"{g['name']}-emit.png")
        g["emit"] = f"textures/{g['name']}-emit.png"
        g["emissiveStrength"] = 1.0
        print(f"{g['name']}: mean cover {float(alpha[valid].mean()):.2f}", flush=True)
    (out/"build.json").write_text(json.dumps(report, indent=1))


def fx_textures():
    """Soft, white effect textures, tinted in Roblox: streaks down the falls, light shafts, mist, lightning."""
    folder = Path("build/lobby/fx")
    folder.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(7)

    def save(name, alpha):
        rgba = np.zeros((*alpha.shape, 4), "u1")
        rgba[..., :3] = 255
        rgba[..., 3] = (np.clip(alpha, 0, 1)*255).astype("u1")
        Image.fromarray(rgba, "RGBA").save(folder/f"{name}.png")

    def blur(a, axis, radius):
        kernel = np.exp(-(np.arange(-radius*3, radius*3 + 1)/radius)**2)
        kernel /= kernel.sum()
        return np.apply_along_axis(lambda line: np.convolve(np.r_[line, line, line], kernel, "same")[len(line):2*len(line)], axis, a)

    n = 256
    y, x = np.mgrid[-1:1:n*1j, -1:1:n*1j]
    r = np.hypot(x, y)
    streak = blur(blur(rng.random((n, n)), 0, 34), 1, 16)
    streak = (streak - streak.min())/(streak.max() - streak.min())
    save("streak", np.clip((streak - 0.35)*2.4, 0, 1)*np.exp(-(x/0.8)**4))
    shafts = blur(rng.random((1, n)), 1, 7)
    shafts = (shafts - shafts.min())/(shafts.max() - shafts.min())
    save("softbeam", np.exp(-(x/0.62)**2)*(0.55 + 0.75*shafts))
    puff = blur(blur(rng.random((n, n)), 0, 14), 1, 14)
    puff = (puff - puff.min())/(puff.max() - puff.min())
    save("mist", np.clip(1 - r, 0, 1)**1.4*(0.5 + puff))
    save("flash", np.exp(-(r/0.42)**2) + 0.25*np.exp(-(r/0.8)**2)*(r < 1))
    zig = 0.0*x
    px, py = 0.0, -0.8
    bolt = np.full(x.shape, 9.0)
    for _ in range(11):
        qx, qy = float(np.clip(px + rng.uniform(-0.3, 0.3), -0.6, 0.6)), py + 0.145
        ab = np.array([qx - px, qy - py])
        t = np.clip(((x - px)*ab[0] + (y - py)*ab[1])/ab.dot(ab), 0, 1)
        bolt = np.minimum(bolt, np.hypot(x - (px + t*ab[0]), y - (py + t*ab[1])))
        px, py = qx, qy
    save("zap", (np.exp(-(bolt/0.018)**2) + 0.5*np.exp(-(bolt/0.07)**2) + 0.0*zig)*np.exp(-(y/0.92)**8))
    for name, a in (("spore", np.clip(np.exp(-(r/0.32)**2) + 0.35*np.exp(-(r/0.75)**2), 0, 1)),):
        save(name, a)
    h, w = 512, 256
    def tile(sigma_y, sigma_x, seed):
        noise = blur(blur(np.random.default_rng(seed).random((h, w)), 0, sigma_y), 1, sigma_x)
        return (noise - noise.min())/(noise.max() - noise.min())
    x = np.linspace(-1, 1, w)[None, :].repeat(h, axis=0)
    left, right = tile(36, 200, 1)[:, :1], tile(36, 200, 2)[:, :1]
    edge = np.where(x < 0, 0.78 + 0.2*left, 0.78 + 0.2*right)
    across = np.clip(x/edge, -1, 1)
    alpha = np.clip((edge - np.abs(x))/0.09, 0, 1)
    bands = tile(30, 9, 3)
    shape = np.sqrt(1 - across**2)
    amount = np.clip(0.12 + 0.55*shape + 0.7*(bands - 0.5), 0, 1)[..., None]
    deep, bright = np.array((26, 128, 138), "f4"), np.array((104, 238, 224), "f4")
    colour = deep*(1 - amount) + bright*amount
    # The wet highlight down one side, wandering as it flows.
    wander = 0.25*(tile(44, 200, 4)[:, :1] - 0.5)
    shine = np.exp(-((across + 0.38 + wander)/0.13)**2)*(0.35 + 0.65*tile(24, 12, 5))
    colour = colour + (np.array((225, 255, 248), "f4") - colour)*(0.75*shine)[..., None]
    rgba = np.dstack([colour, alpha*255]).clip(0, 255).astype("u1")
    Image.fromarray(rgba, "RGBA").save(folder/"flow.png")
    # A ripple spreading on the juice where a fall lands.
    ring = np.exp(-((r - 0.72)/0.09)**2) + 0.35*np.exp(-((r - 0.45)/0.08)**2)
    save("ripple", ring*(r < 1))
    print("fx textures written")


def top_plate(gpu):
    """The outlines of the walkable top, rim and cracks together, measured just under its surface. Decimating the top
    left it lying over some grooves with their paint on it (owner: drawings with no depth), so the plate is built from
    these outlines with real holes (blender_hub_piece.py)."""
    step, n = 0.025, 704
    lo = np.array((-8.8, 12.98, -8.8))
    field = gpu.grid(lo, step, (n, 1, n))[:, 0, :, 0]
    verts, edges = [], []
    for loop in find_contours(field, 0.0):
        if len(loop) < 8 or not np.allclose(loop[0], loop[-1]):
            continue
        poly = approximate_polygon(loop, tolerance=0.45)[:-1]
        if len(poly) < 3:
            continue
        base = len(verts)
        verts += (poly*step + lo[[0, 2]]).tolist()
        edges += [(base + i, base + (i + 1) % len(poly)) for i in range(len(poly))]
    print(f"  top plate: {len(verts)} outline points", flush=True)
    return {"plateVerts": np.array(verts, "f4"), "plateEdges": np.array(edges, "i4"), "plateField": field.astype("f4"),
            "plateLo": lo[[0, 2]].astype("f4"), "plateStep": np.array(step, "f4")}


def sparkle_points(gpu, key, out, limit=45):
    piece = PIECES[key]
    data = np.load(out/f"{piece['sparkle']}.npz")
    verts, faces = data["verts"], data["faces"]
    edges = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]]])
    graph = coo_matrix((np.ones(len(edges), dtype="i1"), (edges[:, 0], edges[:, 1])), shape=(len(verts), len(verts)))
    count, labels = connected_components(graph, directed=False)
    sizes = np.bincount(labels, minlength=count)
    tips = []
    for label in np.argsort(sizes)[::-1][:limit]:
        if sizes[label] < 80:
            break
        v = verts[labels == label]
        tips.append(v[np.argmax(np.linalg.norm(v - v.mean(axis=0), axis=1))])
    tips = np.array(tips, "f4")
    _, emit = gpu.paint(tips)
    colours = emit[:, :3]/np.maximum(emit[:, :3].max(axis=1, keepdims=True), 1e-3)
    points = [{"p": ((t - np.array(piece["origin"]))*piece["scale"]).tolist(), "c": c.tolist()} for t, c in zip(tips, colours)]
    (out/"points.json").write_text(json.dumps(points))
    print(f"  {len(points)} twinkle points", flush=True)


def mesh(key):
    piece = PIECES[key]
    if piece.get("storm"):
        storm_mesh(key)
        return
    gpu = PieceGpu(key)
    print(f"{key}: sampling at {piece['step']} units = {piece['step']*piece['scale']:.2f} studs", flush=True)
    verts, faces = sparse_surface(gpu, piece["lo"], piece["hi"], piece["step"])
    print(f"{len(verts)} verts, {len(faces)} faces", flush=True)
    out = Path("build/lobby/meshes")/key
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.npz"):
        old.unlink()
    centres = verts[faces].mean(axis=1)
    if "components" in piece:
        chosen = split_components(verts, faces, piece["components"])
        tests = [chosen == i for i in range(len(piece["parts"]))]
    else:
        ids = gpu.ids(verts)
        face_ids = ids[faces]
        major = np.where(np.abs(face_ids[:, 1] - face_ids[:, 2]) < 0.01, face_ids[:, 1], face_ids[:, 0])
        taken = np.zeros(len(faces), dtype=bool)
        tests = []
        for spec in piece["parts"]:
            hit = spec["test"](major, centres) & ~taken
            taken |= hit
            tests.append(hit)
        for index, hit in enumerate(tests):
            for _ in range(piece.get("overlap", 0)):
                touched = np.zeros(len(verts), dtype=bool)
                touched[faces[hit]] = True
                hit = touched[faces].any(axis=1)
            tests[index] = hit
    groups = []
    for spec, hit in zip(piece["parts"], tests):
        sel = faces[hit]
        if len(sel) < 20:
            print(f"  {spec['name']}: empty, skipped")
            continue
        used, remap = np.unique(sel, return_inverse=True)
        extra = {}
        if "smooth" in piece:
            extra = dict(zip(("lowVerts", "lowFaces"), piece["smooth"]()))
        plate = key == "hub-rock" and spec["name"] == "Top"
        if plate:
            extra = top_plate(gpu)
        np.savez_compressed(out/f"{spec['name']}.npz", verts=verts[used], faces=remap.reshape(-1, 3).astype("i4"), **extra)
        groups.append({"name": spec["name"], "faces": int(len(sel)), "tris": spec["tris"], "tex": spec["tex"],
                       "ink": spec["ink"]/piece["scale"], "inkRatio": spec["inkRatio"], "hard": spec["hard"],
                       "cage": spec["cage"], "authored": bool(extra) and not plate, "plate": plate})
        print(f"  {spec['name']:10s} {len(sel):9d} dense faces -> {spec['tris']} tris", flush=True)
    if "sparkle" in piece:
        sparkle_points(gpu, key, out)
    meta = {"key": key, "scale": piece["scale"], "origin": list(piece["origin"]), "groups": groups, "rig": piece.get("rig")}
    (out/"meta.json").write_text(json.dumps(meta, indent=1))


EVEN_GLOW = {"Glow", "Sprouts", "Caps", "WellGlow"}
# Set by eye in Roblox: above about 1 blooms. The keystone and juice washed out to white at their measured strengths.
EMIT_STRENGTH = {"Cracks": 1.8, "Glow": 2.6, "Sprouts": 1.8, "Caps": 1.5, "WellGlow": 2.2, "Juice": 0.55, "Key": 1.1}


def paint(key):
    if PIECES[key].get("storm"):
        storm_paint(key)
        return
    out = Path("build/lobby/export")/key
    report = json.loads((out/"build.json").read_text())
    gpu = PieceGpu(key)
    for g in report["groups"]:
        for field in ("emit", "emissiveStrength"):
            g.pop(field, None)
        px = np.load(out/g["positions"])[::-1]
        valid = np.abs(px[..., :3]).sum(axis=2) > 0
        bpos = px[..., :3][valid]
        pos = np.stack([bpos[:, 0], bpos[:, 2], -bpos[:, 1]], axis=1).astype("f4")
        a0, a1 = gpu.paint(pos)
        # The bank's small caps are deepened for Roblox's glow, as in paint_texels (owner: pale and dull).
        small = (a0[:, 3] > 14.5) & (a0[:, 3] < 15.65)
        for a in (a0, a1):
            c = a[small, :3]
            a[small, :3] = c*c/np.maximum(c.max(axis=1, keepdims=True), 1e-4)
        h, w = valid.shape
        alb, emit = np.zeros((h, w, 3), "f4"), np.zeros((h, w, 3), "f4")
        alb[valid], emit[valid] = a0[:, :3], a1[:, :3]
        alb, emit = dilate(alb, valid), dilate(emit, valid)
        # Light that the concept paints into dark rock (the pit's glow, the fissures) is baked into the colour: no
        # runtime light has to reach it, which is what keeps this cheap on a phone.
        glowing_ids = (a0[:, 3] > 2.5) & ~((a0[:, 3] > 3.5) & (a0[:, 3] < 13.5))
        glowing = glowing_ids.mean() > 0.2
        keep = (glowing and not PIECES[key].get("bakeEmit")) or g["name"] == "Cracks"
        base = alb if keep else np.clip(alb*0.85 + emit*0.9, 0, 1)
        base = np.clip(base*PIECES[key].get("gain", 1.0), 0, 1)
        Image.fromarray((to_srgb(base)*255 + 0.5).astype("u1")).save(out/"textures"/f"{g['name']}-color.png")
        g["color"] = f"textures/{g['name']}-color.png"
        lum = emit.max(axis=2)
        even = g["name"] in EVEN_GLOW
        lit = valid & (lum > (0.03 if even else 0.25))
        if lit.sum() > 0.003*valid.sum():
            peak = float(np.percentile(lum[lit], 98))
            mask = np.clip((lum - 0.15)/max(peak - 0.15, 1e-3), 0, 1)
            if even:
                ratio = lum/np.maximum(alb.max(axis=2), 0.03)
                mask = np.clip(ratio/float(np.percentile(ratio[lit], 95)), 0, 1)**1.3
                # Mushroom caps always glow a little, top included (owner).
                ids = np.zeros((h, w), "f4")
                ids[valid] = a0[:, 3]
                caps = dilate(((ids >= 14.5) & (ids < 16.0))[..., None].astype("f4"), valid)[..., 0] > 0.5
                mask = np.where(caps, np.maximum(mask, 0.55), mask)
                # Stems stay plain, so the caps read as what glows.
                stems = dilate((np.abs(ids - 13.0) < 0.5)[..., None].astype("f4"), valid)[..., 0] > 0.5
                mask = np.where(stems, 0.0, mask)
            Image.fromarray((mask*255 + 0.5).astype("u1")).save(out/"textures"/f"{g['name']}-emit.png")
            over = base.max(axis=2)[valid & (mask > 0.5)]
            g["emit"] = f"textures/{g['name']}-emit.png"
            g["emissiveStrength"] = EMIT_STRENGTH.get(g["name"], round(min(4.0, peak/max(float(np.median(over)), 0.05)), 2))
        print(f"{g['name']}: {int(valid.sum())} texels" + (f", glow x{g['emissiveStrength']}" if "emit" in g else ""), flush=True)
    (out/"build.json").write_text(json.dumps(report, indent=1))


def build_in_blender(key):
    subprocess.run([BLENDER, "--background", "--factory-startup", "--python-exit-code", "1",
                    "--python", "tools/lobby/blender_hub_piece.py", "--", key], check=True, stdout=subprocess.DEVNULL)


def main():
    action, *keys = sys.argv[1:]
    if action == "fx":
        fx_textures()
        return
    if action == "list":
        total = 0
        for key, p in PIECES.items():
            count = sum(s["tris"] + (s["tris"]*s["inkRatio"] if s["ink"] else 0) for s in p["parts"])
            count *= 4 if key == "hub-bridge" else 1
            total += count
            print(f"{key:18s} {int(count):7d} tris with ink, {len(p['parts'])} parts")
        print(f"total {int(total)}")
        return
    for key in keys or list(PIECES):
        started = time.time()
        if action in ("mesh", "all"):
            mesh(key)
        if action == "all":
            build_in_blender(key)
        if action in ("paint", "all"):
            paint(key)
        print(f"{key}: {action} done in {time.time() - started:.0f}s", flush=True)


if __name__ == "__main__":
    main()
