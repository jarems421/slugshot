"""Export Rammstone's two final forms for Roblox: one skinned game mesh per form, baked maps, separate glowing eyes.

Owner, 2026-11-13: "finalize this as the transform design... the next step would be to build it in Studio", then "do it
all". The final models are left untouched: each form is read from its source .blend (base:
assets/source/slugs/models/rammstone/rammstone-clean.blend; transformed: rammstone-transformed.blend, its rest pose).

For each form:
- every part is evaluated (bevels applied) into one high-detail mesh; a copy is reduced to under Roblox's 20,000
  triangles a mesh, the face kept finer, and unwrapped;
- colour, glow, contact shading and facet normals are baked from the high mesh onto it; anything that glows carries
  its glow colour, as Roblox's emission is surface colour times the mask;
- the cracked eyes stay their own meshes with their own sharp maps;
- it is skinned to a small game rig: root, body and head for the base form (its idle sways and nods); Body, Tail and
  each arm's upper arm and forearm for the transformed form, as in its preview rig, so the punch can be played;
- it is turned to face +Y (Roblox -Z after the export) and scaled to the game (base body about 0.95 studs tall), and
  written as GLB with a report.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/export_rammstone_roblox.py [-- base transformed]`

Writes build/slugs/rammstone/roblox/{base,transformed}/: model.glb, textures/, export-report.json, renders/.
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
import export_floppy_roblox as ef

SOURCE = ROOT/"assets/source/slugs/models/rammstone"
BUILD = ROOT/"build/slugs/rammstone/roblox"
GAME_SCALE = 0.47  # base body (2.02 tall without horns) about 0.95 studs, Floppy's reference height
TEXTURE, EYE_TEXTURE = 2048, 512
BODY_TRIANGLES = 18500  # the game mesh, under Roblox's 20,000 a mesh
EYE_TRIANGLES = 600
GLOW_STRENGTH = 2.5
ROUGHNESS = 0.55
FORMS = {
    "base": ("rammstone-clean.blend", "RammstoneBody", "rammstone-base"),
    "transformed": ("rammstone-transformed.blend", "RammstoneTransformedBody", "rammstone-transformed"),
}
# Game rigs: (name, head, tail, parent) in source units. The transformed form's match its preview rig.
BASE_BONES = (("root", (0, 0, 0), (0, 0, 0.35), None), ("body", (0, 0, 0.35), (0, 0, 1.05), "root"),
              ("head", (0, 0, 1.05), (0, 0, 1.95), "body"))
TRANSFORMED_BONES = (("Body", (0, 0.6, 1.3), (0, 0.6, 1.9), None), ("Tail", (0, 1.25, 1.26), (0, 2.6, 1.22), "Body"))


def smoothstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0.0, 1.0)
    return t*t*(3.0 - 2.0*t)


def evaluated_copy(obj, name):
    """A world-space mesh object of obj with its modifiers applied, the bone it rode in its "bone" property."""
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    mesh.transform(obj.matrix_world)
    copy = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(copy)
    copy["bone"] = obj.parent_bone if obj.parent_type == "BONE" else ""
    return copy


def gather(form):
    """The form's parts as evaluated copies: (body parts, eyes)."""
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/FORMS[form][0]))
    bpy.context.scene.frame_set(1)
    rig = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if rig:
        for b in rig.pose.bones:
            b.matrix_basis.identity()
        bpy.context.view_layer.update()
    sources = [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render and o.visible_get()]
    parts, eyes = [], []
    for o in sources:
        copy = evaluated_copy(o, "Game_" + o.name)
        (eyes if o.name.startswith("RammstoneEye") else parts).append(copy)
    for o in sources:
        bpy.data.objects.remove(o)
    if rig:
        bpy.data.objects.remove(rig)
    for o in [o for o in bpy.data.objects if o.type in {"EMPTY", "CAMERA", "LIGHT"}]:
        bpy.data.objects.remove(o)
    return parts, eyes


