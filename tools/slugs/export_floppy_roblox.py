"""Make the Roblox version of Floppy from assets/source/slugs/models/floppy/floppy.blend.

Device budget: one 8,000-triangle skinned body and two 400-triangle eyes,
1024 colour and normal maps (baked from the full-detail source), at most four
bone influences per vertex. Roblox bones animate by CFrame only, so the idle's
breathing scale becomes small translations. The model is turned to face +Y so
the project's FBX settings deliver Roblox's -Z forward; 1 Blender unit = 1 stud.

Run with Blender 4.5:
`blender --background --factory-startup --disable-autoexec --python-exit-code 1
--python tools/slugs/export_floppy_roblox.py`

Writes build/slugs/floppy/roblox/: model.fbx, model.glb, idle.fbx, textures/, a review
.blend and export-report.json. Nothing is uploaded.
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT
from blender_pipeline import EXPORT_SETTINGS

SOURCE = ROOT/"assets/source/slugs/models/floppy/floppy.blend"
OUT = ROOT/"build/slugs/floppy/roblox"
BODY_TRIANGLES = 8000
EYE_TRIANGLES = 400
TEXTURE = 1024
# Slugs are about 1 stud tall in Roblox so they read clearly; the blaster is
# resized to fit them (owner, 2026-10-31); then a third smaller, mostly by a narrower base. Source height 2.47 -> ~0.75 studs.
GAME_SCALE = 0.34
# Low roughness for a wet, slimy gloss: wettest low on the body, where it
# sits in its own slime, a touch less shiny on the head; eyes glossier still.
SKIN_ROUGHNESS_LOW = 0.10
# A little taller but no thicker (owner): stretch only the torso, below the
# face, so the head, eyes and width are unchanged. Source units.
TORSO_STRETCH = 0.25
STRETCH_TOP = 1.25
SKIN_ROUGHNESS = 0.22
EYE_ROUGHNESS = 0.08
FPS = 24
LOOP_SECONDS = 12.0


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def reduce(obj, target):
    select_only([obj])
    mod = obj.modifiers.new("Reduce", "DECIMATE")
    mod.ratio = min(1.0, target/triangles(obj))
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def low_copy(high, name, target):
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    bpy.context.collection.objects.link(low)
    reduce(low, target)
    select_only([low])
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    return low


def image(name, colorspace, alpha=False):
    img = bpy.data.images.new(name, TEXTURE, TEXTURE, alpha=alpha, float_buffer=False)
    img.colorspace_settings.name = colorspace
    return img


def bake_to(low, high, kind, target, high_material=None):
    """Bake from the full-detail body onto the game body's own UVs."""
    bake_mat = bpy.data.materials.new("Bake")
    bake_mat.use_nodes = True
    node = bake_mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = target
    bake_mat.node_tree.nodes.active = node
    low.data.materials.clear()
    low.data.materials.append(bake_mat)
    saved = list(high.data.materials)
    if high_material:
        high.data.materials.clear()
        high.data.materials.append(high_material)
    select_only([high, low], active=low)
    bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=0.02, max_ray_distance=0.08,
                        normal_space="TANGENT", margin=8)
    high.data.materials.clear()
    for m in saved:
        high.data.materials.append(m)
    low.data.materials.clear()
    bpy.data.materials.remove(bake_mat)


def emission_of(material):
    """A copy of the skin material that emits its colour texture, for colour baking."""
    tex = next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    mat = bpy.data.materials.new("BakeColour")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    t = nodes.new("ShaderNodeTexImage")
    t.image = tex.image
    e = nodes.new("ShaderNodeEmission")
    o = nodes.new("ShaderNodeOutputMaterial")
    links.new(t.outputs["Color"], e.inputs["Color"])
    links.new(e.outputs["Emission"], o.inputs["Surface"])
    return mat


def save(img, name):
    path = OUT/"textures"/name
    path.parent.mkdir(parents=True, exist_ok=True)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    return path


