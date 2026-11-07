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
from mathutils import Vector, geometry

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


def build_plate(name, data):
    """The flat walkable top: triangulated from the rim and crack outlines, keeping only what is solid."""
    points = [Vector(p) for p in data["plateVerts"].tolist()]
    edges = [tuple(e) for e in data["plateEdges"].tolist()]
    coords, _, faces, _, _, _ = geometry.delaunay_2d_cdt(points, edges, [], 0, 1e-5)
    field, lo, step = data["plateField"], data["plateLo"], float(data["plateStep"])
    verts = np.array([(c.x, 13.0, c.y) for c in coords], "f4")
    kept = []
    for face in faces:
        for i in range(1, len(face) - 1):
            a, b, c = face[0], face[i], face[i + 1]
            mid = (verts[a] + verts[b] + verts[c])/3
            ix = int(round((mid[0] - lo[0])/step))
            iz = int(round((mid[2] - lo[1])/step))
            if not (0 <= ix < field.shape[0] and 0 <= iz < field.shape[1]) or field[ix, iz] >= 0:
                continue
            up = np.cross(verts[b] - verts[a], verts[c] - verts[a])[1]
            kept.append((a, b, c) if up > 0 else (a, c, b))
    used, remap = np.unique(np.array(kept, "i4"), return_inverse=True)
    low = base.build_dense(name, {"verts": verts[used], "faces": remap.reshape(-1, 3)})
    low.name = low.data.name = name
    print(f"{name}: plate of {len(kept)} triangles", flush=True)
    return low


def repack(obj):
    """Pack the islands by their real outlines, turned to fit: smart projection's box packing left about 40% of a map
    empty on a big faceted piece, at a 1024 cap that matters."""
    base.select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(shape_method="CONCAVE", rotate=True, margin_method="FRACTION", margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")


def tile_uv(obj, size):
    """Straight down in world space, repeating every `size` units, so a small map stays crisp over a big area."""
    mesh = obj.data
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (co.x/size, co.y/size)


def planar_uv(obj, half, upright=False):
    """Straight down (or straight on, for an upright sheet), so a round surface has no seams in its maps."""
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (0.5 + 0.5*co.x/half, 0.5 + 0.5*(co.z if upright else co.y)/half)
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
    lantern_groups = {}
    for obj in objects:
        rigid = obj.name.startswith("Deck")
        if obj.name.startswith("Lantern"):
            # Each lantern is one solid thing, on the bone nearest its own middle.
            centres = np.array((-5.4, 0.7, 5.6))*scale
            for v in obj.data.vertices:
                centre = centres[np.argmin(np.abs(centres - v.co.x))]
                pick = int(np.clip(round((centre - xs[0])/gap), 0, BONES - 1))
                if pick not in lantern_groups:
                    lantern_groups[pick] = obj.vertex_groups.new(name=f"B{pick}")
                lantern_groups[pick].add([v.index], 1.0, "REPLACE")
            modifier = obj.modifiers.new("Rig", "ARMATURE")
            modifier.object = arm
            obj.parent = arm
            lantern_groups = {}
            continue
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
        if g.get("shell"):
            # A smoother form than the one baked onto it.
            shell_form = base.build_dense(name + "_Shell", {"verts": data["shellVerts"], "faces": data["shellFaces"]})
            low = decimated(shell_form, name, g["tris"], g["hard"])
            bpy.data.objects.remove(shell_form)
            bpy.context.view_layer.update()
        elif g.get("authored"):
            low = base.build_dense(name, {"verts": data["lowVerts"], "faces": data["lowFaces"]})
            low.name = low.data.name = name
            planar_uv(low, 19.0, g.get("upright"))
        elif g.get("plate"):
            low = build_plate(name, data)
            planar_uv(low, 8.8)
        elif g.get("flat"):
            # Straight-down maps: island seams in an alpha texture drew hard square patches in the storm.
            low = base.build_dense(name, {"verts": data["verts"], "faces": data["faces"]})
            low.name = low.data.name = name
            planar_uv(low, g["half"])
        else:
            low = decimated(dense, name, g["tris"], g["hard"])
        if meta.get("pack") and not g.get("tile"):
            repack(low)
        if g.get("tile"):
            tile_uv(low, g["tile"])
        elif not g.get("flat"):
            base.bake_normal(dense, low, g["cage"])
        if not g.get("tile"):
            base.bake_positions(low)
        low.data.materials.clear()
        low.data.materials.append(bpy.data.materials.new(name))
        exports.append(low)
        entry = {"name": name, "tris": len(low.data.polygons), "tex": g["tex"], "positions": f"textures/{name}-pos.npy", "tile": g.get("tile")}
        if not g.get("flat"):
            entry["normal"] = f"textures/{name}-normal.png"
        if g["ink"] > 0:
            shell = welded_shell(low, g["ink"], 1.0)
            exports.append(shell)
            entry["inkShell"] = shell.name
            entry["inkTris"] = len(shell.data.polygons)
        # Where the part belongs in studs, Y up, for placing it in Roblox.
        # From what is exported, because the game fits a piece by these: anything else moves it off what stands on it.
        coords = np.zeros(len(low.data.vertices)*3)
        low.data.vertices.foreach_get("co", coords)
        coords = coords.reshape(-1, 3)
        verts = (np.stack([coords[:, 0], coords[:, 2], -coords[:, 1]], axis=1) - np.array(origin))*scale
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
