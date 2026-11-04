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
import re
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
  if (id > 18.9 && id < 20.0) { crease = 0.0; idEdge = 0.0; }  // far smaller than the ink's sampling reach
  if (id > 1.15 && id < 1.2) { crease = 0.0; idEdge = 0.0; }
  if (id > 29.5 && id < 31.5) { crease = 0.0; idEdge = 0.0; }
  if (id > 37.5) { crease = 0.0; idEdge = 0.0; }  // lava meets lava with no line between
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


# The storm can't be a volume on a phone. It is one solid body, a funnel rising to the lit eye and reaching behind the rock at
# its rim, with a thin veil of cloud over it turning a little faster for depth. Separate flat sheets read as cut-off pieces.
STORM_RIM = 10.4
VEIL_RIM = 9.6


def storm_body_y(r):
    return 27.6 + 16.5*(1 - r/STORM_RIM)**1.6


def storm_veil_y(r):
    return 26.6 + 9.0*(1 - r/VEIL_RIM)**1.7


STORM_FIELD = """
uniform sampler2D uPos;
layout(location = 0) out vec4 o0;
layout(location = 1) out vec4 o1;
// The spiral's clouds. All of it is smooth round the circle, so it has no seam.
float stormField(vec2 x, float twist) {
  float rr = length(x), sw = atan(x.y, x.x) + 1.5*log(rr + 0.6) + twist;
  vec3 q = vec3(cos(sw)*rr*0.46, 1.7, sin(sw)*rr*0.46);
  float n = 0.55*noise3(q) + 0.3*noise3(q*2.2 + 7.0) + 0.15*noise3(q*4.7 + 3.0);
  return 0.8*n + 0.3*(0.5 + 0.5*sin(sw*3.0));
}
"""
STORM = STORM_FIELD + """
void main() {
  vec3 p = texelFetch(uPos, ivec2(gl_FragCoord.xy), 0).xyz;
  float rr = length(p.xz), v = stormField(p.xz, 0.0);
  // Folds lit on their leading edge, with a fine dark line where one meets the next.
  float ridge = clamp((v - stormField(p.xz, -0.14))*5.0, 0.0, 1.0);
  vec3 c = mix(vec3(0.012, 0.01, 0.024), vec3(0.05, 0.042, 0.09), smoothstep(0.38, 0.5, v));
  c = mix(c, vec3(0.2, 0.17, 0.3), smoothstep(0.47, 0.6, v)*(0.45 + 0.55*ridge));
  c = mix(c, vec3(0.3, 0.26, 0.42), smoothstep(0.62, 0.78, v)*ridge);
  c *= 1.0 - 0.75*(1.0 - smoothstep(0.0, 0.014, abs(v - 0.47)));
  c = mix(c, vec3(0.42, 0.4, 0.58), exp(-rr*rr*0.55));
  c *= 1.0 - 0.5*smoothstep(8.0, 10.0, rr);
  o0 = vec4(c, 0.0);
  o1 = vec4(1.0);
}
"""
STORM_VEIL = STORM_FIELD + """
void main() {
  vec3 p = texelFetch(uPos, ivec2(gl_FragCoord.xy), 0).xyz;
  float rr = length(p.xz), v = stormField(p.xz, 1.9);
  vec3 c = mix(vec3(0.05, 0.042, 0.09), vec3(0.26, 0.22, 0.38), smoothstep(0.5, 0.8, v));
  float a = smoothstep(0.46, 0.74, v)*(1.0 - smoothstep(6.2, 9.3, rr))*smoothstep(0.8, 2.4, rr)*0.8;
  o0 = vec4(c, 0.0);
  o1 = vec4(a);
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
    # The basin is its own game piece.
    basin = "  float basin = fallBasin(p);\n  if (basin < res.x) res = vec2(basin, 1.0);\n"
    assert basin in solid
    solid = solid.replace(basin, "")
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
    glow = glow.replace("  ceilingCrystals(p, res);\n  ceilingVines(p, res);\n", "")  # their own pieces
    # The shaft's crystals are behind the storm in the game, or would stick through it.
    glow = glow.replace(slice_between(glow, "  s = PI*2.0/13.0", "  // Vines trailing"), "")
    isles = slice_between(body, "  // Mini islands", "  // Loose debris")
    bits = slice_between(body, "  // Loose debris", "  // The spawn rock at true scale")
    return {
        # Clipped at the block-out's cavern wall and just above where the storm's rim meets it.
        "rock": f"vec2 assetMap(vec3 p) {{\n{head}{solid}  res.x = max(res.x, max(rr - 31.0, p.y - 30.0));\n  return res;\n}}\n",
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
POOLS = """vec2 assetMap(vec3 p) { return vec2(fallPool(p), 17.0); }
"""
BOWLS = """vec2 assetMap(vec3 p) { return vec2(fallBasin(p), 1.0); }
"""
ARCH = """vec2 assetMap(vec3 p) {
  float bowls = 1e3, fire = 1e3;
  vec2 r = vec2(plazaStage(p), 32.0);
  float py = plazaPylons(p, bowls, fire);
  if (py < r.x) r = vec2(py, 32.0);
  if (bowls < r.x) r = vec2(bowls, 33.0);
  // The molten heart in each pillar's slot.
  float heart = sdBox(vec3(abs(p.x) - 21.0, p.y - 6.2, p.z + 2.2), vec3(0.7, 3.3, 0.25));
  if (heart < r.x) r = vec2(heart, 34.0);
  return r;
}
"""
VOLCANO = """vec2 assetMap(vec3 p) {
  vec2 r = vec2(volcanoD(p), 37.0);
  float flow = volcanoFlow(p);
  if (flow < r.x) r = vec2(flow, 38.0);
  float pool = volcanoPool(p);
  if (pool < r.x) r = vec2(pool, 31.0);
  return r;
}
"""
# The slug side, sampled in the grove's own space: pond at the origin, mountain toward +z, one unit = 5 studs.
GROVE_ITEM = "slug-grove-1"
GROVE_MOUNTAIN = "vec2 assetMap(vec3 p) { return vec2(mountainD(p), 43.0); }\n"
# The ground stops at the cliff, the zone's edges and the wall, and settles to the level next door as it gets there.
GROVE_SOLID = "vec2 assetMap(vec3 p) { return vec2(mountainShell(p) + 0.06, 43.0); }\n"
GROVE_SHELL = "vec2 assetMap(vec3 p) { return vec2(mountainShell(p), 43.0); }\n"
GROVE_FLORA_MAP = "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 53.0); floraKind(p, KIND, res); return res; }\n"
GROVE_GROUND = """vec2 assetMap(vec3 p) {
  vec2 h = vec2(31.0 + p.z, p.x);
  float hr = length(h), a = atan(h.x, h.y);
  float clip = max(max(20.4 - hr, hr - 61.0), max(0.698 - a, a - 2.356)*hr);
  float g = (p.y - groveHeight(p.xz)*smoothstep(0.0, 3.0, -clip))*0.75;
  return vec2(max(g, clip), p.y < -0.09 ? 41.0 : 40.0);
}
"""
GROVE_WATER = """vec2 assetMap(vec3 p) {
  vec2 res = vec2(max(abs(p.y + 0.1) - 0.04, pondEdge(p.xz) - 1.5), 42.0);
  float heap = sdEll(p - vec3(0.4, -0.1, 8.1), vec3(3.3, 0.3, 1.5)) + 0.14*(noise3(p*3.0) - 0.5);
  if (heap*0.7 < res.x) res.x = heap*0.7;
  return res;
}
"""
GROVE_FALLS = "vec2 assetMap(vec3 p) { float along, tier; return vec2(groveFalls(p, along, tier), 44.0); }\n"
GROVE_ROCKS = "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 61.0); groveStones(p, res); groveRunes(p, res); return res; }\n"
GROVE_DRESS = "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 59.0); grovePads(p, res); groveBushes(p, res); groveVines(p, res); return res; }\n"
# The ground of the portal side: stops at the pit, the wall and the zone's edges. The ravine is gone (owner, 2026-11-03).
PLAZA_FLOOR = """vec2 assetMap(vec3 p) {
  float hr = length(p.xz + vec2(0.0, PZ_HUB)), a = atan(p.x, p.z + PZ_HUB), ch = plazaChannels(p.xz);
  float g = smax(p.y*0.8, -max(ch, -p.y - 0.4), 0.06);
  vec2 r = vec2(g, 30.0);
  float l = max(ch, abs(p.y + 0.24) - 0.05);
  if (l < r.x) r = vec2(l, 31.0);
  float clip = max(max(20.4 - hr, hr - 61.0), (abs(a) - 0.735)*hr);
  r.x = max(r.x, clip);
  return r;
}
"""
CEILING_VINES = """vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 12.0); ceilingVines(p, res); return res; }
"""
CEILING_GEMS = """vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 18.0); ceilingCrystals(p, res); return res; }
"""
BRIDGE = """vec2 assetMap(vec3 p) { return ropeBridge(p, 0.0, true); }
"""
PORTAL = """vec2 assetMap(vec3 p) { vec2 r = portal(p/GS); r.x *= GS; return r; }
"""
# The gun side's shop, Slugworks (docs/art/general-shop.md), from the canopy hole composite (asset 15, option A, clustered
# pods). Concept units are 5 studs; the hole's centre is the origin and the hub lies toward -z.
GUN_ITEM = "canopy-hole-1"
GUN_SHOP = "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 117.0); chShopBody(p, res); return res; }\n"


# The ground is nearly flat, at the floor you stand on; its velvet and cobbles are repeating maps (owner, 2026-11-04).
GUN_GROUND = "vec2 assetMap(vec3 p) { return chTerrainGame(p); }\n"
# The spire's roots, vines and shelves; its crystals and the floor's are the approved designs, placed by HubArt.
GUN_SPIRE = """vec2 assetMap(vec3 p) {
  vec2 res = vec2(1e3, 102.0);
  float r = length(p.xz);
  if (p.y < 0.6 && p.y > CH_FLOOR - 1.0 && (r < chSpireR(p.y) + 3.0 || (p.y < CH_FLOOR + 3.0 && r < 14.0))) chSpireGame(p, res);
  return res;
}
"""
# The cavern's wall pieces, each placed many times round the hole: cut flat inside the rock, where nothing shows.
GUN_PIECE = "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 102.0); CALL; res.x = max(res.x, p.z - 0.45); return res; }\n"
GUN_STONES = "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 115.0); chPathway(p, res); chRubble(p, res); return res; }\n"
GUN_STAR = "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 110.0); chFlowerC(p, vec3(0.0), 0.6, 1.0, COL, res); return res; }\n"
ZONE_SLAB = "vec2 assetMap(vec3 p) { return chZoneSlab(p); }\n"


def gun_velvet(lo, hi):
    return lambda ids, c: (np.abs(ids - 101.0) < 0.1) & (c[:, 0] >= lo) & (c[:, 0] < hi)


def gun_spire_rock(ids, c):
    return np.hypot(c[:, 0], c[:, 2]) < 8.5


def gun_floor_rock(ids, c):
    return c[:, 1] < -21.5


def gun_trees(ids, c):
    return (np.abs(ids - 103.0) < 0.1) | ((ids > 108.95) & (ids < 109.6))


def gun_walls(lo, hi):
    return lambda ids, c: (c[:, 0] >= lo) & (c[:, 0] < hi)


def gun_spire_roots(high):
    return lambda ids, c: (c[:, 1] > -12.0) == high


def gun_stones_top(ids, c):
    return c[:, 1] > 0.15


def shop_cap(ids, c):
    return ((np.abs(ids - 107.0) < 0.1) | ((ids > 109.2) & (ids < 109.4))) & (c[:, 1] > 5.0)


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


def energy_sheet(points):
    """The portal's surface: one flat arch per side, sharing every corner, with its edges tucked into the stone. Decimating
    the sampled surface left streaks and hairline cracks that read as shards (owner)."""
    lo, hi = points.min(axis=0), points.max(axis=0)
    inner = (hi[0] - lo[0])/2
    spring, foot, half = hi[1] - inner, lo[1] - 0.15, 0.04
    radius = inner + 0.2
    arc = [(radius*np.cos(a), spring + radius*np.sin(a)) for a in np.linspace(0, np.pi, 33)]
    rim = [(radius, foot)] + arc + [(-radius, foot)]
    verts, faces = [], []
    for side in (1, -1):
        centre = len(verts)
        verts.append((0.0, spring*0.6, side*half))
        verts.extend((x, y, side*half) for x, y in rim)
        for i in range(len(rim)):
            a, b = centre + 1 + i, centre + 1 + (i + 1) % len(rim)
            faces.append((centre, a, b) if side > 0 else (centre, b, a))
    return np.array(verts, "f4"), np.array(faces, "i4")


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
    return np.hypot(c[:, 0], c[:, 2]) < 20.8


def part(name, test, tris, tex, ink=0.0, ink_ratio=1.0, hard=False, cage=None, tile=None):
    return {"name": name, "test": test, "tile": tile, "tris": tris, "tex": tex, "ink": ink, "inkRatio": ink_ratio, "hard": hard, "cage": cage}


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


def pool_group(centre, _i):
    # One pool sits in each quarter of the pit.
    return int((np.arctan2(centre[2], centre[0]) % (2*np.pi))/(np.pi/2))


def debris_group(count):
    falls = json.loads(Path("experiments/lobby/scale/shared/rim_shape.json").read_text())["falls"]
    # Well mixed around the rock, so a group's pieces are never neighbours and they read as moving separately.
    def assign(centre, i):
        beside = min(abs(centre[0]), abs(centre[2]))
        if beside < 2.8 and centre[1] - 13.0 > -3.4 and np.hypot(centre[0], centre[2]) > 6.0:
            return -1
        # Nor in front of a waterfall (owner: rocks poking through it).
        ang, r = np.arctan2(centre[2], centre[0]), np.hypot(centre[0], centre[2])
        for fall in falls:
            if r > 8.5 and abs(np.arctan2(np.sin(ang - fall), np.cos(ang - fall)))*r < 4.5:
                return -1
        return i % count
    return assign


def well_bits_group(centre, i):
    # Inner pieces orbit twice as fast in the concept: three bobbing groups for each speed.
    return (0 if np.hypot(centre[0], centre[2]) < 6.0 else 3) + i % 3


# The same places as the shader's: on its tornado at their heights.
ISLANDS = [(a, 1.6 + 7.0*(min((17.0 + i*2.3 - 15.5)/12.5, 1.0))**1.5) for i, a in enumerate((0.52, 2.44, 3.75, 5.24, 1.48))]


def nearest_island(centre, _i):
    d = [np.hypot(centre[0] - np.cos(a)*r, centre[2] - np.sin(a)*r) for a, r in ISLANDS]
    return int(np.argmin(d))


def storm_surface(rim, height):
    """A round surface seen from below, denser toward the middle where the funnel curves most."""
    rings, sides = 14, 64
    verts = [(0.0, height(0.0), 0.0)]
    for ring in range(1, rings + 1):
        radius = rim*(ring/rings)**1.25
        for side in range(sides):
            angle = 2*np.pi*side/sides
            verts.append((radius*np.cos(angle), height(radius), radius*np.sin(angle)))
    faces = []
    for side in range(sides):
        faces.append((0, 1 + side, 1 + (side + 1) % sides))
    for ring in range(rings - 1):
        base = 1 + ring*sides
        for side in range(sides):
            a, b = base + side, base + (side + 1) % sides
            faces += [(a, a + sides, b), (b, a + sides, b + sides)]
    return np.array(verts, "f4"), np.array(faces, "i4")


def storm_discs():
    return {"StormBody": storm_surface(STORM_RIM, storm_body_y), "StormVeil": storm_surface(VEIL_RIM, storm_veil_y)}


def grove_chunk(x0, x1, z0, z1):
    return lambda _ids, c: (c[:, 0] >= x0) & (c[:, 0] < x1) & (c[:, 2] >= z0) & (c[:, 2] < z1)


def grove_middle(_ids, c):
    return (np.abs(c[:, 0]) < 13.0) & (c[:, 2] < 30.0)


def grove_side(sign):
    return lambda _ids, c: (c[:, 0]*sign >= 13.0) & (c[:, 2] < 30.0)


def gate_piece(direction, r):
    lo, hi = {0: ((-3.7, 11.8, -r - 1.25), (3.7, 16.3, -r + 1.25)), 1: ((r - 1.25, 11.8, -3.7), (r + 1.25, 16.3, 3.7)),
              2: ((-3.7, 11.8, r - 1.25), (3.7, 16.3, r + 1.25)), 3: ((-r - 1.25, 11.8, -3.7), (-r + 1.25, 16.3, 3.7))}[direction]
    return {
        "item": "spawn-rock-1", "map": GATE, "scale": 5.0, "origin": (0.0, 13.0, 0.0), "lo": lo, "hi": hi, "step": 0.022,
        "normalH": 0.004, "gain": 1.45,
        "parts": [
            part("Stone", by_id((0.5, 1.9)), 2000, 512, PROP_INK, 0.6, cage=0.03),
            part("Rope", by_id((1.9, 3.0)), 2600, 1024, 0.0, cage=0.012),
            part("Key", by_id((15.9, 16.5)), 300, 1024, FINE_INK, 1.0, hard=True, cage=0.02),
        ],
    }


PLAZA_PYLONS = ((6.2, -8.5), (14.0, -11.0))


def near_pylon(_ids, c):
    x = np.abs(c[:, 0])
    return np.min([np.hypot(x - px, c[:, 2] - pz) for px, pz in PLAZA_PYLONS], axis=0) < 2.2


def arch_side(sign):
    def test(_ids, c):
        return (np.hypot(c[:, 0], c[:, 1] - 12.0) > 17.0) & (c[:, 1] > 12.7) & (c[:, 0]*sign >= 0)
    return test


def near_pillar(_ids, c):
    return np.abs(np.abs(c[:, 0]) - 21.0) < 6.5


def near_bits(_ids, c):
    bits = ((-10.2, 31.0, 0.2), (-8.0, 29.4, 1.5), (-9.2, 27.3, -0.4), (13.0, 28.0, 0.2), (11.0, 26.0, 1.3))
    return np.min([np.linalg.norm(c - np.array(b), axis=1) for b in bits], axis=0) < 1.5


def below_floor(_ids, c):
    return c[:, 1] < -0.03


def volcano_front(_ids, c):
    return c[:, 2] < 25.0


def portal_piece(item, scale):
    return {
        "item": item, "map": PORTAL, "scale": scale, "origin": (0.0, 0.0, 0.0), "lo": (-12.0, -0.3, -5.5), "hi": (12.0, 22.0, 5.5),
        "step": 0.05, "normalH": 0.004,
        "parts": [
            part("Stone", by_id((5.5, 6.5)), 3600, 1024, ROCK_INK, 0.4, hard=True, cage=0.06),
            part("Iron", by_id((6.5, 7.5)), 1400, 512, PROP_INK, 0.5, cage=0.04),
            part("Gem", by_id((7.5, 8.5)), 500, 256, PROP_INK, 1.0, hard=True, cage=0.04),
            part("Energy", everything, 136, 512, cage=0.05),
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
            part("Roots", by_id((3.5, 4.5)), 4500, 1024, PROP_INK*0.7, 0.7, cage=0.02),
            part("Glow", by_id((15.69, 16.0), (17.5, 20.0), (3.0, 3.5)), 4000, 1024, PROP_INK*1.1, 1.0, cage=0.02),
            part("Flora", everything, 4500, 1024, FINE_INK, 1.0, cage=0.015),
        ],
    },
    "hub-rock-debris": {
        "item": "spawn-rock-1", "map": ROCK_DEBRIS, "scale": 5.0, "origin": (0.0, 13.0, 0.0),
        "lo": (-15.0, 3.0, -15.0), "hi": (15.0, 13.0, 15.0), "step": 0.03, "normalH": 0.004,
        "components": debris_group(3), "gain": 1.7,
        "parts": [part(f"Debris{i}", None, 1300, 256, PROP_INK, 1.0, hard=True, cage=0.02) for i in range(3)],
    },
    "hub-gate-0": gate_piece(0, 6.6),
    "hub-gate-1": gate_piece(1, 6.85),
    "hub-gate-2": gate_piece(2, 6.25),
    "hub-gate-3": gate_piece(3, 6.3),
    "hub-bridge": {
        "item": "bridge-1", "map": BRIDGE, "scale": 2.55, "origin": (0.0, 0.0, 0.0),
        "lo": (-11.2, -3.0, -4.2), "hi": (11.8, 3.6, 4.2), "step": 0.022, "normalH": 0.004, "rig": "bridge",
        "parts": [
            part("Lantern", by_id((2.5, 2.7), (13.7, 13.9)), 1500, 512, FINE_INK, 1.0, hard=True, cage=0.015),
            part("Deck", by_id((1.9, 2.3), (2.7, 3.0)), 2600, 1024, FINE_INK*1.2, 1.0, cage=0.03),
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
    "hub-portal-pvp": portal_piece("gate-pvp-1", 2.5),
    "hub-portal-training": portal_piece("gate-training-1", 1.6),
    "hub-portal-veylume": portal_piece("gate-veylume-1", 1.6),
    "hub-gems": {
        "item": "spawn-rock-1", "map": "minis", "scale": 5.0, "origin": (0.0, 13.0, 0.0), "sparkle": "Minis", "bakeEmit": True,
        "lo": (-8.0, 12.3, -8.0), "hi": (8.0, 13.6, 8.0), "step": 0.0075, "normalH": 0.0015,
        "parts": [
            part("Sprouts", in_sprouts, 1500, 256, FINE_INK*0.6, 1.0, cage=0.006),
            part("Minis", everything, 4600, 512, FINE_INK*0.7, 1.0, hard=True, cage=0.006),
        ],
    },
    # The falls' stone basins, and the pools that fill them. A pool is round, so it can turn in place.
    "hub-basin": {
        "item": "maelstrom-1", "map": POOLS, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "uRo": (0.0, 30.0, 0.0),
        "lo": (-21.0, -2.5, -21.0), "hi": (21.0, -2.0, 21.0), "step": 0.03, "normalH": 0.006, "bakeEmit": True,
        "components": pool_group,
        "parts": [part(f"Pool{i}", None, 240, 512, cage=0.03) for i in range(4)],
    },
    "hub-bowl": {
        "item": "maelstrom-1", "map": BOWLS, "scale": 5.0, "origin": (0.0, 0.0, 0.0),
        "lo": (-21.0, -4.0, -21.0), "hi": (21.0, -2.0, 21.0), "step": 0.02, "normalH": 0.005,
        "components": pool_group,
        "parts": [part(f"Bowl{i}", None, 500, 512, ROCK_INK*0.7, 1.0, cage=0.03) for i in range(4)],
    },
    "hub-storm": {
        "item": "sky-well-1", "map": "bits", "scale": 10.0, "origin": (0.0, 1.0, 0.0), "normalH": 0.01, "storm": True,
        "parts": [part("StormBody", None, 1700, 1024), part("StormVeil", None, 1700, 1024)],
    },
    "hub-well-rock": {
        "item": "sky-well-1", "map": "rock", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-31.5, 16.5, -31.5), "hi": (31.5, 37.0, 31.5), "step": 0.08, "normalH": 0.012, "overlap": 4,
        "parts": [
            part("Crown", by_id((1.02, 1.09)), 3000, 1024, ROCK_INK*1.4, 1.0, hard=True, cage=0.1),
            part("Ring", by_id((1.15, 1.175)), 4600, 1024, ROCK_INK, 1.0, hard=True, cage=0.06),
            part("Pendants", by_id((1.175, 1.2)), 900, 1024, ROCK_INK*1.2, 1.0, hard=True, cage=0.08),
            part("BorderA", lambda ids, c: by_id((1.115, 1.13))(ids, c) & (c[:, 2] < 0), 2600, 1024, ROCK_INK*1.3, 1.0, hard=True, cage=0.12),
            part("BorderB", by_id((1.115, 1.13)), 2600, 1024, ROCK_INK*1.3, 1.0, hard=True, cage=0.12),
            part("Spires", by_id((1.09, 1.15)), 5000, 1024, ROCK_INK*1.4, 1.0, hard=True, cage=0.12),
            part("Mouth", inner_ring, 4500, 1024, ROCK_INK*1.2, 1.0, cage=0.1),
            *[part(f"Cave{i}", in_section(i, 4), 2200, 1024, cage=0.25) for i in range(4)],
        ],
    },
    "hub-arch": {
        "item": "portal-plaza-7", "map": ARCH, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 2, "gain": 2.7,
        "lo": (-28.0, -0.4, -14.0), "hi": (28.0, 33.0, 8.0), "step": 0.05, "normalH": 0.006,
        "parts": [
            part("Pylons", near_pylon, 2600, 1024, PROP_INK, 1.0, hard=True, cage=0.05),
            part("ArchBits", near_bits, 240, 256, PROP_INK, 1.0, hard=True, cage=0.05),
            part("ArchL", arch_side(-1), 1900, 1024, ROCK_INK, 1.0, hard=True, cage=0.08),
            part("ArchR", arch_side(1), 1400, 1024, ROCK_INK, 1.0, hard=True, cage=0.08),
            part("Pillars", near_pillar, 3400, 1024, ROCK_INK, 1.0, cage=0.08),
            part("Base", everything, 1000, 512, ROCK_INK, 1.0, hard=True, cage=0.08),
        ],
    },
    "hub-volcano": {
        "item": "portal-plaza-7", "map": VOLCANO, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 3,
        "lo": (-25.0, -1.2, -3.0), "hi": (25.0, 35.5, 48.0), "step": 0.08, "normalH": 0.012,
        "parts": [
            part("Pool", by_id((30.5, 31.5)), 700, 1024, cage=0.06),
            part("Flows", by_id((37.5, 38.5)), 4800, 1024, FINE_INK*1.5, 1.0, cage=0.06),
            part("VolcanoFront", volcano_front, 6000, 1024, ROCK_INK*1.2, 1.0, cage=0.15),
            part("VolcanoBack", everything, 1400, 512, cage=0.2),
        ],
    },
    # The mesh is the flat-faced "shell"; the layered rock in "map" is baked onto it as colour and normals, so it can be run on (owner).
    "hub-gun-shop": {
        "item": GUN_ITEM, "map": GUN_SHOP, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.6,
        "lo": (-9.0, -0.7, -9.5), "hi": (9.6, 9.6, 9.0), "step": 0.02, "normalH": 0.004,
        "parts": [
            # Owner, 2026-11-04: sloppy outlines, windows cut off, low resolution. Each part its own map, more triangles.
            part("Cap", shop_cap, 10000, 1024, PROP_INK*2.0, 1.0, cage=0.05),
            part("Trunk", by_id((101.9, 102.1)), 5000, 1024, PROP_INK*1.2, 1.0, cage=0.03),
            part("Shrooms", by_id((102.9, 103.1), (106.9, 107.1), (108.95, 109.6)), 3500, 512, FINE_INK*1.5, 1.0, cage=0.02),
            part("PodsHigh", lambda ids, c: c[:, 1] > 3.3, 8000, 1024, PROP_INK, 1.0, cage=0.04),
            part("Pods", everything, 10000, 1024, PROP_INK, 1.0, cage=0.04),
        ],
    },
    "hub-gun-ground": {
        "item": GUN_ITEM, "map": GUN_GROUND, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 2, "gain": 1.6,
        "lo": (-47.0, -28.5, -27.5), "hi": (43.0, 1.2, 21.0), "step": 0.06, "normalH": 0.006,
        "parts": [
            # Owner, 2026-11-04: the velvet looked low resolution. Flat, with a map repeating every 30 studs. The path is its
            # own piece (hub-gun-path).
            part("VelvetA", gun_velvet(-99.0, -15.0), 4000, 1024, tile=6.0),
            part("VelvetB", gun_velvet(-15.0, 15.0), 4000, 1024, tile=6.0),
            part("VelvetC", gun_velvet(15.0, 99.0), 4000, 1024, tile=6.0),
            part("Spire", gun_spire_rock, 5000, 1024, ROCK_INK, 0.7, cage=0.08),
            part("HoleFloor", gun_floor_rock, 4000, 1024, cage=0.08),
            part("WallsA", gun_walls(-99.0, -6.0), 8000, 1024, ROCK_INK, 0.7, cage=0.08),
            part("WallsB", gun_walls(-6.0, 6.0), 8000, 1024, ROCK_INK, 0.7, cage=0.08),
            part("WallsC", everything, 8000, 1024, ROCK_INK, 0.7, cage=0.08),
        ],
    },
    "hub-gun-spire": {
        "item": GUN_ITEM, "map": GUN_SPIRE, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-15.0, -25.0, -15.0), "hi": (15.0, 0.6, 15.0), "step": 0.016, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 4500, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 3200, 512, FINE_INK, 1.0, cage=0.012),
            part("Shelves", by_id((105.9, 107.1)), 4500, 1024, FINE_INK*1.5, 1.0, cage=0.02),
            part("RootsHi", gun_spire_roots(True), 7000, 1024, PROP_INK, 1.0, cage=0.03),
            part("RootsLo", everything, 7000, 1024, PROP_INK, 1.0, cage=0.03),
        ],
    },
    # The cavern (owner, 2026-11-04: roots low quality, vines mushed into glow, cuts in the side mushrooms' caps): each
    # piece modelled once on its own, with the detail it needs, and placed round the hole by HubArt from gun_side.json.
    "hub-gun-root-a": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chRootPiece(p, 0.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-2.0, -15.6, -1.7), "hi": (2.8, 0.9, 0.5), "step": 0.012, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 1300, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 1000, 512, FINE_INK, 1.0, cage=0.012),
            part("Roots", everything, 2000, 1024, PROP_INK, 1.0, cage=0.03),
        ],
    },
    "hub-gun-root-b": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chRootPiece(p, 1.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-2.0, -13.4, -1.7), "hi": (2.0, 0.9, 0.5), "step": 0.012, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 1300, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 1000, 512, FINE_INK, 1.0, cage=0.012),
            part("Roots", everything, 2400, 1024, PROP_INK, 1.0, cage=0.03),
        ],
    },
    "hub-gun-root-c": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chRootPiece(p, 2.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-2.0, -9.4, -1.7), "hi": (2.0, 0.9, 0.5), "step": 0.012, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 900, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 700, 512, FINE_INK, 1.0, cage=0.012),
            part("Roots", everything, 1400, 1024, PROP_INK, 1.0, cage=0.03),
        ],
    },
    "hub-gun-shelves-a": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chShelfPiece(p, 0.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-1.7, -2.0, -2.2), "hi": (1.9, 1.0, 0.5), "step": 0.007, "normalH": 0.003,
        "parts": [
            part("Shelves", everything, 1100, 512, FINE_INK*1.5, 1.0, cage=0.015),
        ],
    },
    "hub-gun-shelves-b": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chShelfPiece(p, 1.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-1.7, -2.4, -2.2), "hi": (1.9, 1.0, 0.5), "step": 0.007, "normalH": 0.003,
        "parts": [
            part("Shelves", everything, 1400, 512, FINE_INK*1.5, 1.0, cage=0.015),
        ],
    },
    "hub-gun-sideshroom-a": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chSideShroom(p, 0.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-2.0, -0.9, -3.8), "hi": (2.0, 3.3, 0.5), "step": 0.009, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 800, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 700, 512, FINE_INK, 1.0, cage=0.012),
            part("Stem", by_id((102.9, 103.1)), 1200, 512, PROP_INK, 1.0, cage=0.02),
            part("Cap", everything, 2600, 1024, PROP_INK, 1.0, cage=0.02),
        ],
    },
    "hub-gun-sideshroom-b": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chSideShroom(p, 2.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-2.0, -0.9, -3.8), "hi": (2.0, 3.3, 0.5), "step": 0.009, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 800, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 700, 512, FINE_INK, 1.0, cage=0.012),
            part("Stem", by_id((102.9, 103.1)), 1200, 512, PROP_INK, 1.0, cage=0.02),
            part("Cap", everything, 2600, 1024, PROP_INK, 1.0, cage=0.02),
        ],
    },
    "hub-gun-vine-a": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chHangVine(p, 0.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-0.4, -3.2, -1.0), "hi": (0.7, 0.3, 0.5), "step": 0.005, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 450, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 350, 512, FINE_INK, 1.0, cage=0.012),
        ],
    },
    "hub-gun-vine-b": {
        "item": GUN_ITEM, "map": GUN_PIECE.replace("CALL", "chHangVine(p, 1.0, res)"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.5,
        "lo": (-0.4, -4.8, -1.0), "hi": (0.7, 0.3, 0.5), "step": 0.005, "normalH": 0.003,
        "parts": [
            part("Beads", by_id((103.9, 104.1)), 650, 512, FINE_INK*0.8, 1.0, cage=0.012),
            part("Vines", by_id((104.9, 105.1)), 450, 512, FINE_INK, 1.0, cage=0.012),
        ],
    },
    # The cobble path (owner, 2026-11-04): real cobbles, raised kerb stones, running on to the rope bridge and breaking up
    # there. Its own piece so it can be sampled finely; the ground under it dips.
    "hub-gun-path": {
        "item": GUN_ITEM, "map": "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 113.0); chPathGame(p, res); return res; }\n",
        "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.6,
        "lo": (-2.0, -0.36, -23.6), "hi": (2.0, 0.3, -14.4), "step": 0.01, "normalH": 0.002,
        "parts": [
            part("Kerb", by_id((115.9, 116.1)), 3500, 1024, FINE_INK*1.2, 1.0, cage=0.012),
            part("PathNear", lambda ids, c: c[:, 2] > -17.6, 12000, 1024, cage=0.01),
            part("PathFar", everything, 12000, 1024, cage=0.01),
        ],
    },
    # The shop's cobble mat (owner, 2026-11-04: too perfect a circle; then faceted at the shop's coarser sampling).
    # The shop's sign (owner, 2026-11-04: the name blurred from a distance): raised, outlined letters, sampled finely.
    # The shop's windows, door and doorframe (owner, 2026-11-04: messy outlines, the door's glow at its corners).
    "hub-gun-trim": {
        "item": GUN_ITEM, "map": "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 118.0); chShopTrim(p, res); return res; }\n",
        "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.6,
        "lo": (-6.2, -0.2, -4.4), "hi": (6.2, 7.0, 4.6), "step": 0.008, "normalH": 0.002,
        "parts": [
            part("Glass", by_id((118.9, 119.1)), 2000, 512, cage=0.01),
            part("Door", by_id((119.9, 120.1)), 800, 512, cage=0.01),
            part("Rims", everything, 10000, 1024, FINE_INK*1.3, 1.0, hard=True, cage=0.01),
        ],
    },
    "hub-gun-sign": {
        "item": GUN_ITEM, "map": "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 121.0); chShopSign(p, res); return res; }\n",
        "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.6,
        "lo": (-1.0, 2.45, -3.45), "hi": (1.0, 3.5, -2.45), "step": 0.004, "normalH": 0.001,
        "parts": [
            part("Letters", by_id((123.9, 124.1)), 4500, 512, FINE_INK*0.6, 1.0, cage=0.006),
            part("Plate", everything, 1500, 1024, FINE_INK*1.5, 1.0, hard=True, cage=0.01),
        ],
    },
    "hub-gun-mat": {
        "item": GUN_ITEM, "map": "vec2 assetMap(vec3 p) { vec2 res = vec2(1e3, 113.0); chShopMat(p, res); return res; }\n",
        "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.6,
        "lo": (-2.3, -0.3, -6.2), "hi": (2.3, 0.2, -2.7), "step": 0.006, "normalH": 0.0015,
        "parts": [part("Mat", everything, 6000, 1024, FINE_INK, 1.0, cage=0.008)],
    },
    "hub-gun-stones": {
        "item": GUN_ITEM, "map": GUN_STONES, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1, "gain": 1.4,
        "lo": (-5.5, -4.6, -16.6), "hi": (5.5, 1.8, -3.8), "step": 0.012, "normalH": 0.003,
        "parts": [
            part("Stones", gun_stones_top, 9000, 1024, ROCK_INK, 0.7, cage=0.03),
            part("Rubble", everything, 3000, 512, ROCK_INK, 0.7, cage=0.02),
        ],
    },
    "hub-flora-gunstar-a": {
        "item": GUN_ITEM, "map": GUN_STAR.replace("COL", "0.0"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.3,
        "lo": (-0.45, -0.15, -0.45), "hi": (0.45, 0.85, 0.45), "step": 0.006, "normalH": 0.002,
        "parts": [part("Plant", everything, 1000, 512, FINE_INK*0.9, 1.0, cage=0.012)],
    },
    "hub-flora-gunstar-b": {
        "item": GUN_ITEM, "map": GUN_STAR.replace("COL", "1.0"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.3,
        "lo": (-0.45, -0.15, -0.45), "hi": (0.45, 0.85, 0.45), "step": 0.006, "normalH": 0.002,
        "parts": [part("Plant", everything, 1000, 512, FINE_INK*0.9, 1.0, cage=0.012)],
    },
    "hub-zone-slab": {
        "item": GUN_ITEM, "map": ZONE_SLAB, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.4,
        "lo": (-1.0, -0.05, -0.8), "hi": (1.0, 0.3, 0.8), "step": 0.008, "normalH": 0.003,
        "parts": [part("Slab", everything, 700, 512, ROCK_INK, 0.7, cage=0.02)],
    },
    "hub-grove-mountain": {
        "item": GROVE_ITEM, "map": GROVE_MOUNTAIN, "shell": GROVE_SHELL, "shellStep": 0.2, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 3,
        "gain": 3.0, "bakeEmit": True, "lo": (-50.0, -1.2, -1.0), "hi": (50.0, 38.0, 60.0), "step": 0.06, "normalH": 0.004,
        "parts": [
            part("MountainM", grove_middle, 9000, 2048, ROCK_INK*2.2, 1.0, hard=True, cage=0.7),
            part("MountainA", grove_side(1), 6000, 2048, ROCK_INK*2.2, 1.0, hard=True, cage=0.7),
            part("MountainB", grove_side(-1), 6000, 2048, ROCK_INK*2.2, 1.0, hard=True, cage=0.7),
            part("MountainBack", everything, 1500, 1024, hard=True, cage=0.7),
        ],
    },
    # What players touch on the mountain, hidden just under its surface. One shape over the whole mountain makes Roblox's collision
    # bridge the valleys between peaks with invisible walls, so it comes in chunks small enough to fit tightly.
    "hub-grove-solid": {
        "item": GROVE_ITEM, "map": GROVE_SOLID, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 1,
        "lo": (-50.0, -1.2, -1.0), "hi": (50.0, 38.0, 60.0), "step": 0.12, "normalH": 0.01,
        "parts": [part(f"Solid{i}{j}", grove_chunk(-50.0 + i*100.0/7, -50.0 + (i + 1)*100.0/7, -1.0 + j*61.0/5, -1.0 + (j + 1)*61.0/5), 700, 64, cage=0.1)
                  for i in range(7) for j in range(5)],
    },
    "hub-grove-ground": {
        "item": GROVE_ITEM, "map": GROVE_GROUND, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 2, "gain": 2.2, "bakeEmit": True,
        "lo": (-48.0, -1.6, -20.0), "hi": (48.0, 3.0, 31.0), "step": 0.06, "normalH": 0.006,
        "parts": [
            part("Bed", by_id((40.5, 41.5)), 1200, 1024, cage=0.05),
            part("Ground", everything, 7000, 2048, cage=0.08),
        ],
    },
    "hub-grove-water": {
        "item": GROVE_ITEM, "map": GROVE_WATER, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.3,
        "lo": (-11.0, -0.5, -11.0), "hi": (11.0, 0.6, 13.0), "step": 0.03, "normalH": 0.006,
        "parts": [part("Pond", everything, 1500, 1024, cage=0.03)],
    },
    "hub-grove-falls": {
        "item": GROVE_ITEM, "map": GROVE_FALLS, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.3,
        "lo": (-6.0, -0.5, 4.0), "hi": (6.0, 24.0, 27.0), "step": 0.05, "normalH": 0.03,
        "parts": [part("Falls", everything, 3000, 1024, FINE_INK*2.0, 1.0, cage=0.03)],
    },
    "hub-grove-rocks": {
        "item": GROVE_ITEM, "map": GROVE_ROCKS, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 2.2, "bakeEmit": True,
        "lo": (-34.0, -1.0, -20.0), "hi": (34.0, 26.0, 34.0), "step": 0.03, "normalH": 0.006,
        "parts": [
            part("Runes", by_id((61.5, 62.5)), 400, 512, PROP_INK, 1.0, hard=True, cage=0.03),
            part("Stones", everything, 4500, 1024, ROCK_INK, 0.7, cage=0.04),
        ],
    },
    "hub-grove-dress": {
        "item": GROVE_ITEM, "map": GROVE_DRESS, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.5,
        "lo": (-34.0, -0.6, -20.0), "hi": (34.0, 30.0, 34.0), "step": 0.025, "normalH": 0.005,
        "parts": [
            part("Bushes", by_id((58.5, 59.5)), 3000, 1024, FINE_INK, 0.7, cage=0.03),
            part("Vines", by_id((59.5, 60.5)), 1200, 512, FINE_INK, 1.0, cage=0.015),
            part("Pads", everything, 600, 512, FINE_INK, 1.0, cage=0.015),
        ],
    },
    "hub-flora-star": {
        "item": GROVE_ITEM, "map": GROVE_FLORA_MAP.replace("KIND", "0.0"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.25,
        "lo": (-1.0, -0.3, -1.0), "hi": (1.0, 1.25, 1.0), "step": 0.006, "normalH": 0.002,
        "parts": [part("Plant", everything, 1400, 512, FINE_INK*0.9, 1.0, cage=0.012)],
    },
    "hub-flora-bell": {
        "item": GROVE_ITEM, "map": GROVE_FLORA_MAP.replace("KIND", "1.0"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.25,
        "lo": (-1.0, -0.3, -1.0), "hi": (1.0, 1.25, 1.0), "step": 0.006, "normalH": 0.002,
        "parts": [part("Plant", everything, 1500, 512, FINE_INK*0.9, 1.0, cage=0.012)],
    },
    "hub-flora-lantern": {
        "item": GROVE_ITEM, "map": GROVE_FLORA_MAP.replace("KIND", "2.0"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.25,
        "lo": (-1.0, -0.3, -1.0), "hi": (1.0, 1.25, 1.0), "step": 0.006, "normalH": 0.002,
        "parts": [part("Plant", everything, 1500, 512, FINE_INK*0.9, 1.0, cage=0.012)],
    },
    "hub-flora-plant": {
        "item": GROVE_ITEM, "map": GROVE_FLORA_MAP.replace("KIND", "3.0"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.25,
        "lo": (-1.0, -0.3, -1.0), "hi": (1.0, 1.25, 1.0), "step": 0.006, "normalH": 0.002,
        "parts": [part("Plant", everything, 1300, 512, FINE_INK*0.9, 1.0, cage=0.012)],
    },
    "hub-flora-grass": {
        "item": GROVE_ITEM, "map": GROVE_FLORA_MAP.replace("KIND", "4.0"), "scale": 5.0, "origin": (0.0, 0.0, 0.0), "gain": 1.25,
        "lo": (-1.0, -0.3, -1.0), "hi": (1.0, 1.25, 1.0), "step": 0.005, "normalH": 0.002,
        "parts": [part("Plant", everything, 520, 256, FINE_INK*0.9, 1.0, cage=0.012)],
    },
    "hub-plaza-floor": {
        "item": "portal-plaza-7", "map": PLAZA_FLOOR, "scale": 5.0, "origin": (0.0, 0.0, 0.0), "overlap": 2, "gain": 2.4,
        "lo": (-42.0, -0.5, -18.0), "hi": (42.0, 0.3, 30.0), "step": 0.05, "normalH": 0.006,
        "parts": [
            # Its own part, on a repeating map: sharing the floor's left it a few blurry pixels per stud (owner).
            part("Lava", by_id((30.5, 31.5)), 900, 1024, tile=6.0),
            part("Cracks", below_floor, 3600, 1024, cage=0.05),
            part("Floor", everything, 2400, 1024, cage=0.08),
        ],
    },
    "hub-ceiling-vines": {
        "item": "sky-well-1", "map": CEILING_VINES, "scale": 10.0, "origin": (0.0, 1.0, 0.0), "gain": 1.5,
        "lo": (-32.0, 12.0, -32.0), "hi": (32.0, 29.5, 32.0), "step": 0.025, "normalH": 0.004,
        "parts": [part("CeilVines", everything, 10000, 1024, FINE_INK*1.6, 1.0, cage=0.03)],
    },
    "hub-ceiling-gems": {
        "item": "sky-well-1", "map": CEILING_GEMS, "scale": 10.0, "origin": (0.0, 1.0, 0.0), "sparkle": "CeilGems",
        "lo": (-32.0, 17.5, -32.0), "hi": (32.0, 29.5, 32.0), "step": 0.03, "normalH": 0.004,
        "parts": [
            part("CollarGems", lambda _ids, c: np.hypot(c[:, 0], c[:, 2]) < 13.0, 1500, 512, PROP_INK, 1.0, hard=True, cage=0.02),
            part("BorderGems", lambda _ids, c: np.hypot(c[:, 0], c[:, 2]) > 25.6, 2200, 1024, PROP_INK*1.3, 1.0, hard=True, cage=0.03),
            part("CeilGems", everything, 3200, 1024, PROP_INK*1.3, 1.0, hard=True, cage=0.03),
        ],
    },
    "hub-well-glow": {
        "item": "sky-well-1", "map": "glow", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-16.0, 15.0, -16.0), "hi": (16.0, 37.0, 16.0), "step": 0.035, "normalH": 0.005, "sparkle": "WellGlow",
        "parts": [part("WellGlow", everything, 4000, 1024, PROP_INK*1.3, 0.8, cage=0.03)],
    },
    "hub-well-isles": {
        "item": "sky-well-1", "map": "isles", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-11.0, 14.0, -11.0), "hi": (11.0, 30.0, 11.0), "step": 0.022, "normalH": 0.004,
        "components": nearest_island, "gain": 1.5,
        "parts": [part(f"Isle{i}", None, 700, 256, PROP_INK*1.3, 0.8, hard=True, cage=0.02) for i in range(5)],
    },
    "hub-well-bits": {
        "item": "sky-well-1", "map": "bits", "scale": 10.0, "origin": (0.0, 1.0, 0.0),
        "lo": (-11.0, 14.0, -11.0), "hi": (11.0, 31.0, 11.0), "step": 0.022, "normalH": 0.004,
        "components": well_bits_group, "gain": 1.5,
        "parts": [part(f"Bits{i}", None, 500, 256, PROP_INK*1.3, 1.0, hard=True, cage=0.02) for i in range(6)],
    },
}


# The library's soft light lifts crack floors and rope that the game has to paint brighter or crisper.
GAME_PAINT = (
    ("float far = 1.0 - smoothstep(chHoleR(chT(p.xz)) + 3.0, chHoleR(chT(p.xz)) + 10.0, length(p.xz));", "float far = 1.0;"),
    ("vec3 c = mix(gEdge, gCore, sw*0.75 + sw2*0.25);\n    c = mix(c, gHot, smoothstep(3.0, 0.0, r)*0.5);", "vec3 c = gEdge;"),
    ("emit += vec3(0.75, 1.0, 0.96)*gloss*(1.0 - 0.55*depth);", "emit += vec3(0.75, 1.0, 0.96)*gloss*(1.0 - 0.55*depth)*0.16;"),
    # Cracks, painted by depth: a touch of lit stone at the lip, black walls, and glowing azure welling up from the bottom.
    ("float core = smoothstep(0.34, 0.8, -fq.x/max(fq.y, 0.01));", "float core = smoothstep(0.42, 0.93, depthT); core *= core;"),
    ("fissure = inside*(0.02 + 0.24*depthT*depthT + 1.7*core);", "fissure = inside*(core + 0.001);"),
    ("s = mix(s, mix(vec3(0.012, 0.016, 0.022), vec3(0.22, 0.75, 0.7), core), inside);",
     "s = mix(s, mix(mix(vec3(0.14, 0.14, 0.18), vec3(0.003, 0.003, 0.006), smoothstep(0.0, 0.1, depthT)), vec3(0.015, 0.22, 0.72), core), inside);"),
    ("vec3 fissureLight = vec3(0.25, 0.95, 0.88)*(0.85 + 0.15*sin(uT*0.7 + l.x + l.z));", "vec3 fissureLight = vec3(0.06, 0.5, 1.0);"),
    ("emit += fissureLight*(1.1*fissure + 0.5*fissureHalo*fissureHalo)*TR(id).z;", "emit += fissureLight*(1.1*fissure + 0.22*fissureHalo*fissureHalo)*TR(id).z;"),
    ("m *= 1.0 - fissureHalo*0.85;", "m *= 1.0 - fissureHalo*0.85; if (fissure > 0.0) m = 0.0;"),
    # Rope: fine dark strands (owner: low quality).
    ("float twist = 0.5 + 0.5*sin((abs(p.x)*2.6 + abs(p.z)*2.6 + p.y*2.2)*17.0);",
     "float twist = smoothstep(-0.35, 0.55, sin((abs(p.x)*2.6 + abs(p.z)*2.6 + p.y*2.2)*34.0));"),
    ("vec3(0.38, 0.3, 0.19), vec3(0.62, 0.52, 0.34), twist", "vec3(0.2, 0.15, 0.09), vec3(0.66, 0.55, 0.37), twist"),
)


CLUSTER = r"  crackCluster\(q, vec3.*?;\n"
SPROUT = r"  wallShroom\(q, vec3\([^\n]*?, 2\.0, stems, caps, capIdx\);\n"


def crack_clusters(page):
    return "".join(re.findall(CLUSTER, page))


class PieceGpu(Gpu):
    def __init__(self, key, source=None):
        self.piece = PIECES[key]
        page = PAGE.read_text(encoding="utf-8")
        clusters = crack_clusters(page)
        sprouts = "".join(re.findall(SPROUT, page))
        if key == "hub-rock-dress":
            page = re.sub(CLUSTER, "", re.sub(SPROUT, "", page))
        # The mountain's paint samples its shape many times. Compiled into every piece's shader it made the driver take the wrong
        # paint branch on other pieces (mushrooms came out in the ground's colours), so only the mountain gets it.
        if key != "hub-grove-mountain":
            page, count = re.subn(r"// @mountain-paint-begin.*?// @mountain-paint-end", "return vec3(0.0);", page, flags=re.S)
            assert count == 1, "the page needs its mountain paint markers"
        for old, new in GAME_PAINT:
            assert old in page, old
            page = page.replace(old, new)
        bank, items = dump_renders(extract(page, r'<script id="lib">(.*?)</script>'), {self.piece["item"]})
        fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
        source = source or self.piece["map"]
        if source == "minis":
            source = ("vec2 assetMap(vec3 p) {\n  vec3 q = p - vec3(0.0, ROCK_TOP, 0.0);\n  vec2 res = vec2(1e3, 19.0);\n"
                      "  float stems = 1e5, caps = 1e5, capIdx = 0.0;\n" + sprouts
                      + "  if (stems < res.x) res = vec2(stems, 13.0);\n  if (caps < res.x) res = vec2(caps, 15.0 + capIdx*0.05);\n"
                      + clusters + "  return res;\n}\n")
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
        super().__init__(page, item, bank, asset_map=source + normal, mains={"grid": GRID, "paint": PAINT, "ids": IDS, "storm": STORM, "stormVeil": STORM_VEIL})

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
        groups.append({"name": name, "faces": len(faces), "tris": len(faces), "tex": 1024 if name == "StormBody" else 512, "ink": 0.0,
                       "inkRatio": 1.0, "hard": False, "cage": 0.1, "flat": True, "half": STORM_RIM + 0.1})
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
        a0, a1 = gpu.paint(pos, program="stormVeil" if g["name"] == "StormVeil" else "storm")
        h, w = valid.shape
        rgb, alpha = np.zeros((h, w, 3), "f4"), np.zeros((h, w, 3), "f4")
        rgb[valid], alpha[valid] = a0[:, :3], a1[:, :3]
        rgb, alpha = dilate(rgb, valid), dilate(alpha, valid)
        # The concept's tone mapping lifts these dark values a lot, so the map is lifted the same way.
        shown = to_srgb(np.clip(rgb*1.25, 0, 1))
        rgba = np.dstack([shown, np.clip(alpha[..., 0], 0, 1)])
        Image.fromarray((rgba*255 + 0.5).astype("u1"), "RGBA").save(out/"textures"/f"{g['name']}-color.png")
        g["color"] = f"textures/{g['name']}-color.png"
        g["alpha"] = g["name"] == "StormVeil"
        Image.fromarray((np.clip(alpha[..., 0], 0, 1)*255).astype("u1")).save(out/"textures"/f"{g['name']}-emit.png")
        g["emit"] = f"textures/{g['name']}-emit.png"
        g["emissiveStrength"] = 1.0
        print(f"{g['name']}: mean cover {float(alpha[valid].mean()):.2f}", flush=True)
    (out/"build.json").write_text(json.dumps(report, indent=1))


def rim_shape():
    """Measures what the art actually is, so the invisible ground matches it: the spawn rock's outline, the pit's edge and
    the raised lip."""
    gpu = PieceGpu("hub-cliff")
    falls = [0.73, 2.1, 4.0, 5.6]  # fallAngle in the shader
    step, n = 0.05, 860
    lo = np.array((-21.5, -0.06, -21.5))
    levels = 16
    grid = gpu.grid(lo, step, (n, levels, n))[..., 0]
    land = grid[:, 0, :] < 0

    def at(field, r, theta):
        x, z = r*np.sin(theta), -r*np.cos(theta)
        return field[int(round((x - lo[0])/step)), int(round((z - lo[2])/step))]

    tops = lo[1] + step*np.argmax(grid[:, ::-1, :] < 0, axis=1)*-1 + step*(levels - 1)
    tops = np.where((grid < 0).any(axis=1), tops, -1.0)
    rs = np.arange(14.0, 21.0, 0.02)
    pit, lip = [], []
    for k in range(72):
        theta = np.radians(k*5.0)
        inner = 21.0
        for r in rs[rs < 19.5][::-1]:  # from solid ground inward; the art's outer clip reads as a false edge
            if not at(land, r, theta):
                inner = r
                break
        pit.append(round(float(inner + 0.02)*5, 2))
        mid = np.radians(k*5.0 + 2.5)
        hits = [(r, at(tops, r, mid)) for r in rs if at(tops, r, mid) > 0.08]
        if hits:
            lip.append({"from": round(hits[0][0]*5, 2), "to": round(hits[-1][0]*5, 2), "top": round(max(h for _, h in hits)*5, 2)})
        else:
            lip.append({"from": 0, "to": 0, "top": 0})
    data = np.load("build/lobby/meshes/hub-rock/Top.npz")
    field, plate_lo, plate_step = data["plateField"], data["plateLo"], float(data["plateStep"])
    rock = []
    for k in range(120):
        best = 0.0
        for offset in (-0.8, 0.0, 0.8):
            theta = np.radians(k*3.0 + offset)
            for r in np.arange(8.7, 3.0, -0.02):
                x, z = r*np.sin(theta), -r*np.cos(theta)
                if field[int(round((x - plate_lo[0])/plate_step)), int(round((z - plate_lo[1])/plate_step))] < 0:
                    best = max(best, r)
                    break
        rock.append(round(best*5, 2))
    out = {"note": "Generated by tools/lobby/hub_mesh.py shape from the concept's own shapes.", "falls": falls, "rock": rock, "pit": pit, "lip": lip}
    Path("experiments/lobby/scale/shared/rim_shape.json").write_text(json.dumps(out))
    print("rock", min(rock), max(rock), "pit", min(pit), max(pit), "lips", sum(1 for x in lip if x["top"]), "tallest", max(x["top"] for x in lip))


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
    save("softbeam", np.exp(-(x/0.5)**2)*(1 - x**2)**2*(0.55 + 0.75*shafts))
    puff = blur(blur(rng.random((n, n)), 0, 14), 1, 14)
    puff = (puff - puff.min())/(puff.max() - puff.min())
    save("mist", np.clip(1 - r, 0, 1)**1.4*(0.5 + puff))
    save("flash", (np.exp(-(r/0.42)**2) + 0.25*np.exp(-(r/0.8)**2))*np.clip(1 - r, 0, 1)**0.7)
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
    y_full, x_full = np.mgrid[-1:1:n*1j, -1:1:n*1j]
    Image.new("RGBA", (16, 16), (10, 11, 28, 255)).save(folder/"cavernsky.png")
    # The portal's swirl: a gentle bending of light, even from the middle out to a soft edge, so it covers the whole surface
    # (owner) rather than gathering at the centre.
    sy, sx = np.mgrid[-1:1:512j, -1:1:512j]
    sr, sa = np.hypot(sx, sy), np.arctan2(sy, sx)
    edge = np.clip((0.86 - sr)/0.34, 0, 1)
    # Arms fade out toward the middle, or they pinch into a point there.
    arms = 0.5 + 0.5*np.cos(3*sa + 3.2*np.log(sr + 0.15))*np.clip(sr/0.3, 0, 1)
    save("swirl", (0.25 + 0.75*arms)*edge*edge*(3 - 2*edge))
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
    colour = colour + (np.array((225, 255, 248), "f4") - colour)*(0.14*shine)[..., None]
    rgba = np.dstack([colour, alpha*255]).clip(0, 255).astype("u1")
    Image.fromarray(rgba, "RGBA").save(folder/"flow.png")
    # Lava: soft glints that drift down a thick flow. The mesh carries the look, so nothing here may read as an edge.
    glint = np.clip((tile(70, 9, 6) - 0.5)/0.3, 0, 1)
    side = np.clip((1 - np.abs(x))/0.5, 0, 1)
    lava = np.array((255, 196, 96), "f4")[None, None]*np.ones((h, w, 1), "f4")
    Image.fromarray(np.dstack([lava, glint*side*255]).clip(0, 255).astype("u1"), "RGBA").save(folder/"lavaflow.png")
    # The downhill lava's slow gloop (owner, 2026-11-03: like the waterfall, slower, part of the lava). Textures on the
    # lava's own part draw on its surface; they can't glow, so they are the dark skin that cools on molten rock: rafts of
    # crust with glowing cracks, and long soft wrinkles down the flow. Tiling both ways; tinted and scrolled in Roblox.
    def periodic(size, along, across, seed):
        f = np.fft.fft2(np.random.default_rng(seed).standard_normal((size, size)))
        ky, kx = np.meshgrid(np.fft.fftfreq(size), np.fft.fftfreq(size), indexing="ij")
        a = np.real(np.fft.ifft2(f*np.exp(-((ky*size/along)**2 + (kx*size/across)**2))))
        return (a - a.min())/(a.max() - a.min())

    def step(e0, e1, v):
        t = np.clip((v - e0)/(e1 - e0), 0, 1)
        return t*t*(3 - 2*t)

    rafts = step(0.56, 0.66, periodic(512, 2.5, 5, 11)*0.8 + periodic(512, 8, 14, 12)*0.2)
    cracks = step(0.045, 0.0, np.abs(periodic(512, 9, 12, 13) - 0.5))
    save("lavacrust", rafts*(0.92 - 0.55*cracks*rafts))
    wrinkles = step(0.12, 0.0, np.abs(periodic(512, 3, 26, 21) - 0.5))*step(0.4, 0.7, periodic(512, 3, 8, 22))
    save("lavaskin", wrinkles*0.7)
    # A molten blob stretched along its flight, and a flame.
    save("droplet", np.exp(-(x_full/0.34)**2 - (y_full/0.82)**2)*1.6)
    tip = np.clip((y_full + 1)/2, 0, 1)
    save("flame", np.exp(-(x_full/(0.55*(1 - tip**1.5) + 0.02))**2)*np.clip(tip*5, 0, 1)*np.clip((1 - tip)*3, 0, 1)*1.4)
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


def sparkle_points(gpu, key, out):
    """A twinkle at the tip of each of the piece's biggest crystals."""
    piece = PIECES[key]
    points = []
    for name, limit in ((piece["sparkle"], 30),):
        data = np.load(out/f"{name}.npz")
        verts, faces = data["verts"], data["faces"]
        edges = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]]])
        graph = coo_matrix((np.ones(len(edges), dtype="i1"), (edges[:, 0], edges[:, 1])), shape=(len(verts), len(verts)))
        count, labels = connected_components(graph, directed=False)
        sizes = np.bincount(labels, minlength=count)
        tips = []
        print(f"  {name}: {count} separate pieces", flush=True)
        for label in np.argsort(sizes)[::-1][:limit]:
            if sizes[label] < 80:
                break
            v = verts[labels == label]
            tips.append(v[np.argmax(v[:, 1])])
        tips = np.array(tips, "f4")
        _, emit = gpu.paint(tips)
        colours = emit[:, :3]/np.maximum(emit[:, :3].max(axis=1, keepdims=True), 1e-3)
        points += [{"p": ((t - np.array(piece["origin"]))*piece["scale"]).tolist(), "c": c.tolist()} for t, c in zip(tips, colours)]
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
    shell = None
    if "shell" in piece:
        shell_verts, shell_faces = sparse_surface(PieceGpu(key, piece["shell"]), piece["lo"], piece["hi"], piece["shellStep"])
        # Only the outer skin: sealed pockets inside the rock would take the triangles, leaving huge shards on the surface.
        edges = np.concatenate([shell_faces[:, [0, 1]], shell_faces[:, [1, 2]]])
        graph = coo_matrix((np.ones(len(edges)), (edges[:, 0], edges[:, 1])), shape=(len(shell_verts), len(shell_verts)))
        labels = connected_components(graph, directed=False)[1]
        face_labels = labels[shell_faces[:, 0]]
        outer = np.bincount(face_labels).argmax()
        print(f"shell: kept {(face_labels == outer).sum()} of {len(shell_faces)} faces", flush=True)
        shell_faces = shell_faces[face_labels == outer]
        shell_centres = shell_verts[shell_faces].mean(axis=1)
        shell_ids = np.zeros(len(shell_faces))
        shell, taken = [], np.zeros(len(shell_faces), dtype=bool)
        for spec in piece["parts"]:
            hit = spec["test"](shell_ids, shell_centres) & ~taken
            taken |= hit
            for _ in range(piece.get("overlap", 0)):
                touched = np.zeros(len(shell_verts), dtype=bool)
                touched[shell_faces[hit]] = True
                hit = touched[shell_faces].any(axis=1)
            used, remap = np.unique(shell_faces[hit], return_inverse=True)
            shell.append((shell_verts[used], remap.reshape(-1, 3).astype("i4")))
    groups = []
    for index, (spec, hit) in enumerate(zip(piece["parts"], tests)):
        sel = faces[hit]
        if len(sel) < 20:
            print(f"  {spec['name']}: empty, skipped")
            continue
        used, remap = np.unique(sel, return_inverse=True)
        extra = {}
        if "smooth" in piece:
            extra = dict(zip(("lowVerts", "lowFaces"), piece["smooth"]()))
        upright = spec["name"] == "Energy"
        if upright:
            extra = dict(zip(("lowVerts", "lowFaces"), energy_sheet(verts[used])))
        plate = key == "hub-rock" and spec["name"] == "Top"
        if plate:
            extra = top_plate(gpu)
        if shell:
            extra = dict(zip(("shellVerts", "shellFaces"), shell[index]))
        np.savez_compressed(out/f"{spec['name']}.npz", verts=verts[used], faces=remap.reshape(-1, 3).astype("i4"), **extra)
        groups.append({"name": spec["name"], "faces": int(len(sel)), "tris": spec["tris"], "tex": spec["tex"],
                       "ink": spec["ink"]/piece["scale"], "inkRatio": spec["inkRatio"], "hard": spec["hard"],
                       "cage": spec["cage"], "authored": bool(extra) and not plate and not shell, "shell": bool(shell), "plate": plate, "upright": upright,
                       "tile": spec["tile"]})
        print(f"  {spec['name']:10s} {len(sel):9d} dense faces -> {spec['tris']} tris", flush=True)
    if "sparkle" in piece:
        sparkle_points(gpu, key, out)
    meta = {"key": key, "scale": piece["scale"], "origin": list(piece["origin"]), "groups": groups, "rig": piece.get("rig")}
    (out/"meta.json").write_text(json.dumps(meta, indent=1))


