"""Build Rammstone's transformed form: concept 2, a new brute's body under the base form's head, in flight.

Owner, 2026-11-13, on concept 1 (the base form with arms and devil horns added): "this aint transformed u just slapped
stuff on the base model, horns facing the wrong way too, look at burpy for example". Their reference picture, a red
hulking brute flying fist first with ram horns and stone fists, "can be used as a reference image but remember we are
using black not blue". Inferno's transformed form ("Burpy") is a new body, a slug-dragon, that carries his face.

So only the base form's head is kept (face, hood, crest, cheek shards, eyes and grin, all accepted), cut off below the
chin. Everything else is new:

- A hulking body flying head first along -y: a deep chest and a tan belly bulging under the chin, massive shoulders
  either side of the head, a hump behind it, and a short body tapering behind, with no tail. It is a smooth surface
  from one signed distance field (ellipsoids and round cones joined smoothly), extracted with surface nets.
- Red rock armour fitted to that surface: rows of pointed plates down the back and flanks, layered over each other like
  the base form's, pauldrons, plates on the upper arms, elbows and forearms, and the chest. The belly stays tan skin;
  the gaps between plates are dark red.
- Black ram horns, ridged, from the base horns' roots, sweeping up and back and curling down behind the head.
- Arms in a flying punch: the right fist driven forward, the left cocked back by the chest. Black stone gauntlets and
  huge fists: the back of the hand, four curled fingers and a thumb, each a faceted block.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_rammstone_transformed.py`

Writes assets/source/slugs/models/rammstone/rammstone-transformed.blend and build/slugs/rammstone/transformed/renders/.
No rig or export. Concept 1 is kept as build_rammstone_transformed-v1-bolted.py and rammstone-transformed-v1.blend.
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
from common import ROOT
import build_rammstone_clean as base

OUT = ROOT/"build/slugs/rammstone/transformed"
BLEND = ROOT/"assets/source/slugs/models/rammstone/rammstone-transformed.blend"

HEAD_CUT = 0.92  # the base form is cut off below its chin; the head above stays exactly as accepted
DROP_PLATES = ("RammstonePlate.0.", "RammstonePlate.1.")  # the base form's lower back plates, inside the new body

# The body's field: ellipsoids (centre, radii) joined with a smooth minimum; "pair" ones are mirrored in x.
BODY = (
    ("torso", (0.0, 0.55, 1.25), (0.78, 0.80, 0.62)),
    ("chest", (0.0, 0.10, 1.05), (0.74, 0.52, 0.52)),
    ("belly", (0.0, -0.12, 0.72), (0.55, 0.55, 0.38)),  # bulging under the chin, tan
    ("hump", (0.0, 0.80, 1.66), (0.70, 0.55, 0.42)),
    ("neck", (0.0, -0.09, 1.12), (0.42, 0.45, 0.40)),  # inside the head's column, so the head sits on it
    ("pair pec", (0.52, -0.04, 1.10), (0.44, 0.40, 0.38)),
    ("pair lat", (0.70, 0.70, 1.28), (0.40, 0.58, 0.50)),
    ("pair trap", (0.70, 0.45, 1.78), (0.45, 0.42, 0.32)),  # shoulder up toward the back of the head
)
REAR = ((0.0, 1.15, 1.15), (0.0, 1.95, 0.98), 0.60, 0.22)  # a short body tapering behind, no tail
BODY_BLEND, ARM_BLEND = 0.22, 0.12

# Arms (shoulder, elbow, wrist): the right (-x) fist driven forward, the left (+x) cocked back by the chest at chin
# height, elbow behind. A brute's arms: the forearm about as thick as the head is tall and the fist as wide as the
# face, as in the owner's reference; the shoulders high, so the head sits down between them.
ARMS = {
    -1.0: ((-1.25, 0.40, 1.62), (-1.48, -0.62, 1.34), (-1.42, -1.66, 1.12)),
    1.0: ((1.25, 0.40, 1.62), (1.86, 1.08, 1.24), (1.80, 0.08, 1.30)),
}
DELTOID = (0.58, 0.56, 0.52)
UPPER_ARM = (0.46, 0.38)  # radius at the shoulder and the elbow
FOREARM = (0.36, 0.44)  # at the elbow and the wrist: thick toward the fist
FIST = (0.50, 0.58, 0.46)  # half depth (along the forearm), width and height

# The back's plates: rows starting at these y, each this long, layered front over back like the base form's blades;
# columns at an angle from the top of the back (centre, half width), the top column over the ones below it. Small
# plates read as a pine cone: few and big, as on the base form. A cap covers the rounded rear: the rows' points all
# met there in a star.
SPINE = ((0.30, 1.50), (0.9, 1.42), (1.5, 1.20), (2.0, 1.02))  # (y, z) of the body's core along it
BACK_ROWS = (0.42, 0.98, 1.50)
BACK_ROW_LENGTH = 0.82
REAR_CAP = ((0.0, 1.75, 1.02), (0.0, 1.0, -0.10))  # its centre and the way it faces: the rear's
# point under the last row (a dome there read as a nose, and the whole rear as a face)
BACK_COLUMNS = ((0.0, 0.40), (0.68, 0.40), (1.32, 0.40), (1.92, 0.32))
BELLY_HALF, BELLY_EDGE = 0.55, 0.30  # tan within this of the middle where the skin faces forward or down
BELLY_END = 1.15  # and ending underneath in a V like the base form's belly marks (from behind, tan at the very
# rear read as a mouth under the round end: a face)


# Ram horn (right side; the left mirrors it): through these points from the base horn's root, up and out, back, and
# curling down behind the head. Concept 1's horns rose and curled in: "horns facing the wrong way".
HORN = ((0.41, -0.17, 2.14), (0.60, -0.06, 2.48), (0.95, 0.22, 2.78), (1.38, 0.58, 2.88), (1.74, 0.95, 2.70),
        (1.86, 1.08, 2.38), (1.76, 0.90, 2.18), (1.60, 0.66, 2.26))
HORN_R, HORN_RINGS = 0.27, 8
GRID = 0.035  # the body field's sample spacing


# ---------------------------------------------------------------- the body's field

def ellipsoid(p, c, r):
    c, r = np.asarray(c), np.asarray(r)
    q = (p - c)/r
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(q/r, axis=-1)
    return k0*(k0 - 1.0)/np.maximum(k1, 1e-9)


def round_cone(p, a, b, r1, r2):
    """Distance to a capsule whose radius runs from r1 at a to r2 at b."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a
    l2 = ba @ ba
    rr = r1 - r2
    a2 = l2 - rr*rr
    il2 = 1.0/l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    xv = pa*l2 - np.outer(y, ba)
    x2 = np.einsum("ij,ij->i", xv, xv)
    y2, z2 = y*y*l2, z*z*l2
    k = math.copysign(1.0, rr)*rr*rr*x2
    d_b = np.sqrt(x2 + z2)*il2 - r2
    d_a = np.sqrt(x2 + y2)*il2 - r1
    d_side = (np.sqrt(np.maximum(x2*a2*il2, 0.0)) + y*rr)*il2 - r1
    return np.where(np.sign(z)*a2*z2 > k, d_b, np.where(np.sign(y)*a2*y2 < k, d_a, d_side))


