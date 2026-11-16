"""Export Boon Doc's two final forms for Roblox: one skinned game mesh per form with baked maps, plus his halo.

Owner, 2026-11-16: "do that for this slug and also for [Boon Doc] ... add both into Studio". Reads the source models
from tools/slugs/build_boon_doc.py untouched (assets/source/slugs/models/boon-doc/).

For each form, as Aquabeek's and Tormato's exports do:
- the dense body and the halo are each reduced (the body under Roblox's 20,000 triangles, the face kept finer) and
  unwrapped;
- normals and contact shading are baked from the dense mesh onto them;
- colour and glow are painted from the concept shader itself at each texel's position, snapped onto the concept's
  surface, so the eye, gilded lid, smile, feathers and glowing bulbs stay sharp;
- both meshes are skinned to one game rig. Base: root, body and head (the bones the slug idles need,
  docs/slugs/motion-library.md), an antenna bone and a wing bone each side, and Halo. Transformed: Body, two bones
  per arm, leg and wing, and Halo. The halo floats free, so it rides its own bone and can bob;
- it is turned to face +Y (Roblox -Z after the export), scaled to the game (base about 0.97 studs tall), and written
  as GLB with a report.

Not yet: separate eye and lid parts for idle expressions (the shared slug idle that would drive them is still being
designed in another session); the eye is painted into the body texture, as the concept's is.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/export_boon_doc_roblox.py [-- base transformed]`

Writes build/slugs/boon-doc/roblox/{base,transformed}/: model.glb, textures/, export-report.json, renders/.
"""
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_boon_doc as bb
import export_floppy_roblox as ef
import export_rammstone_roblox as er
import mouth_rig
import sample_concept as sc
from common import ROOT

SOURCE = bb.SOURCE
BUILD = ROOT/"build/slugs/boon-doc/roblox"
GAME_SCALE = 0.41  # base 2.374 tall in source units, about 0.97 studs
TEXTURE = 2048
HALO_TEXTURE = 512
BODY_TRIANGLES = 18500
HALO_TRIANGLES = 1500
ROUGHNESS = 0.40
FORMS = {
    "base": ("boon-doc-base.blend", "BoonDocBody", "BoonDocHalo", "boon-doc-base"),
    "transformed": ("boon-doc-transformed.blend", "BoonDocTransformedBody", "BoonDocTransformedHalo", "boon-doc-transformed"),
}
SIDES = (("L", 1.0), ("R", -1.0))  # L is his left, +x
# Concept coordinates, his left (tools/slugs/boon_doc_concept/template.html): the transformed arms (arms(): shoulder,
# elbow, wrist, then the hand) and legs (legs(): hip, knee, ankle), and the base antennae (antenna(): root, tip).
ARM = ((0.55, 1.34, 0.10), (0.84, 1.14, 0.36), (0.74, 1.14, 0.80), (0.74, 1.00, 1.02))
LEG = ((0.44, 1.12, -0.58), (0.64, 0.84, -0.66), (0.54, 0.66, -0.94), (0.58, 0.52, -1.06))
ANTENNA = ((0.38, 1.94, -0.06), (0.60, 2.32, -0.62))


def blender(p):
    """Concept (x, y up, z front) to source Blender coordinates (x, -z, y)."""
    return (p[0], -p[2], p[1])


def side_of(co, s):
    return (co[:, 0]*s) > 0


def wing_chain(co, wing, s):
    """Root, middle and tip of one wing, from its own vertices (source coordinates)."""
    pts = co[(wing > 0.5) & side_of(co, s)]
    root = pts[np.argmin(np.abs(pts[:, 0]))]
    d = np.linalg.norm(pts - root, axis=1)
    tip = pts[np.argsort(d)[int(len(d)*0.97)]]
    mid = pts[np.argmin(np.abs(d - 0.5*np.linalg.norm(tip - root)))]
    return root, mid, tip