EVEN_GLOW = {"Plant", "Glow", "Sprouts", "Caps", "WellGlow", "CeilGems", "CollarGems", "BorderGems"}
# Set by eye in Roblox: above about 1 blooms. The keystone and juice washed out to white at their measured strengths.
EMIT_STRENGTH = {"Beads": 0.8, "Letters": 1.0, "Pads": 0.55, "Plant": 1.1, "CollarGems": 2.2, "BorderGems": 2.2, "Ring": 1.4, "Pendants": 1.4, "Cracks": 2.0, "Minis": 1.9, "CeilGems": 2.2, "Pool": 1.5, "Flows": 1.5, "ArchBits": 1.0, "VolcanoFront": 1.0, "Cracks": 1.6, "Pylons": 1.2, "ArchL": 1.4, "ArchR": 1.4, "Pillars": 1.4, "Base": 1.0, "Crown": 1.3, "Ring": 1.2, "Cave0": 1.0, "Cave1": 1.0, "Cave2": 1.0, "Cave3": 1.0, "Glow": 2.6, "Sprouts": 1.8, "Caps": 1.5, "WellGlow": 2.2, "Juice": 0.55, "Key": 1.3, "Pool0": 0.55, "Pool1": 0.55, "Pool2": 0.55, "Pool3": 0.55}