def smin(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0.0)/k
    return np.minimum(a, b) - h*h*k*0.25


def upper_arm_field(p, sign):
    S, E, W = (np.array(v) for v in ARMS[sign])
    return smin(ellipsoid(p, S + np.array((sign*0.05, 0.0, 0.05)), DELTOID), round_cone(p, S, E, *UPPER_ARM), ARM_BLEND)


def forearm_field(p, sign):
    S, E, W = (np.array(v) for v in ARMS[sign])
    return round_cone(p, E, W, *FOREARM)


def arm_field(p, sign):
    return smin(upper_arm_field(p, sign), forearm_field(p, sign), ARM_BLEND)


def torso_field(p):
    d = round_cone(p, *REAR)
    for name, c, r in BODY:
        if name.startswith("pair"):
            for sx in (1.0, -1.0):
                d = smin(d, ellipsoid(p, (c[0]*sx, c[1], c[2]), r), BODY_BLEND)
        else:
            d = smin(d, ellipsoid(p, c, r), BODY_BLEND)
    return d


def field_parts(p):
    """The torso's and each arm's distances at points p (n, 3)."""
    return torso_field(p), arm_field(p, -1.0), arm_field(p, 1.0)


def field(p):
    p = np.asarray(p, float).reshape(-1, 3)
    out = np.empty(len(p))
    for i in range(0, len(p), 400000):
        t, l, r = field_parts(p[i:i + 400000])
        out[i:i + 400000] = smin(smin(t, l, 0.16), r, 0.16)
    return out


def gradient(p, eps=1e-3):
    g = np.zeros_like(p)
    for k in range(3):
        e = np.zeros(3)
        e[k] = eps
        g[:, k] = (field(p + e) - field(p - e))/(2*eps)
    return g


def project(p, level=0.0, iterations=3):
    for _ in range(iterations):
        g = gradient(p)
        p = p - ((field(p) - level)/np.maximum((g*g).sum(1), 1e-9))[:, None]*g
    return p