def weights(form, part):
    """Bone weights for each vertex of part: {bone: array}."""
    co = np.array([tuple(v.co) for v in part.data.vertices])
    if form == "base":
        head = smoothstep(0.85, 1.2, co[:, 2])
        body = smoothstep(0.1, 0.5, co[:, 2])*(1.0 - head)
        return {"root": 1.0 - head - body, "body": body, "head": head}
    bone = part["bone"]
    if not bone:  # the body's skin, bending between Body and Tail as in the preview rig
        tail = smoothstep(1.15, 1.95, co[:, 1])
        return {"Body": 1.0 - tail, "Tail": tail}
    return {bone: np.ones(len(co))}


def add_weights(form, part):
    for bone, w in weights(form, part).items():
        group = part.vertex_groups.get(bone) or part.vertex_groups.new(name=bone)
        for i, value in enumerate(w):
            if value > 1e-4:
                group.add([i], float(value), "REPLACE")


def keep_face(obj):
    """Weights the reduction away from the face (eyes, lids, mouth), whose detail must survive."""
    co = np.array([tuple(v.co) for v in obj.data.vertices])
    face = (co[:, 1] < -0.25) & (np.abs(co[:, 0]) < 0.65) & (co[:, 2] > 0.95) & (co[:, 2] < 1.75)
    group = obj.vertex_groups.new(name="keep")
    for i, f in enumerate(face):
        group.add([i], 0.15 if f else 1.0, "REPLACE")
    return group.name


def join(objs, name):
    ef.select_only(objs)
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = obj.data.name = name
    return obj


def unwrap(low):
    ef.select_only([low])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003)
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")


def new_image(name, size, data=False, hdr=False):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=hdr)
    img.colorspace_settings.name = "Non-Color" if data else "sRGB"
    return img


def bake(low, high, kind, image, selected=True, **extra):
    """Bake into image on low's UVs, from high's surface (selected-to-active) or from low's own materials."""
    holder = bpy.data.materials.new("BakeTarget")
    holder.use_nodes = True
    node = holder.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    holder.node_tree.nodes.active = node
    if selected:
        saved = list(low.data.materials)
        low.data.materials.clear()
        low.data.materials.append(holder)
        ef.select_only([high, low], active=low)
        bpy.ops.object.bake(type=kind, use_selected_to_active=True, cage_extrusion=0.015, max_ray_distance=0.06,
                            margin=8, **extra)
        low.data.materials.clear()
        for m in saved:
            low.data.materials.append(m)
    else:  # baking a mesh from its own materials: every material needs the target image node active
        for mat in low.data.materials:
            t = mat.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = image
            mat.node_tree.nodes.active = t
        ef.select_only([low])
        bpy.ops.object.bake(type=kind, margin=4, **extra)
    bpy.data.materials.remove(holder)


def pixels(image):
    px = np.empty(image.size[0]*image.size[1]*4, np.float32)
    image.pixels.foreach_get(px)
    return px.reshape(image.size[1], image.size[0], 4)