def bones(form, co, parts):
    """(name, head, tail, parent) in source Blender coordinates."""
    out = []
    if form == "base":
        out += [("root", (0, 0, 0), (0, 0, 0.30), None), ("body", (0, 0, 0.30), (0, 0, 1.05), "root"),
                ("head", (0, 0, 1.05), (0, 0, 2.10), "body")]
        for tag, s in SIDES:
            a, c = ((s*q[0], q[1], q[2]) for q in ANTENNA)
            out.append((f"Antenna.{tag}", blender(a), blender(c), "head"))
            root, _, tip = wing_chain(co, parts[:, 0], s)
            out.append((f"Wing.{tag}", tuple(root), tuple(tip), "body"))
        halo = (0, 0.0, 2.50)   # source coordinates: the base halo's centre (its build report's bounds)
        out.append(("Halo", halo, (halo[0], halo[1], halo[2] + 0.2), "head"))
        return tuple(out)
    out.append(("Body", blender((0, 1.40, -0.80)), blender((0, 1.50, 0.70)), None))
    for tag, s in SIDES:
        for chain, name in ((ARM, "Arm"), (LEG, "Leg")):
            pts = [(s*q[0], q[1], q[2]) for q in chain]
            out.append((f"{name}1.{tag}", blender(pts[0]), blender(pts[1]), "Body"))
            out.append((f"{name}2.{tag}", blender(pts[1]), blender(pts[2]), f"{name}1.{tag}"))
            out.append((f"{name}3.{tag}", blender(pts[2]), blender(pts[3]), f"{name}2.{tag}"))
        root, mid, tip = wing_chain(co, parts[:, 0], s)
        out.append((f"Wing1.{tag}", tuple(root), tuple(mid), "Body"))
        out.append((f"Wing2.{tag}", tuple(mid), tuple(tip), f"Wing1.{tag}"))
    halo = blender((0.0, 2.44, 0.60))
    out.append(("Halo", halo, (halo[0], halo[1], halo[2] + 0.2), "Body"))
    return tuple(out)


def chain_weights(co, mine, chain):
    """Split a limb's vertices between its bones by the nearest segment of the chain (source coordinates)."""
    pts = [np.array(p) for p in chain]
    dists = []
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        h = np.clip(((co - a) @ ab)/(ab @ ab), 0.0, 1.0)
        dists.append(np.linalg.norm(co - (a + h[:, None]*ab), axis=1))
    dists = np.stack(dists, 1)
    near = np.exp(-(dists/0.05)**2) + 1e-6
    near /= near.sum(1, keepdims=True)
    return [mine*near[:, i] for i in range(near.shape[1])]


def attributes(obj):
    out = {}
    for name in ("parts", "parts2"):
        if name in obj.data.color_attributes:
            v = np.empty(len(obj.data.vertices)*4, np.float32)
            obj.data.color_attributes[name].data.foreach_get("color", v)
            out[name] = v.reshape(-1, 4)
    return out


def weights(form, co, attr, spec):
    names = [b[0] for b in spec]
    out = {n: np.zeros(len(co)) for n in names}
    parts = attr["parts"]
    if form == "base":
        head = er.smoothstep(0.95, 1.30, co[:, 2])
        body = er.smoothstep(0.08, 0.45, co[:, 2])*(1.0 - head)
        root = 1.0 - head - body
        ant = (attr["parts2"][:, 0] > 0.3).astype(float)*er.smoothstep(1.95, 2.10, co[:, 2])
        wing = (parts[:, 0] > 0.3).astype(float)
        free = (1.0 - ant)*(1.0 - wing)
        out["root"], out["body"], out["head"] = root*free, body*free, head*free
        for tag, s in SIDES:
            out[f"Antenna.{tag}"] = ant*side_of(co, s)
            out[f"Wing.{tag}"] = wing*side_of(co, s)
        return out
    wing = (parts[:, 0] > 0.3).astype(float)
    arm = (parts[:, 1] > 0.3).astype(float)*(1.0 - wing)
    leg = (parts[:, 2] > 0.3).astype(float)*(1.0 - wing)*(1.0 - arm)
    out["Body"] = 1.0 - wing - arm - leg
    for tag, s in SIDES:
        side = side_of(co, s).astype(float)
        for chain, name, mine in ((ARM, "Arm", arm), (LEG, "Leg", leg)):
            pts = [blender((s*q[0], q[1], q[2])) for q in chain]
            for i, w in enumerate(chain_weights(co, mine*side, pts)):
                out[f"{name}{i + 1}.{tag}"] = w
        wb = {b[0]: b for b in spec}
        w1 = chain_weights(co, wing*side, [np.array(wb[f"Wing1.{tag}"][1]), np.array(wb[f"Wing1.{tag}"][2]),
                                           np.array(wb[f"Wing2.{tag}"][2])])
        out[f"Wing1.{tag}"], out[f"Wing2.{tag}"] = w1
    return out


