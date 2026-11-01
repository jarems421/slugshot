"""New blaster barrel tips (owner, 2026-11-01, after the first barrel options).

Brief: the planar bevelled tips "feel wrong… trying to be sharp but it's not… or it should be curved"; keep the
top prong pointing down but turn the bottom prong up, so the tips point toward each other; no hard corner where
the slope starts; give the facing tips something so they are not flat; and add a small detail to the sloped face,
which reads from the front as "a flat slab of orange" (the sides have a line running along them).

Method: cut both orange prongs at Y_CUT, keeping their exact cross-section (with the side line), and loft new tips
from the cut loops. Each ring is the cut loop with its outer part eased toward the inner face along a curve with
zero slope at the cut (so there is no corner), narrowed slightly and ending in a rounded point. Top prong eases
down, bottom prong eases up; the firing gap stays open. Writes one .blend per option.

    blender --background --factory-startup --python tools/lobby/blaster_tips.py -- <accepted.blend> <out dir> [option ...]
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = Path(ARGS[0]).resolve(), Path(ARGS[1]).resolve()

RINGS = 18
# Measured inner faces: top prong underside 0.436, bottom prong top face 0.164.
PRONGS = {"top": (0.436, 1.0), "bottom": (0.164, -1.0)}

# cut/end: where the new tip starts and ends (y); lead: share of the descent that is linear, so the curve leaves the
# cut at the prong's own gentle slope instead of levelling off first.
BASE = dict(cut=1.38, end=1.83, lead=0.0)
OPTIONS = {
    "curved": dict(BASE, tip=0.12, hook=0.0, taper=0.3, ridge=0.0, groove=True, nodes=False),
    "hooked": dict(BASE, tip=0.1, hook=0.05, taper=0.38, ridge=0.0, groove=True, nodes=False),
    "bladed": dict(BASE, tip=0.12, hook=0.015, taper=0.3, ridge=0.035, groove=False, nodes=False),
    "charged": dict(BASE, tip=0.1, hook=0.05, taper=0.38, ridge=0.0, groove=True, nodes=True),
    # Owner's pick, revised (2026-11-01): the bladed ridge without the dip before the blade (the old cut sat after a
    # flat run, so the edge went down, levelled and dropped again; 1.22 is where the prong's own descent ends and the
    # first clean two-loop cut), and about 15% shorter so it clears the floor on the hip: the tip now ends before
    # the accepted blaster's.
    "bladed-final": dict(cut=1.22, end=1.655, lead=0.4, tip=0.12, hook=0.015, taper=0.3, ridge=0.035, groove=False, nodes=False),
}


def ease(t, lead=0.0):
    """0 -> 1 along the tip. With lead 0 it leaves the cut level (no corner); a lead blends in a linear share so it
    leaves at the prong's own gentle slope."""
    return lead*t + (1.0 - lead)*(1.0 - math.cos(t*math.pi/2))


def ordered_loops(bm, y):
    edges = {e for e in bm.edges if e.is_boundary and all(abs(v.co.y - y) < 1e-4 for v in e.verts)}
    verts, loops = {v for e in edges for v in e.verts}, []
    while verts:
        start = verts.pop()
        loop, prev, cur = [start], None, start
        while True:
            nxt = next((e.other_vert(cur) for e in cur.link_edges if e in edges and e.other_vert(cur) is not prev
                        and (e.other_vert(cur) in verts or (e.other_vert(cur) is start and len(loop) > 2))), None)
            if nxt is None or nxt is start:
                break
            loop.append(nxt)
            verts.discard(nxt)
            prev, cur = cur, nxt
        loops.append(loop)
    return loops


def place(x, z, t, z_in, sgn, opt, omax):
    """Where a cut-loop point (x, z) goes at fraction t along the tip."""
    e = ease(t, opt["lead"])
    o = (z - z_in)*sgn                      # distance from the inner face toward the outside
    h = 1.0 - (1.0 - opt["tip"])*e
    o2 = o*h
    if opt["ridge"] and o > 0.0:
        # The ridge comes from lowering the faces either side of the centre line, never raising it, so the
        # silhouette only ever falls toward the tip.
        o2 -= opt["ridge"]*e*min(abs(x)/0.11, 1.0)*(o/omax)
    x2 = x*(1.0 - opt["taper"]*e)
    z2 = z_in + sgn*o2 - sgn*opt["hook"]*t*t
    return x2, z2