def roughness_map(name, value):
    """glTF metallic-roughness texture: roughness in G, metalness (0) in B."""
    img = bpy.data.images.new(name, 64, 64, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.tile([1.0, value, 0.0, 1.0], 64*64).astype(np.float32))
    save(img, name + ".png")
    return img


def body_roughness_map(body):
    """Roughness by height on the body's own UVs: glossiest at the base, rising toward the head."""
    co = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("co", co)
    z = co.reshape(-1, 3)[:, 2]
    t = np.clip((z - 0.35)/(1.5 - 0.35), 0.0, 1.0)
    rough = SKIN_ROUGHNESS_LOW + (SKIN_ROUGHNESS - SKIN_ROUGHNESS_LOW)*t*t*(3 - 2*t)
    attr = body.data.color_attributes.new("gloss", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.stack([np.ones_like(rough), rough, np.zeros_like(rough), np.ones_like(rough)], 1).astype(np.float32).ravel())
    target = image("floppy-body-roughness", "Non-Color")
    mat = bpy.data.materials.new("BakeGloss")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    a = nodes.new("ShaderNodeAttribute")
    a.attribute_name = "gloss"
    e = nodes.new("ShaderNodeEmission")
    o = nodes.new("ShaderNodeOutputMaterial")
    links.new(a.outputs["Color"], e.inputs["Color"])
    links.new(e.outputs["Emission"], o.inputs["Surface"])
    node = nodes.new("ShaderNodeTexImage")
    node.image = target
    nodes.active = node
    saved = list(body.data.materials)
    body.data.materials.clear()
    body.data.materials.append(mat)
    select_only([body])
    bpy.ops.object.bake(type="EMIT", margin=8)
    body.data.materials.clear()
    for m in saved:
        body.data.materials.append(m)
    bpy.data.materials.remove(mat)
    body.data.color_attributes.remove(body.data.color_attributes["gloss"])
    save(target, "floppy-body-roughness.png")
    return target


def add_gloss(mat, img):
    """Wire a roughness map so the glTF export (and Roblox SurfaceAppearance) carries the gloss."""
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    split = nodes.new("ShaderNodeSeparateColor")
    links.new(tex.outputs["Color"], split.inputs["Color"])
    links.new(split.outputs["Green"], shader.inputs["Roughness"])
    links.new(split.outputs["Blue"], shader.inputs["Metallic"])


def game_skin_material(colour, normal, rough):
    mat = bpy.data.materials.new("FloppySkin")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    c = nodes.new("ShaderNodeTexImage")
    c.image = colour
    n = nodes.new("ShaderNodeTexImage")
    n.image = normal
    nm = nodes.new("ShaderNodeNormalMap")
    links.new(c.outputs["Color"], shader.inputs["Base Color"])
    links.new(n.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], shader.inputs["Normal"])
    add_gloss(mat, rough)
    return mat


def roblox_idle(rig):
    """Copy of Idle with no bone scale: breathing becomes a gentle rise of the body and head."""
    source = bpy.data.actions["Idle"]
    source.name = "IdleSource"
    action = source.copy()
    action.name = "Idle"
    breath_w = 3*math.tau/LOOP_SECONDS
    for fc in list(action.fcurves):
        if fc.data_path.endswith(".scale"):
            action.fcurves.remove(fc)
        elif fc.data_path.endswith(".location"):
            for kp in fc.keyframe_points:
                kp.co[1] *= GAME_SCALE
            fc.update()
    for bone, amount in (("body_upper", 0.010), ("head", 0.005)):
        fc = action.fcurves.find(f'pose.bones["{bone}"].location', index=1)
        for kp in fc.keyframe_points:
            t = (kp.co[0] - 1)/FPS
            kp.co[1] = GAME_SCALE*amount*math.sin(t*breath_w)
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
        fc.update()
    rig.animation_data.action = action
    return action


def taller(z):
    """Height map: the torso below STRETCH_TOP grows by TORSO_STRETCH, everything above moves up rigidly."""
    t = np.clip((z - 0.05)/(STRETCH_TOP - 0.05), 0.0, 1.0)
    return z + TORSO_STRETCH*t*t*(3 - 2*t)


