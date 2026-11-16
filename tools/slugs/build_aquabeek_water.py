"""Aquabeek's flight water, run with Blender (4.5): a comic water veil pouring off the tip of each of her six blades and
streaming back, with hard colour bands like Inferno's wing fire (tools/slugs/build_wing_fire.py), in place of a flat
trail sheet (owner, 2026-11-03, on Inferno: a trail sheet read as "an orange box"; 2026-11-14: "let's work on the
transformations and transformation trails").

It is a separate model on the transformed form's own bones (same names and positions, export_aquabeek_roblox.py), plus
two wave bones along each veil, so the approved model is untouched and the game clips it on for flight. Writes
build/slugs/aquabeek/water: model.glb, colour and glow mask, and review renders against the transformed model. Nothing is
uploaded here; see tools/slugs/upload_aquabeek.py.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_aquabeek_water.py`
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import export_aquabeek_roblox as ea
import export_floppy_roblox as ef
import export_rammstone_roblox as er
from build_floppy import smoothstep
from common import ROOT

OUT = ROOT/"build/slugs/aquabeek/water"
TEXTURE = 1024
COLUMNS, ROWS = 48, 10
START = 0.78  # where on the blade the water starts, under its last fifth
LENGTH = 1.0  # how far the stream runs on past the tip, concept units
WIDTH = 0.13  # half width at its fullest
THICK = 0.022
# Across the veil from its lower edge (0) to its crest (1): the hard bands, deep rim to a pale core.
BANDS = ((0.0, (20, 64, 168)), (0.10, (38, 120, 222)), (0.24, (64, 208, 240)), (0.44, (196, 246, 255)),
         (0.62, (64, 208, 240)), (0.80, (38, 120, 222)), (0.92, (20, 64, 168)))
BAND_GLOW = (0.15, 0.35, 0.65, 1.0, 0.65, 0.35, 0.15)
FOAM = (236, 252, 255)


def bezier(a, b, c, t):
    t = np.asarray(t, float)[..., None]
    return (1 - t)**2*a + 2*(1 - t)*t*b + t*t*c


def tangent(a, b, c, t):
    t = np.asarray(t, float)[..., None]
    d = 2*(1 - t)*(b - a) + 2*t*(c - b)
    return d/np.linalg.norm(d, axis=-1, keepdims=True)


def stream(name, s):
    """The veil's centreline points (concept space) for u along it: from under the blade's tip on past it, curving back."""
    a, b, c = (np.array([s*q[0], q[1], q[2]]) for q in ea.BLADES[name])
    p0 = bezier(a, b, c, START)
    tip_dir = tangent(a, b, c, 1.0)
    back = np.array([0.0, 0.0, -1.0])
    q1 = c + tip_dir*LENGTH*0.35
    q2 = c + tip_dir*LENGTH*0.45 + back*LENGTH*0.6
    dist0 = np.linalg.norm(c - p0)
    split = dist0/(dist0 + LENGTH)   # share of u that lies along the blade

    def at(u):
        u = np.asarray(u, float)
        on = u < split
        out = np.empty(u.shape + (3,))
        out[on] = bezier(a, b, c, START + (1.0 - START)*(u[on]/split))
        v = (u[~on] - split)/(1.0 - split)
        out[~on] = bezier(c, q1, q2, v)
        return out
    return at, split


def surface(name, s, phase):
    at, split = stream(name, s)
    us = np.linspace(0.0, 1.0, COLUMNS + 1)
    cs = at(us)
    tang = np.gradient(cs, axis=0)
    tang /= np.linalg.norm(tang, axis=1, keepdims=True)
    side = np.array([s, 0.0, 0.0])
    across = np.cross(tang, side)
    across /= np.linalg.norm(across, axis=1, keepdims=True)
    if across[len(across)//2][1] < 0:   # the crest edge on top
        across = -across
    # Fullest a little past the tip, thin where it leaves the blade, rounding off into foam at the end.
    width = WIDTH*(0.35 + 0.65*np.sin(np.pi*np.clip(us*0.9 + 0.05, 0, 1))**0.8)*(1.0 - smoothstep(0.86, 1.0, us)*0.85)
    crest = 1.0 + 0.30*np.sin(us*21.0 + phase)*smoothstep(split, split + 0.15, us)
    rho = np.linspace(0.0, 1.0, ROWS + 1)
    verts, uv, coords = [], [], []
    for face in (1.0, -1.0):
        for ci, u in enumerate(us):
            for r in rho:
                off = -0.7 + r*(0.7 + crest[ci])   # lower edge to crest
                p = cs[ci] + across[ci]*width[ci]*off
                p = p + side*face*THICK*math.sin(math.pi*r)*(0.4 + 0.6*min(width[ci]/WIDTH, 1.0))
                verts.append(p)
                uv.append((u, r))
                coords.append((u, r))
    n = ROWS + 1
    verts = np.array(verts)
    tris = []
    for offset, face in ((0, 1.0), ((COLUMNS + 1)*n, -1.0)):
        for ci in range(COLUMNS):
            for r in range(ROWS):
                i0, i1 = offset + ci*n + r, offset + (ci + 1)*n + r
                for q in ((i0, i1, i1 + 1), (i0, i1 + 1, i0 + 1)):
                    # Each sheet faces out to its own side of the veil.
                    normal = np.cross(verts[q[1]] - verts[q[0]], verts[q[2]] - verts[q[0]])
                    tris.append(tuple(reversed(q)) if normal[0]*s*face < 0 else q)
    return verts, tris, uv, coords, split, at


def paint():
    v, u = np.mgrid[0.0:1.0:TEXTURE*1j, 0.0:1.0:TEXTURE*1j]
    share = v + 0.035*np.sin(u*53.0) + 0.02*np.sin(u*97.0 + v*13.0)
    rgb = np.zeros((TEXTURE, TEXTURE, 3)) + np.array(BANDS[0][1], float)   # below the first band too
    glow = np.zeros((TEXTURE, TEXTURE)) + BAND_GLOW[0]
    for (start, colour), strength in zip(BANDS, BAND_GLOW):
        rgb[share >= start] = colour
        glow[share >= start] = strength
    # Foam: round flecks gathering toward the end of the stream and along the crest.
    rng = np.random.default_rng(7)
    for _ in range(140):
        cu = 0.35 + 0.65*rng.random()**0.6
        cv = 0.55 + 0.4*rng.random()
        rad = 0.008 + 0.022*rng.random()*cu
        hit = ((u - cu)/1.0)**2 + ((v - cv)/2.2)**2 < (rad*0.6)**2
        rgb[hit] = FOAM
        glow[hit] = 1.0
    end = u > 0.93
    rgb[end & (v > 0.3)] = FOAM
    return rgb/255.0, glow


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    verts, tris, uvs, groups = [], [], [], {}
    wave_bones = []
    for tag, s in ea.SIDES:
        for k, name in enumerate(ea.BLADE_ORDER):
            v, t, uv, coords, split, at = surface(name, s, phase=k*1.7 + (0.9 if s < 0 else 0.0))
            base = len(verts)
            verts += [tuple(ea.blender(p)) for p in v]
            tris += [tuple(base + i for i in tri) for tri in t]
            uvs += uv
            w1, w2 = f"Water{name}1.{tag}", f"Water{name}2.{tag}"
            mid, end = split + (1 - split)*0.45, 1.0
            wave_bones.append((w1, ea.blender(at(np.array([split]))[0]), ea.blender(at(np.array([mid]))[0]),
                               f"Blade{name}2.{tag}"))
            wave_bones.append((w2, ea.blender(at(np.array([mid]))[0]), ea.blender(at(np.array([end]))[0]), w1))
            for i, (u, _) in enumerate(coords):
                on = 1.0 - float(smoothstep(split*0.6, split + 0.05, u))
                second = float(smoothstep(mid - 0.12, mid + 0.12, u))
                # Roblox drops bones that move no vertices, which would cut the chain these hang from: the first ring
                # carries a token share of Body and the blade's first bone.
                token = 0.03 if u < 1e-6 else 0.0
                for bone, value in ((f"Blade{name}2.{tag}", on), (w1, (1 - on)*(1 - second)), (w2, (1 - on)*second),
                                    ("Body", token), (f"Blade{name}1.{tag}", token)):
                    if value > 1e-3:
                        groups.setdefault(bone, []).append((base + i, value))
    mesh = bpy.data.meshes.new("AquabeekWater")
    mesh.from_pydata(verts, [], tris)
    layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            layer.data[li].uv = uvs[mesh.loops[li].vertex_index]
    mesh.shade_smooth()
    obj = bpy.data.objects.new("AquabeekWater", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for bone, entries in groups.items():
        g = obj.vertex_groups.new(name=bone)
        for i, value in entries:
            g.add([i], value, "REPLACE")

    rgb, glow = paint()
    images = {"color": er.write("aquabeek-water-color", rgb, OUT), "glow": er.write("aquabeek-water-glow", np.repeat(glow[..., None], 3, -1), OUT, True)}
    gloss = np.zeros((64, 64, 3))
    gloss[..., 0], gloss[..., 1] = 1.0, 0.2
    images["roughness"] = er.write("aquabeek-water-roughness", gloss, OUT, True)
    obj.data.materials.append(er.game_material("AquabeekWaterSkin", images))

    # The transformed form's bones, then the waves.
    arm = bpy.data.armatures.new("AquabeekWaterRig")
    rig = bpy.data.objects.new(arm.name, arm)
    bpy.context.scene.collection.objects.link(rig)
    ef.select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    spec = [b for b in ea.bones("transformed") if b[0] != "Tail"] + wave_bones   # Tail would move nothing
    for name, head, tail, parent in spec:
        b = arm.edit_bones.new(name)
        b.head, b.tail, b.roll = Vector(head), Vector(tail), 0.0
        if parent:
            b.parent = made[parent]
        made[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    er.skin(obj, rig)
    ef.face_plus_y(rig, [obj])
    ef.GAME_SCALE = ea.GAME_SCALE
    ef.scale_to_blaster(rig, [obj])
    ef.select_only([rig, obj], active=rig)
    bpy.ops.export_scene.gltf(filepath=str(OUT/"model.glb"), export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    obj.data.calc_loop_triangles()
    report = {"triangles": len(obj.data.loop_triangles), "bones": [b[0] for b in spec],
              "boneHeads": {b.name: [round(c, 4) for c in b.head_local] for b in rig.data.bones if b.name in ("Body", "BladeUpper2.L")}}
    (OUT/"report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("triangles", "boneHeads")}))


def review():
    """Against the transformed model, in Cycles like the export renders."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ea.BUILD/"transformed/model.glb"))
    bpy.ops.import_scene.gltf(filepath=str(OUT/"model.glb"))
    for m in bpy.data.materials:
        if m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    n.inputs["Emission Strength"].default_value = 0.6
    bpy.context.scene.render.engine = "CYCLES"
    er.renders(OUT)


if __name__ == "__main__":
    build()
    review()