def surface_nets(lo, hi, h):
    """The field's zero surface as quads: a vertex in each cell the surface crosses, at the mean of its edge crossings,
    and a quad round each grid edge the surface crosses."""
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    n = (np.ceil((hi - lo)/h)).astype(int) + 1
    axes = [lo[k] + h*np.arange(n[k]) for k in range(3)]
    pts = np.stack(np.meshgrid(*axes, indexing="ij"), -1).reshape(-1, 3)
    v = field(pts).reshape(n)
    inside = v < 0
    corners = [(i, j, k) for k in (0, 1) for j in (0, 1) for i in (0, 1)]
    cells = n - 1
    count = sum(inside[i:i + cells[0], j:j + cells[1], k:k + cells[2]].astype(np.int8) for i, j, k in corners)
    active = (count > 0) & (count < 8)
    idx = np.argwhere(active)
    vals = [v[idx[:, 0] + i, idx[:, 1] + j, idx[:, 2] + k] for i, j, k in corners]
    total, hits = np.zeros((len(idx), 3)), np.zeros(len(idx))
    for a in range(8):
        for b in range(a + 1, 8):
            if sum(abs(x - y) for x, y in zip(corners[a], corners[b])) != 1:
                continue
            va, vb = vals[a], vals[b]
            cross = (va < 0) != (vb < 0)
            t = np.where(cross, va/np.where(cross, va - vb, 1.0), 0.0)
            pa, pb = np.array(corners[a]), np.array(corners[b])
            total += cross[:, None]*(idx + pa + t[:, None]*(pb - pa))
            hits += cross
    verts = lo + h*total/hits[:, None]
    cell_id = -np.ones(cells, dtype=np.int64)
    cell_id[tuple(idx.T)] = np.arange(len(idx))
    faces = []
    for a in range(3):
        b, c = (a + 1) % 3, (a + 2) % 3
        s0 = np.take(inside, range(0, n[a] - 1), axis=a)
        s1 = np.take(inside, range(1, n[a]), axis=a)
        e = np.argwhere(s0 != s1)
        e = e[(e[:, b] >= 1) & (e[:, c] >= 1) & (e[:, b] <= n[b] - 2) & (e[:, c] <= n[c] - 2)]
        quad = []
        for db, dc in ((-1, -1), (0, -1), (0, 0), (-1, 0)):
            q = e.copy()
            q[:, b] += db
            q[:, c] += dc
            quad.append(cell_id[tuple(q.T)])
        quad = np.stack(quad, 1)
        flip = ~s0[tuple(e.T)]
        quad[flip] = quad[flip][:, ::-1]
        faces.append(quad)
    return verts, np.concatenate(faces)


def relax(verts, faces, rounds=3):
    """Even the quads out: move each vertex toward its neighbours' mean, then back onto the surface."""
    nbr_sum = np.zeros_like(verts)
    for _ in range(rounds):
        nbr_sum[:] = 0.0
        deg = np.zeros(len(verts))
        for k in range(4):
            a, b = faces[:, k], faces[:, (k + 1) % 4]
            np.add.at(nbr_sum, a, verts[b])
            np.add.at(nbr_sum, b, verts[a])
            np.add.at(deg, a, 1)
            np.add.at(deg, b, 1)
        verts = verts + 0.5*(nbr_sum/np.maximum(deg, 1)[:, None] - verts)
        verts = project(verts, iterations=2)
    return verts


def build_body():
    lo = (-2.6, -2.4, 0.0)
    hi = (2.6, 2.4, 2.6)
    verts, faces = surface_nets(lo, hi, GRID)
    verts = project(verts)
    verts = relax(verts, faces)
    obj = base.make_object("RammstoneBrute", [tuple(v) for v in verts], [tuple(f) for f in faces], smooth=True)
    # The belly: tan where the torso's skin faces forward and down, dark red rock between the plates elsewhere. A
    # signed value (positive is rock) the material thresholds, so the line between them is smooth, not stepped.
    mesh = obj.data
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    g = gradient(co)
    nrm = g/np.linalg.norm(g, axis=1)[:, None]
    t, l, r = field_parts(co)
    on_arm = np.minimum(l, r) < t
    value = np.maximum(BELLY_EDGE - np.maximum(-nrm[:, 1], -nrm[:, 2]), np.abs(co[:, 0]) - BELLY_HALF)
    value = np.maximum(value, co[:, 1] - (BELLY_END - 0.5*np.abs(co[:, 0])))
    value = np.where(on_arm, 1.0, value)
    attr = mesh.attributes.new("armour", "FLOAT", "POINT")
    attr.data.foreach_set("value", value.astype(np.float32))
    return obj


# ---------------------------------------------------------------- plates fitted to the body

def rng(name):
    return np.random.default_rng(abs(hash(name)) % (2**32))


def part(fn, *args):
    """One part's field alone, for fitting plates: a plate fitted to the whole body followed rays through the next part
    (an arm, the torso) and came out far away as slivers and hanging sheets."""
    return lambda p: fn(np.asarray(p, float).reshape(-1, 3), *args)