def loft(bm, loop, z_in, sgn, opt, mat_index):
    omax = max((v.co.z - z_in)*sgn for v in loop)
    prev = loop
    new_faces = []
    for k in range(1, RINGS + 1):
        t = k/RINGS
        y = opt["cut"] + (opt["end"] - opt["cut"])*t
        ring = []
        for v in loop:
            x2, z2 = place(v.co.x, v.co.z, t, z_in, sgn, opt, omax)
            ring.append(bm.verts.new((x2, y, z2)))
        n = len(loop)
        for i in range(n):
            f = bm.faces.new((prev[i], prev[(i + 1) % n], ring[(i + 1) % n], ring[i]))
            f.material_index = mat_index
            new_faces.append(f)
        prev = ring
    # Rounded point: the last ring closes onto a centre slightly ahead, so the tip is never a flat end.
    c = sum((v.co for v in prev), Vector())/len(prev)
    apex = bm.verts.new((c.x, opt["end"] + 0.035, c.z))
    for i in range(len(prev)):
        f = bm.faces.new((prev[i], prev[(i + 1) % len(prev)], apex))
        f.material_index = mat_index
        new_faces.append(f)
    # Orient outward: compare one side face's normal with the direction away from the prong's axis.
    bm.normal_update()
    probe = new_faces[len(loop)//4]
    axis = Vector((0.0, probe.calc_center_median().y, c.z))
    if probe.normal.dot(probe.calc_center_median() - axis) < 0:
        bmesh.ops.reverse_faces(bm, faces=new_faces)
    for f in new_faces:
        f.smooth = True
    return new_faces


def strip(name, pts, normals, width, material):
    """A thin inlay following a surface line, lifted just off it."""
    bm = bmesh.new()
    rows = []
    for p, n in zip(pts, normals):
        side = Vector((1, 0, 0))
        rows.append((bm.verts.new(p + n*0.0025 - side*width), bm.verts.new(p + n*0.0025 + side*width)))
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[0], a[1], b[1], b[0]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(bpy.data.materials[material])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def node(name, centre, radius, material):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius)
    bmesh.ops.translate(bm, verts=bm.verts, vec=centre)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(bpy.data.materials[material])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build(opt):
    o = bpy.data.objects["Orange"]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=5e-4)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, opt["cut"], 0),
                           plane_no=(0, 1, 0), clear_outer=True)
    loops = ordered_loops(bm, opt["cut"])
    print("cut loops", [len(lp) for lp in loops])
    for loop in loops:
        zmid = sum(v.co.z for v in loop)/len(loop)
        z_in, sgn = PRONGS["top" if zmid > 0.3 else "bottom"]
        loft(bm, loop, z_in, sgn, opt, 0)
    bm.transform(o.matrix_world.inverted())
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    # Surface lines for the front-view detail and the charge nodes need the finished surface.
    dg = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(o, dg)
    inv, mw = o.matrix_world.inverted(), o.matrix_world
    if opt["groove"]:
        for name, (z_in, sgn) in PRONGS.items():
            pts, nrm = [], []
            for k in range(26):
                y = 1.2 + (opt["end"] - 0.05 - 1.2)*k/25
                start = inv @ Vector((0.0, y, z_in + sgn*0.5))
                hit = tree.ray_cast(start, (inv.to_3x3() @ Vector((0, 0, -sgn))).normalized(), 1.0)
                if hit[0] is not None:
                    pts.append(mw @ hit[0])
                    nrm.append((mw.to_3x3() @ hit[1]).normalized())
            if len(pts) > 2:
                strip(f"Groove{name}", pts, nrm, 0.007, "Black")
    if opt["nodes"]:
        for name, (z_in, sgn) in PRONGS.items():
            y = opt["end"] - 0.07
            start = inv @ Vector((0.0, y, 0.30))  # middle of the firing gap, casting toward each prong
            hit = tree.ray_cast(start, (inv.to_3x3() @ Vector((0, 0, sgn))).normalized(), 1.0)
            if hit[0] is not None:
                node(f"ChargeNode{name}", mw @ hit[0], 0.024, "CyanGlow")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = ARGS[2:]
    for name, opt in OPTIONS.items():
        if only and name not in only:
            continue
        bpy.ops.wm.open_mainfile(filepath=str(SRC))
        build(opt)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f"blaster-tip-{name}.blend"), copy=True)
        print("TIP", name)


main()
