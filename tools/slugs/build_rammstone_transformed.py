"""Build Rammstone's transformed form: concept 4, a long slug body under the base form's head, with a punch to play.

Owner, 2026-11-13, on concept 1 (the base form with arms and devil horns added): "this aint transformed u just slapped
stuff on the base model, horns facing the wrong way too, look at burpy for example", with a reference of a red brute
flying fist first with ram horns and stone fists, "black not blue". A transformed form is a new body carrying the face,
as Inferno's ("Burpy") slug-dragon is.

On concept 2 (a hulking brute in a flying punch): "The horns are a bit too long... They should point back more as well.
And they should curl a bit more so that they don't look as long." "I don't really want proper fists... I think fists
look goofy... just like have like jagged black rock looking things for the hands." "I want the arms to be a little
curved, like have like elbows." "Rather than... some Superman ass pose... the ramstone is gonna like swing... maybe
start with his hands tucked in at his sides, and it just swings a punch with one of his arms." "The belly's bloody
massive. And make the like body longer... a more gradual descent into that end bit... Right now it looks like a
decapitated bodybuilder. Should be a similar size to Burpee. Maybe not as long, because obviously burpee has a tail."

On concept 3: the length is right but "he's too beefy... Maybe it's because his arms are tucked in too tightly... it
doesn't taper down early enough... a beefy missile. Or maybe it's just because of the chin"; the horns "don't attach
smoothly... tilt them forward... make sure... the horns don't look like they're poking upwards too much" and the curl
"gets too thin. It should stay like the same consistent thick size"; the hands "are perfect, but... add 2 extra rocks
per hand... like the number 5 on a dice", "there's like a red sphere that you can see. It should just be fully rock...
make the hand look a bit bigger too. And more dangerous."

So:
- The base form's head (face, hood, crest, cheek shards, eyes and grin, all accepted) cut off below the chin, at the
  front of a long slug body flying head first along -y, as Burpy's head is the front of his body: about as wide as the
  head, flowing back from the hood and tapering gradually to a point, with no tail and no bulging belly, only a slim tan
  sole underneath. One smooth signed distance field, extracted with surface nets.
- Red rock armour fitted to it: rows of pointed plates down the back and flanks like the base form's, pauldrons, jagged
  bands round each upper arm and forearm, elbow caps.
- Shorter black ram horns curling tightly back and down behind the head.
- Arms bent at the elbow, the hands tucked in at his sides; each hand a jagged lump of black rock with shards, not a
  fist. A simple rig (a body bone and two bones an arm, the pieces riding them) plays the punch: he winds up and swings
  his right arm forward, turning into it, and settles back (frames 1 to 40).

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_rammstone_transformed.py`

Writes assets/source/slugs/models/rammstone/rammstone-transformed.blend and build/slugs/rammstone/transformed/renders/.
No export; the rig is for showing the punch, not the game's. Concepts 1 and 2 are kept as
build_rammstone_transformed-v1-bolted.py / -v2-brute.py and rammstone-transformed-v1.blend / -v2.blend.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT
import build_rammstone_clean as base

OUT = ROOT/"build/slugs/rammstone/transformed"
BLEND = ROOT/"assets/source/slugs/models/rammstone/rammstone-transformed.blend"

HEAD_CUT = 1.24  # (the hood's lower edge; cut at 0.92, its edge hung beside the chin with a gap behind: "look at the gaps")  # the base form's rock underlayer is cut off below the chin; the head above stays exactly as accepted
# The jaw guard: one crescent of red rock hugging the crisp jaw edge, its two edges meeting at each end on the cheek
# plate's own point (0.42, -0.39, 1.10). Rays start at JAW_FROM and aim between the edges; (|u|, (|x|, y, z)):
JAW_FROM = (0.0, -0.10, 1.00)
JAW_TOP = ((0.0, (0.00, -0.66, 0.985)), (0.6, (0.33, -0.56, 0.99)), (0.85, (0.43, -0.45, 1.03)), (1.0, (0.42, -0.39, 1.10)))
JAW_BOTTOM = ((0.0, (0.00, -0.40, 0.80)), (0.6, (0.36, -0.36, 0.84)), (0.85, (0.50, -0.31, 0.99)), (1.0, (0.57, -0.29, 1.17)))  # the lower edge's ends run back
# along the cheek plate's lower edge, filling the wedge of skin left between them when both edges met at the point
DROP_PLATES = ("RammstonePlate.0.", "RammstonePlate.1.", "RammstonePlate.2.")  # the base form's lower back plates,
# inside the new body (row 2's tips poked out under the throat as a red V)

# The chin. The base form's skin is cut off at SKIN_SEAM, below the mouth, and the new body's surface continues its
# column exactly from there (the same superellipse sections), down to COLUMN_BOTTOM, turning under COLUMN_ROUND deep
# into the underside in one surface. Every earlier chin was a second skin meeting the head's: a separate chin showed a
# stitched line or a fold like a fat lip; the head's skin bent under made "that weird double chin skin flab" where it
# met the body underneath, whatever was blended or covered. The tight turn gives a crisp jaw edge with no armour on it
# (owner, on concept 10's jaw plate: "the chin thing is still looking so retarded"): a plate laid round a soft chin read
# as a chin strap, a patch or a slab, whatever its shape.
SKIN_SEAM = 0.95
COLUMN_BOTTOM, COLUMN_ROUND, COLUMN_TOP, COLUMN_BLEND = 0.90, 0.08, 1.20, 0.12
COLUMN = None  # the base form's sections (z, front, back, half), from the sheet: set by main()

# The body: ellipsoids (centre, radii) and a round cone tapering behind, joined with a wide smooth minimum so it
# flows from the head back to its point. About as wide as the hood, like Burpy's body behind his head.
BODY = (  # (name, centre, radii, how wide its join is); concept 3 was "too beefy... a beefy missile": slimmer, and
    # tapering from just behind the shoulders
    ("chest", (0.0, 0.38, 1.40), (0.68, 0.70, 0.54), 0.30),
    ("throat", (0.0, 0.12, 0.90), (0.32, 0.45, 0.10), 0.15),  # under the chin, inside the column at the seam
    ("collar", (0.0, 0.05, 1.18), (0.60, 0.50, 0.28), 0.15),  # solid under the hood either side of the chin
)  # Concept 2's bulging belly was "bloody massive"; concept 3's chin "fat".
REAR = ((0.0, 0.95, 1.34), (0.0, 1.85, 1.15), 0.56, 0.33)
TAIL_END = ((0.0, 1.85, 1.15), (0.0, 2.62, 1.22), 0.33, 0.10)  # the point lifting a little: a straight cone to it
# "looks a bit stiff"  # "a more gradual descent into that end bit", no tail:
# one even taper from behind the shoulders to the point (a body ellipsoid ending part way made a step there)
ARM_BLEND = 0.12

# Arms at rest (shoulder, elbow, wrist): bent, the elbows back, the hands at his sides beside the chin, angled out
# from the body (tucked tight, they made him look beefy).
ARMS = {
    -1.0: ((-0.86, 0.45, 1.40), (-1.30, 1.08, 1.00), (-1.30, 0.36, 0.80)),
    1.0: ((0.86, 0.45, 1.40), (1.30, 1.08, 1.00), (1.30, 0.36, 0.80)),
}
DELTOID = (0.36, 0.34, 0.34)
UPPER_ARM = (0.32, 0.27)  # radius at the shoulder and the elbow
FOREARM = (0.26, 0.30)  # at the elbow and the wrist
HAND = (0.44, 0.48, 0.42)  # the hand's rock: half depth (along the forearm), width and height; "a bit bigger too"

# The punch: (frame, body (turn about z and roll about y in degrees, shift), right arm's (elbow, wrist), left arm's),
# positions in the body's frame; None is an arm at rest. Owner on concept 4's: "it just looks like a small little bop...
# kind of move to the left and then swing... it should be like a full-on hook... the punch should have that oomph". He
# coils away and shifts to his left with the right arm cocked high and back, holds it a moment, then the arm whips
# round wide and across in front (frames 11 to 15 at an even, fast pace) as he turns hard into it and lunges, the left
# arm pulling back; he overshoots, holds the hit and settles.
REST = ((0.0, 0.0, (0.0, 0.0, 0.0)), None, None)
STRIKE = ((-1.25, -0.40, 1.36), (-0.62, -1.18, 1.22))
LEFT_BACK = ((1.32, 1.28, 1.06), (1.38, 0.58, 0.88))
PUNCH = (  # the hit lands at frame 10 (0.42 s in); concept 6's, landing at 15, was "a bit too long" for short shots
    (1,) + REST,
    (5, (-24.0, 6.0, (0.12, 0.10, 0.0)), ((-1.20, 1.25, 1.45), (-1.42, 0.60, 1.60)), None),
    (7, (-26.0, 7.0, (0.13, 0.12, 0.0)), ((-1.20, 1.28, 1.48), (-1.44, 0.62, 1.64)), None),
    (8, (4.0, 0.0, (0.0, -0.10, 0.0)), ((-1.62, 0.25, 1.40), (-1.70, -0.62, 1.30)), LEFT_BACK),
    (10, (26.0, -8.0, (-0.10, -0.30, 0.0)), STRIKE, LEFT_BACK),
    (12, (31.0, -9.0, (-0.12, -0.36, 0.0)), ((-1.22, -0.45, 1.34), (-0.55, -1.22, 1.20)), LEFT_BACK),
    (16, (24.0, -6.0, (-0.08, -0.25, 0.0)), STRIKE, LEFT_BACK),
    (28,) + REST,
    (34,) + REST,
)
FAST = (7, 8)  # keys whose following stretch runs at an even pace: the swing, with no ease into the hit
PUNCH_SHOTS = (1, 5, 7, 8, 10, 12, 16, 28)  # the frames rendered

# The back's plates: rows starting at these y, layered front over back like the base form's blades; columns at an
# angle from the top of the back (centre, half width), the top column over the ones below it. Few big plates (small
# ones read as a pine cone). The last row stops short of the point, where a small cap sits.
SPINE = ((0.25, 1.40), (0.95, 1.34), (1.85, 1.15), (2.60, 1.20))  # (y, z) of the body's core along it
BACK_ROWS = (0.45, 0.95, 1.45, 1.92)  # each row stepping down only a little from the one before: rows whose points
BACK_ROW_LENGTH = 0.72  # flared well up over the next made "a big drop off" at the third
BACK_COLUMNS = ((0.0, 0.40), (0.68, 0.40), (1.32, 0.40), (1.92, 0.32))
REAR_CAP = ((0.0, 2.45, 1.19), (0.0, 1.0, 0.10))  # its centre and the way it faces
BELLY_HALF, BELLY_EDGE, BELLY_END = 0.46, 0.45, 2.45  # the tan sole: this far either side of the middle, where the
# skin faces down (or forward, at the chin), ending near the point in a V like the base form's belly marks

# Ram horn (right side; the left mirrors it): from the base horn's root, coming out of the hood tilted forward, then
# arcing back low over the head and curling tightly down behind it with its tip forward. Concept 2's were "a bit too
# long" and should "point back more... curl a bit more"; concept 3's rose straight up out of the hood ("they don't
# attach smoothly... tilt them forward... make sure... they don't look like they're poking upwards too much").
HORN = ((0.41, -0.17, 2.14), (0.48, -0.28, 2.32), (0.62, -0.16, 2.46), (0.82, 0.18, 2.50), (1.00, 0.58, 2.38),
        (1.08, 0.86, 2.14), (1.05, 0.72, 1.95), (0.99, 0.44, 1.99))
HORN_R, HORN_RINGS = 0.25, 6
HORN_SCALE = 0.82  # the path drawn about its root at this size: concept 4's were "a bit too long"
HORN_TUCK = 0.8  # and drawn this much closer in toward the head: "tuck the horns in a bit more"
GRID = 0.035  # the field's sample spacing


# ---------------------------------------------------------------- fields

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


def as_points(p):
    return np.asarray(p, float).reshape(-1, 3)


def column_sections(s):
    zs = np.linspace(0.70, COLUMN_TOP, 26)
    return (zs,) + tuple(np.array(a) for a in zip(*(base.body_section(s, z) for z in zs)))


def column_field(p):
    """The base form's skin column, its superellipse section at each height, rounded off below COLUMN_BOTTOM and
    closed above COLUMN_TOP (inside the head)."""
    p = as_points(p)
    zs, front, back, half = COLUMN
    z = np.clip(p[:, 2], COLUMN_BOTTOM, COLUMN_TOP)
    f, b, h = (np.interp(z, zs, a) for a in (front, back, half))
    yc, d = (f + b)/2, (b - f)/2
    n = base.BODY_N
    flat = (np.abs(p[:, 0]/h)**n + np.abs((p[:, 1] - yc)/d)**n)**(1.0/n)
    below = np.maximum(COLUMN_BOTTOM - p[:, 2], 0.0)/COLUMN_ROUND
    above = np.maximum(p[:, 2] - COLUMN_TOP, 0.0)/0.05
    return (np.sqrt(flat**2 + below**2 + above**2) - 1.0)*np.minimum(h, d)


def body_field(p):
    """The new body without the head's column."""
    p = as_points(p)
    d = smin(round_cone(p, *REAR), round_cone(p, *TAIL_END), 0.2)
    for _, c, r, k in BODY:
        d = smin(d, ellipsoid(p, c, r), k)
    return d