def hit(origins, dirs, level, reach=2.2, step=0.02, surface=field):
    """Where each ray from inside surface's part first reaches its level (an array or a number)."""
    level = np.broadcast_to(np.asarray(level, float), (len(origins),))
    ts = np.arange(0.0, reach, step)
    p = origins[:, None, :] + ts[None, :, None]*dirs[:, None, :]
    d = surface(p.reshape(-1, 3)).reshape(len(origins), len(ts)) - level[:, None]
    first = np.argmax(d > 0, axis=1)
    lo_t, hi_t = ts[np.maximum(first - 1, 0)], ts[first]
    for _ in range(14):
        mid = (lo_t + hi_t)/2
        out = surface(origins + mid[:, None]*dirs) > level
        hi_t = np.where(out, mid, hi_t)
        lo_t = np.where(out, lo_t, mid)
    return origins + ((lo_t + hi_t)/2)[:, None]*dirs


def frame(axis, ref):
    axis = np.asarray(axis, float)
    axis = axis/np.linalg.norm(axis)
    ref = np.asarray(ref, float)
    n = ref - axis*(ref @ axis)
    n /= np.linalg.norm(n)
    return axis, n, np.cross(axis, n)


def spine_map(U, V):
    """U: angle round the body from the top of the back toward +x; V: y along it."""
    ys, zs = zip(*SPINE)
    origins = np.stack([np.zeros_like(V), V, np.interp(V, ys, zs)], -1)
    return origins, np.stack([np.sin(U), np.zeros_like(U), np.cos(U)], -1)


