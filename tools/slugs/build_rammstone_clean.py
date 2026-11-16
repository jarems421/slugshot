"""Build Rammstone cleanly: separate low-poly pieces measured from the owner's sheet, on the approved proportions.

Owner, 2026-11-08: the voxel-based surface looked "weird": armour edges "splitting" with "loads of little miniature
spikes", the horns standing on a raised shelf rather than "attached to the head like normal", and horns unlike the
sheet's. Cutting facets into a voxel surface keeps its noise, so each part is now built as clean geometry instead, from
tools/slugs/rammstone_measure.py's measurements of the sheet (the same numbers that made the approved blockout):

- Body: a smooth lofted column, the face line and skin width from the sheet, set back under the hood, closed by a dome
  inside it, a little wider under the forehead, the mouth carved into it; the belly's two V markings as hard steps, its rings bent so one runs exactly along each V.
- Rock underlayer: a smooth shell round the back and sides, the inner envelope of the sheet's plate profile, blending
  into the body at the front so no edge shows.
- Plates: separate solid wedges, thin where they tuck under the plate above and thickest at a pointed lower edge, with a
  ridge down the middle. Their tips sit where the sheet's profiles have tips (back 0, 0.31, 0.74, 1.32; sides 0, 0.28,
  0.69, 1.35) and reach the sheet's outline there; the side ones sweep down and back.
- Hood: one faceted shell lofted through the sheet's hood outline at each height, its front pointed into a visor, its
  top a dome up to the crown (no shelf), its lower edge a V brow rising over each eye to a pointed outer corner drawn
  back on the side of the head. Below each eye a cheek plate's front edge slants up and back to that corner. A charcoal
  keel runs from a point above the brow's, widening up the forehead, over the top between the horns and down the back
  to a point. Slabs on its front: a chevron brow band along the brow, and a forehead slab each side between the band
  and the keel, rising to a raised outer corner.
- Face: each eye a shallow dark glossy dome with glowing lava cracks, a wide D in a socket: a soft lower lid along its
  round bottom, its top under the brow, sharp points where they meet. The mouth the sheet's toothy grin: a crescent of smooth white teeth
  in a carved outline with pointed upturned corners and a raised lower lip.
- Horns: six-sided, swept along the sheet's smoothed centreline, set and sized by the front view, tapering to a sharp
  point, their roots sunk into the dome.

Flat shading and a small bevel keep the rock and horns crisp, the bevel's faces lighter so every plate edge catches the
light as on the sheet; the body is smooth. Materials are the surface pass's,
with the sheet's fine faint crazing on the rock in place of its patches of dark cells.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_rammstone_clean.py`

Reads build/slugs/rammstone/clean/measure.json. Writes assets/source/slugs/models/rammstone/rammstone-clean.blend and
build/slugs/rammstone/clean/renders/. No rig or export (owner: not until the look is approved).
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
import build_rammstone_surface as surf

MEASURE = ROOT/"build/slugs/rammstone/clean/measure.json"
OUT = ROOT/"build/slugs/rammstone/clean"
BLEND = ROOT/"assets/source/slugs/models/rammstone/rammstone-clean.blend"

BODY_N = 2.2  # body cross-section superellipse
HOOD_FRONT_N, HOOD_BACK_N = 1.7, 1.9  # the hood's plan: pointed into a visor at the front, a ridge down the back
HOOD_COLUMNS, HOOD_THICK = 16, 0.05  # few columns: large angular facets
HOOD_ROW_Z = (1.24, 1.36, 1.52, 1.74, 1.92, 2.04, 2.14)  # shared by every column: the visor point (1.52), temple corners (1.74)
DOME_START, CROWN = 2.00, 2.20
# Owner, 2026-11-13: from the front "it doesn't have the wideness at the top like it does when you look from the sides...
# that's what gives it its like intimidating look from the front... And it makes the eyes look cramped when they're
# not." From the side the hood at brow height is 1.4 times as deep as the body below it; from the front the sheet's is
# only 1.2 times as wide. So the hood is at least HOOD_FLARE times half its side depth wide: its temple corners reach
# about 0.92 instead of the sheet's 0.79. A departure from the sheet's front view, by the owner's direction.
HOOD_FLARE = 1.17
# Then "reduce the length at which the back of the head is kind of protruding outwards": the hood's overhang behind the
# body is cut by HOOD_BACK_TRIM (its width, set from the sheet's full depth, stays). And gaps "in that corner", "when
# you look under... around where the armor meets the body" and "on the back of the head": the hood was a thin shell
# flared well clear of the body, open underneath. Its lower edge now closes in to the body, so it is solid rock below.
HOOD_BACK_TRIM = 0.35
# The brow's lower edge (|x|, z) from the sheet's front view: a V with its point between the eyes, rising over them.
# Owner, 2026-11-08: "the forehead goes down too much" (the point was at 1.30, over where the eyes go); then the eye
# space under it "a bit too narrow" (it ended at 0.37), so it reaches 0.44; then the eyes should be "drawing back
# more... more predatorial... the corners": on the sheet each eye ends in a point up and back on the side of the head.
# Then a review the owner passed on: the brow should cover "the upper portion of the eyes... a stronger overhang... that
# characteristic half-lidded appearance... particularly at the outer corners". Lowering it hid its raised outer corners
# behind the cheek plates from the front (owner: "you can't see the raised corners in the corners of the forehead...
# still looks sort of cramped"), so it is a steep V again and the eyes' tops follow it instead. Then "from the front it
# just looks so cramped": the cheek plates closed the face in at 0.44 where the sheet's skin shows to the body's side
# (0.53), so the eye corner and the cheek plates' front edges moved out. The line is read off the sheet's front view
# pixel by pixel: 1.385 between the eyes, 1.44 at 0.15, 1.605 at 0.50, 1.645 at the corner.
BROW = ((0.0, 1.385), (0.15, 1.44), (0.50, 1.605))
BROW_TIP = BROW[0][1]
# Then "the eyes look too far into the corners of the forehead... increase the size of the forehead so that the eyes
# stay in the same place, but... there's more space around them... but don't make the eyes look cramped again": each
# eye's outer end ran into the corner at the face's edge. The face is FACE_WIDEN wider each side under the forehead, and
# the corner and the cheek plates' front edges moved out with it; the eyes and the brow over them stay. Then the sides
# "look... too puffy... it just removes the jagged look that we're going for. But I like how it looks wider": the
# widened skin swelled out in a curve from the mouth to the eyes, and the cheek plates shrank to slivers beside it. So the
# face widens only at the eyes' height (FACE_WIDEN_Z, in a straight ramp), and the cheek plates stand further out
# (CHEEK_PROUD) with their front edges in a straight slant from beside the mouth's corners (CHEEK_FRONT) up to the
# brow's corner: the face is framed by chunky rock in straight lines, wider at the top.
FACE_WIDEN, FACE_WIDEN_Z = 0.07, (1.25, 1.45)
EYE_CORNER = (0.66, 1.675)  # (|x|, z): the brow rises to it, and the cheek plate's front edge slants up and back to it
CHEEK_BOTTOM = 1.24  # the hood's lower edge behind the eye corner
# Then "the sides of the like diagonal lines they look too blocky rather than like they're going into the skin"; then,
# with screenshots, from the side "there's this gap... tilt the sideburn looking arm back to fill that gap", "at the
# bottom of the sideburn... it pokes out", from the front "very blocky as if it's a sideburn rather than... a sharp piece
# of armor kind of coming out of the skin... just slanted coming out of the skin", and its edge by the eye "curved" where
# it should be straight. So each cheek plate is a shard (build_cheek): a front edge on the skin, straight seen from the
# front from a point beside the mouth's corner (CHEEK_TIP) up under the brow's corner (CHEEK_TOP); its face tilting
# back and out from that edge to its back edge at the armour's surface (CHEEK_INSET under it), which rises from the
# point to CHEEK_BACK (angle from the front round the hood, height) under the hood's flap behind the eye. Then gaps "in
# that corner we were filling in": from the front, under the flared brow corner, a hollow 0.25 deep showed the hood's
# side far behind. So the back edge then rises forward into that corner to CHEEK_CORNER, just under the brow's lip, and
# the shard's top fills it.
CHEEK_TIP, CHEEK_TOP, CHEEK_BACK, CHEEK_CORNER = (0.42, 1.10), (0.575, 1.645), (1.30, 1.40), (1.12, 1.66)
CHEEK_INSET, CHEEK_EDGE, CHEEK_RIDGE, CHEEK_RIDGE_AT = 0.015, 0.004, 0.055, 0.3  # the ridge: how far proud, and where across
# The face, from the sheet's front view and close-ups (owner, 2026-11-08: "Make the mouth and eyes look exactly like
# this"). Each eye is a shallow dark glossy dome on the face, a wide D seen from the front (right eye): its top runs
# EYE_HIDDEN above the brow's edge, so the brow cuts it; its lower edge is a curve (Bezier handles EYE_LOWER) from a
# sharp inner point under the brow's beak (EYE_INNER_X) down to a broad round bottom near 1.30 in the middle and
# steeply up to a sharp outer point under the raised brow (EYE_OUTER_X), both EYE_GAP under the brow. A soft lower lid
# ridge LID_CREST high follows the lower edge, so it sits in a socket. Owner: an eye filling the drawn-back corner
# looked "too cramped"; ovals were "a bit too rounded. It should be like a sharper finish where the eye meets the
# forehead"; then an almond, its low point near the inner end and a long tail up to the outer point, "droop[ed] down so
# much". The review: "flatten their forward projection... position them deeper beneath the brow"; then "the eyes are
# too close together".
EYE_INNER_X, EYE_OUTER_X, EYE_GAP, EYE_HIDDEN = 0.13, 0.50, 0.005, 0.03
EYE_LOWER = ((0.19, 1.24), (0.53, 1.27))
# Owner, 2026-11-13: "when you look from the side, the eyes are like kind of under the armor... I like the general eye
# design... but it's just not being executed properly"; "Bring the eyes to life, make the orange glow". At 0.025 the dome
# read as a flat dark sticker from the side and three-quarter; the sheet's eyes are glossy orbs. EYE_BULGE was 0.05.
# Then "bulge out a little more. Not... like bug eyes, but just so that they look more like meteors": 0.075, the dome
# gently lumpy (EYE_LUMP) like a rock rather than glass, smooth at the rim.
EYE_BULGE, EYE_SINK, LID_CREST = 0.075, 0.006, 0.0045
EYE_LUMP = 0.004
# Then "improve the eye shape... something just feels off with it". Beside the sheet's front view, ours had cracks
# spread evenly over a glossy black ball with an orange ring round its bottom (goggles); the sheet's eye is warm dark
# brown, darker up under the brow, in a dark socket, with one glowing crack across its middle and a few branches, a
# fierce focus. The cracks are now drawn (EYE_CRACKS, in eye-local coordinates: (x - centre)/EYE_LOCAL_R, inner -1 to
# outer +1, bottom -1 to top +1, mirrored for the left eye) into a small texture: core, glow and a broad warmth.
EYE_LOCAL_R = 0.19
EYE_CRACKS = (
    (((-0.70, -0.25), (-0.45, -0.31), (-0.20, -0.27), (0.05, -0.33), (0.30, -0.28), (0.55, -0.31), (0.70, -0.24)), 0.040),
    (((0.40, -0.30), (0.45, -0.12), (0.38, 0.06), (0.43, 0.27)), 0.030),
    (((-0.50, -0.30), (-0.56, -0.12), (-0.50, 0.04)), 0.026),
    (((-0.08, -0.29), (-0.13, -0.43), (-0.07, -0.56)), 0.026),
    (((0.33, -0.29), (0.38, -0.46)), 0.022),
    (((0.18, -0.29), (0.25, -0.17)), 0.018),
    (((-0.30, -0.28), (-0.36, -0.41)), 0.018),
    # More (owner: "Add more glowing cracks to the eyes"): a second crack across the upper middle, joined to the first,
    # and short branches toward the rim.
    (((-0.62, 0.02), (-0.38, 0.08), (-0.12, 0.03), (0.12, 0.10), (0.33, 0.05)), 0.026),
    (((-0.20, -0.27), (-0.16, -0.12), (-0.12, 0.03)), 0.020),
    (((0.12, 0.10), (0.17, 0.26), (0.11, 0.40)), 0.018),
    (((-0.38, 0.08), (-0.43, 0.24)), 0.016),
    (((0.62, -0.28), (0.73, -0.45)), 0.018),
    (((-0.62, -0.26), (-0.73, -0.42)), 0.018),
    (((0.05, -0.33), (0.10, -0.50), (0.04, -0.64)), 0.018),
    (((-0.45, -0.31), (-0.40, -0.50)), 0.014),
    (((0.45, -0.12), (0.62, -0.08)), 0.014),
)
# The mouth: the sheet's toothy grin (owner, 2026-11-08: "let's just switch to the other smile... the one that has the
# teeth showing"). A crescent opening: a shallow top edge dipping from the corners to GRIN_TOP_MID, a deep rounded
# bottom edge down to GRIN_BOTTOM_MID, meeting in pointed corners at GRIN_CORNER that flick up. Smooth white teeth fill
# it, shadowed under the upper lip and into the corners, the upper and lower rows meeting at GRIN_BITE of the way down.
# A carved dark line runs round it, with a raised lower lip under the bottom edge.
GRIN_CORNER, GRIN_TOP_MID, GRIN_BOTTOM_MID = (0.32, 1.19), 1.14, 1.045  # owner: "too packed... the smile looks a bit too big"; then "Move the mouth down a bit" (by 0.04)
# Then "improve the smile a bit. So it looks more emotional": the corners curl higher (the upper lip dips 0.05 to the
# middle instead of 0.027), and a short crease curves up round each corner (SMILE_CREASE, offsets from the corner) as
# the cheek pushes up.
# Separate strokes "not attached properly", so the upper lip's line runs on through each corner into its crease.
SMILE_CREASE = ((0.010, 0.006), (0.019, 0.016), (0.023, 0.028), (0.021, 0.040))  # then "Reduce the size of the lines... on the edges"
GRIN_BITE = 0.58
# Owner, 2026-11-13: two little ogre fangs, then flat fangs on the teeth, then 3D tusks standing out of the mouth, all
# tried; then "I like the idea of the fangs, but they're just not looking that good... the smile looks fine as is...
# Let's just remove the things for now": the grin has no fangs. The last tusk build is kept beside the model as
# build_rammstone_clean-v20-tusks.py and rammstone-clean-v20.blend.
# Owner, 2026-11-13: "make the mouth look like it's actually ingrained into the face rather than looking painted on".
# The body's skin is carved MOUTH_DEPTH into the face inside the grin, its wall dropping within MOUTH_WALL and darkened
# ("ink"); the lips' inner sides curl down into it and the teeth sit at its floor. The wall is nearly a step: the body's
# rings are 0.01 apart, so a gentler wall came out stepped where the teeth met it.
MOUTH_DEPTH, MOUTH_WALL = 0.02, 0.004
# The belly's V markings (surf.CHEVRONS): a hard step of STEP in height where the segment above stands LAP proud, settling
# back over LAP_FADE, with a dark band CREASE_BAND tall under it. Owner: they "don't look hard enough".
STEP, LAP, LAP_FADE, CREASE_BAND = 0.004, 0.016, 0.28, 0.014
# The charcoal keel, from the sheet: a wedge up the forehead from a point above the brow's (front view), over the top
# between the horns, and a wedge down the back to a point (back view). Its sides bow out a little. Owner: the grey line
# "should be wider at the top and narrow at the bottom", then "a little less triangular".
KEEL_FRONT_TIP, KEEL_FRONT_CREST, KEEL_FRONT_HALF = 1.52, 2.04, 0.21
KEEL_BACK_TIP, KEEL_BACK_CREST, KEEL_BACK_HALF = 1.68, 2.11, 0.17
KEEL_BOW = 0.75  # width grows as (distance from the tip)**KEEL_BOW: below 1 the sides bow out
# The forehead's plates, from the sheet's front view (its plate seams show plainly in a high-pass of it). Owner: from
# the front the forehead "looks so cramped" and the design "feels plain compared to the original": the sheet's front is
# layered slabs with lit edges, ours one smooth shell. A brow band: a chevron slab across the face, its lower edge the
# brow, its upper edge from the crest's point up to BAND_TOP at the eye corner. Above it each side a forehead slab from
# the crest's side out to a raised outer corner, thicker there so it catches the light.
BAND_TOP = ((0.0, 1.53), (0.22, 1.59), (EYE_CORNER[0], 1.785))
BAND_THICK, FOREHEAD_THICK, CORNER_RAISE, SLAB_SINK = 0.05, 0.03, 0.025, 0.03
FOREHEAD_TOP = ((0.0, 1.90), (0.62, 1.93))  # the forehead slab's upper edge: (inner x from the crest's side, z), (outer x, z)
# Each side a wing slab beyond the band and forehead slab, tapering to a raised point at the flared temple corner
# (HOOD_FLARE), as the sheet's outer plates step out to its corners.
WING_TIP_Z, WING_GAP, WING_THICK = 1.74, 0.02, (0.035, 0.05)
FACE_RECESS = 0.30  # how far the face sets back per unit of height above the brow's point, under the hood
SHELL_TOP = 1.80
PLATE_OVERLAP = 0.12
PLATE_COLUMNS = ((0.0, 1.00), (0.85, 0.95), (1.60, 0.80))  # (angle from the spine, angular width)
SIDE_SWEEP = 0.45  # radians the side plates travel toward the spine per unit of height, down and back
BEVEL = 0.009  # wide enough that the light edge faces it adds (the "edge" materials) read as the sheet's lit plate edges


def smoothstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0.0, 1.0)
    return t*t*(3.0 - 2.0*t)


def gaussian(a, sigma):
    r = int(3*sigma) + 1
    k = np.exp(-0.5*(np.arange(-r, r + 1)/sigma)**2)
    return np.convolve(np.pad(a, r, mode="edge"), k/k.sum(), mode="valid")


def envelope(a, half):
    """Rolling minimum: the inner line under a sawtooth outline."""
    p = np.pad(a, half, mode="edge")
    return np.array([p[i:i + 2*half + 1].min() for i in range(len(a))])


class Sheet:
    def __init__(self, data):
        self.d = data
        rows = data["rows"]
        self.z = np.array([r["z"] for r in rows])

        def col(key, fill=np.nan):
            return np.array([r.get(key, fill) for r in rows])

        self.front_half = col("frontHalf", 0.0)
        self.side_front = col("sideMainFront")
        self.side_back = col("sideMainBack")
        self.side_back_all = col("sideBack", 0.0)
        n = len(self.z)
        b = data["body"]
        self.face_y = gaussian(np.array(b["faceY"][:n]), 6.0)
        self.back_y = gaussian(np.array(b["backY"][:n]), 8.0)
        self.half = gaussian(np.array(b["half"][:n]), 6.0)
        # Under-plate envelopes for the shell.
        self.shell_x = gaussian(envelope(self.front_half, 25), 6.0) - 0.02
        self.shell_back = gaussian(envelope(self.side_back_all, 25), 6.0) - 0.02

    def at(self, arr, z):
        return float(np.interp(z, self.z, arr))


# ---------------------------------------------------------------- body

def body_section(s, z):
    """The body's cross-section at a height: front (y), back (y), half width."""
    front0 = s.at(s.face_y, min(z, 1.40))
    back = front0 + 0.85*(s.at(s.back_y, min(z, 1.40)) - front0)
    front = front0 + 0.03*smoothstep(1.15, 1.45, z) + FACE_RECESS*max(z - BROW_TIP, 0.0)  # gradual: no fold over the mouth
    half = s.at(s.half, min(z, 1.40)) + FACE_WIDEN*float(np.clip((z - FACE_WIDEN_Z[0])/(FACE_WIDEN_Z[1] - FACE_WIDEN_Z[0]), 0.0, 1.0))
    return front, back, half


