"""Blaster barrel variants for the Slugshot look review (owner, 2026-11-01: "more like a dangerous weapon…
not a full redesign or changing colours… the shape of the barrel").

Starts from a copy of the accepted blaster (`build/slugs/floppy/blaster-long-bevel/grip-shortened.blend` in the
slug pipeline worktree) and adds parts in the existing materials only, placed on the prongs' measured surfaces
(source units, barrel along +Y, Z up). Owner rules kept from the blaster rounds: tips slope down, never up, and
the firing gap between the prongs stays open. Writes one .blend per variant.

    blender --background --factory-startup --python tools/lobby/blaster_variants.py -- <accepted.blend> <out dir>
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = Path(ARGS[0]).resolve(), Path(ARGS[1]).resolve()

# Measured prong surfaces (ray casts on the accepted mesh): top prong underside 0.436, top 0.638 (bevelling to
# 0.459 at the tip, y 1.774), half-width about 0.10; bottom prong top face 0.164 (bevelling to 0.014), bottom
# -0.007, half-width about 0.111. The canister ends at y 1.196.
TIP_Y = 1.774


def hull(name, points, material):
    """A convex part from a point cloud, flat shaded like the gun's hard-surface panels."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(bpy.data.materials[material])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mirror_x(points):
    return [(-x, y, z) for x, y, z in points]


def box_points(x0, x1, y0, y1, z0, z1, chamfer=0.0):
    """Corners of a box, with its y-z outline chamfered (an octagonal plate) when chamfer > 0."""
    c = chamfer
    outline = [(y0 + c, z0), (y1 - c, z0), (y1, z0 + c), (y1, z1 - c), (y1 - c, z1), (y0 + c, z1), (y0, z1 - c), (y0, z0 + c)]
    return [(x, y, z) for x in (x0, x1) for y, z in outline]


def fangs():
    """Steel teeth along both inner faces beyond the canister, raked forward like a jaw."""
    parts = []
    for i, y in enumerate((1.27, 1.37, 1.47, 1.57)):
        base = [(sx*0.08, y + dy, 0.452) for sx in (-1, 1) for dy in (0.0, 0.095)]  # sunk into the underside
        tip = [(sx*0.018, y + 0.09, 0.378) for sx in (-1, 1)]
        parts.append(hull(f"FangTop{i}", base + tip, "Steel"))
    for i, y in enumerate((1.24, 1.34, 1.44)):
        base = [(sx*0.085, y + dy, 0.148) for sx in (-1, 1) for dy in (0.0, 0.095)]
        tip = [(sx*0.018, y + 0.09, 0.222) for sx in (-1, 1)]
        parts.append(hull(f"FangBottom{i}", base + tip, "Steel"))
    return parts


def claws():
    """Steel claws that carry each prong's downward tip bevel on to a hooked point."""
    top = ([(sx*0.07, 1.62, z) for sx in (-1, 1) for z in (0.445, 0.55)]
           + [(sx*0.06, TIP_Y, z) for sx in (-1, 1) for z in (0.425, 0.462)]
           + [(sx*0.008, 1.93, 0.385) for sx in (-1, 1)])
    bottom = ([(sx*0.075, 1.58, z) for sx in (-1, 1) for z in (0.0, 0.1)]
              + [(sx*0.065, TIP_Y, z) for sx in (-1, 1) for z in (-0.02, 0.02)]
              + [(sx*0.008, 1.92, -0.075) for sx in (-1, 1)])
    return [hull("ClawTop", top, "Steel"), hull("ClawBottom", bottom, "Steel")]


def armour():
    """Graphite side plates on both prongs with steel bolts: a heavier, built-up barrel."""
    parts = []
    for name, (xi, xo, z0, z1) in {"Top": (0.094, 0.121, 0.468, 0.608), "Bottom": (0.105, 0.132, 0.022, 0.14)}.items():
        plate = box_points(xi, xo, 0.84, 1.28, z0, z1, chamfer=0.03)
        parts.append(hull(f"Armour{name}R", plate, "BodyGrey"))
        parts.append(hull(f"Armour{name}L", mirror_x(plate), "BodyGrey"))
        for y in (0.9, 1.22):
            for sx in (-1, 1):
                bolt = [(sx*(xo - 0.004 + t), y + 0.013*math.cos(a), (z0 + z1)/2 + 0.013*math.sin(a))
                        for t in (0.0, 0.01) for a in [k*math.pi/5 for k in range(10)]]
                parts.append(hull(f"Bolt{name}{y}{sx}", bolt, "Steel"))
    return parts


def vents():
    """Angled vent slots cut into both prongs' sides near the front, slanting forward like the tip bevel."""
    cutters = []
    for name, (y0s, z0, z1) in {"Top": ((1.30, 1.38, 1.46), 0.47, 0.6), "Bottom": ((1.24, 1.32, 1.40), 0.025, 0.135)}.items():
        for i, y in enumerate(y0s):
            slot = [(x, y + (z - z0)/(z1 - z0)*0.05 + dy, z) for x in (0.072, 0.3) for z in (z0, z1) for dy in (0.0, 0.026)]
            cutters.append(hull(f"Vent{name}{i}R", slot, "Orange"))
            cutters.append(hull(f"Vent{name}{i}L", mirror_x(slot), "Orange"))
    orange = bpy.data.objects["Orange"]
    for c in cutters:
        c.matrix_world = c.matrix_world  # cutters are in world space; the boolean uses world transforms
        md = orange.modifiers.new(c.name, "BOOLEAN")
        md.operation, md.solver, md.object = "DIFFERENCE", "EXACT", c
    bpy.context.view_layer.objects.active = orange
    for md in list(orange.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    for c in cutters:
        bpy.data.objects.remove(c)
    return []


VARIANTS = {
    "current": [],
    "fangs": [fangs],
    "claws": [claws],
    "armoured": [armour, vents],
    "combined": [claws, armour, vents],
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, steps in VARIANTS.items():
        bpy.ops.wm.open_mainfile(filepath=str(SRC))
        for step in steps:
            step()
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f"blaster-{name}.blend"), copy=True)
        print("VARIANT", name, len(bpy.data.objects))


main()