def stretch_torso(rig, meshes):
    for m in meshes:
        co = np.empty(len(m.data.vertices)*3)
        m.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        co[:, 2] = taller(co[:, 2])
        m.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
        m.data.update()
    select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    for b in rig.data.edit_bones:
        b.head.z, b.tail.z = float(taller(b.head.z)), float(taller(b.tail.z))
    bpy.ops.object.mode_set(mode="OBJECT")


def scale_to_blaster(rig, meshes):
    """Apply GAME_SCALE to mesh and bones; bone translations in the idle are scaled in roblox_idle."""
    for m in meshes:
        select_only([m])
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in [rig] + meshes:
        o.scale = (GAME_SCALE,)*3
    select_only([rig] + meshes, active=rig)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for m in meshes:
        m.parent = rig


def face_plus_y(rig, meshes):
    """Turn the model 180 degrees so the project FBX settings give Roblox -Z forward."""
    for m in meshes:
        select_only([m])
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in [rig] + meshes:
        o.rotation_euler = (0, 0, math.pi)
    select_only([rig] + meshes, active=rig)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    for m in meshes:
        m.parent = rig


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(model, idle, expected_bones):
    """Reimport both files and check what Roblox will receive."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(model), automatic_bone_orientation=False)
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bones = sorted(b.name for b in rig.data.bones)
    assert bones == sorted(expected_bones), f"bones changed: {bones}"
    report = {"bones": bones, "meshes": {}}
    for m in meshes:
        influences = max(len([g for g in v.groups if g.weight > 1e-5]) for v in m.data.vertices)
        normalised = all(abs(sum(g.weight for g in v.groups) - 1) < 0.002 for v in m.data.vertices)
        assert influences <= 4 and normalised, f"bad skin weights on {m.name}"
        report["meshes"][m.name] = {"triangles": triangles(m), "maxInfluences": influences}
    xs = [(m.matrix_world @ v.co) for m in meshes for v in m.data.vertices]
    lo = [min(c[i] for c in xs) for i in range(3)]
    hi = [max(c[i] for c in xs) for i in range(3)]
    report["boundsBlender"] = {"min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi]}
    face = [c for m in meshes if m.name.startswith("Eye") for c in [m.matrix_world @ v.co for v in m.data.vertices]]
    report["facesPlusY"] = sum(c.y for c in face)/len(face) > 0
    report["heightStuds"] = round(hi[2] - lo[2], 3)
    assert 0.88 <= report["heightStuds"] <= 0.97, f"Floppy should be about 0.93 studs tall: {report['heightStuds']}"
    report["sizeStuds"] = [round(hi[i] - lo[i], 3) for i in range(3)]
    assert report["facesPlusY"], "eyes are not on the +Y side"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(idle), automatic_bone_orientation=False)
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    action = rig.animation_data.action
    start, end = action.frame_range
    scene = bpy.context.scene
    scene.frame_set(int(start))
    first = [b.matrix.copy() for b in rig.pose.bones]
    motion, scale_drift = 0.0, 0.0
    for f in range(int(start), int(end) + 1, 12):
        scene.frame_set(f)
        motion = max(motion, max((a.translation - b.matrix.translation).length for a, b in zip(first, rig.pose.bones)))
        scale_drift = max(scale_drift, max(abs(s - 1) for b in rig.pose.bones for s in b.matrix_basis.to_scale()))
    scene.frame_set(int(end))
    seam = max(abs(a[i][j] - b.matrix[i][j]) for a, b in zip(first, rig.pose.bones) for i in range(4) for j in range(4))
    assert seam < 1e-3 and scale_drift < 1e-4 and motion > 0.002, (seam, scale_drift, motion)
    report["idle"] = {"seconds": round((end - start)/FPS, 3), "loopSeam": round(seam, 6),
                      "maxBoneScaleChange": round(scale_drift, 6), "maxBoneTravel": round(motion, 4)}
    return report


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    rig = bpy.data.objects["FloppyRig"]
    rig.animation_data.action = None
    for b in rig.pose.bones:
        b.matrix_basis.identity()
    high = bpy.data.objects["FloppyBody"]
    high.name = "FloppyBody_Source"
    skin = high.data.materials[0]

    body = low_copy(high, "FloppyBody", BODY_TRIANGLES)
    select_only([body])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    colour = image("floppy-body-color", "sRGB")
    normal = image("floppy-body-normal", "Non-Color")
    bake_to(body, high, "EMIT", colour, emission_of(skin))
    bake_to(body, high, "NORMAL", normal)
    paths = [save(colour, "floppy-body-color.png"), save(normal, "floppy-body-normal.png")]
    body.data.materials.append(game_skin_material(colour, normal, body_roughness_map(body)))

    eyes = []
    for tag in ("L", "R"):
        src = bpy.data.objects["Eye" + tag]
        src.name = "Eye" + tag + "_Source"
        eye = low_copy(src, "Eye" + tag, EYE_TRIANGLES)
        eye.data.materials[0] = eye.data.materials[0].copy()
        tex = next(n for n in eye.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE").image
        paths.append(save(tex, tex.name + ".png"))
        add_gloss(eye.data.materials[0], roughness_map("floppy-eye-roughness-" + tag, EYE_ROUGHNESS))
        eyes.append(eye)
    for name in ("FloppyBody_Source", "EyeL_Source", "EyeR_Source"):
        bpy.data.objects.remove(bpy.data.objects[name])

    meshes = [body] + eyes
    stretch_torso(rig, meshes)
    face_plus_y(rig, meshes)
    scale_to_blaster(rig, meshes)
    idle = roblox_idle(rig)
    for b in rig.pose.bones:
        b.matrix_basis.identity()
    OUT.mkdir(parents=True, exist_ok=True)
    settings = dict(EXPORT_SETTINGS, path_mode="COPY", embed_textures=True)
    select_only([rig] + meshes, active=rig)
    rig.animation_data.action = None
    model = OUT/"model.fbx"
    bpy.ops.export_scene.fbx(filepath=str(model), bake_anim=False, **settings)
    rig.animation_data.action = idle
    scene.frame_start, scene.frame_end = 1, int(LOOP_SECONDS*FPS) + 1
    idle_path = OUT/"idle.fbx"
    bpy.ops.export_scene.fbx(filepath=str(idle_path), bake_anim=True, **dict(EXPORT_SETTINGS))
    # GLB carries the textures and skin reliably for Open Cloud upload; glTF's
    # +Z-forward conversion of this +Y-facing model gives Roblox -Z forward.
    rig.animation_data.action = None
    for b in rig.pose.bones:
        b.matrix_basis.identity()
    select_only([rig] + meshes, active=rig)
    glb = OUT/"model.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"floppy-roblox.blend"), compress=True)
    bones = [b.name for b in rig.data.bones]

    report = {"source": str(SOURCE.relative_to(ROOT)), "sourceSha256": digest(SOURCE), "tool": bpy.app.version_string,
              "units": "1 Blender unit = 1 stud", "axes": {"blender": "+Y forward, +Z up", "fbx": "-Z forward, +Y up"},
              "budget": {"bodyTriangles": BODY_TRIANGLES, "eyeTriangles": EYE_TRIANGLES, "texture": TEXTURE, "maxInfluences": 4},
              "gameScale": GAME_SCALE, "torsoStretch": TORSO_STRETCH, "roughness": {"skinBase": SKIN_ROUGHNESS_LOW, "skinHead": SKIN_ROUGHNESS, "eyes": EYE_ROUGHNESS},
              "files": {p.relative_to(OUT).as_posix(): digest(p) for p in [model, idle_path, glb] + paths},
              "studioImportVerified": False}
    report.update(verify(model, idle_path, bones))
    (OUT/"export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