def limb_map(a, b, out):
    """U: angle round the limb a to b from the side facing out; V: 0 at a to 1 at b."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    axis, n, m = frame(b - a, out)

    def f(U, V):
        origins = a + (b - a)*V[:, None]
        return origins, np.cos(U)[:, None]*n + np.sin(U)[:, None]*m
    return f


def cap_map(centre, axis, side):
    """U, V: angles across and along a cap round axis from centre."""
    centre = np.asarray(centre, float)
    n, s, t = frame(axis, side)

    def f(U, V):
        d = n + np.tan(U)[:, None]*s + np.tan(V)[:, None]*t
        return np.broadcast_to(centre, d.shape).copy(), d/np.linalg.norm(d, axis=1)[:, None]
    return f


def plate(name, mapping, u, v, rows, cols, lift, thick=0.12, flare=0.0, taper=None, jag=0.0, closed=False,
          jitter=0.016, reach=2.2, surface=field):
    """A faceted rock plate standing lift off the body over the patch u (low, high) by v (low, high) of mapping, thick
    deep (its underside inside the body). It flares out by flare toward v's high end, narrows to taper(t) of its width
    along it (a point where taper reaches 0), and its low edge is cut jagged by jag. A ray that runs further than reach
    inside the body stays inside it (a cap's wide corner rays otherwise came out far away, as a long spike)."""
    r = rng(name)
    ts = np.linspace(0.0, 1.0, rows + 1)
    ss = np.linspace(0.0, 1.0, cols, endpoint=False) if closed else np.linspace(-1.0, 1.0, cols + 1)
    width = len(ss)
    U, V, T, point = [], [], [], []
    for i, t in enumerate(ts):
        w = 1.0 if taper is None else taper(t)
        point += [w <= 1e-6]*width
        for k, sv in enumerate(ss):
            if closed:
                U.append(u[0] + (u[1] - u[0])*sv)
            else:
                U.append((u[0] + u[1])/2 + (u[1] - u[0])/2*sv*w)
            dv = -jag*(1.0 if k % 2 == 0 else 0.2) if i == 0 else 0.0
            V.append(v[0] + (v[1] - v[0])*t + dv)
            T.append(t)
    U, V, T, point = np.array(U), np.array(V), np.array(T), np.array(point)
    origins, dirs = mapping(U, V)
    noise = r.uniform(-0.008, 0.008, len(U))
    nudge = r.uniform(-jitter, jitter, (len(U), 3))
    noise[point], nudge[point] = 0.0, 0.0  # a row narrowed to a point stays one point
    level = lift + flare*T + noise
    outer = hit(origins, dirs, level, reach, surface=surface)
    inner = hit(origins, dirs, lift - thick, reach, surface=surface)
    # Nudge the outer points across the ray, so the facets come out uneven.
    nudge -= dirs*(nudge*dirs).sum(1)[:, None]
    outer += nudge
    count = len(U)
    verts = [tuple(x) for x in outer] + [tuple(x) for x in inner]
    idx = lambda layer, i, k: layer*count + i*width + (k % width)
    span = width if closed else width - 1
    faces = []
    for i in range(rows):
        for k in range(span):
            faces.append((idx(0, i, k), idx(0, i, k + 1), idx(0, i + 1, k + 1), idx(0, i + 1, k)))
            faces.append((idx(1, i + 1, k), idx(1, i + 1, k + 1), idx(1, i, k + 1), idx(1, i, k)))
    for i in (0, rows):
        for k in range(span):
            faces.append((idx(0, i, k), idx(1, i, k), idx(1, i, k + 1), idx(0, i, k + 1)))
    if not closed:
        for k in (0, width - 1):
            for i in range(rows):
                faces.append((idx(0, i, k), idx(0, i + 1, k), idx(1, i + 1, k), idx(1, i, k)))
    faces = [f for f in faces if len({verts[j] for j in f}) >= 3]
    return base.make_object(name, verts, faces, smooth=False, facet=0.5)


def blade(t):
    """Full width, then narrowing to a point: the base form's back plates."""
    return 1.0 if t < 0.5 else max(0.0, 1.0 - (t - 0.5)/0.5)**0.8


def build_back():
    torso = part(torso_field)
    plates = []
    for row, y0 in enumerate(BACK_ROWS):
        for col, (centre, half) in enumerate(BACK_COLUMNS):
            if (row == 0 and col >= 2) or (row == 2 and col == 3):  # the shoulders; the rear is narrow
                continue
            for sx in ((1.0,) if col == 0 else (1.0, -1.0)):
                name = f"RammstoneBack.{row}.{col}{'' if col == 0 else ('R' if sx > 0 else 'L')}"
                lift = 0.09 - 0.014*row - 0.01*col
                length = BACK_ROW_LENGTH*(0.7 if row == 2 else 1.0)  # the last row's points stop short of the rear's
                plates.append(plate(name, spine_map, (sx*centre - half, sx*centre + half), (y0, y0 + length),
                                    3, 3, lift, flare=0.06, taper=blade, jitter=0.012, surface=torso))
    plates.append(plate("RammstoneRearCap", cap_map(REAR_CAP[0], REAR_CAP[1], (1.0, 0.0, 0.0)), (-1.0, 1.0),
                        (-1.0, 0.8), 2, 3, 0.04, thick=0.12, jitter=0.03, reach=0.8, surface=torso))
    return plates


def arm_frame(sign):
    S, E, W = (np.array(v) for v in ARMS[sign])
    out = np.array((sign, 0.0, 0.35))
    return S, E, W, out


def build_arm_plates(sign):
    tag = "R" if sign < 0 else "L"
    S, E, W, out = arm_frame(sign)
    upper = part(upper_arm_field, sign)
    plates = []
    # Pauldron: a cap over the shoulder. Then bands all the way round the arm ("its arms should look like really
    # armored"), each jagged at its elbow end: a lame under the pauldron, the upper arm and the forearm.
    plates.append(plate(f"RammstonePauldron.{tag}", cap_map(S, (sign*0.70, -0.05, 0.72), (0.0, 1.0, 0.0)),
                        (-1.3, 1.3), (-1.2, 1.2), 4, 5, 0.11, thick=0.17, reach=1.2, surface=upper))
    up_arm = limb_map(E, S, out)  # from the elbow, so each band's jagged first edge faces it
    round_arm = (0.0, 2*math.pi)
    plates.append(plate(f"RammstoneLame.{tag}", up_arm, round_arm, (0.52, 0.88), 1, 7, 0.085, flare=-0.02, jag=0.07,
                        closed=True, reach=0.9, surface=upper))
    plates.append(plate(f"RammstoneUpperArm.{tag}", up_arm, round_arm, (0.12, 0.56), 2, 7, 0.07, flare=-0.015,
                        jag=0.08, closed=True, reach=0.9, surface=upper))
    # Elbow: a cap pointing back off the bend.
    bend = -((S - E)/np.linalg.norm(S - E) + (W - E)/np.linalg.norm(W - E))
    plates.append(plate(f"RammstoneElbow.{tag}", cap_map(E, bend, (0.0, 0.0, 1.0)), (-1.1, 1.1), (-1.0, 1.0), 2, 3,
                        0.075, taper=lambda t: 1.0 - 0.5*t, reach=0.9, surface=part(arm_field, sign)))
    plates.append(plate(f"RammstoneForearm.{tag}", limb_map(E, W, out), round_arm, (0.08, 0.74), 2, 7, 0.065,
                        flare=0.02, jag=0.06, closed=True, reach=0.9, surface=part(forearm_field, sign)))
    return plates


def build_chest():
    plates = []
    for sx, tag in ((1.0, "L"), (-1.0, "R")):
        def mapping(U, V, sx=sx):
            origins = np.stack([sx*U, np.full_like(U, 0.30), V], -1)
            d = np.array((sx*0.35, -1.0, -0.12))
            return origins, np.broadcast_to(d/np.linalg.norm(d), origins.shape).copy()
        plates.append(plate(f"RammstonePec.{tag}", mapping, (0.46, 1.0), (0.62, 1.10), 3, 3, 0.07,
                            surface=part(torso_field)))
    return plates


# ---------------------------------------------------------------- horns and fists (black stone)

def frames_along(points):
    """Tangents and parallel-transported normals along a polyline, so a swept section does not twist."""
    tangents = []
    for i in range(len(points)):
        a, b = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
        tangents.append((b - a).normalized())
    up = Vector((0.0, 0.0, 1.0)) if abs(tangents[0].z) < 0.9 else Vector((1.0, 0.0, 0.0))
    normals = [(up - tangents[0]*up.dot(tangents[0])).normalized()]
    for i in range(1, len(points)):
        normals.append((normals[-1] - tangents[i]*normals[-1].dot(tangents[i])).normalized())
    return tangents, normals


def sweep(name, points, radii, sides, jitter=0.0, squash=1.0, phase=0.0):
    """A faceted tube along points, a radius per point, closed at the root and pointed if the last radius is 0."""
    tangents, normals = frames_along(points)
    r = rng(name)
    verts, faces = [], []
    tip = radii[-1] <= 1e-6
    rings = len(points) - (1 if tip else 0)
    for i in range(rings):
        t, n = tangents[i], normals[i]
        b = t.cross(n)
        for k in range(sides):
            a = 2*math.pi*k/sides + phase
            q = points[i] + n*(radii[i]*math.cos(a)) + b*(radii[i]*squash*math.sin(a))
            if jitter:
                q += Vector(r.uniform(-jitter, jitter, 3))*min(1.0, radii[i]/0.05)
            verts.append(tuple(q))
    for i in range(rings - 1):
        for k in range(sides):
            a, c = i*sides + k, i*sides + (k + 1) % sides
            faces.append((a, c, c + sides, a + sides))
    if tip:
        verts.append(tuple(points[-1]))
        e = (rings - 1)*sides
        faces += [(e + k, e + (k + 1) % sides, len(verts) - 1) for k in range(sides)]
    faces.append(tuple(range(sides - 1, -1, -1)))
    return base.make_object(name, verts, faces, smooth=False, facet=0.5)


def catmull(controls, per):
    ext = [controls[0]*2 - controls[1]] + list(controls) + [controls[-1]*2 - controls[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1:i + 3]
        for j in range(per):
            t = j/per
            out.append(0.5*((2*p1) + (-p0 + p2)*t + (2*p0 - 5*p1 + 4*p2 - p3)*t*t + (-p0 + 3*p1 - 3*p2 + p3)*t**3))
    out.append(controls[-1])
    return out


def resample(points, count):
    p = np.array([tuple(q) for q in points])
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    u = np.linspace(0.0, s[-1], count)
    return [Vector(tuple(np.interp(x, s, p[:, k]) for k in range(3))) for x in u], s[-1]


def build_ram_horn(sign):
    controls = [Vector((c[0]*sign, c[1], c[2])) for c in HORN]
    pts, _ = resample(catmull(controls, 8), 72)
    down = (pts[0] - pts[1]).normalized()
    pts = [pts[0] + down*0.14] + pts  # its root continued into the hood, so it grows out of it
    radii = []
    for k in range(len(pts)):
        u = max(k - 1, 0)/(len(pts) - 2)
        ring = (u*HORN_RINGS) % 1.0  # each ring swells toward its far edge, then steps down: the ram horn's ridges
        radii.append(HORN_R*(1.0 - u)**0.7*(1.0 + 0.06*ring**1.5) if k < len(pts) - 1 else 0.0)
    return sweep(f"RammstoneRamHorn.{'L' if sign > 0 else 'R'}", pts, radii, 7, jitter=0.012, squash=0.78,
                 phase=math.pi/7)


def superellipsoid(name, centre, axes, half, n=3.0, rows=7, cols=10, jitter=0.0):
    """A faceted rounded block (superellipsoid of exponent n) at centre with axes (forward, side, up)."""
    f, sd, up = (Vector(a) for a in axes)
    centre = Vector(centre)
    r = rng(name)
    verts, faces = [], []
    e = 2.0/n

    def sp(v, p):
        return math.copysign(abs(v)**p, v)

    for i in range(rows + 1):
        th = math.pi*i/rows
        for j in range(cols):
            ph = 2*math.pi*j/cols
            x = sp(math.sin(th), e)*sp(math.cos(ph), e)
            y = sp(math.sin(th), e)*sp(math.sin(ph), e)
            z = sp(math.cos(th), e)
            q = centre + f*(x*half[0]) + sd*(y*half[1]) + up*(z*half[2])
            if jitter and 0 < i < rows:
                q += Vector(r.uniform(-jitter, jitter, 3))
            verts.append(tuple(q))
    for i in range(rows):
        for j in range(cols):
            a, b = i*cols + j, i*cols + (j + 1) % cols
            faces.append((a, b, b + cols, a + cols))
    return base.make_object(name, verts, faces, smooth=False, facet=0.5)


def build_fist(sign):
    """The gauntlet's cuff over the wrist, and the fist: the back of the hand, four curled fingers side by side across
    its front, and the thumb folded across them."""
    tag = "R" if sign < 0 else "L"
    S, E, W, out = arm_frame(sign)
    parts = [plate(f"RammstoneCuff.{tag}", limb_map(E, W, out), (0.0, 2*math.pi), (0.70, 1.04), 2, 7, 0.06,
                   thick=0.16, flare=0.04, jag=0.14, closed=True, jitter=0.03, reach=0.9,
                   surface=part(forearm_field, sign))]
    f = Vector(tuple(W - E)).normalized()
    sd = Vector((0.0, 0.0, 1.0)).cross(f).normalized()
    up = f.cross(sd).normalized()
    if up.z < 0:
        up, sd = -up, -sd
    w = Vector(tuple(W))
    k = FIST[1]/0.47  # the sizes below were set on a fist 0.47 wide
    centre = w + f*0.28*k + up*0.06*k
    parts.append(superellipsoid(f"RammstoneHand.{tag}", centre, (f, sd, up), (0.40*k, FIST[1], FIST[2]*0.82), n=2.6,
                                jitter=0.02*k))
    # Fingers: shorter than the hand is tall (tall ones read as bars), the middle two a little bigger.
    for i in range(4):
        x = (i - 1.5)/1.5
        big = 0.012 if i in (1, 2) else 0.0
        q = w + f*(0.58 - 0.04*abs(x))*k + sd*(x*FIST[1]*0.72) - up*0.02*k
        parts.append(superellipsoid(f"RammstoneFinger{i}.{tag}", q, (f, sd, up),
                                    ((0.18 + big)*k, (0.125 + big)*k, (0.28 + big)*k), n=2.4, rows=5, cols=8,
                                    jitter=0.014*k))
    # Thumb: two chunky blocks like the fingers (a swept tube read as a twig): its root on the inner side of the
    # hand, its end lying across the first two fingers' lower half.
    inner = sd if (sd.x*sign) < 0 else -sd  # toward the body
    parts.append(superellipsoid(f"RammstoneThumbRoot.{tag}", w + (f*0.36 + inner*0.44 - up*0.10)*k, (f, sd, up),
                                (0.22*k, 0.13*k, 0.17*k), n=2.4, rows=5, cols=8, jitter=0.014*k))
    parts.append(superellipsoid(f"RammstoneThumb.{tag}", w + (f*0.74 + inner*0.24 - up*0.17)*k, (f, sd, up),
                                (0.12*k, 0.22*k, 0.12*k), n=2.4, rows=5, cols=8, jitter=0.012*k))
    return parts


# ---------------------------------------------------------------- head, materials and render

def cut_head(built):
    """Keep the base form above HEAD_CUT: delete the body's and underlayer's skin below it and the lower back plates."""
    keep = []
    for o in built["parts"]:
        if o.name.startswith(DROP_PLATES):
            bpy.data.objects.remove(o)
            continue
        if o.name in ("RammstoneBody", "RammstoneRockUnder"):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < HEAD_CUT], context="VERTS")
            bm.to_mesh(o.data)
            bm.free()
        keep.append(o)
    return keep


