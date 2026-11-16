"""Export Aquabeek's two final forms for Roblox: one skinned game mesh per form with baked maps.

Owner, 2026-11-14: "this is the design ... finalize this as a design, and then build out Aquabeek and ... get into
Roblox". Reads the source models from tools/slugs/build_aquabeek.py untouched (assets/source/slugs/models/aquabeek/).

For each form:
- a copy of the dense source mesh is reduced to under Roblox's 20,000 triangles a mesh, the face kept finer, and
  unwrapped;
- normals and contact shading are baked from the dense mesh onto it;
- colour and glow are painted from the concept shader itself (sample_concept.py): each texel's position on the game
  mesh is baked, snapped onto the concept's surface and coloured there, so the eyes, lashes and scales come out as
  sharp as the concept at the texture's resolution rather than blurred through vertex colours;
- the base form's eyes are cut out and rebuilt as eyeballs and blink lids on their own bones (aquabeek_eyes.py), so
  she can glance and blink; at rest she looks as before;
- it is skinned to a small game rig: root, body and head for the base form (its idle sways and nods; she faces the
  mesh's -Z in Roblox, as Roblox drops bones without skinned vertices); Body, Tail and two bones along each of the six blades for the transformed form,
  so the blades can ripple and the tail swing;
- it is turned to face +Y (Roblox -Z after the export) and scaled to the game (base about 0.96 studs tall, Floppy's
  reference height), and written as GLB with a report.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/export_aquabeek_roblox.py [-- base transformed]`

Writes build/slugs/aquabeek/roblox/{base,transformed}/: model.glb, textures/, export-report.json, renders/.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aquabeek_eyes
import mouth_rig
import build_aquabeek as ba
import export_floppy_roblox as ef
import export_rammstone_roblox as er
import sample_concept as sc
from common import ROOT

SOURCE = ba.SOURCE
BUILD = ROOT/"build/slugs/aquabeek/roblox"
GAME_SCALE = 0.43  # base 2.235 tall in source units, about 0.96 studs
TEXTURE = 2048
BODY_TRIANGLES = 18500
GLOW_STRENGTH = 2.5
ROUGHNESS = 0.30  # wet and glossy
FORMS = {
    "base": ("aquabeek-base.blend", "AquabeekBody", "aquabeek-base"),
    "transformed": ("aquabeek-transformed.blend", "AquabeekTransformedBody", "aquabeek-transformed"),
}
SIDES = (("L", 1.0), ("R", -1.0))  # L is her left, +x
# The transformed form's blades at rest, concept coordinates (tools/slugs/aquabeek_concept/template.html wingFin):
# root, bend and tip, with the sign of x per side.
BLADES = {
    "Upper": ((0.22, 1.94, -0.32), (0.60, 2.28, -0.85), (0.76, 2.30, -1.75)),
    "Middle": ((0.40, 1.66, -0.38), (0.86, 1.80, -0.82), (1.04, 1.70, -1.50)),
    "Lower": ((0.30, 1.28, -0.40), (0.76, 1.02, -0.86), (0.86, 0.86, -1.65)),
}
BLADE_ORDER = ("Upper", "Middle", "Lower")  # wingFin's blade index


def blender(p):
    """Concept (x, y up, z front) to source Blender coordinates (x, -z, y)."""
    return (p[0], -p[2], p[1])


def bones(form):
    """(name, head, tail, parent) in source Blender coordinates."""
    if form == "base":
        return (("root", (0, 0, 0), (0, 0, 0.30), None), ("body", (0, 0, 0.30), (0, 0, 1.05), "root"),
                ("head", (0, 0, 1.05), (0, 0, 2.10), "body"))
    out = [("Body", blender((0, 1.42, -0.20)), blender((0, 1.42, 0.50)), None),
           ("Tail", blender((0, 1.36, -0.95)), blender((0, 1.30, -2.05)), "Body")]
    for tag, s in SIDES:
        for name, (a, b, c) in BLADES.items():
            a, b, c = ((s*q[0], q[1], q[2]) for q in (a, b, c))
            out.append((f"Blade{name}1.{tag}", blender(a), blender(b), "Body"))
            out.append((f"Blade{name}2.{tag}", blender(b), blender(c), f"Blade{name}1.{tag}"))
    return tuple(out)


def weights(form, obj):
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if form == "base":
        head = er.smoothstep(0.95, 1.30, co[:, 2])
        body = er.smoothstep(0.08, 0.45, co[:, 2])*(1.0 - head)
        return {"root": 1.0 - head - body, "body": body, "head": head}
    blade = np.empty(len(co)*4, np.float32)
    obj.data.color_attributes["blade"].data.foreach_get("color", blade)
    blade = blade.reshape(-1, 4)
    on, t, which = blade[:, 0] > 0.5, blade[:, 1], np.rint(blade[:, 2]*2).astype(int)
    wb = on*er.smoothstep(0.03, 0.18, t)
    second = er.smoothstep(0.40, 0.65, t)
    tail = er.smoothstep(0.75, 1.55, co[:, 1])   # Blender +y is back
    out = {"Body": (1.0 - wb)*(1.0 - tail), "Tail": (1.0 - wb)*tail}
    for tag, s in SIDES:
        side = (co[:, 0]*s) > 0
        for i, name in enumerate(BLADE_ORDER):
            mine = wb*side*(which == i)
            out[f"Blade{name}1.{tag}"] = mine*(1.0 - second)
            out[f"Blade{name}2.{tag}"] = mine*second
    return out


def add_weights(form, obj):
    for bone, w in weights(form, obj).items():
        group = obj.vertex_groups.new(name=bone)
        for i in np.nonzero(w > 1e-4)[0]:
            group.add([int(i)], float(w[i]), "REPLACE")


def keep_face(form, obj):
    """Weights the reduction away from the face (eyes, lids, mouth, beak), whose detail must survive."""
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if form == "base":
        face = (co[:, 1] < -0.15) & (np.abs(co[:, 0]) < 0.70) & (co[:, 2] > 1.0) & (co[:, 2] < 1.95)
    else:
        face = (co[:, 1] < 0.05) & (co[:, 2] > 1.15) & (co[:, 2] < 1.95)
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
        v = sc.sample_points(ba.PAGE, *ba.probe(form, which), concept, chunk=1 << 19)[:, :3].astype(float)/255.0
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
    arm = bpy.data.armatures.new(f"Aquabeek{form.title()}Rig")
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
    high = bpy.data.objects[ba.FORMS[form]["name"]]
    high.name = "High"
    add_weights(form, high)
    low = high.copy()
    low.data = high.data.copy()
    low.name = low.data.name = body_name
    bpy.context.scene.collection.objects.link(low)
    ef.reduce(low, BODY_TRIANGLES, keep=keep_face(form, low))
    low.vertex_groups.remove(low.vertex_groups["keep"])
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
        extra, eyes = aquabeek_eyes.build(low, rig, out)
        meshes += extra
        bone_names += [f"{kind}_{tag}" for tag, _ in aquabeek_eyes.SIDES for kind in ("eye", "lid")]
        # Her painted mouth (template.html, B, FACE 3: MOUTH (0, 1.286), MW 0.238, corners lifted, her right higher).
        bone_names += mouth_rig.add(low, rig, {"mouth_L": (0.235, 1.312), "mouth_R": (-0.235, 1.326),
                                               "mouth_low": (0.0, 1.250)}, 0.07)
    for mesh in meshes:
        er.skin(mesh, rig)
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
              "eyes": eyes,
              "sizeStuds": [round(hi[i] - lo[i], 3) for i in range(3)],
              "boneHeads": {b.name: [round(c, 4) for c in b.head_local] for b in rig.data.bones},
              "reviewRenders": review, "studioImportVerified": False}
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