def add_groups(obj, w):
    for bone, values in w.items():
        group = obj.vertex_groups.new(name=bone)
        for i in np.nonzero(values > 1e-4)[0]:
            group.add([int(i)], float(values[i]), "REPLACE")


def keep_face(form, obj):
    """Weights the reduction away from the face (eye, gilded lid, smile), whose detail must survive."""
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    if form == "base":
        face = (co[:, 1] < -0.15) & (np.abs(co[:, 0]) < 0.70) & (co[:, 2] > 1.0) & (co[:, 2] < 2.0)
    else:
        face = (co[:, 1] < -0.30) & (np.abs(co[:, 0]) < 0.75) & (co[:, 2] > 1.05) & (co[:, 2] < 1.95)
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


def shader_maps(form, low, high, stem, out, size, halo):
    """Colour (with contact shading, glow added) and glow mask painted from the concept shader; baked normals."""
    scene = bpy.context.scene
    scene.cycles.samples = 16
    pos, covered = position_map(low, size)
    pts = pos[covered]
    concept = np.stack([pts[:, 0], pts[:, 2], -pts[:, 1]], 1)
    print(form, stem, "painting", len(concept), "texels from the shader", flush=True)
    rgb = {}
    for name, which in (("colour", 20), ("glow", 21)):
        v = sc.sample_points(bb.PAGE, *bb.probe(form, which, halo), concept, chunk=1 << 19)[:, :3].astype(float)/255.0
        img = np.zeros((size, size, 3))
        img[covered] = v*v*(2.0 if name == "glow" else 1.0)
        rgb[name] = img
    ao_img = er.new_image("bake_ao_" + stem, size, data=True)
    er.bake(low, high, "AO", ao_img, True)
    ao = er.pixels(ao_img)[..., :1].astype(float)
    glow = rgb["glow"]
    col = np.clip(rgb["colour"]*(0.72 + 0.28*ao) + glow, 0.0, 1.0)
    amount = np.clip(np.max(glow, axis=-1, keepdims=True)/0.5, 0.0, 1.0)
    images = {"color": er.write(f"{stem}-color", col, out),
              "glow": er.write(f"{stem}-glow", np.repeat(amount, 3, -1), out, True)}
    normal = er.new_image("bake_normal_" + stem, size, data=True)
    er.bake(low, high, "NORMAL", normal, True, normal_space="TANGENT")
    images["normal"] = er.write(f"{stem}-normal", er.pixels(normal)[..., :3], out, True)
    gloss = np.zeros((64, 64, 3))
    gloss[..., 0], gloss[..., 1] = 1.0, (0.25 if halo else ROUGHNESS)
    images["roughness"] = er.write(f"{stem}-roughness", gloss, out, True)
    return images