def periodic_cells(n, cells_u, cells_v, seed):
    """Cells repeating seamlessly across an n by n map: distance to the cell's own point and to its nearest edge (true
    distance, so seams are even all round), both in cell widths, and the cell's id."""
    rng = np.random.default_rng(seed)
    jitter = rng.uniform(0.15, 0.85, (cells_v, cells_u, 2))
    v, u = np.mgrid[0:n, 0:n]/n
    fu, fv = u*cells_u, v*cells_v
    iu, iv = np.floor(fu).astype("i4"), np.floor(fv).astype("i4")
    best, ids = np.full((n, n), 9.0), np.zeros((n, n), "i4")
    near = np.zeros((n, n, 2))
    for dv in (-1, 0, 1):
        for du in (-1, 0, 1):
            cu, cv = iu + du, iv + dv
            o = jitter[cv % cells_v, cu % cells_u]
            r = np.dstack([cu + o[..., 0] - fu, cv + o[..., 1] - fv])
            d = np.hypot(r[..., 0], r[..., 1])
            closer = d < best
            near = np.where(closer[..., None], r, near)
            ids = np.where(closer, (cv % cells_v)*cells_u + cu % cells_u, ids)
            best = np.minimum(best, d)
    edge = np.full((n, n), 9.0)
    for dv in range(-2, 3):
        for du in range(-2, 3):
            cu, cv = iu + du, iv + dv
            o = jitter[cv % cells_v, cu % cells_u]
            r = np.dstack([cu + o[..., 0] - fu, cv + o[..., 1] - fv])
            diff = r - near
            length = np.hypot(diff[..., 0], diff[..., 1])
            other = length > 1e-6
            mid = 0.5*(near + r)
            dist = (mid[..., 0]*diff[..., 0] + mid[..., 1]*diff[..., 1])/np.maximum(length, 1e-6)
            edge = np.where(other, np.minimum(edge, dist), edge)
    return best, edge, ids