def bevel(obj, clear=None, angle=50.0):
    """base.bevel's light worn edge, only on edges sharper than angle: plates' rims and the deeper creases. At the
    base form's 30 degrees every facet edge of a plate wrapped round an arm got one, and they read as scratches."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    weight = [float(len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(angle)
                    and (clear is None or min(clear(v.co) for v in e.verts) > 0.012)) for e in bm.edges]
    bm.free()
    obj.data.attributes.new("bevel_weight_edge", "FLOAT", "EDGE").data.foreach_set("value", np.array(weight, np.float32))
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = base.BEVEL
    mod.segments = 1
    mod.limit_method = "WEIGHT"
    mod.material = 1


def body_material(skin, rock):
    """The body's skin: the head's tan skin on the belly, the plates' dark red rock elsewhere, split on "armour"."""
    mat = skin.copy()
    mat.name = "RammstoneBruteSkin"
    tree = mat.node_tree
    output = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
    link = output.inputs["Surface"].links[0]
    skin_out = link.from_socket
    dark = tree.nodes.new("ShaderNodeBsdfPrincipled")
    rock_mix = base.attribute_mix(rock, "facet")
    dark.inputs["Base Color"].default_value = tuple(rock_mix.inputs[6].default_value)
    dark.inputs["Roughness"].default_value = 0.75
    dark.inputs["Specular IOR Level"].default_value = 0.3
    attr = tree.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "armour"
    step = tree.nodes.new("ShaderNodeMapRange")
    step.inputs["From Min"].default_value = -0.01
    step.inputs["From Max"].default_value = 0.01
    tree.links.new(attr.outputs["Fac"], step.inputs["Value"])
    mix = tree.nodes.new("ShaderNodeMixShader")
    tree.links.new(step.outputs["Result"], mix.inputs["Fac"])
    tree.links.new(skin_out, mix.inputs[1])
    tree.links.new(dark.outputs["BSDF"], mix.inputs[2])
    tree.links.new(mix.outputs["Shader"], output.inputs["Surface"])
    return mat