def build_rig(form, spec):
    arm = bpy.data.armatures.new(f"BoonDoc{form.title()}Rig")
    rig = bpy.data.objects.new(arm.name, arm)
    bpy.context.scene.collection.objects.link(rig)
    ef.select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, head, tail, parent in spec:
        b = arm.edit_bones.new(name)
        b.head, b.tail, b.roll = Vector(head), Vector(tail), 0.0
        if parent:
            b.parent = made[parent]
        made[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def game_mesh(form, high, name, stem, out, target, size, halo, face=True):
    """Reduce, unwrap and paint one dense mesh; returns the game copy (the dense one is removed)."""
    low = high.copy()
    low.data = high.data.copy()
    low.name = low.data.name = name
    bpy.context.scene.collection.objects.link(low)
    keep = keep_face(form, low) if face else None
    ef.reduce(low, target, keep=keep)
    if keep:
        low.vertex_groups.remove(low.vertex_groups["keep"])
    for a in [a.name for a in low.data.color_attributes]:
        try:   # the game material doesn't read them, so the GLB carries none either way
            low.data.color_attributes.remove(low.data.color_attributes[a])
        except RuntimeError:
            pass
    er.unwrap(low)
    images = shader_maps(form, low, high, stem, out, size, halo)
    low.data.materials.clear()
    low.data.materials.append(er.game_material(name + "Skin", images))
    bpy.data.objects.remove(high)
    return low


def export(form):
    blend, body_name, halo_name, stem = FORMS[form]
    out = BUILD/form
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/blend))
    bpy.context.scene.render.engine = "CYCLES"
    high = bpy.data.objects[bb.FORMS[form]["name"]]
    high_halo = bpy.data.objects[bb.FORMS[form]["name"].replace("Body", "Halo")]
    high.name, high_halo.name = "High", "HighHalo"
    co = np.empty(len(high.data.vertices)*3)
    high.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    attr = attributes(high)
    spec = bones(form, co, attr["parts"])
    add_groups(high, weights(form, co, attr, spec))
    hw = np.ones(len(high_halo.data.vertices))
    add_groups(high_halo, {"Halo": hw})
    low = game_mesh(form, high, body_name, stem, out, BODY_TRIANGLES, TEXTURE, 0)
    halo = game_mesh(form, high_halo, halo_name, stem + "-halo", out, HALO_TRIANGLES, HALO_TEXTURE, 1, face=False)
    rig = build_rig(form, spec)
    bone_names = [b[0] for b in spec]
    if form == "base":
        # His painted mouth (template.html, MOUTHV 0: MOUTH (0, 1.255), MW 0.285, MDEEP 0.092, MTC 0.026), so SlugIdle
        # can bend it.
        bone_names += mouth_rig.add(low, rig, {"mouth_L": (0.285, 1.281), "mouth_R": (-0.285, 1.281),
                                               "mouth_low": (0.0, 1.159)}, 0.07)
    for mesh in (low, halo):
        er.skin(mesh, rig)
    # Roblox drops bones without skinned vertices, so every bone must carry some.
    used = set()
    for mesh in (low, halo):
        idx = {g.index: g.name for g in mesh.vertex_groups}
        for v in mesh.data.vertices:
            used.update(idx[g.group] for g in v.groups if g.weight > 1e-3)
    empty = [b for b in bone_names if b not in used]
    assert not empty, f"bones without weights: {empty}"
    ef.face_plus_y(rig, [low, halo])
    ef.GAME_SCALE = GAME_SCALE
    ef.scale_to_blaster(rig, [low, halo])
    review = er.renders(out)
    ef.select_only([rig, low, halo], active=rig)
    glb = out/"model.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    report = {"form": form, "tool": bpy.app.version_string, "gameScale": GAME_SCALE, "bones": bone_names, "meshes": {},
              "boneHeads": {b.name: [round(c, 4) for c in b.head_local] for b in rig.data.bones},
              "reviewRenders": review, "studioImportVerified": False}
    for mesh in (low, halo):
        mesh.data.calc_loop_triangles()
        influences = max(len([g for g in v.groups if g.weight > 1e-5]) for v in mesh.data.vertices)
        report["meshes"][mesh.name] = {"triangles": len(mesh.data.loop_triangles), "maxInfluences": influences}
        assert len(mesh.data.loop_triangles) <= 20000 and influences <= 4, report["meshes"]
    pts = [low.matrix_world @ v.co for v in low.data.vertices]
    report["sizeStuds"] = [round(max(c[i] for c in pts) - min(c[i] for c in pts), 3) for i in range(3)]
    (out/"export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FORMS)
    for form in argv:
        export(form)


if __name__ == "__main__":
    main()