def torso_field(p):
    p = as_points(p)
    return smin(body_field(p), column_field(p), COLUMN_BLEND)


def upper_arm_field(p, sign):
    S, E, W = (np.array(v) for v in ARMS[sign])
    p = as_points(p)
    return smin(ellipsoid(p, S + np.array((sign*0.05, 0.0, 0.04)), DELTOID), round_cone(p, S, E, *UPPER_ARM), ARM_BLEND)


def forearm_field(p, sign):
    S, E, W = (np.array(v) for v in ARMS[sign])
    return round_cone(as_points(p), E, W, *FOREARM)


def field(p):
    """The whole body at rest."""
    p = as_points(p)
    d = torso_field(p)
    for sign in (-1.0, 1.0):
        d = np.minimum(d, np.minimum(upper_arm_field(p, sign), forearm_field(p, sign)))
    return d


def part(fn, *args):
    """One part's field alone: plates fitted to the whole body followed rays through the next part (an arm, the torso)
    and came out far away as slivers and hanging sheets."""
    return lambda p: fn(as_points(p), *args)


def gradient(f, p, eps=1e-3):
    g = np.zeros_like(p)
    for k in range(3):
        e = np.zeros(3)
        e[k] = eps
        g[:, k] = (f(p + e) - f(p - e))/(2*eps)
    return g


