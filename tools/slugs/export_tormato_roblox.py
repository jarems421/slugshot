"""Export Tormato's two final forms for Roblox: one skinned game mesh per form with baked maps.

Owner, 2026-11-16: "do that for this slug and also for [Boon Doc] ... add both into Studio". Reads the source models
from tools/slugs/build_tormato.py untouched (assets/source/slugs/models/tormato/).

For each form, as Aquabeek's export does:
- a copy of the dense source mesh is reduced to under Roblox's 20,000 triangles a mesh, the face kept finer, and
  unwrapped;
- normals and contact shading are baked from the dense mesh onto it;
- colour and glow are painted from the concept shader itself (sample_concept.py): each texel's position on the game
  mesh is baked, snapped onto the concept's surface and coloured there, so the storm eyes, tornado mark, teeth and
  bands come out as sharp as the concept at the texture's resolution;
- it is skinned to a small game rig: root, body and head for the base form, the bones the slug idles need
  (docs/slugs/motion-library.md); Body, Head, two tail bones and three bones along each wing for the transformed form,
  so the head can turn, the tail swing and the flap travel out along each wing;
- it is turned to face +Y (Roblox -Z after the export) and scaled to the game (base about 0.96 studs tall, Floppy's
  reference height), and written as GLB with a report.

Not yet: separate eye and lid parts for idle expressions (the shared slug idle that would drive them is still being
designed in another session); the eyes are painted into the body texture, as the concept's are.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/export_tormato_roblox.py [-- base transformed]`

Writes build/slugs/tormato/roblox/{base,transformed}/: model.glb, textures/, export-report.json, renders/.
"""
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_tormato as bt
import export_floppy_roblox as ef
import export_rammstone_roblox as er
import mouth_rig
import tormato_eyes
import sample_concept as sc
from common import ROOT

SOURCE = bt.SOURCE
BUILD = ROOT/"build/slugs/tormato/roblox"
GAME_SCALE = 0.41  # base 2.348 tall in source units, about 0.96 studs
TEXTURE = 2048
BODY_TRIANGLES = 18500
ROUGHNESS = 0.35  # wet and glossy, like Floppy
FORMS = {
    "base": ("tormato-base.blend", "TormatoBody", "tormato-base"),
    "transformed": ("tormato-transformed.blend", "TormatoTransformedBody", "tormato-transformed"),
}
SIDES = (("L", 1.0), ("R", -1.0))  # L is his left, +x
# The transformed form's wing at rest (REST 1), concept coordinates, his left: root, wrist, hand, tip
# (tools/slugs/tormato_concept/template.html wing(): root (0.42, 1.52, -0.95), the flap's height x*0.30 + 0.04x^2).
WING = ((0.42, 1.52, -0.80), (1.22, 1.79, -0.45), (1.87, 2.04, -0.67), (2.47, 2.30, -1.35))
# The tail's centre line (xfAxis): its root, middle and tip.
TAIL = ((0.0, 1.30, -1.50), (0.11, 1.36, -2.30), (-0.01, 1.53, -3.10))


def blender(p):
    """Concept (x, y up, z front) to source Blender coordinates (x, -z, y)."""
    return (p[0], -p[2], p[1])


def bones(form):
    """(name, head, tail, parent) in source Blender coordinates."""
    if form == "base":
        return (("root", (0, 0, 0), (0, 0, 0.30), None), ("body", (0, 0, 0.30), (0, 0, 1.10), "root"),
                ("head", (0, 0, 1.10), (0, 0, 2.30), "body"))
    out = [("Body", blender((0, 1.25, -1.15)), blender((0, 1.30, -0.30)), None),
           ("Head", blender((0, 1.40, -0.30)), blender((0, 1.75, 0.55)), "Body"),
           ("Tail1", blender(TAIL[0]), blender(TAIL[1]), "Body"),
           ("Tail2", blender(TAIL[1]), blender(TAIL[2]), "Tail1")]
    for tag, s in SIDES:
        pts = [(s*q[0], q[1], q[2]) for q in WING]
        parent = "Body"
        for i in range(3):
            name = f"Wing{i + 1}.{tag}"
            out.append((name, blender(pts[i]), blender(pts[i + 1]), parent))
            parent = name
    return tuple(out)