def soft_noise(n, radius, seed):
    kernel = np.exp(-(np.arange(-radius*3, radius*3 + 1)/radius)**2)
    kernel /= kernel.sum()
    noise = np.random.default_rng(seed).random((n, n))
    spectrum = np.fft.fft(kernel, n)
    noise = np.fft.ifft(np.fft.fft(noise, axis=0)*spectrum[:, None], axis=0).real
    noise = np.fft.ifft(np.fft.fft(noise, axis=1)*spectrum[None, :], axis=1).real
    return (noise - noise.min())/(noise.max() - noise.min())


def save_tile(out, g, colour, height, studs, emit=None, strength=0.0, bump=1.0):
    """colour linear 0..1; height in studs over a map `studs` across. Writes the maps and fills in the group's entry."""
    name = g["name"]
    textures = out/"textures"
    Image.fromarray((to_srgb(np.clip(colour, 0, 1))*255 + 0.5).astype("u1")).save(textures/f"{name}-color.png")
    n = height.shape[0]
    texel = studs/n
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1))/(2*texel)
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0))/(2*texel)
    normal = np.dstack([-dx*bump, dy*bump, np.ones_like(dx)])
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    Image.fromarray(((normal*0.5 + 0.5)*255 + 0.5).astype("u1")).save(textures/f"{name}-normal.png")
    g["color"], g["normal"] = f"textures/{name}-color.png", f"textures/{name}-normal.png"
    if emit is not None:
        Image.fromarray((np.clip(emit, 0, 1)*255 + 0.5).astype("u1")).save(textures/f"{name}-emit.png")
        g["emit"], g["emissiveStrength"] = f"textures/{name}-emit.png", strength
    print(f"{name}: repeating map, {n} texels over {studs:.1f} studs", flush=True)


