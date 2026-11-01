"""Blender 5.2 build of a lobby asset from tools/lobby/sdf_mesh.py output.

For each material group: build the dense mesh, decimate a game copy with outward normals, unwrap it, bake
a tangent normal map from the dense mesh and a texel-position map of the game mesh, and add an
inverted-hull ink shell at the group's Slugshot mix width (an inflated copy with reversed faces; Roblox
culls back faces, so only the outline shows). tools/lobby/paint_texels.py then paints every texel straight
from the concept shader at its position, so ink lines stay crisp. Exports <key>.glb (Y up, studs).

    blender --background --factory-startup --python tools/lobby/blender_lobby_asset.py -- <key> [budget]
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:]
KEY = ARGS[0]
BUDGET = int(ARGS[1]) if len(ARGS) > 1 else 14000  # game triangles for the whole asset, excluding ink
SRC = (Path("build/lobby/meshes")/KEY).resolve()
OUT = (Path("build/lobby/export")/KEY).resolve()
TEX = 1024
MIN_TRIS, MAX_TRIS = 300, 14000
HARD = {"Crystal", "Iron", "Gem", "Stone"}  # faceted pieces keep sharp edges
SMALL_DETAIL = {"GlowCap", "Stem", "Crystal", "Gem", "Bulb"}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for backend in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = backend
            prefs.get_devices()
        except TypeError:
            continue
        if any(d.type == backend for d in prefs.devices):
            for d in prefs.devices:
                d.use = d.type == backend
            scene.cycles.device = "GPU"
            break


def to_blender(v):
    return np.stack([v[:, 0], -v[:, 2], v[:, 1]], axis=1)  # Y-up studs -> Blender Z-up


def select_only(*objs, active=None):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[-1]


def build_dense(name, data):
    me = bpy.data.meshes.new(name + "_Dense")
    me.from_pydata(to_blender(data["verts"]).tolist(), [], data["faces"].tolist())
    me.validate()
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name + "_Dense", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def orient_like(low, dense):
    """Keep the marching-cubes winding, which faces outward. Blender's "recalculate outside" guesses wrong
    on open pieces (a mushroom cap cut where it meets its stem) and turned whole caps, stems and crystals
    inside out, so Roblox culled them and only their ink showed. Flip any island the dense mesh disagrees
    with instead."""
    tree = BVHTree.FromObject(dense, bpy.context.evaluated_depsgraph_get())
    bm = bmesh.new()
    bm.from_mesh(low.data)
    seen, flipped = set(), 0
    for face in bm.faces:
        if face in seen:
            continue
        island, stack = [], [face]
        seen.add(face)
        while stack:
            f = stack.pop()
            island.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g not in seen:
                        seen.add(g)
                        stack.append(g)
        votes = 0
        for f in island:
            normal = tree.find_nearest(f.calc_center_median())[1]
            votes += 1 if normal is not None and normal.dot(f.normal) > 0 else -1
        if votes < 0:
            bmesh.ops.reverse_faces(bm, faces=island)
            flipped += 1
    bm.to_mesh(low.data)
    bm.free()
    return flipped


def make_low(dense, name, target):
    low = dense.copy()
    low.data = dense.data.copy()
    low.name = low.data.name = name
    bpy.context.scene.collection.objects.link(low)
    faces = len(low.data.polygons)
    if target < faces:
        md = low.modifiers.new("Decimate", "DECIMATE")
        md.ratio = target/faces
        md.use_collapse_triangulate = True
        select_only(low)
        bpy.ops.object.modifier_apply(modifier=md.name)
    flipped = orient_like(low, dense)
    if flipped:
        print(f"{name}: re-oriented {flipped} islands")
    select_only(low)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    for p in low.data.polygons:
        p.use_smooth = True
    if name in HARD:
        low.data.set_sharp_from_angle(angle=math.radians(35))
    return low


def node_material(name, build):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    build(nt, em)
    return mat


def bake_target(low, image):
    mat = bpy.data.materials.new(f"Target_{low.name}_{image.name}")
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    mat.node_tree.nodes.active = node
    return mat


def bake_normal(dense, low):
    img = bpy.data.images.new(f"{low.name}_normal", TEX, TEX, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    low.data.materials.clear()
    low.data.materials.append(bake_target(low, img))
    select_only(dense, low, active=low)
    extent = max(dense.dimensions)*0.01 + 0.08
    bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=extent,
                        max_ray_distance=extent*2, normal_space="TANGENT", margin=8)
    img.filepath_raw = str(OUT/"textures"/f"{low.name}-normal.png")
    img.file_format = "PNG"
    img.save()


def bake_positions(low):
    """World position of every texel (alpha 1 where the mesh covers it), for per-texel painting."""
    img = bpy.data.images.new(f"{low.name}_pos", TEX, TEX, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels[:] = np.zeros(TEX*TEX*4, dtype="f4")  # alpha 0 marks texels the mesh does not cover

    def build(nt, em):
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        nt.links.new(geo.outputs["Position"], em.inputs["Color"])
    low.data.materials.clear()
    low.data.materials.append(node_material(f"Pos_{low.name}", build))
    tgt = bake_target(low, img)
    low.data.materials.append(tgt)
    low.data.materials[0].node_tree.nodes.new("ShaderNodeTexImage").image = img
    nt = low.data.materials[0].node_tree
    nt.nodes.active = [n for n in nt.nodes if n.type == "TEX_IMAGE"][0]
    low.data.materials.pop(index=1)
    select_only(low)
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=False, margin=0)
    px = np.array(img.pixels[:], dtype="f4").reshape(TEX, TEX, 4)
    np.save(OUT/"textures"/f"{low.name}-pos.npy", px)


def ink_shell(low, width):
    bm = bmesh.new()
    bm.from_mesh(low.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal*width
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    me = bpy.data.meshes.new(low.name + "_Ink")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(low.name + "_Ink", me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.get("Ink") or bpy.data.materials.new("Ink")
    mat.diffuse_color = (0.006, 0.006, 0.008, 1)
    me.materials.append(mat)
    return obj


def main():
    reset()
    meta = json.loads((SRC/"meta.json").read_text())
    (OUT/"textures").mkdir(parents=True, exist_ok=True)
    total = sum(g["faces"] for g in meta["groups"])
    report = {"key": KEY, "groups": []}
    exports = []
    for g in meta["groups"]:
        name = g["name"]
        dense = build_dense(name, np.load(SRC/f"{name}.npz"))
        target = int(min(MAX_TRIS, max(MIN_TRIS, BUDGET*g["faces"]/total)))
        if name in SMALL_DETAIL:
            # Many small pieces share one mesh: never crush them below a quarter of their dense detail.
            target = max(target, int(min(g["faces"]*0.25, 4000)))
        low = make_low(dense, name, target)
        bake_normal(dense, low)
        bake_positions(low)
        mat = bpy.data.materials.new(name)
        low.data.materials.clear()
        low.data.materials.append(mat)
        exports.append(low)
        entry = {"name": name, "id": g["id"], "tris": len(low.data.polygons), "ink": g["ink"],
                 "normal": f"textures/{name}-normal.png", "positions": f"textures/{name}-pos.npy"}
        if g["ink"] > 0:
            exports.append(ink_shell(low, g["ink"]))
            entry["inkShell"] = name + "_Ink"
        report["groups"].append(entry)
        dense.hide_set(True)
        dense.hide_render = True
        print(f"{name}: {entry['tris']} tris")
    select_only(*exports)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f"{KEY}.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_materials="PLACEHOLDER")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f"{KEY}.blend"))
    (OUT/"build.json").write_text(json.dumps(report, indent=1))
    print("LOBBY_ASSET_DONE", OUT)


main()