def project(f, p, level=0.0, iterations=3):
    for _ in range(iterations):
        g = gradient(f, p)
        p = p - ((f(p) - level)/np.maximum((g*g).sum(1), 1e-9))[:, None]*g
    return p


def surface_nets(f, lo, hi, h):
    """f's zero surface as quads: a vertex in each cell the surface crosses, at the mean of its edge crossings, and a
    quad round each grid edge the surface crosses."""
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    n = (np.ceil((hi - lo)/h)).astype(int) + 1
    axes = [lo[k] + h*np.arange(n[k]) for k in range(3)]
    pts = np.stack(np.meshgrid(*axes, indexing="ij"), -1).reshape(-1, 3)
    v = np.concatenate([f(pts[i:i + 400000]) for i in range(0, len(pts), 400000)]).reshape(n)
    inside = v < 0
    corners = [(i, j, k) for k in (0, 1) for j in (0, 1) for i in (0, 1)]
    cells = n - 1
    count = sum(inside[i:i + cells[0], j:j + cells[1], k:k + cells[2]].astype(np.int8) for i, j, k in corners)
    idx = np.argwhere((count > 0) & (count < 8))
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


def relax(f, verts, faces, rounds=3):
    """Even the quads out: move each vertex toward its neighbours' mean, then back onto the surface."""
    for _ in range(rounds):
        nbr_sum = np.zeros_like(verts)
        deg = np.zeros(len(verts))
        for k in range(4):
            a, b = faces[:, k], faces[:, (k + 1) % 4]
            np.add.at(nbr_sum, a, verts[b])
            np.add.at(nbr_sum, b, verts[a])
            np.add.at(deg, a, 1)
            np.add.at(deg, b, 1)
        verts = verts + 0.5*(nbr_sum/np.maximum(deg, 1)[:, None] - verts)
        verts = project(f, verts, iterations=2)
    return verts


def skin(name, f, lo, hi, armour):
    """A smooth skin mesh of f's surface inside the box lo to hi; armour(points, normals) gives the "armour" value the
    material splits on (positive: dark red rock; negative: tan skin)."""
    verts, faces = surface_nets(f, lo, hi, GRID)
    verts = relax(f, project(f, verts), faces)
    obj = base.make_object(name, [tuple(v) for v in verts], [tuple(q) for q in faces], smooth=True)
    mesh = obj.data
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    g = gradient(f, co)
    value = armour(co, g/np.linalg.norm(g, axis=1)[:, None])
    mesh.attributes.new("armour", "FLOAT", "POINT").data.foreach_set("value", value.astype(np.float32))
    return obj