def write(name, rgb, out, data=False):
    """Save rgb (linear for colour, raw for data) as a PNG under out/textures, packed for the GLB."""
    if not data:
        rgb = np.where(rgb <= 0.0031308, 12.92*rgb, 1.055*np.power(np.maximum(rgb, 0.0), 1/2.4) - 0.055)
    size = rgb.shape[0]
    img = bpy.data.images.new(name, size, size, alpha=False)
    img.colorspace_settings.name = "Non-Color" if data else "sRGB"
    img.pixels.foreach_set(np.concatenate([np.clip(rgb, 0, 1), np.ones(rgb.shape[:-1] + (1,))], -1).astype(np.float32).ravel())
    path = out/"textures"/(name + ".png")
    path.parent.mkdir(parents=True, exist_ok=True)
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def maps(low, high, stem, size, out, selected=True):
    """Colour (with glow colour where it glows, and contact shading), glow mask and, for the body, normals."""
    scene = bpy.context.scene
    scene.cycles.samples = 16
    colour = new_image("bake_colour", size, hdr=True)
    bake(low, high, "DIFFUSE", colour, selected, pass_filter={"COLOR"})
    glow = new_image("bake_glow", size, hdr=True)
    bake(low, high, "EMIT", glow, selected)
    col = pixels(colour)[..., :3].astype(float)
    em = pixels(glow)[..., :3].astype(float)
    if selected:
        ao_img = new_image("bake_ao", size, data=True)
        bake(low, high, "AO", ao_img, selected)
        ao = pixels(ao_img)[..., :1].astype(float)
        col = col*(0.7 + 0.3*ao)
    amount = np.clip(np.max(em, axis=-1, keepdims=True)/2.0, 0.0, 1.0)
    hue = em/np.maximum(np.max(em, axis=-1, keepdims=True), 1e-6)
    col = col*(1.0 - amount) + hue*amount
    images = {"color": write(f"{stem}-color", col, out), "glow": write(f"{stem}-glow", np.repeat(amount, 3, -1), out, True)}
    if selected:
        normal = new_image("bake_normal", size, data=True)
        bake(low, high, "NORMAL", normal, selected, normal_space="TANGENT")
        images["normal"] = write(f"{stem}-normal", pixels(normal)[..., :3], out, True)
    gloss = np.zeros((64, 64, 3))
    gloss[..., 0], gloss[..., 1] = 1.0, ROUGHNESS
    images["roughness"] = write(f"{stem}-roughness", gloss, out, True)
    return images


def game_material(name, images):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    c = nodes.new("ShaderNodeTexImage")
    c.image = images["color"]
    links.new(c.outputs["Color"], shader.inputs["Base Color"])
    links.new(c.outputs["Color"], shader.inputs["Emission Color"])
    if "normal" in images:
        n = nodes.new("ShaderNodeTexImage")
        n.image = images["normal"]
        nm = nodes.new("ShaderNodeNormalMap")
        links.new(n.outputs["Color"], nm.inputs["Color"])
        links.new(nm.outputs["Normal"], shader.inputs["Normal"])
    ef.add_gloss(mat, images["roughness"])
    g = nodes.new("ShaderNodeTexImage")
    g.image = images["glow"]
    mul = nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = GLOW_STRENGTH
    links.new(g.outputs["Color"], mul.inputs[0])
    links.new(mul.outputs["Value"], shader.inputs["Emission Strength"])
    return mat


