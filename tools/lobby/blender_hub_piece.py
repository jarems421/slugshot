"""Blender 5.2 build of a hub piece from tools/lobby/hub_mesh.py output.

Works like tools/lobby/blender_lobby_asset.py and shares its bakes, with a budget, texture size and ink shell per part.
The mesh stays in shader units while baking, so the painter can read positions straight back into the concept shader,
then converts to studs for export. The bridge is also skinned, so it can sway and dip on one set of bones.

    blender --background --factory-startup --python tools/lobby/blender_hub_piece.py -- <key>
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import blender_lobby_asset as base  # noqa: E402

KEY = base.KEY
SRC = base.SRC
OUT = base.OUT
BONES = 17
RIG_SPAN = 10.6


def decimated(dense, name, target, hard):
    low = base.make_low(dense, name, target)
    if hard:
        low.data.set_sharp_from_angle(angle=math.radians(35))
    return low


def welded_shell(low, width, ratio):
    """Ink shell, optionally from a lighter copy of the part: an outline doesn't need the full shape."""
    source = low
    if ratio < 0.999:
        source = low.copy()
        source.data = low.data.copy()
        source.name = low.name + "_InkSource"
        bpy.context.scene.collection.objects.link(source)
        md = source.modifiers.new("Decimate", "DECIMATE")
        md.ratio = ratio
        base.select_only(source)
        bpy.ops.object.modifier_apply(modifier=md.name)
    shell = base.ink_shell(source, width)
    shell.name = shell.data.name = low.name + "_Ink"
    if source is not low:
        bpy.data.objects.remove(source)
        bpy.context.view_layer.update()
    return shell


def to_studs(obj, scale, origin):
    """Shader units to studs, about the piece's origin. Blender is Z up with Y = -z."""
    mesh = obj.data
    co = np.empty(len(mesh.vertices)*3, dtype="f8")
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    co -= np.array([origin[0], -origin[2], origin[1]])
    co *= scale
    mesh.vertices.foreach_set("co", co.ravel())
    mesh.update()


def planar_uv(obj, half):
    """Straight down, so a round surface has no seams in its maps."""
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (0.5 + 0.5*co.x/half, 0.5 + 0.5*co.y/half)
    for p in mesh.polygons:
        p.use_smooth = True


def add_bridge_rig(objects, scale):
    """Flat chain of bones along the bridge. Planks are rigid on their nearest bone so each moves as a board; ropes
    blend between neighbours so they stay smooth. Bone names are read by HubMotion.client on the Roblox side."""
    arm_data = bpy.data.armatures.new("BridgeRig")
    arm = bpy.data.objects.new("BridgeRig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    base.select_only(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    xs = np.linspace(-RIG_SPAN, RIG_SPAN, BONES)*scale
    for i, x in enumerate(xs):
        bone = arm_data.edit_bones.new(f"B{i}")
        bone.head = (float(x), 0.0, 0.0)
        bone.tail = (float(x), 0.0, 1.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    gap = xs[1] - xs[0]
    for obj in objects:
        rigid = obj.name.startswith("Deck")
        groups = [obj.vertex_groups.new(name=f"B{i}") for i in range(BONES)]
        for v in obj.data.vertices:
            t = (v.co.x - xs[0])/gap
            if rigid:
                groups[int(np.clip(round(t), 0, BONES - 1))].add([v.index], 1.0, "REPLACE")
            else:
                i = int(np.clip(math.floor(t), 0, BONES - 2))
                f = float(np.clip(t - i, 0.0, 1.0))
                groups[i].add([v.index], 1.0 - f, "REPLACE")
                groups[i + 1].add([v.index], f, "REPLACE")
        modifier = obj.modifiers.new("Rig", "ARMATURE")
        modifier.object = arm
        obj.parent = arm
    return arm


def main():
    base.reset()
    meta = json.loads((SRC/"meta.json").read_text())
    (OUT/"textures").mkdir(parents=True, exist_ok=True)
    scale, origin = meta["scale"], meta["origin"]
    report = {"key": KEY, "scale": scale, "groups": []}
    exports = []
    for g in meta["groups"]:
        name = g["name"]
        base.TEX = g["tex"]
        data = np.load(SRC/f"{name}.npz")
        dense = base.build_dense(name, data)
        if g.get("authored"):
            low = base.build_dense(name, {"verts": data["lowVerts"], "faces": data["lowFaces"]})
            low.name = low.data.name = name
            planar_uv(low, 19.0)
        elif g.get("flat"):
            # Straight-down maps: island seams in an alpha texture drew hard square patches in the storm.
            low = base.build_dense(name, {"verts": data["verts"], "faces": data["faces"]})
            low.name = low.data.name = name
            planar_uv(low, 9.5)
        else:
            low = decimated(dense, name, g["tris"], g["hard"])
        if not g.get("flat"):
            base.bake_normal(dense, low, g["cage"])
        base.bake_positions(low)
        low.data.materials.clear()
        low.data.materials.append(bpy.data.materials.new(name))
        exports.append(low)
        entry = {"name": name, "tris": len(low.data.polygons), "tex": g["tex"], "positions": f"textures/{name}-pos.npy"}
        if not g.get("flat"):
            entry["normal"] = f"textures/{name}-normal.png"
        if g["ink"] > 0:
            shell = welded_shell(low, g["ink"], 1.0)
            exports.append(shell)
            entry["inkShell"] = shell.name
            entry["inkTris"] = len(shell.data.polygons)
        # Where the part belongs in studs, Y up, for placing it in Roblox.
        verts = (data["verts"] - np.array(origin))*scale
        entry["boundsMin"] = verts.min(axis=0).tolist()
        entry["boundsMax"] = verts.max(axis=0).tolist()
        report["groups"].append(entry)
        bpy.data.objects.remove(dense)
        bpy.context.view_layer.update()
        print(f"{name}: {entry['tris']} tris, ink {entry.get('inkTris', 0)}", flush=True)
    for obj in exports:
        to_studs(obj, scale, origin)
    select = list(exports)
    if meta.get("rig") == "bridge":
        select.append(add_bridge_rig(exports, scale))
    base.select_only(*select)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f"{KEY}.glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="PLACEHOLDER", export_skins=True,
                              export_animations=False)
    (OUT/"build.json").write_text(json.dumps(report, indent=1))
    print("HUB_PIECE_DONE", OUT, flush=True)


main()