def belly(co, nrm):
    """The tan sole: underneath, within BELLY_HALF of the middle, facing down, ending in a V; and the chin all round."""
    chin = (co[:, 1] < 0.45) & (co[:, 2] < 1.05)  # the chin and the throat's sides back to the chest's plates: a shorter
    # reach left a red sliver on the throat's side
    value = np.maximum(np.where(chin, -1.0, BELLY_EDGE + nrm[:, 2]), np.abs(co[:, 0]) - BELLY_HALF)
    return np.maximum(value, co[:, 1] - (BELLY_END - 0.5*np.abs(co[:, 0])))


def trim_to_seam(obj):
    """Where the body's skin lies on the head's column above SKIN_SEAM, the head's own skin is there: the body's is
    sunk just inside it (more from a little below the seam up), so the head skin's clean cut edge is all that shows.
    Snapped to the seam, the body's edge showed as a ragged line under the mouth; deleted above it, it left a jagged
    edge with slits beside the jaw ("these last lil gaps")."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    co = np.array([tuple(v.co) for v in bm.verts])
    col = column_field(co)
    on_column = (np.abs(col) < 0.012) & (col <= body_field(co) + 0.01)
    g = gradient(column_field, co)
    g /= np.linalg.norm(g, axis=1)[:, None]
    drop = []
    for v, on, n in zip(bm.verts, on_column, g):
        if on and v.co.z > SKIN_SEAM + 0.06 and abs(v.co.x) < 0.40 and v.co.y < -0.30:
            drop.append(v)  # behind the mouth, which is carved into the head's skin: left there, this plain column
            # stood in front of the teeth and turned them red; its cut edge is hidden under the head's front face
        elif on and v.co.z > SKIN_SEAM - 0.02:
            v.co -= Vector(n)*0.008*min(1.0, (v.co.z - (SKIN_SEAM - 0.02))/0.03)
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def match_normals(head, torso):
    """Give the body's skin its field's own normals, and the head's skin the column's normals near the seam, so both
    shade alike where they meet (left to their own faces, a faint line showed across the chin). The head's other corners
    keep theirs (the mouth's sharp edges)."""
    mesh = torso.data
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    g = gradient(torso_field, co.reshape(-1, 3))
    mesh.normals_split_custom_set_from_vertices([tuple(v) for v in g/np.linalg.norm(g, axis=1)[:, None]])
    mesh = head.data
    normals = [tuple(n.vector) for n in mesh.corner_normals]
    loop_verts = np.empty(len(mesh.loops), np.int64)
    mesh.loops.foreach_get("vertex_index", loop_verts)
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    near = np.nonzero(co[:, 2] < SKIN_SEAM + 0.05)[0]
    g = gradient(column_field, co[near])
    fixed = dict(zip(near.tolist(), (g/np.linalg.norm(g, axis=1)[:, None]).tolist()))
    mesh.normals_split_custom_set([tuple(fixed[v]) if v in fixed else normals[i] for i, v in enumerate(loop_verts)])


def build_skins():
    torso = skin("RammstoneTransformedBody", torso_field, (-1.0, -0.8, 0.3), (1.0, 2.95, 2.25), belly)
    trim_to_seam(torso)
    arms = {}
    all_rock = lambda co, nrm: np.ones(len(co))
    for sign in (-1.0, 1.0):
        tag = "R" if sign < 0 else "L"
        S, E, W = (np.array(v) for v in ARMS[sign])
        upper_lo = np.minimum(S, E) - 0.62
        upper_hi = np.maximum(S, E) + 0.62
        fore_lo = np.minimum(E, W) - 0.5
        fore_hi = np.maximum(E, W) + 0.5
        arms[sign] = (skin(f"RammstoneUpperArmSkin.{tag}", part(upper_arm_field, sign), upper_lo, upper_hi, all_rock),
                      skin(f"RammstoneForearmSkin.{tag}", part(forearm_field, sign), fore_lo, fore_hi, all_rock))
    return torso, arms


# ---------------------------------------------------------------- plates fitted to the body

def rng(name):
    return np.random.default_rng(abs(hash(name)) % (2**32))


def hit(origins, dirs, level, reach=2.2, step=0.02, surface=field):
    """Where each ray from inside surface's part first reaches its level (an array or a number); a ray still inside
    after reach stays at its origin."""
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
        return a + (b - a)*V[:, None], np.cos(U)[:, None]*n + np.sin(U)[:, None]*m
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
          jitter=0.016, reach=2.2, surface=field, ridge=0.0, pinch=False):
    """A faceted rock plate standing lift off surface's part over the patch u (low, high) by v (low, high) of mapping,
    thick deep (its underside inside the body). It flares out by flare toward v's high end, narrows to taper(t) of its
    width along it (a point where taper reaches 0), and its low edge is cut jagged by jag. With ridge, it stands that
    much further out along its middle, most in the middle of the ridge. With pinch, its end columns are left exact (no
    jitter or ridge), so a mapping that brings an end's rows together closes it to a clean point."""
    r = rng(name)
    ts = np.linspace(0.0, 1.0, rows + 1)
    ss = np.linspace(0.0, 1.0, cols, endpoint=False) if closed else np.linspace(-1.0, 1.0, cols + 1)
    width = len(ss)
    U, V, T, S, point = [], [], [], [], []
    for i, t in enumerate(ts):
        w = 1.0 if taper is None else taper(t)
        point += [w <= 1e-6]*width
        for k, sv in enumerate(ss):
            U.append(u[0] + (u[1] - u[0])*sv if closed else (u[0] + u[1])/2 + (u[1] - u[0])/2*sv*w)
            V.append(v[0] + (v[1] - v[0])*t - (jag*(1.0 if k % 2 == 0 else 0.2) if i == 0 else 0.0))
            T.append(t)
            S.append(sv)
    U, V, T, S, point = np.array(U), np.array(V), np.array(T), np.array(S), np.array(point)
    origins, dirs = mapping(U, V)
    outside = int((surface(origins) > lift - thick).sum())
    if outside:  # a ray starting outside its surface never meets it, and the plate's vertex hangs at the ray's start
        print(f"WARNING {name}: {outside} of {len(U)} rays start outside the surface")
    noise = r.uniform(-0.008, 0.008, len(U))
    nudge = r.uniform(-jitter, jitter, (len(U), 3))
    noise[point], nudge[point] = 0.0, 0.0  # a row narrowed to a point stays one point
    raised = ridge*np.sin(np.pi*T)*(0.6 + 0.4*(1.0 - np.abs(S)))
    if pinch:
        keep = 1.0 - S**4
        noise, nudge, raised = noise*keep, nudge*keep[:, None], raised*keep
    outer = hit(origins, dirs, lift + flare*T + raised + noise, reach, surface=surface)
    inner = hit(origins, dirs, lift - thick, reach, surface=surface)
    nudge -= dirs*(nudge*dirs).sum(1)[:, None]  # across the ray, so the facets come out uneven
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
    last = len(BACK_ROWS) - 1
    for row, y0 in enumerate(BACK_ROWS):
        for col, (centre, half) in enumerate(BACK_COLUMNS):
            if (row == 0 and col >= 2) or (row == last and col == 3):  # the shoulders; the narrow point
                continue
            for sx in ((1.0,) if col == 0 else (1.0, -1.0)):
                name = f"RammstoneBack.{row}.{col}{'' if col == 0 else ('R' if sx < 0 else 'L')}"
                lift = 0.085 - 0.007*row - 0.01*col
                length = BACK_ROW_LENGTH*(0.75 if row == last else 1.0)
                plates.append(plate(name, spine_map, (sx*centre - half, sx*centre + half), (y0, y0 + length),
                                    3, 3, lift, flare=0.035, taper=blade, jitter=0.012, surface=torso))
    plates.append(plate("RammstoneRearCap", cap_map(REAR_CAP[0], REAR_CAP[1], (1.0, 0.0, 0.0)), (-1.0, 1.0),
                        (-1.0, 0.8), 2, 3, 0.04, thick=0.10, jitter=0.02, reach=0.6, surface=torso))
    for sx, tag in ((1.0, "L"), (-1.0, "R")):  # the chest's sides below the shoulders, beside the chin
        def mapping(U, V, sx=sx):
            # Rays from deep in the chest: once the body was slimmed, many started outside it, never met its surface
            # and left the plate hanging behind as an open shell ("still hollow on that like half cylinder thing").
            origins = np.stack([sx*U*0.3, np.full_like(U, 0.55), V], -1)
            d = np.stack([sx*(0.5 + U), -np.ones_like(U), np.full_like(U, -0.1)], -1)
            return origins, d/np.linalg.norm(d, axis=1)[:, None]
        plates.append(plate(f"RammstoneChest.{tag}", mapping, (0.30, 0.62), (1.06, 1.30), 2, 3, 0.006, flare=0.065,
                            surface=torso))  # just off the skin at its lower edge, so it rises out of it
    return plates