def smooth_rise(a, b, v):
    t = np.clip((v - a)/(b - a), 0, 1)
    return t*t*(3 - 2*t)


def velvet_maps(out, g, gain):
    """The spore velvet as the concept paints it (canopyHolePaint, id 101): purple cushions split by near-black seams, each
    its own shade, with glowing magenta specks. Cells 1.5 per unit, so a 6-unit tile holds 9 across."""
    n, cells = 1024, 9
    d1, gap, ids = periodic_cells(n, cells, cells, 101)
    shade = np.random.default_rng(7).random(cells*cells)[ids]
    g1, g2 = soft_noise(n, 30, 11), soft_noise(n, 6, 12)
    tops = np.stack([np.interp(shade, [0, 1], [a, b]) for a, b in ((0.045, 0.085), (0.022, 0.04), (0.1, 0.16))], axis=-1)
    seam = smooth_rise(0.012, 0.09, gap)
    colour = np.array([0.012, 0.008, 0.03]) + (tops - np.array([0.012, 0.008, 0.03]))*seam[..., None]
    colour = colour*(0.8 + 0.35*(0.6*g1 + 0.4*g2))[..., None]
    # Specks: small round glowing dots, sparse, away from the seams.
    rng = np.random.default_rng(13)
    speck = np.zeros((n, n))
    w = np.arange(-6, 7)
    for _ in range(700):
        cx, cy, rad = rng.uniform(0, n), rng.uniform(0, n), rng.uniform(1.6, 3.2)
        cols, rows = (int(cx) + w) % n, (int(cy) + w) % n
        dx, dy = np.meshgrid(int(cx) + w - cx, int(cy) + w - cy)
        dot = 1 - smooth_rise(rad*0.6, rad, np.hypot(dx, dy))
        speck[np.ix_(rows, cols)] = np.maximum(speck[np.ix_(rows, cols)], dot)
    speck *= seam
    pink = np.array([1.0, 0.4, 0.85])
    emit = colour*0.1 + pink*speck[..., None]*0.6
    base = np.clip((colour*0.85 + emit*0.9)*gain, 0, 1)
    studs = g["tile"]*5.0
    height = 0.7*smooth_rise(0.0, 0.16, gap)*(1 - np.clip(d1, 0, 1)**2)
    save_tile(out, g, base, height, studs, emit=speck, strength=1.4, bump=1.0)


