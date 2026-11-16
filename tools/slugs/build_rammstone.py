"""Build Rammstone's review model in Blender from his concept (docs/slugs/catalog/evidence/rammstone/rammstone.html).

Ports the concept's shape and colour functions to NumPy, with the owner's structural round of 2026-11-07 applied to the
shapes themselves: bigger, fewer and irregular rock plates, a heavier hood with a lower brow, faceted horns leaning out,
bigger eyes, a simpler grin with smirk and neutral variants, and warm edge highlights painted into the colour. Meshes the
result with surface nets, reduces it to a review mesh, colours each face from its part and renders fixed review views.

This is the appearance model only. The owner asked for no rig or Roblox export until the look is approved, so neither
exists yet. Run with Blender 4.5:

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_rammstone.py [-- grin|smirk|neutral]`

Writes assets/source/slugs/models/rammstone/rammstone.blend and ignored build/slugs/rammstone/: renders and
report.json. Nothing is uploaded. Concept coordinates are y-up with the face toward +z; Blender gets (x, -z, y).
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_floppy as bf
import export_floppy_roblox as ef
from common import ROOT
from build_floppy import gradient, sd_bezier, sd_ell, smax, smin, smoothstep, surface_nets, to_blender

SOURCE = ROOT/"assets/source/slugs/models/rammstone"
BUILD = ROOT/"build/slugs/rammstone"
STEP = 0.011
BOUNDS = ((-1.15, 1.15), (-0.03, 3.15), (-1.20, 1.05))
REVIEW_TRIANGLES = 140000
EXPRESSIONS = ("grin", "smirk", "neutral")

ROCK = np.array([0.170, 0.016, 0.012])
ROCK_HI = np.array([0.420, 0.045, 0.030])
ROCK_WARM = np.array([0.850, 0.130, 0.035])  # volcanic edge highlight, painted rather than lit
ROCK_DK = np.array([0.090, 0.008, 0.006])
SKIN = np.array([0.560, 0.270, 0.150])
SKIN_DK = np.array([0.330, 0.130, 0.070])
HORN = np.array([0.040, 0.032, 0.030])
HORN_HI = np.array([0.120, 0.100, 0.092])
LINE = np.array([0.090, 0.030, 0.020])
LAVA = np.array([1.000, 0.260, 0.030])
HOT = np.array([1.000, 0.640, 0.200])
TEETH = np.array([1.0, 0.95, 0.84])

SKIN_ID, ROCK_ID, HORN_ID, EYE_ID = range(4)


def mix(a, b, t):
    return a + (b - a)*np.asarray(t)[..., None]


def fract(x):
    return x - np.floor(x)


def nrm(v):
    v = np.asarray(v, float)
    return v/np.linalg.norm(v)


def hash2(x, y):
    return fract(np.sin(x*127.1 + y*311.7)*43758.5453)


def vnoise(x, y):
    ix, iy = np.floor(x), np.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx*fx*(3 - 2*fx), fy*fy*(3 - 2*fy)
    a, b = hash2(ix, iy), hash2(ix + 1, iy)
    c, d = hash2(ix, iy + 1), hash2(ix + 1, iy + 1)
    return (a + (b - a)*fx) + ((c + (d - c)*fx) - (a + (b - a)*fx))*fy


def fbm(x, y):
    v, a = 0.0, 0.5
    for _ in range(4):
        v = v + a*vnoise(x, y)
        x, y, a = x*2.03 + 1.7, y*2.03 + 1.7, a*0.5
    return v


def fissure(x, y, width):
    """Meandering cracks: where a smooth noise crosses its middle value."""
    return 1.0 - smoothstep(0.0, width, np.abs(fbm(x, y) - 0.5))


# ---------------------------------------------------------------- body and face

def body_core(p):
    d = sd_ell(p - [0.0, 0.22, 0.0], np.array([0.56, 0.24, 0.52]))
    d = smin(d, sd_ell(p - [0.0, 0.92, 0.0], np.array([0.50, 0.92, 0.46])), 0.30)
    return smin(d, sd_ell(p - [0.0, 1.60, 0.04], np.array([0.50, 0.48, 0.48])), 0.22)


EYE_C = np.array([0.235, 1.655, 0.455])
EYE_DIM = np.array([0.185, 0.112, 0.130])
EYE_TILT = 0.28
EYE_TOP = 0.045  # the brow cuts the eye flat this far above its centre


def eye_local(q):
    l = q - EYE_C
    c, s = math.cos(EYE_TILT), math.sin(EYE_TILT)
    return np.stack([c*l[:, 0] + s*l[:, 1], -s*l[:, 0] + c*l[:, 1], l[:, 2]], -1)


def eye_shape(q, grow):
    l = eye_local(q)
    return smax(sd_ell(l, EYE_DIM + grow), l[:, 1] - EYE_TOP - grow, 0.02)


def mirror(p):
    return np.stack([np.abs(p[:, 0]), p[:, 1], p[:, 2]], -1)


# The mouth: a grin with solid upper teeth, a closed smirk, or a level line. x runs across the mouth.
GRIN_Y = 1.40


def mouth_curve(x, expression):
    """Height of the mouth line (the upper lip for the grin) above GRIN_Y."""
    if expression == "grin":
        return 0.30*x*x + 0.05*x
    if expression == "smirk":
        return 0.06*x*x + 2.2*np.maximum(x, 0.0)**3 + 0.03*x
    return 0.07*x*x


MOUTH_HALF = {"grin": 0.27, "smirk": 0.21, "neutral": 0.20}


def grin_dist(p):
    """Inside of the open grin: between the upper lip and a full lower lip."""
    x = p[:, 0]
    top = GRIN_Y + mouth_curve(x, "grin")
    bottom = GRIN_Y - 0.125 + 1.10*x*x + 0.05*x
    return np.maximum(np.maximum(p[:, 1] - top, bottom - p[:, 1]), np.abs(x) - MOUTH_HALF["grin"])


def line_dist(p, expression):
    x = p[:, 0]
    d = np.abs(p[:, 1] - GRIN_Y - mouth_curve(x, expression))
    return np.maximum(d, np.abs(x) - MOUTH_HALF[expression])


def fold_line(x, y0):
    return y0 + 0.40*np.abs(x)


def fold_step(p, y0):
    l = fold_line(p[:, 0], y0)
    return smoothstep(l - 0.008, l + 0.008, p[:, 1])*smoothstep(l + 0.34, l + 0.04, p[:, 1])


def skin(p, expression):
    d = body_core(p)
    front = (p[:, 2] > 0.15).astype(float)
    d = d - front*0.016*(fold_step(p, 1.02) + fold_step(p, 0.42))*smoothstep(0.40, 0.24, np.abs(p[:, 0]))
    if expression == "grin":
        d = d + front*0.030*(1.0 - smoothstep(-0.016, 0.010, grin_dist(p)))
    else:
        d = d + front*0.010*(1.0 - smoothstep(0.0, 0.012, line_dist(p, expression)))
    d = smax(d, -eye_shape(mirror(p), 0.015), 0.03)
    return smax(d, -p[:, 1], 0.015)


# ---------------------------------------------------------------- rock armour

ARMOUR_ANGLE = 1.85  # radians from the spine that the armour reaches


def brow_y(x):
    return 1.57 + 0.55*np.abs(x)


def opening(p):
    """Negative where no rock covers: the face below the brow and the belly."""
    a = np.abs(np.arctan2(p[:, 0], -p[:, 2]))
    return np.maximum((ARMOUR_ANGLE - a)*0.45, p[:, 1] - brow_y(p[:, 0]))


HOOD_PLANES = [  # (normal on the +x side, distance from the head centre)
    # Seen from the side the hood is a wedge: a visor jutting past the face, sloping back to the crown.
    (nrm([0.0, 1.0, 0.45]), 0.484),     # top, sloping down to the visor's tip
    (nrm([0.35, 0.25, 0.90]), 0.70),    # brow faces, meeting in a V down the middle
    (nrm([0.0, 0.25, 0.97]), 0.73),     # a narrow flat down the middle, so the forehead is not a knife edge
    (nrm([1.0, 0.25, 0.10]), 0.64),     # temples
    (nrm([0.60, 0.80, 0.10]), 0.62),    # upper side bevels
    (nrm([0.7, 0.4, -0.6]), 0.55),
    (nrm([0.0, 0.3, -1.0]), 0.50),
]
HOOD_CENTRE = np.array([0.0, 1.62, 0.0])


def hood_planes(p):
    s = mirror(p - HOOD_CENTRE)
    return np.stack([s @ n - d for n, d in HOOD_PLANES], -1)


def hood_poly(p):
    return hood_planes(p).max(-1)


def hood_bottom(z):
    return 1.50 + 0.30*np.maximum(0.6 - z, 0.0)


def hood(p):
    return np.maximum(hood_poly(p), hood_bottom(p[:, 2]) - p[:, 1])


# Plates in rows down the back and sides, rising towards the belly so they meet in chevrons up the spine. Each plate is
# a solid wedge, thin where it tucks under the plate above and thickest at its pointed lower edge, ridged down the middle
# and swept down and back. Size, length, angle and spacing vary per plate.
ROW_H = 0.40
COL_W = 0.80
PLATE_R = 0.5
TOP_Y = 2.05
CHEV = 0.14


def plate(p, a, w, row, col):
    """Distance to one plate per point (row and col are per-point arrays), and (down, across, hash)."""
    stagger = 0.5*np.mod(row, 2.0)
    base = (col + stagger)*COL_W
    side = np.sign(base)
    h = hash2(row, np.abs(base)*3.0)
    h2 = hash2(row + 7.3, np.abs(base)*5.0)
    h3 = hash2(row + 3.1, np.abs(base)*2.0 + 1.0)
    ac = base + side*(h3 - 0.5)*0.12
    yt = TOP_Y - row*ROW_H + CHEV*np.abs(ac) + (h2 - 0.5)*0.10
    valid = (np.abs(ac) <= ARMOUR_ANGLE + 0.05) & (yt > 0.15) & (yt < 2.20) & (row >= 0)
    sweep = 0.55*smoothstep(0.2, 1.4, np.abs(ac)) + (h2 - 0.5)*0.25
    dn = np.stack([-side*sweep, -np.ones_like(sweep)], -1)
    dn = dn/np.linalg.norm(dn, axis=-1, keepdims=True)
    qa, qy = (a - ac)*PLATE_R, p[:, 1] - yt
    v = qa*dn[:, 0] + qy*dn[:, 1]
    u = -qa*dn[:, 1] + qy*dn[:, 0]
    L = 0.66 + 0.16*h
    wh = 0.27 + 0.06*h3
    T = (0.20 + 0.07*h)*(1.0 + 0.5*smoothstep(1.0, 1.8, np.abs(ac)))*(1.0 + 0.35*smoothstep(1.0, 1.9, yt))
    au = np.abs(u)/wh
    top = T*np.clip(v/L, 0.0, 1.0)**0.7*(1.0 - 0.35*au) + 0.04*(h - 0.5)*u/wh
    d = (w - top)*0.75
    d = np.maximum(d, np.maximum(-v, v - L*(1.0 - 0.40*au))*0.7)
    d = np.maximum(d, np.abs(u) - wh)
    d = np.maximum(d, -(w + 0.05))
    d = np.where(valid, d, 1e3)
    return d, np.stack([v/L, u/wh, h], -1)


def plates(p, w):
    a = np.arctan2(p[:, 0], -p[:, 2])
    r0 = np.floor((TOP_Y - p[:, 1] + CHEV*np.abs(a))/ROW_H)
    best = np.full(len(p), 1e3)
    info = np.zeros((len(p), 3))
    for i in range(3):
        row = r0 - i
        c0 = np.floor(a/COL_W - 0.5*np.mod(row, 2.0) + 0.5)
        for j in (-2, -1, 0, 1, 2):
            d, inf = plate(p, a, w, row, c0 + j)
            better = d < best
            best = np.where(better, d, best)
            info[better] = inf[better]
    return best, info


def armour(p, w=None):
    w = body_core(p) if w is None else w
    d = np.minimum(w - 0.012, hood(p))
    near = w < 0.45
    pl = np.full(len(p), 1e3)
    if near.any():
        pl[near] = plates(p[near], w[near])[0]
    d = np.minimum(d, np.where(near, pl, w - 0.3))
    d = smax(d, -opening(p), 0.012)
    return np.maximum(d, -p[:, 1])


# ---------------------------------------------------------------- horns, keel, eyes

HORN_A, HORN_B, HORN_C = np.array([0.27, 1.98, -0.12]), np.array([0.38, 2.64, -0.02]), np.array([0.50, 2.74, -0.64])
HORN_ROOT, HORN_TIP = 0.25, 0.016


def horn(p):
    """Faceted horns: a hexagonal section swept along a curve that rises, leans out and arcs back."""
    q = mirror(p)
    dist, t = sd_bezier(q, HORN_A, HORN_B, HORN_C)
    tt = t[:, None]
    c = (1 - tt)**2*HORN_A + 2*(1 - tt)*tt*HORN_B + tt*tt*HORN_C
    tan = 2*(1 - tt)*(HORN_B - HORN_A) + 2*tt*(HORN_C - HORN_B)
    tan = tan/np.linalg.norm(tan, axis=1, keepdims=True)
    n1 = np.cross(tan, [1.0, 0.0, 0.0])
    n1 = n1/np.maximum(np.linalg.norm(n1, axis=1, keepdims=True), 1e-6)
    n2 = np.cross(n1, tan)
    o = q - c
    x, y = np.abs(np.sum(o*n2, 1))*1.12, np.abs(np.sum(o*n1, 1))
    r = HORN_ROOT + (HORN_TIP - HORN_ROOT)*t**0.75
    # Hexagon (after Inigo Quilez), flat sides facing front and back.
    k = (-0.866025404, 0.5, 0.577350269)
    m = np.minimum(k[0]*x + k[1]*y, 0.0)
    x, y = x - 2*m*k[0], y - 2*m*k[1]
    x, y = x - np.clip(x, -k[2]*r, k[2]*r), y - r
    hexd = np.hypot(x, y)*np.sign(y)
    # Past the root and the tip, close the ends.
    ends = (t <= 0.0) | (t >= 1.0)
    return np.maximum(hexd, np.where(ends, np.abs(np.sum(o*tan, 1)), -1e3))*0.85, t


def keel(p):
    wdt = (0.045 + 0.035*smoothstep(1.60, 2.10, p[:, 1]))*smoothstep(-0.10, 0.10, p[:, 2])
    d = np.maximum(hood_poly(p) - 0.015, np.abs(p[:, 0]) - wdt)
    d = np.maximum(d, brow_y(p[:, 0]) - 0.012 - p[:, 1])
    return np.maximum(d, 0.02 - p[:, 2])


def eyes(p):
    return eye_shape(mirror(p), 0.0)


def parts(p, expression):
    """Distance to each part: skin, rock, horn and eye."""
    hd = np.minimum(horn(p)[0]*0.9, keel(p))
    return np.stack([skin(p, expression), armour(p), hd, eyes(p)], -1)


def union(p, expression):
    return parts(p, expression).min(-1)


# ---------------------------------------------------------------- colour

def rock_colour(p):
    w = body_core(p)
    pd, info = plates(p, w)
    planes = np.sort(hood_planes(p), -1)
    hd = np.maximum(planes[:, -1], hood_bottom(p[:, 2]) - p[:, 1])
    on_plate = (pd < 0.02) & (pd <= hd + 0.004)
    on_hood = ~on_plate & (hd < 0.02)
    col = np.tile(ROCK_DK*0.7, (len(p), 1))  # crevices between plates
    # Plates: darker where tucked under the plate above, worn and warm along the lower and side edges.
    pc = ROCK[None]*(0.80 + 0.40*info[:, 2:3])
    pc = pc*(0.55 + 0.45*smoothstep(0.0, 0.30, info[:, 0]))[:, None]
    edge = np.maximum(smoothstep(0.84, 1.0, info[:, 0]/(1.0 - 0.40*np.abs(info[:, 1]))), smoothstep(0.86, 1.0, np.abs(info[:, 1])))
    ridge = 1.0 - smoothstep(0.0, 0.10, np.abs(info[:, 1]))
    pc = mix(pc, ROCK_HI, np.maximum(edge*0.5, ridge*0.25*smoothstep(0.3, 0.9, info[:, 0])))
    pc = mix(pc, ROCK_WARM, edge*0.35)
    col[on_plate] = pc[on_plate]
    # Hood: its facet edges and the brow's rim catch the warm highlight.
    hc = np.tile(ROCK*0.95, (len(p), 1))
    facet = 1.0 - smoothstep(0.0, 0.03, planes[:, -1] - planes[:, -2])
    rim = smoothstep(brow_y(p[:, 0]) + 0.06, brow_y(p[:, 0]), p[:, 1])*(p[:, 2] > 0.0)
    hc = mix(hc, ROCK_HI, np.maximum(facet*0.45, rim*0.6))
    hc = mix(hc, ROCK_WARM, np.maximum(facet*0.25, rim*0.35))
    col[on_hood] = hc[on_hood]
    # A few cracks, in patches.
    a = np.arctan2(p[:, 0], -p[:, 2])
    cx, cy = a*1.2, p[:, 1]*2.6
    cracks = fissure(cx*1.6, cy*1.6, 0.022)*smoothstep(0.50, 0.68, vnoise(cx*1.3 + 4.0, cy*1.3 + 4.0))
    return mix(col, ROCK_DK, cracks*0.85)


def horn_colour(p):
    _, t = horn(p)
    col = mix(np.tile(HORN, (len(p), 1)), HORN_HI, smoothstep(0.3, 0.9, t)*0.6)
    on_keel = keel(p) < horn(p)[0]*0.9
    col[on_keel] = mix(HORN[None], HORN_HI, 0.5)[0]
    cr = fissure(np.arctan2(p[:, 0], p[:, 2])*2.0, p[:, 1]*3.0 + p[:, 2]*2.0, 0.02)
    return mix(col, np.array([0.012, 0.010, 0.010]), cr*0.7)


def eye_colour(p):
    side = np.where(p[:, 0] < 0.0, -1.0, 1.0)
    l = eye_local(mirror(p))
    u, v = l[:, 0]*side/EYE_DIM[0], l[:, 1]/(EYE_DIM[1]*1.3)
    r = np.hypot(u, v)
    line = fissure(u*0.8 + side*3.1, v*0.8 + 1.7, 0.022)
    core = 1.0 - smoothstep(0.0, 0.55, r)
    glow = mix(LAVA[None]*np.ones((len(p), 1)), HOT, core*0.6)*(line*(0.8 + 0.7*core))[:, None] + LAVA*(0.16*core*core)[:, None]
    col = mix(np.tile(np.array([0.045, 0.016, 0.012]), (len(p), 1)), LAVA*0.4, line*0.6)
    return col, glow


def skin_colour(p, expression):
    ax = np.abs(p[:, 0])
    col = np.tile(SKIN, (len(p), 1))
    col = mix(col, col*np.array([1.08, 1.04, 1.0]), smoothstep(0.30, 0.0, ax))
    col = mix(col, SKIN_DK, smoothstep(0.30, 0.46, ax)*0.35)
    col = mix(col, SKIN_DK, (1.0 - smoothstep(0.03, 0.12, p[:, 1]))*0.45)
    front = (p[:, 2] > 0.15).astype(float)
    fd = np.minimum(np.abs(p[:, 1] - fold_line(p[:, 0], 1.02)), np.abs(p[:, 1] - fold_line(p[:, 0], 0.42)))
    col = mix(col, SKIN_DK, (1.0 - smoothstep(0.004, 0.020, fd))*smoothstep(0.40, 0.24, ax)*0.75*front)
    # Shade under the brow.
    sk = ((ax - 0.235)/0.26)**2 + ((p[:, 1] - 1.66)/0.15)**2
    col = mix(col, col*np.array([0.62, 0.48, 0.42]), 0.5*np.exp(-sk*1.2)*front)
    x = p[:, 0]
    if expression == "grin":
        gd = grin_dist(p)
        inside = (1.0 - smoothstep(-0.003, 0.003, gd))*front
        lip = GRIN_Y + mouth_curve(x, "grin")
        # Upper teeth fill the top of the mouth, a dark line where they meet the lower ones, shade at the corners.
        corner = smoothstep(0.12, MOUTH_HALF["grin"], ax)
        teeth = mix(np.tile(TEETH, (len(p), 1)), np.array([0.30, 0.12, 0.07]), np.maximum(corner*0.85, smoothstep(0.035, 0.07, lip - p[:, 1])))
        meet = np.abs(p[:, 1] - (lip - 0.038 - 0.25*x*x))
        teeth = mix(teeth, np.array([0.45, 0.30, 0.24]), (1.0 - smoothstep(0.002, 0.006, meet))*(1.0 - corner)*0.8)
        col = mix(col, teeth, inside)
        below = (1.0 - inside)*(1.0 - smoothstep(0.0, 0.05, gd))*(p[:, 1] < lip - 0.04)*front
        col = mix(col, col*np.array([0.72, 0.56, 0.48]), below*0.7)
        outline = np.abs(gd) - 0.003
    else:
        outline = line_dist(p, expression) - 0.004
    # The mouth line, with a short hook at the high corner.
    ends = np.hypot(np.abs(x) - MOUTH_HALF[expression] - 0.01, p[:, 1] - GRIN_Y - mouth_curve(x, expression) - 0.02) - 0.006
    hook = np.where((x > 0) | (expression == "grin"), ends, 1e3)
    col = mix(col, LINE, (1.0 - smoothstep(0.0, 0.004, np.minimum(outline, hook)))*front)
    return col


def colours(p, part, expression):
    col = np.zeros((len(p), 3))
    glow = np.zeros((len(p), 3))
    for pid, fn in ((SKIN_ID, lambda q: skin_colour(q, expression)), (ROCK_ID, rock_colour), (HORN_ID, horn_colour)):
        m = part == pid
        if m.any():
            col[m] = fn(p[m])
    m = part == EYE_ID
    if m.any():
        col[m], glow[m] = eye_colour(p[m])
    return col, glow


# ---------------------------------------------------------------- mesh

def sample(expression):
    (x0, x1), (y0, y1), (z0, z1) = BOUNDS
    xs = np.arange(x0, x1 + 1e-9, STEP)
    ys = np.arange(y0, y1 + 1e-9, STEP)
    zs = np.arange(z0, z1 + 1e-9, STEP)
    vals = np.empty((len(xs), len(ys), len(zs)), np.float32)
    Y, Z = np.meshgrid(ys, zs, indexing="ij")
    for i, x in enumerate(xs):
        vals[i] = union(np.stack([np.full(Y.size, x), Y.ravel(), Z.ravel()], -1), expression).reshape(Y.shape)
    return xs, ys, zs, vals


def project(p, expression, iterations=3):
    f = lambda q: union(q, expression)
    for _ in range(iterations):
        d = f(p)
        g = gradient(f, p)
        step = d/np.maximum(np.sum(g*g, axis=1), 1e-6)
        p = p - g*np.clip(step, -0.006, 0.006)[:, None]
    return p


def concept_positions(mesh):
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return np.stack([co[:, 0], co[:, 2], -co[:, 1]], -1)


def part_material(name, colour_attr, roughness, emission=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = colour_attr
    links.new(attr.outputs["Color"], shader.inputs["Base Color"])
    bf.set_inputs(shader, {"Roughness": roughness, "Specular IOR Level": 0.15})
    if emission:
        glow = nodes.new("ShaderNodeAttribute")
        glow.attribute_name = "Glow"
        links.new(glow.outputs["Color"], shader.inputs["Emission Color"])
        bf.set_inputs(shader, {"Emission Strength": 2.5})
    return mat


def build_mesh(expression):
    print("sampling", expression)
    xs, ys, zs, vals = sample(expression)
    verts, faces = surface_nets(xs, ys, zs, vals)
    del vals
    print("surface nets", len(verts), "verts")
    obj = bf.mesh_object("Rammstone", to_blender(project(verts, expression, 2)), faces)
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = STEP
    ef.select_only([obj])
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    ef.reduce(obj, REVIEW_TRIANGLES)
    co = project(concept_positions(obj.data), expression)
    obj.data.vertices.foreach_set("co", to_blender(co).astype(np.float32).ravel())
    obj.data.update()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Subdivide the eyes, so their fissures stay thin lines rather than blotches.
    bm.faces.ensure_lookup_table()
    centres = np.array([tuple(f.calc_center_median()) for f in bm.faces])
    centres = np.stack([centres[:, 0], centres[:, 2], -centres[:, 1]], -1)
    on_eye = parts(centres, expression).argmin(-1) == EYE_ID
    eye_faces = [f for f, e in zip(bm.faces, on_eye) if e]
    edges = list({e for f in eye_faces for e in f.edges})
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=3, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    co = project(concept_positions(obj.data), expression, 1)
    obj.data.vertices.foreach_set("co", to_blender(co).astype(np.float32).ravel())
    obj.data.update()
    return obj


def paint(obj, expression):
    mesh = obj.data
    n = len(mesh.polygons)
    centres = np.empty(n*3)
    mesh.polygons.foreach_get("center", centres)
    centres = centres.reshape(-1, 3)
    centres = np.stack([centres[:, 0], centres[:, 2], -centres[:, 1]], -1)
    part = parts(centres, expression).argmin(-1)
    for name, attr, rough, glow in (("RammstoneSkin", "Col", 0.5, False), ("RammstoneRock", "Col", 0.85, False),
                                    ("RammstoneHorn", "Col", 0.6, False), ("RammstoneEye", "Col", 0.25, True)):
        mesh.materials.append(part_material(name, attr, rough, glow))
    mesh.polygons.foreach_set("material_index", part.astype(np.int32))
    # Colour per face corner, from the face's own part, so material borders stay crisp.
    loop_vert = np.empty(len(mesh.loops), np.int32)
    mesh.loops.foreach_get("vertex_index", loop_vert)
    loop_face = np.repeat(np.arange(n), 3)
    co = concept_positions(mesh)[loop_vert]
    col, glow = colours(co, part[loop_face], expression)
    for name, values in (("Col", col), ("Glow", glow)):
        layer = mesh.color_attributes.new(name, "FLOAT_COLOR", "CORNER")
        layer.data.foreach_set("color", np.concatenate([values, np.ones((len(values), 1))], -1).astype(np.float32).ravel())
    ef.select_only([obj])
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38))
    counts = np.bincount(part, minlength=4)
    return {"skin": int(counts[0]), "rock": int(counts[1]), "horn": int(counts[2]), "eye": int(counts[3])}


def check(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    loose = sum(1 for v in bm.verts if not v.link_faces)
    bm.free()
    return {"triangles": ef.triangles(obj), "nonManifoldEdges": non_manifold, "looseVerts": loose}


def render(out, expression):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Review")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.045, 0.040, 0.048, 1)
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.render.resolution_x = scene.render.resolution_y = 720
    scene.view_settings.view_transform = "Standard"
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
    key.data.energy = 1.5
    key.rotation_euler = (math.radians(50), math.radians(-30), math.radians(-25))
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
    fill.data.energy = 0.3
    fill.data.color = (0.75, 0.75, 1.0)
    fill.rotation_euler = (math.radians(70), math.radians(20), math.radians(140))
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
    rim.data.energy = 1.4
    rim.data.color = (1.0, 0.45, 0.25)
    rim.rotation_euler = (math.radians(65), math.radians(0), math.radians(200))
    front = bpy.data.objects.new("Front", bpy.data.lights.new("Front", "SUN"))
    front.data.energy = 0.7
    front.data.color = (1.0, 0.95, 0.9)
    front.rotation_euler = (math.radians(75), 0.0, 0.0)
    for light in (key, fill, rim, front):
        scene.collection.objects.link(light)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 70
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre, distance = Vector((0, 0, 1.45)), 7.0
    views = [("front", 0.0, 0.12), ("three-quarter", 0.7, 0.12), ("side", 1.5708, 0.10), ("back", 3.1416, 0.12),
             ("other-side", -1.5708, 0.10)] if expression == "grin" else []
    paths = []
    for name, yaw, rise in views:
        offset = Vector((math.sin(yaw), -math.cos(yaw), rise))*distance
        cam.location = centre + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        paths.append(shot(scene, out/"renders"/f"{name}.png"))
    # The face, close, for each expression.
    face = Vector((0, 0, 1.62))
    for name, yaw in (("face", 0.0), ("face-three-quarter", 0.6)):
        offset = Vector((math.sin(yaw), -math.cos(yaw), 0.05))*4.4
        cam.location = face + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        paths.append(shot(scene, out/"renders"/f"{name}-{expression}.png"))
    return paths


def shot(scene, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path.name


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    expressions = args or list(EXPRESSIONS)
    report = {"tool": bpy.app.version_string, "step": STEP, "expressions": {}}
    for expression in expressions:
        assert expression in EXPRESSIONS, expression
        bf.reset()
        obj = build_mesh(expression)
        faces = paint(obj, expression)
        entry = {"facesByPart": faces, **check(obj), "renders": render(BUILD, expression)}
        report["expressions"][expression] = entry
        print(expression, json.dumps(entry))
        if expression == "grin":
            SOURCE.mkdir(parents=True, exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"rammstone.blend"), compress=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD/"report.json").write_text(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