def arm_frame(sign):
    S, E, W = (np.array(v) for v in ARMS[sign])
    return S, E, W, np.array((sign, 0.0, 0.35))


def build_arm_plates(sign):
    """(upper arm's plates, forearm's plates): a pauldron over the shoulder, then jagged bands all the way round the
    arm ("its arms should look like really armored"), and a cap on the elbow."""
    tag = "R" if sign < 0 else "L"
    S, E, W, out = arm_frame(sign)
    upper = part(upper_arm_field, sign)
    fore = part(forearm_field, sign)
    round_arm = (0.0, 2*math.pi)
    up_arm = limb_map(E, S, out)  # from the elbow, so each band's jagged first edge faces it
    on_upper = [
        plate(f"RammstonePauldron.{tag}", cap_map(S, (sign*0.70, -0.05, 0.72), (0.0, 1.0, 0.0)), (-1.15, 1.15),
              (-1.05, 1.05), 3, 4, 0.09, thick=0.15, reach=1.0, surface=upper),
        plate(f"RammstoneLame.{tag}", up_arm, round_arm, (0.52, 0.86), 1, 7, 0.08, flare=-0.02, jag=0.07, closed=True,
              reach=0.8, surface=upper),
        plate(f"RammstoneUpperArm.{tag}", up_arm, round_arm, (0.14, 0.56), 2, 7, 0.065, flare=-0.015, jag=0.08,
              closed=True, reach=0.8, surface=upper),
    ]
    bend = -((S - E)/np.linalg.norm(S - E) + (W - E)/np.linalg.norm(W - E))
    on_upper.append(plate(f"RammstoneElbow.{tag}", cap_map(E, bend, (0.0, 0.0, 1.0)), (-1.0, 1.0), (-0.9, 0.9), 2, 3,
                          0.07, taper=lambda t: 1.0 - 0.5*t, reach=0.8, surface=lambda p: np.minimum(upper(p), fore(p))))
    on_fore = [plate(f"RammstoneForearm.{tag}", limb_map(E, W, out), round_arm, (0.10, 0.70), 2, 7, 0.06, flare=0.02,
                     jag=0.06, closed=True, reach=0.8, surface=fore)]
    return on_upper, on_fore


# ---------------------------------------------------------------- horns and hands (black stone)

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
    s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])
    u = np.linspace(0.0, s[-1], count)
    return [Vector(tuple(np.interp(x, s, p[:, k]) for k in range(3))) for x in u]


