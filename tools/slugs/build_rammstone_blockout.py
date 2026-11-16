"""Build Rammstone's silhouette blockout in Blender, with the owner's sheet set up as aligned reference images.

Takes the volume carved from the sheet (tools/slugs/rammstone_blockout_volume.py), gives it three flat colours (rock,
skin, horn; no eyes or detail), places each sheet view on a plane behind the model at the same scale, and renders
orthographic views matching the sheet's front, sides and back pixel for pixel, plus a three-quarter view. Run with
Blender 4.5:

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_rammstone_blockout.py`

Writes assets/source/slugs/models/rammstone/rammstone-blockout.blend and build/slugs/rammstone/blockout/renders/.
Reference planes sit in their own collection, hidden from renders and, when the file opens, from the viewport; show them
in the Outliner to check alignment. The file uses Workbench: view it in Solid with Attribute colour to see the parts.
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

REF = ROOT/"build/slugs/rammstone/reference"
OUT = ROOT/"build/slugs/rammstone/blockout"
BLEND = ROOT/"assets/source/slugs/models/rammstone/rammstone-blockout.blend"
TRIANGLES = 120000
SCALE = 4  # render pixels per sheet pixel
COLOURS = {1: (0.36, 0.035, 0.025), 2: (0.62, 0.33, 0.20), 3: (0.05, 0.045, 0.045)}

# Each view: where the camera sits (unit direction from the model) and which world axis runs to the image's right.
VIEWS = {
    "front": (Vector((0, -1, 0)), Vector((1, 0, 0))),
    "side-left": (Vector((1, 0, 0)), Vector((0, 1, 0))),
    "back": (Vector((0, 1, 0)), Vector((-1, 0, 0))),
    "side-right": (Vector((-1, 0, 0)), Vector((0, -1, 0))),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_mesh(calib):
    data = np.load(OUT/"volume.npz")
    verts, faces, part = data["verts"], data["faces"], data["part"]
    mesh = bpy.data.meshes.new("RammstoneBlockout")
    mesh.from_pydata(verts.tolist(), [], faces.tolist())
    obj = bpy.data.objects.new("RammstoneBlockout", mesh)
    bpy.context.collection.objects.link(obj)
    attr = mesh.attributes.new("part", "INT", "POINT")
    attr.data.foreach_set("value", part.astype(np.int32))
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("Reduce", "DECIMATE")
    mod.ratio = min(1.0, TRIANGLES/len(faces))
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    # Flat colour per part, from the part attribute that decimation carried along.
    part = np.empty(len(mesh.vertices), np.int32)
    mesh.attributes["part"].data.foreach_get("value", part)
    col = np.array([COLOURS.get(int(p), COLOURS[1]) for p in part])
    layer = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    layer.data.foreach_set("color", np.concatenate([col, np.ones((len(col), 1))], -1).astype(np.float32).ravel())
    mat = bpy.data.materials.new("Blockout")
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    node = mat.node_tree.nodes.new("ShaderNodeAttribute")
    node.attribute_name = "Col"
    mat.node_tree.links.new(node.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.8
    mesh.materials.append(mat)
    return obj


def view_frame(name, calib):
    """Camera centre and size so one render pixel block covers one sheet pixel."""
    c = calib[name]
    rows, cols = c["size"]
    toward, right = VIEWS[name]
    across = ((cols - 1)/2 - c["centreColumn"])*calib["pixel"]
    up = (c["baseRow"] - (rows - 1)/2)*calib["pixel"]
    centre = right*across + Vector((0, 0, up))
    return centre, rows, cols


def reference_planes(calib):
    coll = bpy.data.collections.new("Reference")
    bpy.context.scene.collection.children.link(coll)
    for name in VIEWS:
        centre, rows, cols = view_frame(name, calib)
        toward, right = VIEWS[name]
        w, h = cols*calib["pixel"], rows*calib["pixel"]
        mesh = bpy.data.meshes.new(f"Ref-{name}")
        corners = [centre - right*w/2 + Vector((0, 0, -h/2)), centre + right*w/2 + Vector((0, 0, -h/2)),
                   centre + right*w/2 + Vector((0, 0, h/2)), centre - right*w/2 + Vector((0, 0, h/2))]
        # Behind the model as the camera sees it.
        corners = [v - toward*2.5 for v in corners]
        mesh.from_pydata([tuple(v) for v in corners], [], [(0, 1, 2, 3)])
        uv = mesh.uv_layers.new()
        for loop, coord in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop.uv = coord
        img = bpy.data.images.load(str(REF/f"{name}.png"))
        img.pack()
        mat = bpy.data.materials.new(f"Ref-{name}")
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        for n in list(nodes):
            nodes.remove(n)
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        emit = nodes.new("ShaderNodeEmission")
        out = nodes.new("ShaderNodeOutputMaterial")
        links.new(tex.outputs["Color"], emit.inputs["Color"])
        links.new(emit.outputs["Emission"], out.inputs["Surface"])
        # Each plane faces its own camera; from behind (the opposite view) it is culled, so it never hides the model.
        mat.use_backface_culling = True
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(f"Ref-{name}", mesh)
        obj.hide_render = True
        coll.objects.link(obj)


def render(calib, obj):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_shadows = True
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    paths = {}
    for name in VIEWS:
        centre, rows, cols = view_frame(name, calib)
        toward, _ = VIEWS[name]
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = max(rows, cols)*calib["pixel"]
        scene.render.resolution_x, scene.render.resolution_y = cols*SCALE, rows*SCALE
        cam.location = centre + toward*10
        cam.rotation_euler = (-toward).to_track_quat("-Z", "Y").to_euler()
        path = OUT/"renders"/f"{name}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths[name] = path.name
    # Three-quarter, in perspective like the sheet's hero view: the front-left.
    cam.data.type = "PERSP"
    cam.data.lens = 85
    scene.render.resolution_x = scene.render.resolution_y = 900
    scene.render.film_transparent = False
    target = Vector((0, 0, 1.45))
    offset = Vector((-math.sin(0.62), -math.cos(0.62), 0.10))*9.5
    cam.location = target + offset
    cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
    path = OUT/"renders"/"three-quarter.png"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    paths["three-quarter"] = path.name
    bpy.data.objects.remove(cam)
    return paths


def main():
    calib = json.loads((OUT/"calibration.json").read_text())
    reset()
    obj = build_mesh(calib)
    reference_planes(calib)
    renders = render(calib, obj)
    # Open with the references hidden: in Solid view they are blank sheets that block the orbit. One click shows them.
    bpy.context.view_layer.layer_collection.children["Reference"].hide_viewport = True
    obj.data.calc_loop_triangles()
    report = {"tool": bpy.app.version_string, "triangles": len(obj.data.loop_triangles), "renders": renders}
    (OUT/"report.json").write_text(json.dumps(report, indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