def weights(form, obj):
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if form == "base":
        head = er.smoothstep(1.05, 1.40, co[:, 2])
        body = er.smoothstep(0.08, 0.45, co[:, 2])*(1.0 - head)
        return {"root": 1.0 - head - body, "body": body, "head": head}
    parts = np.empty(len(co)*4, np.float32)
    obj.data.color_attributes["parts"].data.foreach_get("color", parts)
    parts = parts.reshape(-1, 4)
    cx, cz = co[:, 0], -co[:, 1]   # concept x and z (front +)
    span = np.abs(cx) - 0.42
    wing = (parts[:, 0] > 0.3)*er.smoothstep(0.02, 0.30, span)
    rest = 1.0 - wing
    head = er.smoothstep(-0.55, -0.15, cz)*rest
    tt = (-cz - 1.50)/1.60
    t2 = er.smoothstep(0.35, 0.65, tt)*rest
    t1 = er.smoothstep(-0.15, 0.15, tt)*rest - t2
    out = {"Body": np.clip(rest - head - t1 - t2, 0.0, 1.0), "Head": head, "Tail1": np.clip(t1, 0.0, 1.0), "Tail2": t2}
    w3 = er.smoothstep(1.25, 1.65, span)
    w1 = 1.0 - er.smoothstep(0.55, 0.95, span)
    w2 = np.clip(1.0 - w1 - w3, 0.0, 1.0)
    for tag, s in SIDES:
        side = (cx*s) > 0
        for i, w in enumerate((w1, w2, w3)):
            out[f"Wing{i + 1}.{tag}"] = wing*side*w
    return out


def add_weights(form, obj):
    for bone, w in weights(form, obj).items():
        group = obj.vertex_groups.new(name=bone)
        for i in np.nonzero(w > 1e-4)[0]:
            group.add([int(i)], float(w[i]), "REPLACE")


def keep_face(obj):
    """Weights the reduction away from the face (eyes, mouth, teeth, forehead mark), whose detail must survive."""
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    face = (co[:, 1] < -0.15) & (np.abs(co[:, 0]) < 0.75) & (co[:, 2] > 1.05) & (co[:, 2] < 2.15)
    group = obj.vertex_groups.new(name="keep")
    for i, f in enumerate(face):
        group.add([i], 0.15 if f else 1.0, "REPLACE")
    return group.name


def position_map(low, size):
    """Each texel's position on low (source coordinates), and which texels it covers."""
    mat = bpy.data.materials.new("Position")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    for n in list(nodes):
        nodes.remove(n)
    geo = nodes.new("ShaderNodeNewGeometry")
    em = nodes.new("ShaderNodeEmission")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(geo.outputs["Position"], em.inputs["Color"])
    links.new(em.outputs["Emission"], out.inputs["Surface"])
    saved = list(low.data.materials)
    low.data.materials.clear()
    low.data.materials.append(mat)
    img = bpy.data.images.new("bake_position", size, size, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.zeros(size*size*4, np.float32))
    er.bake(low, None, "EMIT", img, selected=False)
    low.data.materials.clear()
    for m in saved:
        low.data.materials.append(m)
    px = er.pixels(img)
    return px[..., :3].astype(float), px[..., 3] > 0.5


def shader_maps(form, low, high, stem, out):
    """Colour (with contact shading, glow added) and glow mask painted from the concept shader; baked normals."""
    scene = bpy.context.scene
    scene.cycles.samples = 16
    pos, covered = position_map(low, TEXTURE)
    pts = pos[covered]
    concept = np.stack([pts[:, 0], pts[:, 2], -pts[:, 1]], 1)
    print(form, "painting", len(concept), "texels from the shader", flush=True)
    rgb = {}
    for name, which in (("colour", 20), ("glow", 21)):
        v = sc.sample_points(bt.PAGE, *bt.probe(form, which), concept, chunk=1 << 19)[:, :3].astype(float)/255.0
        img = np.zeros((TEXTURE, TEXTURE, 3))
        img[covered] = v*v*(2.0 if name == "glow" else 1.0)
        rgb[name] = img
    ao_img = er.new_image("bake_ao", TEXTURE, data=True)
    er.bake(low, high, "AO", ao_img, True)
    ao = er.pixels(ao_img)[..., :1].astype(float)
    glow = rgb["glow"]
    col = np.clip(rgb["colour"]*(0.72 + 0.28*ao) + glow, 0.0, 1.0)
    amount = np.clip(np.max(glow, axis=-1, keepdims=True)/0.5, 0.0, 1.0)
    images = {"color": er.write(f"{stem}-color", col, out),
              "glow": er.write(f"{stem}-glow", np.repeat(amount, 3, -1), out, True)}
    normal = er.new_image("bake_normal", TEXTURE, data=True)
    er.bake(low, high, "NORMAL", normal, True, normal_space="TANGENT")
    images["normal"] = er.write(f"{stem}-normal", er.pixels(normal)[..., :3], out, True)
    gloss = np.zeros((64, 64, 3))
    gloss[..., 0], gloss[..., 1] = 1.0, ROUGHNESS
    images["roughness"] = er.write(f"{stem}-roughness", gloss, out, True)
    return images


