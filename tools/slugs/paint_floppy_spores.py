"""Add the spore spots and antenna-bulb glow to the approved Floppy source without rebuilding it.

Owner, 2026-11-01: "make the bulbs of the antenna slightly luminous… add greenish brownish spores, diffused spots
around the body… medium-sized… just on the plain body", away from the back marks and belly. build_floppy.py now
paints both from the concept, but a rebuild would redo the repaired topology (floppy-chamber-repair.md), so this
one-off applies the same rules (`spores`, `bulb_glow`) to the repaired source in place:

- each body texel's rest position is baked (as build_floppy does) and mapped back to concept space;
- inside a spot the existing baked colour is darkened toward the spore colour, keeping its baked shading and grade;
- a grey glow mask of the bulbs is added and wired into the skin's emission, so the export can bake it too.

The source is checkpointed to build/slugs/floppy/checkpoints/before-spores first. Run with Blender 4.5:

`blender --background --factory-startup --python tools/slugs/paint_floppy_spores.py`
"""
import shutil
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_floppy as bf  # noqa: E402
from common import ROOT  # noqa: E402

SOURCE = ROOT/"assets/source/slugs/models/floppy/floppy-repaired.blend"
TEXTURES = ROOT/"assets/source/slugs/models/floppy/textures"
CHECKPOINT = ROOT/"build/slugs/floppy/checkpoints/before-spores"
GLOW_STRENGTH = 2.0


def bake_rest(body, size):
    """Concept-space rest position of every texel the body covers (None where it covers none)."""
    mesh = body.data
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    concept = np.stack([co[:, 0], co[:, 2], -co[:, 1]], -1)  # inverse of build_floppy.to_blender
    attr = mesh.attributes.new("rest", "FLOAT_VECTOR", "POINT")
    attr.data.foreach_set("vector", (concept*0.25 + 0.5).astype(np.float32).ravel())
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    image = bpy.data.images.new("bake_rest", size, size, alpha=True, float_buffer=True)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(np.zeros(size*size*4, np.float32))
    mat = bpy.data.materials.new("Bake_rest")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    a = nodes.new("ShaderNodeAttribute")
    a.attribute_name = "rest"
    e = nodes.new("ShaderNodeEmission")
    o = nodes.new("ShaderNodeOutputMaterial")
    links.new(a.outputs["Vector"], e.inputs["Color"])
    links.new(e.outputs["Emission"], o.inputs["Surface"])
    t = nodes.new("ShaderNodeTexImage")
    t.image = image
    nodes.active = t
    saved = list(mesh.materials)
    mesh.materials.clear()
    mesh.materials.append(mat)
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.bake(type="EMIT", margin=12, use_clear=False)
    px = np.empty(size*size*4, np.float32)
    image.pixels.foreach_get(px)
    px = px.reshape(size, size, 4)
    mesh.materials.clear()
    for m in saved:
        mesh.materials.append(m)
    mesh.attributes.remove(mesh.attributes["rest"])
    bpy.data.images.remove(image)
    bpy.data.materials.remove(mat)
    return px


def main():
    CHECKPOINT.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE, CHECKPOINT/SOURCE.name)
    shutil.copy2(TEXTURES/"floppy-body.png", CHECKPOINT/"floppy-body.png")
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    body = bpy.data.objects["FloppyBody"]
    skin = body.data.materials[0]
    tex = next(n for n in skin.node_tree.nodes if n.type == "TEX_IMAGE")
    size = tex.image.size[0]
    rest = bake_rest(body, size)
    covered = rest[..., 3] > 0.5
    pts = (rest[..., :3][covered].astype(float) - 0.5)/0.25

    # Spots: the albedo goes BODY -> SPORE inside a spot; scale the baked texel by that ratio (through the
    # build's 1.12 grade), so its baked occlusion and grade survive.
    px = np.empty(size*size*4, np.float32)
    tex.image.pixels.foreach_get(px)
    px = px.reshape(size, size, 4)
    m = np.zeros((size, size))
    m[covered] = 0.7*bf.spores(pts)
    ratio = (bf.SPORE/bf.BODY)**1.12
    if not tex.image.is_float and tex.image.colorspace_settings.name == "sRGB":
        ratio = ratio**(1/2.2)  # 8-bit sRGB pixels: the same darkening, expressed in stored values
    px[..., :3] *= (1.0 - m[..., None]) + m[..., None]*ratio
    tex.image.pixels.foreach_set(px.ravel())
    tex.image.filepath_raw = str(TEXTURES/"floppy-body.png")
    tex.image.file_format = "PNG"
    tex.image.save()
    tex.image.pack()

    # Bulb glow mask, wired into the skin's emission.
    g = np.zeros((size, size))
    g[covered] = bf.bulb_glow(pts)
    glow = bpy.data.images.new("floppy-body-glow", size, size, alpha=False)
    glow.colorspace_settings.name = "Non-Color"
    glow.pixels.foreach_set(np.concatenate([np.repeat(g[..., None], 3, -1), np.ones((size, size, 1))], -1).astype(np.float32).ravel())
    glow.filepath_raw = str(TEXTURES/"floppy-body-glow.png")
    glow.file_format = "PNG"
    glow.save()
    glow.pack()
    nodes, links = skin.node_tree.nodes, skin.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    gt = nodes.new("ShaderNodeTexImage")
    gt.image = glow
    gt.label = "Bulb glow"
    mul = nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = GLOW_STRENGTH
    links.new(gt.outputs["Color"], mul.inputs[0])
    links.new(mul.outputs["Value"], shader.inputs["Emission Strength"])
    shader.inputs["Emission Color"].default_value = tuple(bf.BULB_GLOW) + (1.0,)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)
    print("SPORES_DONE spots texels", int((m > 0.05).sum()), "glow texels", int((g > 0.05).sum()))


main()