def build_ram_horn(sign):
    root = Vector(HORN[0])
    controls = [root + (Vector(c) - root)*HORN_SCALE for c in HORN]
    controls = [Vector((root.x + (c.x - root.x)*HORN_TUCK, c.y, c.z)) for c in controls]
    controls = [Vector((c.x*sign, c.y, c.z)) for c in controls]
    pts = resample(catmull(controls, 8), 64)
    down = (pts[0] - pts[1]).normalized()
    pts = [pts[0] + down*0.14] + pts  # its root continued into the hood, so it grows out of it
    radii = []
    for k in range(len(pts)):
        u = max(k - 1, 0)/(len(pts) - 2)
        ring = (u*HORN_RINGS) % 1.0  # each ring swells toward its far edge, then steps down: the ram horn's ridges
        # Thick all the way round the curl ("it gets too thin. It should stay like the same consistent thick size"),
        # closing to a blunt point only at the very end.
        end = min(1.0, (1.0 - u)/0.08)**0.6
        radii.append(HORN_R*(1.0 - 0.3*u)*(1.0 + 0.06*ring**1.5)*end if k < len(pts) - 1 else 0.0)
    return sweep(f"RammstoneRamHorn.{'L' if sign > 0 else 'R'}", pts, radii, 7, jitter=0.012, squash=0.78,
                 phase=math.pi/7)


def rock(name, centre, axes, half, rows=4, cols=7, n=2.0, jitter=0.0):
    """A faceted lump of rock: a coarse superellipsoid of exponent n at centre, axes (forward, side, up), each vertex
    pushed in or out at random so no two facets match."""
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
            ph = 2*math.pi*(j + 0.5*(i % 2))/cols
            local = Vector((sp(math.sin(th), e)*sp(math.cos(ph), e)*half[0], sp(math.sin(th), e)*sp(math.sin(ph), e)*half[1],
                            sp(math.cos(th), e)*half[2]))
            if 0 < i < rows:
                local *= 1.0 + r.uniform(-0.3*jitter, jitter)  # mostly outward: dents showed the arm inside
            verts.append(tuple(centre + f*local.x + sd*local.y + up*local.z))
    for i in range(rows):
        for j in range(cols):
            a, b = i*cols + j, i*cols + (j + 1) % cols
            faces.append((a, b, b + cols, a + cols))
    return base.make_object(name, verts, faces, smooth=False, facet=0.5)


def build_hand(sign):
    """The cuff round the wrist and the hand: a jagged lump of black rock with shards breaking out of its front and
    top, not a fist ("I think fists look goofy... jagged black rock looking things for the hands")."""
    tag = "R" if sign < 0 else "L"
    S, E, W, out = arm_frame(sign)
    parts = [plate(f"RammstoneCuff.{tag}", limb_map(E, W, out), (0.0, 2*math.pi), (0.66, 1.02), 2, 7, 0.06,
                   thick=0.16, flare=0.05, jag=0.12, closed=True, jitter=0.03, reach=0.8, surface=part(forearm_field, sign))]
    f = Vector(tuple(W - E)).normalized()
    sd = Vector((0.0, 0.0, 1.0)).cross(f).normalized()
    up = f.cross(sd).normalized()
    if up.z < 0:
        up, sd = -up, -sd
    outward = sd if (sd.x*sign) > 0 else -sd
    centre = Vector(tuple(W)) + f*0.22  # back over the wrist, so no red arm shows round it from the side
    parts.append(rock(f"RammstoneHand.{tag}", centre, (f, sd, up), HAND, jitter=0.16))
    # Shards: chunky wedges a little proud of the lump, (direction in forward, outward and up, length past the lump,
    # radius at the root). Five on the front like the five on a die (owner: "add 2 extra rocks per hand... like the
    # number 5 on a dice"), and four breaking out diagonally round the wrist ("more diagonal, sharp rock coming out to
    # cover that area"). Long thin ones read as a spiked mine.
    # Short and broad, as on concept 3's hands (which the owner called perfect); longer ones, and four spikes round
    # the wrist, read as a spiked mace.
    front = [((1.0, 0.0, 0.0), 0.15, 0.21)] + [((1.0, 0.55*a, 0.50*b), 0.12, 0.19) for a, b in ((1, 1), (-1, 1), (1, -1), (-1, -1))]
    wrist = [((-1.0, 0.75, 0.45), 0.10, 0.21), ((-1.0, -0.6, -0.55), 0.09, 0.20)]  # lying back along the wrist
    for k, (d, length, radius) in enumerate(front + wrist):
        direction = (f*d[0] + outward*d[1] + up*d[2]).normalized()
        reach = (HAND[0]*abs(direction.dot(f)) + HAND[1]*abs(direction.dot(sd)) + HAND[2]*abs(direction.dot(up)))*0.85
        root = centre + direction*(reach*0.35)
        tip = centre + direction*(reach + length)
        pts = [root, root + (tip - root)*0.55, tip]
        # Flattened into diagonal blades ("3 diagonal rocks"), not round spikes.
        parts.append(sweep(f"RammstoneHandShard{k}.{tag}", pts, [radius*1.15, radius*0.9, 0.0], 5, jitter=0.025,
                           squash=0.55, phase=0.6 + 0.9*k))
    return parts


# ---------------------------------------------------------------- head, materials, rig and render