def build_rig(form):
    arm = bpy.data.armatures.new(f"Tormato{form.title()}Rig")
    rig = bpy.data.objects.new(arm.name, arm)
    bpy.context.scene.collection.objects.link(rig)
    ef.select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    spec = bones(form)
    for name, head, tail, parent in spec:
        b = arm.edit_bones.new(name)
        b.head, b.tail, b.roll = Vector(head), Vector(tail), 0.0
        if parent:
            b.parent = made[parent]
        made[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig, [b[0] for b in spec]


def export(form):
    blend, body_name, stem = FORMS[form]
    out = BUILD/form
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/blend))
    high = bpy.data.objects[bt.FORMS[form]["name"]]
    high.name = "High"
    add_weights(form, high)
    low = high.copy()
    low.data = high.data.copy()
    low.name = low.data.name = body_name
    bpy.context.scene.collection.objects.link(low)
    ef.reduce(low, BODY_TRIANGLES, keep=keep_face(low))
    low.vertex_groups.remove(low.vertex_groups["keep"])
    rims = tormato_eyes.cut_openings(low) if form == "base" else None
    for name in [a.name for a in low.data.color_attributes]:
        try:   # the game material doesn't read them, so the GLB carries none either way
            low.data.color_attributes.remove(low.data.color_attributes[name])
        except RuntimeError:
            pass
    er.unwrap(low)
    bpy.context.scene.render.engine = "CYCLES"
    images = shader_maps(form, low, high, stem, out)
    low.data.materials.clear()
    low.data.materials.append(er.game_material(body_name + "Skin", images))
    bpy.data.objects.remove(high)

    rig, bone_names = build_rig(form)
    meshes, eyes = [low], None
    if form == "base":
        # His storm eyes cut out and rebuilt as discs that spin on eye_L/eye_R (tormato_eyes.py).
        extra, eyes = tormato_eyes.build(low, rig, out, rims)
        meshes.append(extra)
        bone_names += [f"eye_{tag}" for tag, _ in tormato_eyes.SIDES]
        # His painted mouth (template.html: MOUTH (0.020, 1.325), MW 0.285, MDEEP 0.142, MTILT 0.10, MCURVE 0.42),
        # so SlugIdle can bend it.
        bone_names += mouth_rig.add(low, rig, {"mouth_L": (0.305, 1.388), "mouth_R": (-0.265, 1.331),
                                               "mouth_low": (0.020, 1.183)}, 0.08)
    for mesh in meshes:
        er.skin(mesh, rig)
    # Roblox drops bones without skinned vertices, so every bone must carry some.
    used = set()
    for mesh in meshes:
        idx = {g.index: g.name for g in mesh.vertex_groups}
        for v in mesh.data.vertices:
            used.update(idx[g.group] for g in v.groups if g.weight > 1e-3)
    empty = [b for b in bone_names if b not in used]
    assert not empty, f"bones without weights: {empty}"
    ef.face_plus_y(rig, meshes)
    ef.GAME_SCALE = GAME_SCALE
    ef.scale_to_blaster(rig, meshes)
    review = er.renders(out)
    ef.select_only([rig] + meshes, active=rig)
    glb = out/"model.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    low.data.calc_loop_triangles()
    influences = max(len([g for g in v.groups if g.weight > 1e-5]) for v in low.data.vertices)
    pts = [low.matrix_world @ v.co for v in low.data.vertices]
    lo = [min(c[i] for c in pts) for i in range(3)]
    hi = [max(c[i] for c in pts) for i in range(3)]
    report = {"form": form, "tool": bpy.app.version_string, "gameScale": GAME_SCALE, "bones": bone_names,
              "meshes": {low.name: {"triangles": len(low.data.loop_triangles), "maxInfluences": influences}},
              "sizeStuds": [round(hi[i] - lo[i], 3) for i in range(3)],
              "boneHeads": {b.name: [round(c, 4) for c in b.head_local] for b in rig.data.bones},
              "eyes": eyes, "reviewRenders": review, "studioImportVerified": False}
    (out/"export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    assert report["meshes"][low.name]["triangles"] <= 20000, report["meshes"]
    assert influences <= 4


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FORMS)
    for form in argv:
        export(form)


if __name__ == "__main__":
    main()