def build_rig(form):
    bones = BASE_BONES if form == "base" else TRANSFORMED_BONES + arm_bones()
    arm = bpy.data.armatures.new(f"Rammstone{form.title()}Rig")
    rig = bpy.data.objects.new(arm.name, arm)
    bpy.context.scene.collection.objects.link(rig)
    ef.select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, head, tail, parent in bones:
        b = arm.edit_bones.new(name)
        b.head, b.tail, b.roll = Vector(head), Vector(tail), 0.0
        if parent:
            b.parent = made[parent]
            b.use_connect = name.startswith("Forearm")
        made[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig, [b[0] for b in bones]


def arm_bones():
    """The transformed form's arm bones, from its builder's rest pose."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import build_rammstone_transformed as bt
    out = []
    for sign in (-1.0, 1.0):
        tag = "R" if sign < 0 else "L"
        S, E, W = bt.ARMS[sign]
        out += [(f"UpperArm.{tag}", S, E, "Body"), (f"Forearm.{tag}", E, W, f"UpperArm.{tag}")]
    return tuple(out)


def skin(obj, rig):
    ef.select_only([obj])
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig


def export(form):
    blend, body_name, stem = FORMS[form]
    out = BUILD/form
    out.mkdir(parents=True, exist_ok=True)
    parts, eyes = gather(form)
    for p in parts + eyes:
        add_weights(form, p)
    high = join(parts, "High")
    low = high.copy()
    low.data = high.data.copy()
    low.name = low.data.name = body_name
    bpy.context.scene.collection.objects.link(low)
    ef.reduce(low, BODY_TRIANGLES, keep=keep_face(low))
    low.vertex_groups.remove(low.vertex_groups["keep"])
    unwrap(low)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    print(form, "baking body")
    body_maps = maps(low, high, stem, TEXTURE, out)
    low.data.materials.clear()
    low.data.materials.append(game_material(body_name + "Skin", body_maps))
    bpy.data.objects.remove(high)

    eye_objs = []
    for e in eyes:
        tag = e.name[-1]
        ef.reduce(e, EYE_TRIANGLES)
        if "EyeLocal" in e.data.uv_layers:
            e.data.uv_layers.active = e.data.uv_layers["EyeLocal"]
        print(form, "baking eye", tag)
        eye_maps = maps(e, None, f"{stem}-eye-{tag}", EYE_TEXTURE, out, selected=False)
        e.data.materials.clear()
        e.data.materials.append(game_material(f"{body_name}Eye{tag}", eye_maps))
        e.name = e.data.name = f"{body_name[:-4]}Eye{tag}"  # RammstoneEyeL, RammstoneTransformedEyeL
        eye_objs.append(e)

    rig, bone_names = build_rig(form)
    if form == "base":
        # His painted grin (build_rammstone.py: GRIN_Y 1.40, half-width 0.27, line 0.30x^2 + 0.05x).
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import mouth_rig
        bone_names += mouth_rig.add(low, rig, {"mouth_L": (0.265, 1.432), "mouth_R": (-0.265, 1.408),
                                               "mouth_low": (0.0, 1.335)}, 0.08)
    meshes = [low] + eye_objs
    for m in meshes:
        skin(m, rig)
    ef.face_plus_y(rig, meshes)
    ef.GAME_SCALE = GAME_SCALE
    ef.scale_to_blaster(rig, meshes)
    review = renders(out)
    ef.select_only([rig] + meshes, active=rig)
    glb = out/"model.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    report = {"form": form, "tool": bpy.app.version_string, "gameScale": GAME_SCALE, "bones": bone_names,
              "meshes": {}, "reviewRenders": review, "studioImportVerified": False}
    points = []
    for m in meshes:
        m.data.calc_loop_triangles()
        own = [m.matrix_world @ v.co for v in m.data.vertices]
        influences = max(len([g for g in v.groups if g.weight > 1e-5]) for v in m.data.vertices)
        report["meshes"][m.name] = {"triangles": len(m.data.loop_triangles), "maxInfluences": influences}
        points += own
    lo = [min(c[i] for c in points) for i in range(3)]
    hi = [max(c[i] for c in points) for i in range(3)]
    report["sizeStuds"] = [round(hi[i] - lo[i], 3) for i in range(3)]
    report["boneHeads"] = {b.name: [round(c, 4) for c in b.head_local] for b in rig.data.bones}
    (out/"export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    assert all(v["triangles"] <= 20000 for v in report["meshes"].values()), report["meshes"]


def renders(out):
    """The game mesh with its baked maps, lit plainly, as Roblox might show it."""
    scene = bpy.context.scene
    scene.cycles.samples = 24
    scene.render.resolution_x = scene.render.resolution_y = 700
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Review")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.45, 0.44, 0.48, 1)
    scene.world = world
    sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(-30), math.radians(150))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 60
    scene.collection.objects.link(cam)
    scene.camera = cam
    meshes = [o for o in scene.objects if o.type == "MESH"]
    pts = [m.matrix_world @ Vector(c) for m in meshes for c in m.bound_box]
    lo = Vector(map(min, *pts))
    hi = Vector(map(max, *pts))
    centre, reach = (lo + hi)/2, (hi - lo).length
    names = []
    for name, yaw, rise in (("front", math.pi, 0.15), ("three-quarter", math.pi - 0.7, 0.2), ("side", math.pi/2, 0.1),
                            ("back", 0.0, 0.25)):
        offset = Vector((math.sin(yaw), -math.cos(yaw), rise)).normalized()*reach*2.2
        cam.location = centre + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        path = out/"renders"/f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        names.append(path.name)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)
    return names


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FORMS)
    for form in argv:
        export(form)


if __name__ == "__main__":
    main()