def build_jaw():
    """The jaw guard (see JAW_TOP): just off the skin at its edges and standing out a little along the jaw edge, as the
    cheek plates rise out of the face, its ends on the cheek plates' points. Owner: "now theres no armour on jaw"."""
    surface = part(torso_field)
    origin = np.array(JAW_FROM)

    def edge(curve, U):
        knots = [k for k, _ in curve]
        x, y, z = (np.interp(np.abs(U), knots, [q[i] for _, q in curve]) for i in range(3))
        return np.stack([x*np.sign(U), y, z], -1)

    def toward(points):
        d = points - origin
        return d/np.linalg.norm(d, axis=1)[:, None]

    def mapping(U, V):
        d = (1.0 - V)[:, None]*toward(edge(JAW_BOTTOM, U)) + V[:, None]*toward(edge(JAW_TOP, U))
        return np.broadcast_to(origin, d.shape).copy(), d/np.linalg.norm(d, axis=1)[:, None]
    return plate("RammstoneJaw", mapping, (-1.0, 1.0), (0.0, 1.0), 4, 8, 0.016, thick=0.07, ridge=0.03, jitter=0.003,
                 reach=1.0, surface=surface, pinch=True)


def cut_head(s, built):
    """Keep the base form's head: its skin cut off at SKIN_SEAM (the new body's surface carries on from there), its
    rock underlayer cut off below HEAD_CUT, and its lower back plates removed."""
    keep = []
    for o in built["parts"]:
        if o.name.startswith(DROP_PLATES):
            bpy.data.objects.remove(o)
            continue
        if o.name == "RammstoneBody":
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0.0, 0.0, SKIN_SEAM),
                                   plane_no=(0.0, 0.0, 1.0), clear_inner=True)
            bm.to_mesh(o.data)
            bm.free()
        if o.name == "RammstoneRockUnder":
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


def body_material(skin_mat, rock_mat):
    """The new body's skin: the head's tan skin on the sole, the plates' dark red rock elsewhere, split on "armour"."""
    mat = skin_mat.copy()
    mat.name = "RammstoneBruteSkin"
    tree = mat.node_tree
    output = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
    skin_out = output.inputs["Surface"].links[0].from_socket
    dark = tree.nodes.new("ShaderNodeBsdfPrincipled")
    dark.inputs["Base Color"].default_value = tuple(base.attribute_mix(rock_mat, "facet").inputs[6].default_value)
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


TAIL_BONE = ((0.0, 1.25, 1.26), (0.0, 2.6, 1.22))
TAIL_SWING = {1: 0.0, 5: 9.0, 7: 10.0, 8: 3.0, 10: -12.0, 12: 6.0, 16: -3.0, 28: 0.0, 34: 0.0}  # the tail's turn (degrees)
# against the body's through the punch: it lags behind the wind-up and the swing, then whips past and settles, so
# the body bends instead of turning as one stiff block