def cobble_maps(out, g, gain):
    """The path's cobbles (id 113): worn grey-violet stones, each its own shade, domed, with dark joints. 2.4 per unit."""
    n, cells = 1024, 6
    d1, gap, ids = periodic_cells(n, cells, cells, 113)
    shade = np.random.default_rng(3).random(cells*cells)[ids]
    g1, g2 = soft_noise(n, 24, 21), soft_noise(n, 4, 22)
    stone = np.stack([np.interp(shade, [0, 1], [a, b]) for a, b in ((0.15, 0.27), (0.14, 0.25), (0.2, 0.33))], axis=-1)
    stone = stone*(0.8 + 0.25*g1 + 0.12*(g2 - 0.5))[..., None]
    # Worn edges: each stone darker toward its joints, so it reads as rounded.
    stone = stone*(0.72 + 0.28*smooth_rise(0.0, 0.22, gap))[..., None]
    joint = smooth_rise(0.014, 0.05, gap)
    colour = np.array([0.03, 0.025, 0.05]) + (stone - np.array([0.03, 0.025, 0.05]))*joint[..., None]
    base = np.clip((colour*0.85 + colour*0.05*0.9)*gain, 0, 1)
    height = 0.35*smooth_rise(0.0, 0.08, gap)*(1 - np.clip(d1, 0, 1)**2) + 0.03*g2
    save_tile(out, g, base, height, g["tile"]*5.0)


