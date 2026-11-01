"""Export the chosen blaster (bladed-ridge tips) for Roblox with Slugshot ink outlines.

Owner, 2026-11-01: "once you fix that with the gun, make that the Roblox model". Writes, into <out dir>:
- model.glb: every part plus a `<Part>_Ink` inverted-hull shell (near-black, reversed faces; Roblox culls back
  faces so only the rim shows), the same shells the look renders use;
- mesh-specs.json: each part's bounds in gun space (X right, Y up, -Z toward the muzzle), the layout the Floppy
  test place's BlasterMesh mapping needs. Finishes for the ink shells are added by tools/lobby/blaster_mapping.py.

    blender --background --factory-startup --python tools/lobby/export_blaster_look.py -- <blaster.blend> <out dir>
"""

import json
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = Path(ARGS[0]).resolve(), Path(ARGS[1]).resolve()
INK_WIDTH = 0.016
THIN_PARTS = {"Steel", "White", "ChargerVane", "GripBand"}
NO_INK = {"CyanGlow"}
MAX_PART_TRIS = 7000  # a thin glowing strip; an outline would swallow it


def part_name(o):
    return o.material_slots[0].material.name.split(".")[0] if o.material_slots and o.material_slots[0].material else o.name


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SRC))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # Bake transforms so bounds and shells are in gun-source space.
    for o in bpy.context.view_layer.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # One object per part, named by its material, as the existing mapping expects (extra pieces such as the
    # bladed tips live inside "Orange" already; loose parts with the same material are joined into it).
    groups = {}
    for o in meshes:
        groups.setdefault(part_name(o), []).append(o)
    parts = []
    for name, objs in groups.items():
        if len(objs) > 1:
            for o in bpy.context.view_layer.objects:
                o.select_set(o in objs)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.object.join()
        obj = objs[0]
        obj.name = obj.data.name = name
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if tris > MAX_PART_TRIS:
            # The lofted tips are dense; keep the part well under Roblox's 20k-per-mesh cap.
            md = obj.modifiers.new("Reduce", "DECIMATE")
            md.ratio, md.use_symmetry, md.symmetry_axis = MAX_PART_TRIS/tris, True, "X"
            for o2 in bpy.context.view_layer.objects:
                o2.select_set(o2 is obj)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=md.name)
        parts.append(obj)
    ink = bpy.data.materials.new("Ink")
    shells = []
    for o in parts:
        if o.name in NO_INK:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bm.normal_update()
        width = INK_WIDTH*(0.7 if o.name in THIN_PARTS else 1.0)
        for v in bm.verts:
            v.co += v.normal*width
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        me = bpy.data.meshes.new(o.name + "_Ink")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(ink)
        shell = bpy.data.objects.new(o.name + "_Ink", me)
        bpy.context.scene.collection.objects.link(shell)
        shells.append(shell)
    specs = []
    for o in parts + shells:
        vs = [v.co for v in o.data.vertices]
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        c, s = (lo + hi)/2, hi - lo
        # Blender +Y (muzzle) / +Z (up) -> gun space X right, Y up, -Z toward the muzzle.
        specs.append({"name": o.name, "centre": [c.x, c.z, -c.y], "size": [s.x, s.z, s.y], "triangles": sum(len(p.vertices) - 2 for p in o.data.polygons)})
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/"mesh-specs.json").write_text(json.dumps(specs, indent=1))
    for o in bpy.context.view_layer.objects:
        o.select_set(o in parts + shells)
    bpy.ops.export_scene.gltf(filepath=str(OUT/"model.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_materials="PLACEHOLDER")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"blaster-look.blend"), copy=True)
    print("BLASTER_EXPORT", len(parts), "parts", len(shells), "ink shells", sum(sp["triangles"] for sp in specs), "triangles")


main()