def skin_to_tail(rig, obj):
    """The body's skin bends between the body and tail bones, its weight moving to the tail behind the shoulders."""
    obj.parent = rig
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    y = co.reshape(-1, 3)[:, 1]
    w = np.clip((y - 1.15)/0.8, 0.0, 1.0)
    w = w*w*(3.0 - 2.0*w)
    body, tail = obj.vertex_groups.new(name="Body"), obj.vertex_groups.new(name="Tail")
    for i, wt in enumerate(w):
        body.add([i], float(1.0 - wt), "REPLACE")
        tail.add([i], float(wt), "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


def build_rig(groups):
    """An armature with a body bone and two bones an arm; every piece rides one bone (no skinning). For showing the
    punch only; the game's rig comes after the look is approved."""
    rig = bpy.data.objects.new("RammstoneTransformed", bpy.data.armatures.new("RammstoneTransformedRig"))
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    body = bones.new("Body")
    body.head, body.tail = (0.0, 0.6, 1.3), (0.0, 0.6, 1.9)
    tail = bones.new("Tail")
    tail.head, tail.tail, tail.parent = TAIL_BONE[0], TAIL_BONE[1], body
    for sign in (-1.0, 1.0):
        tag = "R" if sign < 0 else "L"
        S, E, W = ARMS[sign]
        upper = bones.new(f"UpperArm.{tag}")
        upper.head, upper.tail, upper.parent = S, E, body
        fore = bones.new(f"Forearm.{tag}")
        fore.head, fore.tail, fore.parent, fore.use_connect = E, W, upper, True
    bpy.ops.object.mode_set(mode="OBJECT")
    for name, objects in groups.items():
        bone = rig.data.bones[name]
        at_tail = rig.matrix_world @ bone.matrix_local @ Matrix.Translation((0.0, bone.length, 0.0))
        for o in objects:
            o.parent = rig
            o.parent_type = "BONE"
            o.parent_bone = name
            o.matrix_parent_inverse = at_tail.inverted()
    return rig


def animate_punch(rig):
    """Keys PUNCH: the body turns, rolls and shifts; each arm's bones turn to aim at the elbow and wrist given."""
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = PUNCH[0][0], PUNCH[-1][0]

    def local(bone, q):
        m = rig.data.bones[bone].matrix_local.to_3x3()
        return (m.inverted() @ q.to_matrix() @ m).to_quaternion()

    def aim(sign, target):
        S, E0, W0 = (Vector(v) for v in ARMS[sign])
        if target is None:
            return Quaternion(), Quaternion()
        E1, W1 = Vector(target[0]), Vector(target[1])
        q_upper = (E0 - S).rotation_difference(E1 - S)
        return q_upper, q_upper.inverted() @ (W0 - E0).rotation_difference(W1 - E1)

    body_basis = rig.data.bones["Body"].matrix_local.to_3x3().inverted()
    for frame, (turn, roll, shift), right, left in PUNCH:
        rot = {"Body": Quaternion((0.0, 0.0, 1.0), math.radians(turn)) @ Quaternion((0.0, 1.0, 0.0), math.radians(roll))}
        rot["UpperArm.R"], rot["Forearm.R"] = aim(-1.0, right)
        rot["UpperArm.L"], rot["Forearm.L"] = aim(1.0, left)
        for bone, q in rot.items():
            pb = rig.pose.bones[bone]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = local(bone, q)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        body = rig.pose.bones["Body"]
        body.location = body_basis @ Vector(shift)
        body.keyframe_insert("location", frame=frame)
        tail = rig.pose.bones["Tail"]
        tail.rotation_mode = "QUATERNION"
        tail.rotation_quaternion = local("Tail", Quaternion((0.0, 0.0, 1.0), math.radians(TAIL_SWING[frame])))
        tail.keyframe_insert("rotation_quaternion", frame=frame)
    for curve in action_fcurves(rig):
        for key in curve.keyframe_points:
            if int(round(key.co.x)) in FAST:
                key.interpolation = "LINEAR"
    scene.frame_set(1)


def action_fcurves(obj):
    """The F-curves of obj's action, from its slot's channelbag where actions are layered (Blender 4.4 on)."""
    action = obj.animation_data.action
    if hasattr(action, "layers") and action.layers:
        slot = obj.animation_data.action_slot
        return [c for layer in action.layers for strip in layer.strips for c in strip.channelbag(slot).fcurves]
    return list(action.fcurves)


def bounds(objects):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objects:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def render(objects, option=()):
    """Front, sides and back orthographic and three-quarter, hero, chase and face in perspective, at rest; then the
    punch from the three-quarter view; the base form's review lights."""
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
    scene.frame_set(1)
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

    def aim(target, yaw, rise, dist):
        offset = Vector((-math.sin(yaw), -math.cos(yaw), rise)).normalized()*dist
        cam.location = target + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()

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
    reach = size.length
    for name, yaw, rise, target, dist in (("three-quarter", 0.62, 0.18, mid, 2.3*reach), ("hero", -0.55, -0.10, mid, 2.2*reach),
                                          ("chase", math.pi + 0.35, 0.45, mid, 2.4*reach),
                                          ("face", 0.30, 0.06, Vector((0.0, -0.4, 1.4)), 1.25*reach)):
        aim(target, yaw, rise, dist)
        shot(name)
    # The chin from low in front, as the owner looks at it, with and without option B, and the face with it.
    low = Vector((0.5, -5.0, -0.1))
    cam.location = low
    cam.rotation_euler = (Vector((0.0, -0.3, 1.05)) - low).to_track_quat("-Z", "Y").to_euler()
    shot("chin-clean")
    for o in option:
        o.hide_render = False
    shot("chin-blades")
    aim(Vector((0.0, -0.4, 1.4)), 0.30, 0.06, 1.25*reach)
    shot("face-blades")
    for o in option:
        o.hide_render = True
    scene.render.resolution_x, scene.render.resolution_y = 800, 640
    aim(mid + Vector((0.0, -0.4, 0.0)), 0.85, 0.28, 2.6*reach)  # from in front on his right, the punching side
    for frame in PUNCH_SHOTS:
        scene.frame_set(frame)
        shot(f"punch-{frame:02d}")
    scene.frame_set(1)
    for o in [o for o in scene.objects if o.type in {"LIGHT", "CAMERA"}]:
        bpy.data.objects.remove(o)
    return names


def main():
    s = base.Sheet(json.loads(base.MEASURE.read_text()))
    built = base.build(s, horns=False)
    head = cut_head(s, built)
    bpy.data.objects.remove(built["rig"])
    rock_mat, skin_mat, horn_mat = (bpy.data.materials[n] for n in ("RammstoneRock", "RammstoneSkin", "RammstoneHorn"))
    rock_edge, horn_edge = bpy.data.materials["RammstoneRockEdge"], bpy.data.materials["RammstoneHornEdge"]
    body_mat = body_material(skin_mat, rock_mat)
    global COLUMN
    COLUMN = column_sections(s)
    torso, arm_skins = build_skins()
    match_normals(next(o for o in head if o.name == "RammstoneBody"), torso)
    clear = lambda q: float(field(np.array(tuple(q)))[0])
    back = build_back() + [build_jaw()]
    horns = [build_ram_horn(1.0), build_ram_horn(-1.0)]
    def centre_y(o):
        return sum(v.co.y for v in o.data.vertices)/len(o.data.vertices)
    on_tail = [o for o in back if o.name.startswith(("RammstoneBack.", "RammstoneRearCap")) and centre_y(o) > 1.7]
    groups = {"Body": head + [o for o in back if o not in on_tail] + horns, "Tail": on_tail}
    red, black, skins = list(back), list(horns), [torso]
    for sign in (-1.0, 1.0):
        tag = "R" if sign < 0 else "L"
        on_upper, on_fore = build_arm_plates(sign)
        hand = build_hand(sign)
        upper_skin, fore_skin = arm_skins[sign]
        groups[f"UpperArm.{tag}"] = [upper_skin] + on_upper
        groups[f"Forearm.{tag}"] = [fore_skin] + on_fore + hand
        red += on_upper + on_fore
        black += hand
        skins += [upper_skin, fore_skin]
    for o in skins:
        o.data.materials.append(body_mat)
    for o in red:
        bevel(o, clear=clear)
        o.data.materials.append(rock_mat)
        o.data.materials.append(rock_edge)
    for o in black:
        bevel(o, angle=35.0)
        o.data.materials.append(horn_mat)
        o.data.materials.append(horn_edge)
    rig = build_rig(groups)
    skin_to_tail(rig, torso)
    animate_punch(rig)
    everything = [o for objs in groups.values() for o in objs] + [torso]
    renders = render(everything)
    report = {"tool": bpy.app.version_string, "triangles": base.triangles(everything),
              "body_triangles": base.triangles(skins), "plates": len(red), "punch_frames": [k[0] for k in PUNCH],
              "renders": renders}
    (OUT/"report.json").write_text(json.dumps(report, indent=2))
    for screen in bpy.data.screens:  # open in colour: saved in Solid shading, it opened grey for the owner
        for area in screen.areas:
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.shading.type = "MATERIAL"
                    space.overlay.show_bones = False
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