def kerb_maps(out, g, gain):
    """The kerb (id 116): larger, darker stones, longer along the path. 1.6 across by 1.2 along per unit."""
    n = 1024
    d1, gap, ids = periodic_cells(n, 4, 3, 116)
    shade = np.random.default_rng(5).random(12)[ids]
    g1, g2 = soft_noise(n, 24, 31), soft_noise(n, 4, 32)
    stone = np.stack([np.interp(shade, [0, 1], [a, b]) for a, b in ((0.1, 0.19), (0.095, 0.18), (0.14, 0.24))], axis=-1)
    stone = stone*(0.8 + 0.3*g1 + 0.12*(g2 - 0.5))[..., None]
    stone = stone*(0.72 + 0.28*smooth_rise(0.0, 0.2, gap))[..., None]
    joint = smooth_rise(0.014, 0.05, gap)
    colour = np.array([0.025, 0.02, 0.04]) + (stone - np.array([0.025, 0.02, 0.04]))*joint[..., None]
    base = np.clip(colour*0.89*gain, 0, 1)
    height = 0.3*smooth_rise(0.0, 0.07, gap) + 0.03*g2
    save_tile(out, g, base, height, g["tile"]*5.0)


TILE_MAPS = {"Velvet": velvet_maps, "Path": cobble_maps, "Mat": cobble_maps, "Kerb": kerb_maps}


