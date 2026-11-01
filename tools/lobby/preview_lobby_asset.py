"""Render the game-ready lobby asset (as exported for Roblox) to check it against the library concept.

Opens build/lobby/export/<key>/<key>.blend, applies the baked maps the way Roblox will (colour, normal,
emission mask times strength) with back-face-culled ink shells, and renders a three-quarter and a front
view under dim cavern light to build/lobby/export/<key>/preview_*.png.

    blender --background --python tools/lobby/preview_lobby_asset.py -- <key>
"""

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

KEY = sys.argv[sys.argv.index("--") + 1]
OUT = (Path("build/lobby/export")/KEY).resolve()
bpy.ops.wm.open_mainfile(filepath=str(OUT/f"{KEY}.blend"))
report = json.loads((OUT/"build.json").read_text())
scene = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.view_settings.view_transform = "AgX"
scene.render.resolution_x, scene.render.resolution_y = 900, 700

for o in list(scene.objects):
    if o.name.endswith("_Dense"):
        bpy.data.objects.remove(o)


def textured(name, g):
    mat = bpy.data.materials.new("Preview_" + name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.7
    col = nt.nodes.new("ShaderNodeTexImage")
    col.image = bpy.data.images.load(str(OUT/g["color"]))
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = bpy.data.images.load(str(OUT/g["normal"]))
    nrm.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if "emit" in g:
        em = nt.nodes.new("ShaderNodeTexImage")
        em.image = bpy.data.images.load(str(OUT/g["emit"]))
        em.image.colorspace_settings.name = "Non-Color"
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
        mul.inputs["Factor"].default_value = 1.0
        nt.links.new(col.outputs["Color"], next(s for s in mul.inputs if s.identifier == "A_Color"))
        nt.links.new(em.outputs["Color"], next(s for s in mul.inputs if s.identifier == "B_Color"))
        nt.links.new(next(s for s in mul.outputs if s.identifier == "Result_Color"), bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = g.get("emissiveStrength", 1.0)
    return mat


ink = bpy.data.materials.new("PreviewInk")
ink.use_backface_culling = True
ink.diffuse_color = (0.006, 0.006, 0.008, 1)
ink.use_nodes = True
b = next(n for n in ink.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
b.inputs["Base Color"].default_value = (0.006, 0.006, 0.008, 1)
b.inputs["Roughness"].default_value = 1.0
for g in report["groups"]:
    obj = scene.objects[g["name"]]
    obj.data.materials.clear()
    obj.data.materials.append(textured(g["name"], g))
    if "inkShell" in g:
        shell = scene.objects[g["inkShell"]]
        shell.data.materials.clear()
        shell.data.materials.append(ink)

world = bpy.data.worlds.new("Cave")
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.03, 0.035, 0.06, 1)
scene.world = world
lo = Vector((1e9,)*3); hi = Vector((-1e9,)*3)
for o in scene.objects:
    if o.type == "MESH":
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
centre, size = (lo + hi)/2, max(hi - lo)
key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
key.data.energy, key.data.color = 2.5, (0.75, 0.82, 1.0)
key.rotation_euler = (math.radians(35), 0, math.radians(-30))
scene.collection.objects.link(key)
warm = bpy.data.objects.new("Warm", bpy.data.lights.new("Warm", "POINT"))
warm.data.energy, warm.data.color = 60*size*size, (1.0, 0.6, 0.3)
warm.location = centre + Vector((-size, -size, size*0.3))
scene.collection.objects.link(warm)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
for name, yaw in (("threequarter", -0.65), ("front", 0.0)):
    d = size*1.9
    # Blender front is -Y (Roblox -Z).
    cam.location = centre + Vector((math.sin(yaw)*d, -math.cos(yaw)*d, size*0.45))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(OUT/f"preview_{name}.png")
    bpy.ops.render.render(write_still=True)
print("PREVIEW_DONE")