def superellipse(theta, a, b, n):
    """Point on a superellipse, theta from +y (the back) toward +x."""
    sx, cy = math.sin(theta), math.cos(theta)
    return a*math.copysign(abs(sx)**(2/n), sx), b*math.copysign(abs(cy)**(2/n), cy)


def body_radius(s, z, ang):
    """Distance from the body's centre to its surface in a direction (ang from the back, toward +x)."""
    front, back, half = body_section(s, z)
    yc, d = (front + back)/2, (back - front)/2
    sx, cy = abs(math.sin(ang)), abs(math.cos(ang))
    return (max(sx/half, 1e-9)**BODY_N + max(cy/d, 1e-9)**BODY_N)**(-1/BODY_N), yc


def belly_rings():
    """Ring heights before warping: every 0.01, plus at each chevron's tip the dark band's lower edge and the step's two
    edges."""
    tips = [tip for tip, _ in surf.CHEVRONS]
    zs = [z for z in np.arange(0.0, 2.03, 0.01) if all(not (t - CREASE_BAND - 0.005 < z < t + STEP/2 + 0.005) for t in tips)]
    for t in tips:
        zs += [t - CREASE_BAND, t - STEP/2, t + STEP/2]
    return np.array(sorted(zs))


def belly_warp(s, theta):
    """A body column's ring heights, warped so one ring runs exactly along each V marking: the band round each chevron's
    tip is lifted by the V's rise at this column, and round the back by its full rise. Marks painted across level rings
    came out stepped and blurred ("pixelated", owner, 2026-11-08)."""
    pts = [(0.0, 0.0)]
    for tip, rise in sorted(surf.CHEVRONS):
        z = tip
        for _ in range(3):
            half = body_section(s, z)[2]
            x = half if math.cos(theta) > 0 else abs(superellipse(theta, half, 1.0, BODY_N)[0])
            z = tip + rise*x
        pts += [(tip - 0.03, z - 0.03), (tip + 0.03, z + 0.03)]
    pts += [(1.10, 1.10), (3.0, 3.0)]
    return [p[0] for p in pts], [p[1] for p in pts]