def magma_maps(out, g):
    """A seamless sheet of magma: dark plates of crust split by crisp, glowing cracks, with finer cracks inside the plates."""
    n = 1024
    y, x = np.mgrid[0:1:n*1j, 0:1:n*1j]*(n - 1)/n

    def soft(seed, radius):
        kernel = np.exp(-(np.arange(-radius*3, radius*3 + 1)/radius)**2)
        kernel /= kernel.sum()
        noise = np.random.default_rng(seed).random((n, n))
        spectrum = np.fft.fft(kernel, n)
        noise = np.fft.ifft(np.fft.fft(noise, axis=0)*spectrum[:, None], axis=0).real
        noise = np.fft.ifft(np.fft.fft(noise, axis=1)*spectrum[None, :], axis=1).real
        return (noise - noise.min())/(noise.max() - noise.min())

    def cracks(count, seed, wobble):
        rng = np.random.default_rng(seed)
        wx, wy = x + wobble*(soft(seed + 1, 40) - 0.5), y + wobble*(soft(seed + 2, 40) - 0.5)
        first, second = np.full((n, n), 9.0), np.full((n, n), 9.0)
        for i in range(count):
            for j in range(count):
                px, py = (i + rng.uniform(0.12, 0.88))/count, (j + rng.uniform(0.12, 0.88))/count
                d = np.hypot((wx - px + 0.5) % 1.0 - 0.5, (wy - py + 0.5) % 1.0 - 0.5)
                second = np.where(d < first, first, np.minimum(second, d))
                first = np.minimum(first, d)
        return second - first

    def rise(a, b, v):
        t = np.clip((v - a)/(b - a), 0, 1)
        return t*t*(3 - 2*t)

    main, fine = cracks(6, 11, 0.1), cracks(15, 23, 0.05)
    plate = soft(41, 26)
    grain = soft(43, 3)
    heat = 1 - rise(0.005, 0.042, main)
    heat = np.maximum(heat, 0.62*(1 - rise(0.002, 0.012, fine))*rise(0.03, 0.06, main))
    heat = np.maximum(heat, 0.34*rise(0.55, 0.8, plate))
    ramp = [(0.0, (26, 15, 15)), (0.3, (120, 22, 6)), (0.55, (232, 78, 10)), (0.8, (255, 140, 30)), (1.0, (255, 205, 90))]
    colour = np.dstack([np.interp(heat, [k for k, _ in ramp], [c[i] for _, c in ramp]) for i in range(3)])
    colour = colour*(0.84 + 0.32*grain[..., None]*(1 - heat[..., None]) + 0.16*heat[..., None])
    textures = out/"textures"
    Image.fromarray(np.clip(colour, 0, 255).astype("u1")).save(textures/"Lava-color.png")
    Image.fromarray((np.clip(heat*1.25, 0, 1)*255).astype("u1")).save(textures/"Lava-emit.png")
    height = rise(0.0, 0.05, main) + 0.3*rise(0.0, 0.014, fine) + 0.25*grain
    dx, dy = np.roll(height, -1, 1) - np.roll(height, 1, 1), np.roll(height, -1, 0) - np.roll(height, 1, 0)
    normal = np.dstack([-dx*7, dy*7, np.ones_like(dx)])
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    Image.fromarray(((normal*0.5 + 0.5)*255).astype("u1")).save(textures/"Lava-normal.png")
    g["color"], g["normal"], g["emit"] = "textures/Lava-color.png", "textures/Lava-normal.png", "textures/Lava-emit.png"
    g["emissiveStrength"] = 1.15
    print("Lava: repeating magma map", flush=True)


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
        if g.get("tile"):
            painter = next((f for prefix, f in TILE_MAPS.items() if g["name"].startswith(prefix)), None)
            if painter:
                painter(out, g, PIECES[key].get("gain", 1.0))
            else:
                magma_maps(out, g)
            continue
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
        # Energy keeps its colour in the map and glows through its mask; baked in, it washes out to cream.
        keep = (glowing and not PIECES[key].get("bakeEmit")) or g["name"] in ("Cracks", "Energy")
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
                caps = dilate((((ids >= 14.5) & (ids < 16.0)) | ((ids >= 47.0) & (ids < 47.9)))[..., None].astype("f4"), valid)[..., 0] > 0.5
                mask = np.where(caps, np.maximum(mask, 0.55), mask)
                # Stems stay plain, so the caps read as what glows.
                stems = dilate(((np.abs(ids - 13.0) < 0.5) | (np.abs(ids - 46.0) < 0.5))[..., None].astype("f4"), valid)[..., 0] > 0.5
                mask = np.where(stems, 0.0, mask)
            if g["name"] == "Minis":
                # Glowing all over, brightest at the tips, so they light up from any angle (owner).
                mask = np.maximum(mask, 0.6)
            Image.fromarray((mask*255 + 0.5).astype("u1")).save(out/"textures"/f"{g['name']}-emit.png")
            over = base.max(axis=2)[valid & (mask > 0.5)]
            g["emit"] = f"textures/{g['name']}-emit.png"
            g["emissiveStrength"] = EMIT_STRENGTH.get(g["name"], round(min(4.0, peak/max(float(np.median(over)), 0.05)), 2))
        if g["name"] == "Energy":
            # Solid maps with no gaps or surface detail: islands, seams and facets read as shards on a plain glow (owner).
            # The glow's hue, because the unlit colour is muted. Dark, with the glow strength making it up in the game: any
            # light landing on a brighter map picks out the mesh's triangles as streaks.
            glow = np.median(emit[valid], axis=0)
            flat = tuple(int(v) for v in to_srgb(glow/glow.max()*0.25)*255 + 0.5)
            Image.new("RGB", (64, 64), flat).save(out/"textures"/"Energy-color.png")
            Image.new("L", (64, 64), 255).save(out/"textures"/"Energy-emit.png")
            Image.new("RGB", (64, 64), (128, 128, 255)).save(out/"textures"/"Energy-normal.png")
            g["emit"] = "textures/Energy-emit.png"
        black = float((alb[valid].max(axis=1) < 0.012).mean())
        if black > 0.5:
            print(f"WARNING {g['name']}: {black:.0%} of texels are ink black", flush=True)
        print(f"{g['name']}: {int(valid.sum())} texels" + (f", glow x{g['emissiveStrength']}" if "emit" in g else ""), flush=True)
    (out/"build.json").write_text(json.dumps(report, indent=1))


def build_in_blender(key):
    subprocess.run([BLENDER, "--background", "--factory-startup", "--python-exit-code", "1",
                    "--python", "tools/lobby/blender_hub_piece.py", "--", key], check=True, stdout=subprocess.DEVNULL)


def main():
    action, *keys = sys.argv[1:]
    if action == "shape":
        rim_shape()
        return
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