def bounds(objects):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objects:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def render(objects):
    """Front, sides and back orthographic; three-quarter, a low hero angle, the shooter's chase view from behind and
    the face in perspective; the base form's review lights."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Review")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.05, 0.045, 0.05, 1)
    scene.world = world
    for name, energy, colour, rot in (("Key", 1.6, (1, 0.97, 0.93), (50, -30, -25)), ("Fill", 0.35, (0.75, 0.75, 1.0), (70, 20, 140)),
                                      ("Rim", 1.3, (1.0, 0.5, 0.3), (65, 0, 200)), ("Front", 0.6, (1, 0.95, 0.9), (75, 0, 0))):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.data.color = colour
        light.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(light)
    lo, hi = bounds(objects)
    mid, size = (lo + hi)/2, hi - lo
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    out = OUT/"renders"
    out.mkdir(parents=True, exist_ok=True)
    names = []

    def shot(name):
        scene.render.filepath = str(out/f"{name}.png")
        bpy.ops.render.render(write_still=True)
        names.append(f"{name}.png")

    scene.render.film_transparent = True
    cam.data.type = "ORTHO"
    scene.render.resolution_x, scene.render.resolution_y = 1000, 800
    for name, toward, wide in (("front", Vector((0, -1, 0)), size.x), ("side-left", Vector((1, 0, 0)), size.y),
                               ("back", Vector((0, 1, 0)), size.x), ("side-right", Vector((-1, 0, 0)), size.y)):
        cam.data.ortho_scale = max(size.z*1.25, wide)*1.06
        cam.location = mid + toward*12
        cam.rotation_euler = (-toward).to_track_quat("-Z", "Y").to_euler()
        shot(name)
    scene.render.film_transparent = False
    cam.data.type = "PERSP"
    cam.data.lens = 70
    scene.render.resolution_x, scene.render.resolution_y = 1000, 800
    reach = size.length
    for name, yaw, rise, target, dist in (("three-quarter", 0.62, 0.18, mid, 2.3*reach), ("hero", -0.55, -0.10, mid, 2.2*reach),
                                          ("chase", math.pi + 0.35, 0.45, mid, 2.4*reach),
                                          ("face", 0.30, 0.06, Vector((-0.2, -0.4, 1.4)), 1.25*reach)):
        offset = Vector((-math.sin(yaw), -math.cos(yaw), rise)).normalized()*dist
        cam.location = target + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        shot(name)
    for o in [o for o in scene.objects if o.type in {"LIGHT", "CAMERA"}]:
        bpy.data.objects.remove(o)
    return names


def main():
    s = base.Sheet(json.loads(base.MEASURE.read_text()))
    built = base.build(s, horns=False)
    head = cut_head(built)
    rock, skin, horn = (bpy.data.materials[n] for n in ("RammstoneRock", "RammstoneSkin", "RammstoneHorn"))
    rock_edge, horn_edge = bpy.data.materials["RammstoneRockEdge"], bpy.data.materials["RammstoneHornEdge"]
    body = build_body()
    body.data.materials.append(body_material(skin, rock))
    clear = lambda q: float(field(np.array(tuple(q)))[0])
    red = build_back() + build_chest() + build_arm_plates(-1.0) + build_arm_plates(1.0)
    black = [build_ram_horn(1.0), build_ram_horn(-1.0)] + build_fist(-1.0) + build_fist(1.0)
    for o in red:
        bevel(o, clear=clear)
        o.data.materials.append(rock)
        o.data.materials.append(rock_edge)
    for o in black:
        bevel(o, angle=35.0)
        o.data.materials.append(horn)
        o.data.materials.append(horn_edge)
    added = [body] + red + black
    for o in added:
        o.parent = built["rig"]
    built["rig"].name = "RammstoneTransformed"
    everything = head + added
    renders = render(everything)
    report = {"tool": bpy.app.version_string, "triangles": base.triangles(everything),
              "body_triangles": base.triangles([body]), "plates": len(red), "renders": renders}
    (OUT/"report.json").write_text(json.dumps(report, indent=2))
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