def belly_weight(x, theta):
    """How much of the belly marks a column shows: all of it across the front, none toward the sides."""
    return float((1.0 - smoothstep(0.36, 0.48, abs(x)))*smoothstep(0.3, 0.6, -math.cos(theta)))


def build_body(s):
    zs = belly_rings()
    seg = 48
    thetas = [2*math.pi*i/seg for i in range(seg)]
    warps = [belly_warp(s, theta) for theta in thetas]
    verts, faces, weights = [], [], []
    for zu in zs:
        for theta, (wa, wb) in zip(thetas, warps):
            z = float(np.interp(zu, wa, wb))
            front, back, half = body_section(s, z)
            k = math.sqrt(max(0.0, 1.0 - ((z - 1.86)/0.17)**2)) if z > 1.86 else 1.0
            yc, d = (front + back)/2, (back - front)/2
            x, y = superellipse(theta, half*k, d*k, BODY_N)
            w = belly_weight(x, theta)
            # The sheet's V markings: each segment laps over the one below at a hard step, settling back above it.
            lap = sum(LAP*(1.0 - float(smoothstep(0.0, LAP_FADE, zu - tip))) for tip, _ in surf.CHEVRONS if zu > tip)*w
            r = math.hypot(x, y)
            verts.append((x*(1 + lap/r), yc + y*(1 + lap/r), z))
            weights.append(w)
    rings = len(zs)
    for r in range(rings - 1):
        for i in range(seg):
            a, b = r*seg + i, r*seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    verts.append((0.0, body_section(s, 0.0)[0]/2 + body_section(s, 0.0)[1]/2, 0.0))
    verts.append((0.0, float(np.mean([v[1] for v in verts[(rings - 1)*seg:rings*seg]])), float(verts[(rings - 1)*seg][2])))
    bottom, top = len(verts) - 2, len(verts) - 1
    faces += [(bottom, (i + 1) % seg, i) for i in range(seg)]
    faces += [(top, (rings - 1)*seg + i, (rings - 1)*seg + (i + 1) % seg) for i in range(seg)]
    obj = make_object("RammstoneBody", verts, faces, smooth=True)
    mesh = obj.data
    assert len(mesh.vertices) == len(verts) and len(mesh.polygons) == len(faces)
    # The dark line is exactly the step and the band under it, and the step's edges are sharp, so the marks stay crisp.
    crease = np.zeros(len(faces), np.float32)
    step_rings = set()
    for tip, _ in surf.CHEVRONS:
        band, lower, upper = (int(np.argmin(abs(zs - z))) for z in (tip - CREASE_BAND, tip - STEP/2, tip + STEP/2))
        step_rings |= {lower, upper}
        for r in (band, lower):
            for i in range(seg):
                crease[r*seg + i] = (weights[r*seg + i] + weights[r*seg + (i + 1) % seg])/2
    mesh.attributes.new("crease", "FLOAT", "FACE").data.foreach_set("value", crease)
    edges = np.empty(len(mesh.edges)*2, np.int64)
    mesh.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    ring = np.where(edges < rings*seg, edges//seg, -1)
    w = np.array(weights + [0.0, 0.0])
    sharp = (ring[:, 0] == ring[:, 1]) & np.isin(ring[:, 0], list(step_rings)) & (w[edges].min(axis=1) > 0.05)
    mesh.attributes.new("sharp_edge", "BOOLEAN", "EDGE").data.foreach_set("value", sharp)
    mesh.update()
    carve_mouth(s, obj, seg, rings)
    return obj


def mouth_depth(x, z):
    """How far the skin is carved in at (x, z) seen from the front: MOUTH_DEPTH inside the grin, falling to it over
    MOUTH_WALL from the edge (so it is shallow in the thin corners)."""
    if abs(x) >= GRIN_CORNER[0]:
        return 0.0
    top, bottom = grin_edges(x)
    inside = min(top - z, z - bottom)
    return MOUTH_DEPTH*float(smoothstep(0.0, MOUTH_WALL, inside)) if inside > 0.0 else 0.0


def carve_mouth(s, obj, seg, rings):
    """Carve the mouth into the body: split the faces round the grin into thin columns (a body column is about 0.07
    wide there), lay every vertex there on the body's smooth surface, push those inside the grin in by mouth_depth and
    darken them with "ink"."""
    cx, cz = GRIN_CORNER
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()

    def near(v):
        return abs(v.co.x) <= cx + 0.03 and GRIN_BOTTOM_MID - 0.02 <= v.co.z <= cz + 0.02 and v.co.y < 0.0

    region = [f for f in bm.faces if all(near(v) for v in f.verts)]
    ring = lambda v: v.index//seg if v.index < rings*seg else -1
    across = {e for f in region for e in f.edges if ring(e.verts[0]) == ring(e.verts[1]) >= 0}
    bmesh.ops.subdivide_edges(bm, edges=list(across), cuts=7, use_grid_fill=True)
    ink = bm.verts.layers.float.new("ink")
    for v in bm.verts:
        if near(v):
            p, n = face_point(s, v.co.x, v.co.z)
            d = mouth_depth(v.co.x, v.co.z)
            v.co = p - n*d
            v[ink] = 0.85*d/MOUTH_DEPTH
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


# ---------------------------------------------------------------- shell and plates

def shell_point(s, ang, z):
    """The rock underlayer: the sheet's inner plate envelope round the back and sides, blending into the body toward the
    front so its edge is never seen."""
    rb, yc = body_radius(s, z, ang)
    sx, cy = abs(math.sin(ang)), abs(math.cos(ang))
    bx = max(s.at(s.shell_x, z), 0.2)
    by = max(s.at(s.shell_back, z) - yc, 0.2)
    re = (max(sx/bx, 1e-9)**2.3 + max(cy/by, 1e-9)**2.3)**(-1/2.3)
    w = float(smoothstep(1.45, 1.95, abs(ang)))
    r = re + (rb - 0.01 - re)*w
    return Vector((r*math.sin(ang), yc + r*math.cos(ang), z))


def shell_normal(s, ang, z):
    e = 1e-3
    da = shell_point(s, ang + e, z) - shell_point(s, ang - e, z)
    dz = shell_point(s, ang, z + e) - shell_point(s, ang, z - e)
    n = da.cross(dz).normalized()
    p = shell_point(s, ang, z)
    _, yc = body_radius(s, z, ang)
    return n if n.dot(Vector((p.x, p.y - yc, 0.0))) > 0 else -n


def build_shell(s):
    angs = np.linspace(-2.0, 2.0, 41)
    zs = np.arange(0.0, SHELL_TOP + 1e-6, 0.03)
    verts = [tuple(shell_point(s, a, z)) for z in zs for a in angs]
    faces = []
    na = len(angs)
    for r in range(len(zs) - 1):
        for i in range(na - 1):
            a = r*na + i
            faces.append((a, a + na, a + na + 1, a + 1))
    return make_object("RammstoneRockUnder", verts, faces, smooth=True, facet=0.3)


ROW_SEGMENTS = ((0.0, 0.68), (0.60, 1.32), (1.24, 1.97))  # blades along each half-row, spine to front (|angle|)


def row_lower(tiers, k, ang):
    """A row's lower edge at an angle: lowest at the spine, rising to the side tip at a quarter turn and a little past."""
    spine, side = tiers[k]
    return spine + (side - spine)*min(1.0, abs(ang)/(math.pi/2))**0.85 + 0.04*max(abs(ang) - math.pi/2, 0.0)


def row_upper(s, tiers, k, ang):
    """Each row tucks under the next one up, and the top row under the hood."""
    if k + 1 < len(tiers):
        return row_lower(tiers, k + 1, ang) + PLATE_OVERLAP
    return hood_bottom(s, math.pi - abs(ang)) + 0.12


def blade(s, name, sign, a_back, a_front, z_tip, z_top_back, z_top_front, z_front_low, T, seed, front_lift):
    """One blade: a slanted lower edge running from a low, thick tip at its spine end up to its front corner, which
    thins toward the belly; a crease from the top front corner to the tip splits it into two clean planes."""
    rnd = np.random.default_rng(seed)
    mid_a = a_back*0.72 + a_front*0.28
    mid_z = z_tip*0.5 + (z_top_back*0.7 + z_top_front*0.3)*0.5
    spec = [(a_back - 0.05, z_top_back, 0.012), (a_front + 0.03, z_top_front, 0.010), (a_front + 0.03, z_front_low, front_lift),
            (a_back, z_tip, 1.00), (mid_a, mid_z, 0.52)]
    top, bottom = [], []
    for a, z, h in spec:
        ang = sign*a
        p, n = shell_point(s, ang, z), shell_normal(s, ang, z)
        top.append(p + n*(h*T if h > 0.05 else h)*(1.0 + rnd.uniform(-0.05, 0.05)))
        bottom.append(p - n*0.04)
    verts = [tuple(v) for v in top + bottom]
    outline, ridge = [0, 1, 2, 3], 4
    faces = [(outline[i], outline[(i + 1) % 4], ridge) for i in range(4)]
    faces += [(5 + ridge, 5 + outline[(i + 1) % 4], 5 + outline[i]) for i in range(4)]
    faces += [(outline[i], 5 + outline[i], 5 + outline[(i + 1) % 4], outline[(i + 1) % 4]) for i in range(4)]
    return make_object(name, verts, faces, smooth=False, facet=float(rnd.uniform(0.2, 0.8)))


def build_plates(s):
    """Rows of overlapping blades in chevrons: each row's spine tip from the sheet's profile, its side tip from the
    front view one row up (the row's edge rises about 0.3 from the spine to the sides)."""
    back_tips = s.d["plateTipsZ"]
    side_tips = [t if t < 1.2 else 1.03 for t in s.d["sidePlateTipsZ"]]
    # The top row lies level, so its thick tips fill under the hood's lip at the sides.
    tiers = [(back_tips[k], side_tips[k + 1] if k + 1 < len(side_tips) else back_tips[k]) for k in range(len(back_tips))]
    objs = []
    for k in range(len(tiers)):
        for j, (a0, a1) in enumerate(ROW_SEGMENTS):
            for sign in (1.0, -1.0):
                z_tip = max(row_lower(tiers, k, a0) - 0.02, 0.0)
                z_front_low = row_lower(tiers, k, a1) + 0.05
                top_b, top_f = row_upper(s, tiers, k, a0), row_upper(s, tiers, k, a1)
                zt = max(z_tip, 0.02)
                reach_back = s.at(s.side_back_all, zt) - s.at(s.shell_back, zt)
                reach_side = s.at(s.front_half, zt) - s.at(s.shell_x, zt)
                T = float(np.clip(reach_back + (reach_side - reach_back)*abs(math.sin(a0 + 0.3)), 0.07, 0.22))
                seed = 100*k + 10*j + (5 if sign < 0 else 0)
                front_lift = 0.10 if j == len(ROW_SEGMENTS) - 1 else 0.35  # flush toward the belly
                objs.append(blade(s, f"RammstonePlate.{k}.{j}{'L' if sign < 0 else 'R'}", sign, a0, a1, z_tip,
                                  top_b, top_f, z_front_low, T, seed, front_lift))
    return objs


# ---------------------------------------------------------------- hood

def hood_outline(s, z):
    """The hood's plan at a height: half width, front and back, from the sheet, at least HOOD_FLARE times half its depth
    so it flares as wide from the front as from the side; a dome above DOME_START."""
    zz = min(z, DOME_START)
    f = s.at(gaussian(np.nan_to_num(s.side_front, nan=-0.4), 2.0), zz)
    b = s.at(gaussian(np.nan_to_num(s.side_back, nan=0.4), 2.0), zz)
    w = max(s.at(gaussian(s.front_half, 2.0), zz), HOOD_FLARE*(b - f)/2)
    back = body_section(s, zz)[1]
    if b > back:
        b = back + (b - back)*(1.0 - HOOD_BACK_TRIM)
    if z > DOME_START:
        k = math.sqrt(max(0.0, 1.0 - ((z - DOME_START)/(CROWN - DOME_START))**2))
        mid = (f + b)/2
        w, f, b = w*k, mid + (f - mid)*k, mid + (b - mid)*k
    return w, f, b


def hood_point(s, phi, z):
    w, f, b = hood_outline(s, z)
    yc, d = (f + b)/2, (b - f)/2
    n = HOOD_FRONT_N if math.cos(phi) < 0 else HOOD_BACK_N
    x, y = superellipse(phi, w, d, n)
    return Vector((x, yc + y, z))


def hood_bottom(s, phi):
    """The hood's lower edge per column: a V brow over the face rising to the eye corners, low behind them over the
    cheek plates, higher round the back."""
    x = abs(hood_point(s, phi, 1.45).x)
    c = math.cos(phi)
    edge = BROW + (EYE_CORNER,)
    front = float(np.interp(x, [p[0] for p in edge], [p[1] for p in edge])) if x <= EYE_CORNER[0] + 0.005 else CHEEK_BOTTOM
    if c >= 0.0:
        # From the back: a V pointing down at the spine, up to the hood's back corners, down to eye level at the sides.
        psi = math.acos(min(1.0, c))
        return 1.48 + 0.16*float(smoothstep(0.0, 0.9, psi)) - 0.14*float(smoothstep(0.9, math.pi/2, psi))
    return 1.50 + (front - 1.50)*float(smoothstep(0.0, -0.40, c))


def front_column(s, x):
    """The hood column's angle from the front (phi = pi) that sits at |x| at brow height."""
    w = hood_outline(s, 1.45)[0]
    return math.asin(min(1.0, (x/w)**(HOOD_FRONT_N/2)))


def hood_columns(s):
    """Even columns, plus one each side at each bend of the brow and at the eye corner."""
    phis = [2*math.pi*i/HOOD_COLUMNS for i in range(HOOD_COLUMNS)]
    for x in [q[0] for q in BROW[1:]] + [EYE_CORNER[0]]:
        a = front_column(s, x)
        # Skip one that would sit on an even column: a sliver of a column between them would read as a slit.
        phis += [phi for phi in (math.pi - a, math.pi + a) if min(abs(phi - q) for q in phis) > 0.03]
    return sorted(phis)


def build_hood(s):
    phis = hood_columns(s)
    cols = len(phis)
    # Each column runs from its own lower edge up through the shared rows above it, so neighbouring facets line up;
    # rows spread per column twist the faces between close columns into slits.
    heights = [[z0] + [z for z in HOOD_ROW_Z if z > z0 + 0.03] for z0 in (hood_bottom(s, phi) for phi in phis)]
    outer, inner, start = [], [], []
    for phi, zs in zip(phis, heights):
        start.append(len(outer))
        for i, z in enumerate(zs):
            p = hood_point(s, phi, z)
            w, f, b = hood_outline(s, z)
            c = Vector((0.0, (f + b)/2, z))
            outer.append(p)
            q = p - c
            if i == 0:
                # The lower edge closes in to just inside the body, so the hood's underside is a solid face of rock.
                cb = Vector((0.0, body_radius(s, z, 0.0)[1], z))
                d = p - cb
                rb, _ = body_radius(s, z, math.atan2(d.x, d.y))
                inner.append(cb + d.normalized()*(rb - 0.01))
            else:
                inner.append(c + q*max(0.0, 1.0 - HOOD_THICK/max(q.length, 1e-6)))
    w, f, b = hood_outline(s, CROWN - 1e-4)
    crown = Vector((0.0, (f + b)/2, CROWN))
    verts = [tuple(v) for v in outer] + [tuple(v) for v in inner] + [tuple(crown), tuple(crown - Vector((0, 0, HOOD_THICK)))]
    n_out = len(outer)
    co, ci = 2*n_out, 2*n_out + 1
    faces = []

    def both(face):
        faces.append(face)
        faces.append(tuple(n_out + v for v in reversed(face)))

    for c in range(cols):
        d = (c + 1) % cols
        za, zb = heights[c], heights[d]
        i = j = 0
        # Zip the two columns: a quad where both reach the same row, a triangle where one column has a row the other lacks.
        while i < len(za) - 1 or j < len(zb) - 1:
            a, b = start[c] + i, start[d] + j
            if j == len(zb) - 1 or (i < len(za) - 1 and za[i + 1] < zb[j + 1] - 1e-6):
                both((a, b, a + 1))
                i += 1
            elif i == len(za) - 1 or zb[j + 1] < za[i + 1] - 1e-6:
                both((a, b, b + 1))
                j += 1
            else:
                both((a, b, b + 1, a + 1))
                i += 1
                j += 1
        top_a, top_b = start[c] + len(za) - 1, start[d] + len(zb) - 1
        faces.append((top_a, top_b, co))
        faces.append((ci, n_out + top_b, n_out + top_a))
        # The lip along the lower edge, which the brow's thickness shows.
        faces.append((n_out + start[c], n_out + start[d], start[d], start[c]))
    obj = make_object("RammstoneHood", verts, faces, smooth=False, facet=0.5)
    return obj


def side_point(s, a, z, out, sign):
    """A point out from the body's surface (radially) at angle a from the front round it, at height z, on one side."""
    ang = math.pi - a  # body_radius measures from the back
    r, yc = body_radius(s, z, ang)
    return Vector((0.0, yc, z)) + Vector((sign*math.sin(ang), math.cos(ang), 0.0))*(r + out)


def side_angle(s, x, z):
    """The angle from the front round the body at which its surface is |x| out from the middle, seen from the front."""
    lo, hi = 0.0, math.pi/2
    for _ in range(40):
        mid = (lo + hi)/2
        lo, hi = (mid, hi) if side_point(s, mid, z, 0.0, 1.0).x < x else (lo, mid)
    return (lo + hi)/2


def build_cheek(s, sign):
    """The rock shard down the side of the face below an eye (see CHEEK_TIP). Rows run up it from its point; across
    each row, the front edge just off the skin, a ridge, and the back edge just under the armour's surface. The faces
    are flat, so it reads as a cut stone; underneath it is closed just inside the skin."""
    (x0, z0), (x1, z1) = CHEEK_TIP, CHEEK_TOP
    knots = (0.0, 0.6, 1.0)
    a_tip = side_angle(s, x0, z0)
    rows = 8
    outer, inner = [], []
    for i in range(rows + 1):
        v = i/rows
        z = z0 + (z1 - z0)*v
        front = side_point(s, side_angle(s, x0 + (x1 - x0)*v, z), z, CHEEK_EDGE, sign)
        # The back edge sweeps back and up under the flap, then forward and up into the brow's corner.
        ab = float(np.interp(v, knots, (a_tip, CHEEK_BACK[0], CHEEK_CORNER[0])))
        zb = float(np.interp(v, knots, (z0, CHEEK_BACK[1], CHEEK_CORNER[1])))
        hood = hood_point(s, math.pi - sign*ab, zb)
        c = Vector((0.0, body_radius(s, zb, 0.0)[1], zb))
        back = c + (hood - c)*(1.0 - CHEEK_INSET/max((hood - c).length, 1e-6))
        if i == 0:
            back = front.copy()
        ridge = front.lerp(back, CHEEK_RIDGE_AT)
        cr = Vector((0.0, body_radius(s, ridge.z, 0.0)[1], ridge.z))
        ridge += (ridge - cr).normalized()*CHEEK_RIDGE*min(1.0, 3.0*v)
        for q in (front, ridge, back):
            outer.append(q)
            cq = Vector((0.0, body_radius(s, q.z, 0.0)[1], q.z))
            d = q - cq
            rb, _ = body_radius(s, q.z, math.atan2(d.x, d.y))
            inner.append(cq + d.normalized()*(rb - 0.01))
    m, n = 3, len(outer)
    faces = []
    for i in range(rows):
        a, b = i*m, (i + 1)*m
        for j in range(m - 1):
            faces.append((a + j, a + j + 1, b + j + 1, b + j))
            faces.append((n + b + j, n + b + j + 1, n + a + j + 1, n + a + j))
        for j in (0, m - 1):
            faces.append((a + j, b + j, n + b + j, n + a + j))
    for j in range(m - 1):  # the top, under the brow and the flap
        e = rows*m
        faces.append((e + j, n + e + j, n + e + j + 1, e + j + 1))
    verts = [tuple(v) for v in outer + inner]
    return make_object(f"RammstoneCheek.{'R' if sign > 0 else 'L'}", verts, faces, smooth=False, facet=0.45)


def build_keel(s, hood):
    """The charcoal keel: a wedge up the forehead, over the top between the horns and a wedge down the back, its sides
    bowed out a little. Two planes meet at a raised ridge down the middle. Each row is laid on the hood by casting in
    toward the middle of the head, so the rows run round it from front to back."""
    bpy.context.view_layer.update()
    _, f, b = hood_outline(s, 1.90)
    centre = Vector((0.0, (f + b)/2, 1.75))

    def angle(p):
        """Round the head in the y-z plane: 0 straight ahead, pi/2 straight up, pi straight back."""
        d = p - centre
        a = math.atan2(d.z, -d.y)
        return a + 2*math.pi if a < -math.pi/2 else a

    front_tip, front_crest = angle(hood_point(s, math.pi, KEEL_FRONT_TIP)), angle(hood_point(s, math.pi, KEEL_FRONT_CREST))
    back_crest, back_tip = angle(hood_point(s, 0.0, KEEL_BACK_CREST)), angle(hood_point(s, 0.0, KEEL_BACK_TIP))
    n = 30
    verts, faces = [], []
    for i in range(n):
        a = front_tip + (back_tip - front_tip)*i/(n - 1)
        if a < front_crest:
            w = KEEL_FRONT_HALF*((a - front_tip)/(front_crest - front_tip))**KEEL_BOW
        elif a > back_crest:
            w = KEEL_BACK_HALF*((back_tip - a)/(back_tip - back_crest))**KEEL_BOW
        else:
            w = KEEL_FRONT_HALF + (KEEL_BACK_HALF - KEEL_FRONT_HALF)*(a - front_crest)/(back_crest - front_crest)
        w = max(w, 0.004)
        inward = -Vector((0.0, -math.cos(a), math.sin(a)))
        hits = []
        for x in (-w, -0.002, 0.002, w):
            found, p, normal, _ = hood.ray_cast(centre + Vector((x, 0.0, 0.0)) - inward*3.0, inward)
            assert found, (x, a)
            hits.append((p, normal))
        # The ridge sits on the hood's middle edge: average the faces either side of it.
        hits[1:3] = [((hits[1][0] + hits[2][0])/2, (hits[1][1] + hits[2][1]).normalized())]
        for (p, normal), lift in zip(hits, (0.008, 0.024, 0.008)):
            verts.append(tuple(p + normal*lift))
        for p, normal in hits:
            verts.append(tuple(p - normal*0.03))
    for i in range(n - 1):
        a, b = i*6, (i + 1)*6
        for c in (0, 1):
            faces.append((a + c, a + c + 1, b + c + 1, b + c))
            faces.append((a + 3 + c, b + 3 + c, b + 4 + c, a + 4 + c))
        faces.append((a, b, b + 3, a + 3))
        faces.append((a + 2, a + 5, b + 5, b + 2))
    faces.append((0, 3, 4, 1)); faces.append((1, 4, 5, 2))
    e = (n - 1)*6
    faces.append((e, e + 1, e + 4, e + 3)); faces.append((e + 1, e + 2, e + 5, e + 4))
    return make_object("RammstoneKeel", verts, faces, smooth=False, facet=0.6)


def hood_front(s, x, z):
    """A point on the hood's smooth outer surface seen from the front at (x, z), and its outward normal."""
    def at(x, z):
        a = math.asin(min(1.0, abs(x)/hood_outline(s, z)[0])**(HOOD_FRONT_N/2))
        return hood_point(s, math.pi - math.copysign(a, x), z)

    e = 1e-3
    n = (at(x + e, z) - at(x - e, z)).cross(at(x, z + e) - at(x, z - e)).normalized()
    return at(x, z), (n if n.y < 0 else -n)


def keel_side(keel):
    """The keel's edge seen from the front: its |x| as a function of z up the forehead."""
    co = np.empty(len(keel.data.vertices)*3)
    keel.data.vertices.foreach_get("co", co)
    edge = co.reshape(-1, 6, 3)[:, 2]  # each row: edge, ridge, edge, then the three under the hood
    front = edge[(edge[:, 1] < 0.0) & (edge[:, 2] < 2.05)]
    front = front[np.argsort(front[:, 2])]
    return lambda z: float(np.interp(z, front[:, 2], np.abs(front[:, 0])))


def build_slab(s, name, lower, upper, thick):
    """A rock slab on the hood's front between two lines seen from the front (lists of (x, z), column by column),
    standing thick[i] proud of the hood's smooth surface along its normal and sunk SLAB_SINK under it. Flat shaded, it
    follows the hood in one facet per column (more rows crumpled it over the hood's point) and its edges step out of it,
    so it reads as a separate plate."""
    rows = 2
    top, bottom = [], []
    for (xl, zl), (xu, zu), t in zip(lower, upper, thick):
        for r in range(rows):
            v = r/(rows - 1)
            p, n = hood_front(s, xl + (xu - xl)*v, zl + (zu - zl)*v)
            top.append(p + n*t)
            bottom.append(p - n*SLAB_SINK)
    cols, m = len(lower), len(top)
    o = lambda c, r: c*rows + r
    faces = []
    for c in range(cols - 1):
        for r in range(rows - 1):
            faces.append((o(c, r), o(c + 1, r), o(c + 1, r + 1), o(c, r + 1)))
            faces.append((m + o(c, r + 1), m + o(c + 1, r + 1), m + o(c + 1, r), m + o(c, r)))
        for r in (0, rows - 1):
            faces.append((o(c, r), m + o(c, r), m + o(c + 1, r), o(c + 1, r)))
    for c in (0, cols - 1):
        for r in range(rows - 1):
            faces.append((o(c, r), o(c, r + 1), m + o(c, r + 1), m + o(c, r)))
    return make_object(name, [tuple(v) for v in top + bottom], faces, smooth=False, facet=0.55)


def build_forehead(s, keel):
    """The brow band across the face and a forehead slab each side above it (see BAND_TOP)."""
    def band_top(x):
        return float(np.interp(abs(x), [q[0] for q in BAND_TOP], [q[1] for q in BAND_TOP]))

    xs = (0.0, BROW[1][0], BAND_TOP[1][0], 0.36, BROW[-1][0], EYE_CORNER[0])
    cols = [-x for x in reversed(xs[1:])] + list(xs)
    # The lower edge a little under the hood's, so the band's thick lip covers the hood's own.
    band = build_slab(s, "RammstoneBrow", [(x, brow_z(x) - 0.006) for x in cols], [(x, band_top(x)) for x in cols],
                      [BAND_THICK]*len(cols))
    side = keel_side(keel)
    # Where the keel's side crosses the band's top: the forehead slab's lower inner corner.
    zs = np.linspace(BAND_TOP[0][1], BAND_TOP[-1][1], 400)
    z0 = float(zs[np.argmax([side(z) + 0.015 <= np.interp(z, [q[1] for q in BAND_TOP], [q[0] for q in BAND_TOP]) for z in zs])])
    x0 = float(np.interp(z0, [q[1] for q in BAND_TOP], [q[0] for q in BAND_TOP]))
    (zi, (xo, zo)) = FOREHEAD_TOP[0][1], FOREHEAD_TOP[1]
    xi = side(zi) + 0.015
    slabs = [band]
    for sign in (1.0, -1.0):
        lower, upper, thick = [], [], []
        for u in np.linspace(0.0, 1.0, 5):
            x = x0 + (EYE_CORNER[0] - x0)*u
            lower.append((sign*x, band_top(x)))
            upper.append((sign*(xi + (xo - xi)*u), zi + (zo - zi)*u))
            thick.append(FOREHEAD_THICK + CORNER_RAISE*u*u)
        if sign < 0:
            lower, upper, thick = lower[::-1], upper[::-1], thick[::-1]
        slabs.append(build_slab(s, f"RammstoneForehead.{'R' if sign > 0 else 'L'}", lower, upper, thick))
        # The wing: from beside the band's and forehead slab's outer ends out to a point at the flared temple corner.
        tip = (hood_outline(s, WING_TIP_Z)[0] - 0.04, WING_TIP_Z)
        (xl, zl), (xu, zu) = (EYE_CORNER[0] + WING_GAP, EYE_CORNER[1] + 0.005), (xo + WING_GAP, zo)
        lower, upper, thick = [], [], []
        for u in np.linspace(0.0, 1.0, 4):
            lower.append((sign*(xl + (tip[0] - xl)*u), zl + (tip[1] - 0.01 - zl)*u))
            upper.append((sign*(xu + (tip[0] - xu)*u), zu + (tip[1] + 0.01 - zu)*u))
            thick.append(WING_THICK[0] + (WING_THICK[1] - WING_THICK[0])*u)
        slabs.append(build_slab(s, f"RammstoneWing.{'R' if sign > 0 else 'L'}", lower, upper, thick))
    return slabs


# ---------------------------------------------------------------- horns

def horn_path(s):
    """The sheet's horn centreline from where it starts to climb, smoothed and resampled, its root continued down."""
    h = np.array(s.d["horn"])
    climb = np.nonzero(h[:, 2] >= s.d["splitZ"] + 0.05)[0]
    h = h[max(int(climb[0]) - 2, 0):] if len(climb) else h
    p = h[:, :3]
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    t = np.concatenate([[0.0], np.cumsum(seg)])
    t /= t[-1]
    samples = np.linspace(0.0, 1.0, 22)
    pts = np.stack([np.interp(samples, t, p[:, i]) for i in range(3)], -1)
    # The sheet's horns grow from further forward on the head than the profile's medial axis starts.
    pts[:, 1] -= 0.12*np.clip(1.0 - samples/0.55, 0.0, 1.0)
    for i in range(3):
        sm = gaussian(pts[:, i], 1.6)
        sm[0], sm[-1] = pts[0, i], pts[-1, i]
        pts[:, i] = sm
    rf = gaussian(np.interp(samples, t, h[:, 3]), 2.0)
    rs = gaussian(np.interp(samples, t, h[:, 4]), 2.0)
    root = max(np.median(rf[:5]), 0.12)
    rx = np.maximum(rf, 0.0)
    ry = np.maximum(rs, rf*(1.25 - 0.55*samples))  # long front-to-back where it meets the head, as in the side view
    taper = (1.0 - samples)**0.5
    rx = np.minimum(rx, root*taper*1.05)*1.0
    ry = np.minimum(ry, root*taper*1.15)
    d = pts[1] - pts[0]
    d /= np.linalg.norm(d)
    extra = np.array([pts[0] - d*k for k in (0.16, 0.08)])
    pts = np.concatenate([extra, pts])
    rx = np.concatenate([[rx[0]]*2, rx])
    ry = np.concatenate([[ry[0]]*2, ry])
    return pts, rx, ry


def build_horn(s, mirror):
    pts, rx, ry = horn_path(s)
    if mirror:
        pts = pts*np.array([-1.0, 1.0, 1.0])
    verts, faces = [], []
    sides = 6
    n = len(pts)
    for i in range(n - 1):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        tan = Vector(b - a).normalized()
        e1 = Vector((1.0, 0.0, 0.0))
        e1 = (e1 - tan*e1.dot(tan)).normalized()
        e2 = tan.cross(e1)
        c = Vector(pts[i])
        for k in range(sides):
            th = 2*math.pi*k/sides + math.pi/6  # a vertex forward, so the horn has a front ridge
            verts.append(tuple(c + e1*(rx[i]*math.cos(th)) + e2*(ry[i]*math.sin(th))))
    tip = len(verts)
    verts.append(tuple(pts[-1]))
    for i in range(n - 2):
        for k in range(sides):
            a, b = i*sides + k, i*sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    last = (n - 2)*sides
    faces += [(last + k, last + (k + 1) % sides, tip) for k in range(sides)]
    faces.append(tuple(range(sides - 1, -1, -1)))
    obj = make_object("RammstoneHorn" + (".L" if mirror else ".R"), verts, faces, smooth=False, facet=0.5)
    return obj


# ---------------------------------------------------------------- face

def face_point(s, x, z):
    """A point on the body's surface seen from the front, and its outward normal (the body's own superellipse)."""
    def at(x, z):
        front, back, half = body_section(s, z)
        yc, d = (front + back)/2, (back - front)/2
        t = min(abs(x)/half, 0.999)
        return Vector((x, yc - d*(1.0 - t**BODY_N)**(1/BODY_N), z))

    e = 1e-3
    n = (at(x, z + e) - at(x, z - e)).cross(at(x + e, z) - at(x - e, z)).normalized()
    return at(x, z), (-n if n.y > 0 else n)


def eye_height(t):
    """The eye's height over the face at a fraction t of the way from its middle to its rim."""
    return (EYE_BULGE + EYE_SINK)*math.sqrt(max(0.0, 1.0 - t*t)) - EYE_SINK


def brow_z(x):
    """The brow's lower edge over the face at |x| (seen from the front)."""
    edge = BROW + (EYE_CORNER,)
    return float(np.interp(abs(x), [q[0] for q in edge], [q[1] for q in edge]))


def eye_lower(u):
    """A point on the eye's lower edge, u from its inner point (0) to its outer point (1), and the direction away from
    the eye there (seen from the front, right eye)."""
    p0 = Vector((EYE_INNER_X, brow_z(EYE_INNER_X) - EYE_GAP))
    p3 = Vector((EYE_OUTER_X, brow_z(EYE_OUTER_X) - EYE_GAP))
    p1, p2 = Vector(EYE_LOWER[0]), Vector(EYE_LOWER[1])
    point = (1 - u)**3*p0 + 3*u*(1 - u)**2*p1 + 3*u*u*(1 - u)*p2 + u**3*p3
    tangent = 3*(1 - u)**2*(p1 - p0) + 6*u*(1 - u)*(p2 - p1) + 3*u*u*(p3 - p2)
    return point, Vector((tangent.y, -tangent.x)).normalized()


def eye_outline():
    """The eye's outline as a closed (x, z) polygon (lower edge, then the hidden top along the brow) and its middle."""
    lower = [eye_lower(i/40)[0] for i in range(41)]
    top = [Vector((x, brow_z(x) + EYE_HIDDEN)) for x in np.linspace(EYE_OUTER_X, EYE_INNER_X, 12)]
    mid = eye_lower(0.5)[0]
    return [tuple(q) for q in lower + top], (mid.x, (mid.y + brow_z(mid.x))/2)


def outline_radius(outline, centre, theta):
    """Distance from centre to a closed (x, z) outline along a direction."""
    d = Vector((math.cos(theta), math.sin(theta)))
    c = Vector(centre)
    best = 0.0
    for i in range(len(outline)):
        a, b = Vector(outline[i]) - c, Vector(outline[(i + 1) % len(outline)]) - c
        e = b - a
        den = d.x*e.y - d.y*e.x
        if abs(den) < 1e-12:
            continue
        t = (a.x*e.y - a.y*e.x)/den
        u = (a.x*d.y - a.y*d.x)/den
        if t > 0 and 0.0 <= u <= 1.0:
            best = max(best, t)
    return best


def face_out(obj):
    """An open strip's faces turned to face out of the face (toward -y), which recalculating normals cannot decide."""
    mesh = obj.data
    normals = np.empty(len(mesh.polygons)*3)
    mesh.polygons.foreach_get("normal", normals)
    if normals.reshape(-1, 3)[:, 1].mean() > 0:
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()


def build_eye(s, sign):
    """A shallow dark glossy dome on the face inside the eye's almond, rising EYE_BULGE along the face's normal and
    sinking under the skin at its rim so its edge is a clean curve; the brow hides its top, the lid hugs its bottom. UVs
    are eye-local, so the drawn cracks sit the same in each eye, mirrored."""
    outline, centre = eye_outline()
    rings, spokes = 12, 48
    verts, uvs, rim = [], [], []
    for r in range(rings + 1):
        t = r/rings
        for k in range(spokes if r else 1):
            theta = 2*math.pi*k/spokes
            rad = outline_radius(outline, centre, theta)*t
            x, z = centre[0] + rad*math.cos(theta), centre[1] + rad*math.sin(theta)
            p, n = face_point(s, sign*x, z)
            lump = math.sin(41.0*x + 17.0*z)*math.sin(29.0*z - 23.0*x + 1.7 + 2.0*sign)
            verts.append(tuple(p + n*(eye_height(t) + EYE_LUMP*(1.0 - t*t)*lump)))
            uvs.append((0.5 + 0.5*(x - centre[0])/EYE_LOCAL_R, 0.5 + 0.5*(z - centre[1])/EYE_LOCAL_R))
            rim.append(t)
    faces = [(0, 1 + k, 1 + (k + 1) % spokes) for k in range(spokes)]
    for r in range(1, rings):
        a, b = 1 + (r - 1)*spokes, 1 + r*spokes
        faces += [(a + k, b + k, b + (k + 1) % spokes, a + (k + 1) % spokes) for k in range(spokes)]
    obj = make_object(f"RammstoneEye.{'R' if sign > 0 else 'L'}", verts, faces, smooth=True)
    mesh = obj.data
    assert len(mesh.vertices) == len(verts)
    uv = mesh.uv_layers.new(name="EyeLocal")  # the right eye's x for both, so the left eye's cracks mirror its
    loops = np.empty(len(mesh.loops), np.int64)
    mesh.loops.foreach_get("vertex_index", loops)
    uv.data.foreach_set("uv", np.array(uvs, np.float32)[loops].ravel())
    mesh.attributes.new("rim", "FLOAT", "POINT").data.foreach_set("value", np.array(rim, np.float32))  # 0 middle, 1 edge
    return obj


def build_lid(s, sign):
    """The lower lid: a soft ridge of skin along the eye's lower edge between its two points. It rises from under the
    eye's rim with a shadow line ("ink") where it meets the eye, crests LID_CREST just outside it and sinks back into the
    face, so the eye sits in a socket; it fades out into the points."""
    outline, centre = eye_outline()
    rows = ((-0.004, None, 0.8, 0.0), (0.0, 0.003, 0.65, 0.0), (0.004, 1.0, 0.1, 0.03), (0.009, 0.7, 0.0, 0.02),
            (0.016, 0.25, 0.0, 0.0), (0.024, -0.008, 0.0, 0.0))  # (out from the edge, height (crest fraction if 1 or less), ink, lip)
    spill_rows = (1.0, 0.8, 0.35, 0.1, 0.0, 0.0)  # the eye's glow on the lid's inner slope ("spill")
    samples = 64
    verts, ink, lip, spill = [], [], [], []
    for i in range(samples + 1):
        u = i/samples
        edge, out = eye_lower(u)
        k = float(smoothstep(0.0, 0.15, min(u, 1.0 - u)))
        spill += [g*k for g in spill_rows]
        for d, h, dark, light in rows:
            q = edge + out*d
            p, n = face_point(s, sign*q.x, q.y)
            if h is None:
                c = Vector(centre)
                h = eye_height((q - c).length/max(outline_radius(outline, centre, math.atan2(q.y - c.y, q.x - c.x)), 1e-6)) - 0.002
            elif 0.0 < h <= 1.0 and d > 0.0:
                h = LID_CREST*h*k - 0.002*(1.0 - k)
            verts.append(tuple(p + n*h))
            ink.append(dark*k)
            lip.append(light*k)
    m = len(rows)
    faces = [(i*m + j, i*m + j + 1, (i + 1)*m + j + 1, (i + 1)*m + j) for i in range(samples) for j in range(m - 1)]
    obj = make_object(f"RammstoneLid.{'R' if sign > 0 else 'L'}", verts, faces, smooth=True)
    face_out(obj)
    mesh = obj.data
    assert len(mesh.vertices) == len(verts)
    mesh.attributes.new("ink", "FLOAT", "POINT").data.foreach_set("value", np.array(ink, np.float32))
    mesh.attributes.new("lip", "FLOAT", "POINT").data.foreach_set("value", np.array(lip, np.float32))
    mesh.attributes.new("spill", "FLOAT", "POINT").data.foreach_set("value", np.array(spill, np.float32))
    return obj


def carved_line(s, name, points, half_width, crest, darkness, outside=False, depth=0.0):
    """A carved line on the face: a strip of skin through points ((x, z) seen from the front, smoothed) carrying it.
    Across it: rising out of the skin on one side, the dark line (the "ink" attribute, up to darkness), then a small
    raised lip lightened by the "lip" attribute on the other side (below, or outside with outside=True), sinking back
    under the skin. Its edges are under the skin, so no outline of the strip shows. It narrows into its ends. With a
    depth, its inner side curls dark down into a carving that deep (the mouth) instead."""
    pts = [Vector(q) for q in points]
    # Catmull-Rom through the points.
    samples = []
    ext = [pts[0]*2 - pts[1]] + pts + [pts[-1]*2 - pts[-2]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for j in range(8):
            t = j/8
            samples.append(0.5*((2*p1) + (-p0 + p2)*t + (2*p0 - 5*p1 + 4*p2 - p3)*t*t + (-p0 + 3*p1 - 3*p2 + p3)*t**3))
    samples.append(pts[-1])
    length = [0.0]
    for a, b in zip(samples, samples[1:]):
        length.append(length[-1] + (b - a).length)
    verts, ink, lip = [], [], []
    for i, q in enumerate(samples):
        p, n = face_point(s, q.x, q.y)
        a, b = samples[max(i - 1, 0)], samples[min(i + 1, len(samples) - 1)]
        tangent = (face_point(s, b.x, b.y)[0] - face_point(s, a.x, a.y)[0]).normalized()
        down = -n.cross(tangent).normalized()*(-1.0 if outside else 1.0)
        u = length[i]/length[-1]
        end = min(u, 1.0 - u)
        k = 0.35 + 0.65*float(smoothstep(0.0, 0.12, end))
        line = half_width*(0.6 + 0.4*float(smoothstep(0.0, 0.2, end)))
        top = crest*k - 0.001*(1.0 - k)
        # (distance below the line, height over the skin, ink, lip)
        # Both edges dive steeply under the skin: the body's facets sit up to about 0.002 inside its smooth surface
        # between columns, and a shallow dive met them along a wavy line.
        # Into a carving, the curl stays in front of the carved skin (which is stepped by the body's rings) down to the
        # teeth, so the teeth's visible edge is where they meet this smooth curl.
        inner = ((-3.2*line, -depth - 0.006, 1, 0), (-2.6*line, -0.95*depth, 1, 0), (-1.8*line, -0.5*depth, 1, 0)) \
            if depth else ((-3.0*line, -0.008, 0, 0), (-2.0*line, 0.0002, 0.3, 0))
        across = inner + ((-line, 0.0006, 1, 0), (0.0, 0.0005, 1, 0),
                  (line, 0.0006, 1, 0), (line + 0.002*k, 0.0016, 0.2, 0.2), (line + 0.006*k, top, 0, 0.6),
                  (line + 0.011*k, top*0.6, 0, 0.3), (line + 0.016*k, 0.0004, 0, 0), (line + 0.020*k, -0.008, 0, 0))
        for d, h, dark, light in across:
            verts.append(tuple(p + down*d + n*h))
            ink.append(dark*darkness)
            lip.append(light)
    m = len(across)
    faces = [(i*m + j, i*m + j + 1, (i + 1)*m + j + 1, (i + 1)*m + j) for i in range(len(samples) - 1) for j in range(m - 1)]
    obj = make_object(name, verts, faces, smooth=True)
    face_out(obj)
    mesh = obj.data
    assert len(mesh.vertices) == len(verts)
    mesh.attributes.new("ink", "FLOAT", "POINT").data.foreach_set("value", np.array(ink, np.float32))
    mesh.attributes.new("lip", "FLOAT", "POINT").data.foreach_set("value", np.array(lip, np.float32))
    return obj


def grin_edges(x):
    """The grin's top and bottom edges at x (seen from the front)."""
    cx, cz = GRIN_CORNER
    r = min(abs(x)/cx, 1.0)
    return GRIN_TOP_MID + (cz - GRIN_TOP_MID)*r**2, GRIN_BOTTOM_MID + (cz - GRIN_BOTTOM_MID)*r**2.2


def build_teeth(s):
    """Both rows of teeth filling the grin as plain white: the upper row rounds off down to the bite line and the lower
    row, a little behind it, rounds off up to it, so the line is a clean dark groove ("bite"). "shade" darkens under the
    upper lip and into the corners. All of it inside the carved mouth."""
    cx = GRIN_CORNER[0]
    cols = 160
    vs = list(np.linspace(0.0, GRIN_BITE, 16)) + list(np.linspace(GRIN_BITE, 1.0, 12)[1:])
    verts, shade, bite = [], [], []
    for i in range(cols + 1):
        x = cx*0.995*(2*i/cols - 1)
        top, bottom = grin_edges(x)
        corner = float(smoothstep(0.72, 1.0, abs(x)/cx))
        for v in vs:
            upper = v <= GRIN_BITE
            r = v/GRIN_BITE if upper else (1.0 - v)/(1.0 - GRIN_BITE)  # 0 at the lip, 1 at the bite line
            edge = math.sqrt(max(0.0, 1.0 - max(0.0, (r - 0.45)/0.55)**2))  # rounding off into the bite line
            height = (0.006 if upper else 0.0045)*edge*(1.0 - 0.6*corner)
            p, n = face_point(s, x, top + (bottom - top)*v)
            verts.append(tuple(p + n*(height + (0.001 if upper else 0.0005) - MOUTH_DEPTH)))
            shade.append(max(0.6*float(smoothstep(0.2, 0.0, v)), 0.85*corner))
            bite.append(math.exp(-((v - GRIN_BITE)/0.025)**2)*(1.0 - corner))
    m = len(vs)
    faces = [(i*m + j, i*m + j + 1, (i + 1)*m + j + 1, (i + 1)*m + j) for i in range(cols) for j in range(m - 1)]
    obj = make_object("RammstoneTeeth", verts, faces, smooth=True)
    face_out(obj)
    mesh = obj.data
    assert len(mesh.vertices) == len(verts)
    for name, values in (("shade", shade), ("bite", bite)):
        mesh.attributes.new(name, "FLOAT", "POINT").data.foreach_set("value", np.array(values, np.float32))
    return obj


def build_lips(s):
    """The grin's carved outline: the upper lip's dark line along the top edge, running on past each corner into a
    crease curving up round it (SMILE_CREASE), with a faint rim above it; the lower lip's dark line along the bottom
    edge with the raised lip under it."""
    cx, cz = GRIN_CORNER
    xs = np.linspace(-cx*0.92, cx*0.92, 11)
    crease = [(cx + dx, cz + dz) for dx, dz in SMILE_CREASE]
    upper = [(-x, z) for x, z in reversed(crease)] + [(-cx, cz)] + [(x, grin_edges(x)[0]) for x in xs] + [(cx, cz)] + crease
    lower = [(-cx, cz)] + [(x, grin_edges(x)[1]) for x in xs] + [(cx, cz)]
    return [carved_line(s, "RammstoneLipUpper", upper, 0.0045, 0.003, 1.0, outside=True, depth=MOUTH_DEPTH),
            carved_line(s, "RammstoneLipLower", lower, 0.004, 0.0055, 1.0, depth=MOUTH_DEPTH)]


def teeth_material():
    """Teeth: smooth warm white, darker where "shade" says (under the upper lip, into the corners), a fine dark line
    where "bite" says."""
    mat = bpy.data.materials.new("RammstoneTeeth")
    mat.use_nodes = True
    tree = mat.node_tree
    shader = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    colour = None
    for name, value in (("shade", (0.22, 0.14, 0.10, 1)), ("bite", (0.16, 0.10, 0.08, 1))):
        attr = tree.nodes.new("ShaderNodeAttribute")
        attr.attribute_name = name
        mix = tree.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        tree.links.new(attr.outputs["Fac"], mix.inputs[0])
        if colour is None:
            mix.inputs[6].default_value = (1.0, 0.95, 0.86, 1)
        else:
            tree.links.new(colour, mix.inputs[6])
        mix.inputs[7].default_value = value
        colour = mix.outputs[2]
    tree.links.new(colour, shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.3
    shader.inputs["Specular IOR Level"].default_value = 0.5
    return mat


def mouth_shading(skin):
    """Lets the skin carry the mouth: lightened along the lower lip by the "lip" attribute, darkened to the line by
    "ink". The body has neither, so it is unchanged."""
    tree = skin.node_tree
    shader = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    link = shader.inputs["Base Color"].links[0]
    colour = link.from_socket
    tree.links.remove(link)
    for name, value in (("lip", (0.90, 0.48, 0.28, 1)), ("ink", (0.06, 0.025, 0.015, 1))):
        attr = tree.nodes.new("ShaderNodeAttribute")
        attr.attribute_name = name
        mix = tree.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        tree.links.new(attr.outputs["Fac"], mix.inputs[0])
        tree.links.new(colour, mix.inputs[6])
        mix.inputs[7].default_value = value
        colour = mix.outputs[2]
    tree.links.new(colour, shader.inputs["Base Color"])


def eye_spill(skin):
    """Lets the skin glow faintly orange where the "spill" attribute says (the lids' inner slopes), as the eyes' light
    catches the socket on the sheet. The body has no such attribute, so it is unchanged."""
    tree = skin.node_tree
    shader = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    attr = tree.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "spill"
    strength = tree.nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    strength.inputs[1].default_value = 0.3  # 0.8 drew an orange ring round each eye (goggles)
    tree.links.new(attr.outputs["Fac"], strength.inputs[0])
    shader.inputs["Emission Color"].default_value = (1.0, 0.25, 0.03, 1)
    tree.links.new(strength.outputs["Value"], shader.inputs["Emission Strength"])


def eye_crack_image(size=512):
    """EYE_CRACKS drawn into an image over eye-local coordinates: red the cracks' hot cores, green a glow round them,
    blue a broad warmth. Each crack is a jagged polyline (seeded), narrowing toward its ends."""
    rnd = np.random.default_rng(7)
    g = (np.arange(size) + 0.5)/size*2.0 - 1.0
    px, pz = np.meshgrid(g, g)  # image rows run bottom to top
    core, glow, warm = (np.zeros((size, size)) for _ in range(3))
    for points, width in EYE_CRACKS:
        pts = [np.array(points[0])]
        for a, b in zip(points, points[1:]):
            a, b = np.array(a), np.array(b)
            normal = np.array((a[1] - b[1], b[0] - a[0]))/max(np.linalg.norm(b - a), 1e-6)
            for k in (1, 2, 3):
                pts.append(a + (b - a)*k/4 + normal*rnd.uniform(-0.015, 0.015))
            pts.append(b)
        for i, (a, b) in enumerate(zip(pts, pts[1:])):
            along = (i + 0.5)/(len(pts) - 1)
            w = width*(0.55 + 0.45*math.sin(math.pi*along))
            ab = b - a
            t = np.clip(((px - a[0])*ab[0] + (pz - a[1])*ab[1])/max(ab @ ab, 1e-9), 0.0, 1.0)
            d = np.hypot(px - a[0] - t*ab[0], pz - a[1] - t*ab[1])
            core = np.maximum(core, np.clip(1.0 - (d - 0.5*w)/(0.5*w), 0.0, 1.0))
            glow = np.maximum(glow, np.exp(-(d/0.07)**2))
            warm = np.maximum(warm, np.exp(-(d/0.22)**2))
    rgba = np.stack([core, glow, warm, np.ones_like(core)], -1).astype(np.float32)
    image = bpy.data.images.new("RammstoneEyeCracks", size, size)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(rgba.ravel())
    image.pack()
    return image


def face_materials():
    """Eyes: warm dark-brown glossy stone, darker up under the brow and toward the rim (the socket), with the drawn
    glowing cracks: a yellow core in an orange glow and a broad warmth round them."""
    eye = bpy.data.materials.new("RammstoneEye")
    eye.use_nodes = True
    tree = eye.node_tree
    shader = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    uv = tree.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "EyeLocal"
    tex = tree.nodes.new("ShaderNodeTexImage")
    tex.image = eye_crack_image()
    tex.extension = "EXTEND"
    tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    channels = tree.nodes.new("ShaderNodeSeparateColor")
    tree.links.new(tex.outputs["Color"], channels.inputs["Color"])
    core, glow, warm = channels.outputs[0], channels.outputs[1], channels.outputs[2]
    local = tree.nodes.new("ShaderNodeSeparateXYZ")
    tree.links.new(uv.outputs["UV"], local.inputs["Vector"])

    def ramp(value, lo, hi):
        m = tree.nodes.new("ShaderNodeMapRange")
        m.inputs["From Min"].default_value = lo
        m.inputs["From Max"].default_value = hi
        tree.links.new(value, m.inputs["Value"])
        return m.outputs["Result"]

    def mix(fac, a, b):
        m = tree.nodes.new("ShaderNodeMix")
        m.data_type = "RGBA"
        tree.links.new(fac, m.inputs[0])
        for socket, value in ((m.inputs[6], a), (m.inputs[7], b)):
            if isinstance(value, tuple):
                socket.default_value = (*value, 1)
            else:
                tree.links.new(value, socket)
        return m.outputs[2]

    def math_node(op, a, b):
        m = tree.nodes.new("ShaderNodeMath")
        m.operation = op
        for socket, value in ((m.inputs[0], a), (m.inputs[1], b)):
            if isinstance(value, float):
                socket.default_value = value
            else:
                tree.links.new(value, socket)
        return m.outputs["Value"]

    rim = tree.nodes.new("ShaderNodeAttribute")
    rim.attribute_name = "rim"
    base = mix(ramp(local.outputs["Y"], 0.45, 0.8), (0.10, 0.036, 0.02), (0.018, 0.007, 0.005))  # darker up under the brow
    base = mix(ramp(rim.outputs["Fac"], 0.7, 1.0), base, (0.008, 0.003, 0.002))  # the socket
    heat = math_node("MAXIMUM", math_node("MULTIPLY", glow, 0.6), math_node("MULTIPLY", warm, 0.15))
    tree.links.new(mix(heat, base, (0.6, 0.10, 0.01)), shader.inputs["Base Color"])
    tree.links.new(mix(core, (1.0, 0.24, 0.02), (1.0, 0.62, 0.14)), shader.inputs["Emission Color"])
    strength = math_node("ADD", math_node("MULTIPLY", core, 8.0),
                         math_node("ADD", math_node("MULTIPLY", glow, 1.2), math_node("MULTIPLY", warm, 0.12)))
    tree.links.new(strength, shader.inputs["Emission Strength"])
    shader.inputs["Roughness"].default_value = 0.3
    shader.inputs["Specular IOR Level"].default_value = 0.5
    shader.inputs["Coat Weight"].default_value = 0.25
    shader.inputs["Coat Roughness"].default_value = 0.1
    return eye


# ---------------------------------------------------------------- assembly

def make_object(name, verts, faces, smooth, facet=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", np.full(len(mesh.polygons), smooth))
    if facet is not None:
        rnd = np.random.default_rng(abs(hash(name)) % (2**32))
        attr = mesh.attributes.new("facet", "FLOAT", "FACE")
        attr.data.foreach_set("value", np.clip(facet + rnd.uniform(-0.12, 0.12, len(mesh.polygons)), 0, 1).astype(np.float32))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def body_clearance(s, p):
    """How far a point stands outside the body's surface, across the body at its height."""
    if not 0.0 <= p.z <= 2.03:
        return 1.0
    front, back, half = body_section(s, p.z)
    yc = (front + back)/2
    r, _ = body_radius(s, p.z, math.atan2(p.x, p.y - yc))
    if p.z > 1.86:
        r *= math.sqrt(max(0.0, 1.0 - ((p.z - 1.86)/0.17)**2))
    return math.hypot(p.x, p.y - yc) - r


def bevel(obj, width=BEVEL, clear=None):
    """A small bevel on edges sharper than 30 degrees. With clear (a point's distance outside the body), only edges
    standing clear of the skin get one: owner, 2026-11-13, the orange edging "where the armor meets the belly... is kind
    of messed up... I don't know if it's outline or like cracks": a plate's lit bevel running into the skin ended in a
    stray orange sliver there."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    weight = [float(len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(30)
                    and (clear is None or min(clear(v.co) for v in e.verts) > 0.012)) for e in bm.edges]
    bm.free()
    obj.data.attributes.new("bevel_weight_edge", "FLOAT", "EDGE").data.foreach_set("value", np.array(weight, np.float32))
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = 1
    mod.limit_method = "WEIGHT"
    mod.harden_normals = False
    mod.material = 1  # the light "edge" material in each rock and charcoal object's second slot


def fine_cracks(tree, coords):
    """The sheet's crazing: a fine, faint network of slightly wobbly lines darkening the rock, fainter in places.
    Owner, 2026-11-08: the patches of large dark cells "look a bit weird"."""
    wobble = surf.node(tree, "ShaderNodeTexNoise", Scale=6.0, Detail=3.0)
    tree.links.new(coords.outputs["Object"], wobble.inputs["Vector"])
    offset = tree.nodes.new("ShaderNodeVectorMath")
    offset.operation = "MULTIPLY_ADD"
    tree.links.new(wobble.outputs["Color"], offset.inputs[0])
    offset.inputs[1].default_value = (0.03, 0.03, 0.03)
    offset.inputs[2].default_value = (-0.015, -0.015, -0.015)
    vec = tree.nodes.new("ShaderNodeVectorMath")
    vec.operation = "ADD"
    tree.links.new(coords.outputs["Object"], vec.inputs[0])
    tree.links.new(offset.outputs["Vector"], vec.inputs[1])
    vor = tree.nodes.new("ShaderNodeTexVoronoi")
    vor.voronoi_dimensions = "3D"
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 14.0
    tree.links.new(vec.outputs["Vector"], vor.inputs["Vector"])
    line = tree.nodes.new("ShaderNodeMapRange")
    line.inputs["From Max"].default_value = 0.03
    line.inputs["To Min"].default_value = 1.0
    line.inputs["To Max"].default_value = 0.0
    tree.links.new(vor.outputs["Distance"], line.inputs["Value"])
    fade_noise = surf.node(tree, "ShaderNodeTexNoise", Scale=2.0, Detail=1.0)
    tree.links.new(coords.outputs["Object"], fade_noise.inputs["Vector"])
    fade = tree.nodes.new("ShaderNodeMapRange")
    fade.inputs["From Min"].default_value = 0.35
    fade.inputs["From Max"].default_value = 0.65
    fade.inputs["To Min"].default_value = 0.35
    tree.links.new(fade_noise.outputs["Fac"], fade.inputs["Value"])
    cracks = tree.nodes.new("ShaderNodeMath")
    cracks.operation = "MULTIPLY"
    tree.links.new(line.outputs["Result"], cracks.inputs[0])
    tree.links.new(fade.outputs["Result"], cracks.inputs[1])
    return cracks.outputs["Value"], "MULTIPLY", (0.62, 0.57, 0.57)


def edge_material(mat, name, dark, light):
    """A copy of mat with lighter facet colours, for the faces the bevel adds along sharp edges: the sheet's plates and
    horns have light, worn edges that catch the light all round."""
    edge = mat.copy()
    edge.name = name
    attr = next(n for n in edge.node_tree.nodes if n.type == "ATTRIBUTE" and n.attribute_name == "facet")
    mix = attr.outputs["Fac"].links[0].to_node
    mix.inputs[6].default_value = (*dark, 1)
    mix.inputs[7].default_value = (*light, 1)
    return edge


def attribute_mix(mat, name):
    """The colour mix that the named attribute drives in mat."""
    attr = next(n for n in mat.node_tree.nodes if n.type == "ATTRIBUTE" and n.attribute_name == name)
    return attr.outputs["Fac"].links[0].to_node


def liven(rock, skin, horn):
    """Owner, 2026-11-13: "bring more life to the colors too, like make the red a bit shiny or something. Make the tummy
    color have a bit more life". The rock a richer, deeper red with a light crisp coat (a broad shine washed it pink
    in the viewport's light; a crisper one turned whole flat facets white under a sun); the skin a warmer, more saturated peach, soft (subsurface) and a little glossy; the horns
    a little shiny."""
    mix = attribute_mix(rock, "facet")
    mix.inputs[6].default_value = (0.24, 0.012, 0.008, 1)
    mix.inputs[7].default_value = (0.38, 0.026, 0.014, 1)
    shader = next(n for n in rock.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    for name, value in (("Roughness", 0.6), ("Specular IOR Level", 0.35), ("Coat Weight", 0.15), ("Coat Roughness", 0.3)):
        shader.inputs[name].default_value = value
    mix = attribute_mix(skin, "crease")
    mix.inputs[6].default_value = (0.76, 0.33, 0.17, 1)
    mix.inputs[7].default_value = (0.40, 0.13, 0.06, 1)
    shader = next(n for n in skin.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    for name, value in (("Roughness", 0.42), ("Specular IOR Level", 0.4), ("Subsurface Weight", 0.25),
                        ("Subsurface Radius", (1.0, 0.35, 0.18)), ("Subsurface Scale", 0.03)):
        shader.inputs[name].default_value = value
    shader = next(n for n in horn.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    for name, value in (("Roughness", 0.5), ("Specular IOR Level", 0.4)):
        shader.inputs[name].default_value = value


def assign_materials(body, rocks, under, horns):
    holder = body
    surf.materials(holder, cracks=fine_cracks)  # creates RammstoneRock, RammstoneSkin, RammstoneHorn on the body
    rock, skin, horn = (bpy.data.materials[n] for n in ("RammstoneRock", "RammstoneSkin", "RammstoneHorn"))
    liven(rock, skin, horn)
    rock_edge = edge_material(rock, "RammstoneRockEdge", (0.66, 0.11, 0.05), (0.84, 0.18, 0.08))
    horn_edge = edge_material(horn, "RammstoneHornEdge", (0.16, 0.14, 0.14), (0.24, 0.21, 0.20))
    body.data.materials.clear()
    body.data.materials.append(skin)
    for o in rocks + [under]:  # the underlayer is the same rock, so where it shows it reads as rock, not a hole
        o.data.materials.append(rock)
        o.data.materials.append(rock_edge)
    for o in horns:
        o.data.materials.append(horn)
        o.data.materials.append(horn_edge)


def build(s, horns=True):
    """Every part of the base form in a fresh scene, materials assigned, parented to a "Rammstone" empty; the parts are
    returned by name. Without horns for the transformed form (build_rammstone_transformed.py), which has its own."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = build_body(s)
    under = build_shell(s)
    plates = build_plates(s)
    hood = build_hood(s)
    keel = build_keel(s, hood)
    cheeks = [build_cheek(s, 1.0), build_cheek(s, -1.0)]
    forehead = build_forehead(s, keel)
    horns = [build_horn(s, False), build_horn(s, True)] if horns else []
    clear = lambda q: body_clearance(s, q)
    for o in plates + cheeks + forehead + [keel] + horns:
        bevel(o, clear=clear)
    bevel(hood, 0.006, clear)  # a wider one fills the hood's creases up through the keel lying on it
    assign_materials(body, plates + cheeks + forehead + [hood], under, horns + [keel])
    eyes = [build_eye(s, 1.0), build_eye(s, -1.0)]
    lids = [build_lid(s, 1.0), build_lid(s, -1.0)]
    teeth = build_teeth(s)
    lips = build_lips(s)
    eye_mat = face_materials()
    for o in eyes:
        o.data.materials.append(eye_mat)
    skin = bpy.data.materials["RammstoneSkin"]
    mouth_shading(skin)
    eye_spill(skin)
    for o in lids + lips:
        o.data.materials.append(skin)
    teeth_mat = teeth_material()
    teeth.data.materials.append(teeth_mat)
    face = eyes + lids + [teeth] + lips
    rig = bpy.data.objects.new("Rammstone", None)
    bpy.context.collection.objects.link(rig)
    parts = [body, under, hood, keel] + cheeks + forehead + plates + horns + face
    for o in parts:
        o.parent = rig
    return {"rig": rig, "body": body, "plates": plates, "parts": parts}


def triangles(objects):
    total = 0
    for o in objects:
        o.data.calc_loop_triangles()
        total += len(o.data.loop_triangles)
    return total


def main():
    s = Sheet(json.loads(MEASURE.read_text()))
    built = build(s)
    calib = json.loads(surf.CALIB.read_text())
    surf.OUT = OUT
    renders = surf.render(calib)
    report = {"tool": bpy.app.version_string, "plates": len(built["plates"]), "triangles": triangles(built["parts"]),
              "renders": renders}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/"report.json").write_text(json.dumps(report, indent=2))
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
