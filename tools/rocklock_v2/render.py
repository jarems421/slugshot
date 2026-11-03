"""Blender previews of the built Rocklock v2 map (build/rocklock-v2/generated/map.rbxmx).

blender -b --factory-startup -P render.py -- <out_dir> [test] [ONLY=prefix,...]
Rebuilds every visible part with its colour, adds the runtime earth zones (Terrain is
filled by the server at run time), map lights and a sun through the ceiling holes, and
renders overview cutaways, player-height views, the three tiers, routes and before/after
destruction pairs. "After" views hide every destructible and add the predicted rubble
from build/rocklock-v2/preview.json (the game computes real landings with raycasts).
Roblox (x, y, z) maps to Blender (x, -z, y). These are design previews, not Studio captures.
"""
import json
import math
import os
import sys
import xml.etree.ElementTree as ET

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
TEST = "test" in argv[1:]
ONLY = [p for a in argv[1:] if a.startswith("ONLY=") for p in a[5:].split(",") if p]
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

MAP = os.path.join(ROOT, "build", "rocklock-v2", "generated", "map.rbxmx")
PREVIEW = json.load(open(os.path.join(ROOT, "build", "rocklock-v2", "preview.json")))
CUT = 40.0
AMBIENT = 6.5
os.makedirs(OUT, exist_ok=True)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)
scene = bpy.context.scene


def rb(x, y, z):
    return Vector((x, -z, y))


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


parts = []  # (group, cls, cf, size, rgb)
lights = []


def walk(item, folder, parent_cf):
    cls = item.get("class")
    props = item.find("Properties")
    name = props.findtext("string[@name='Name']") if props is not None else ""
    cf = parent_cf
    if cls == "Folder":
        folder = name
    if props is not None and cls in ("Part", "WedgePart"):
        node = props.find("CoordinateFrame[@name='CFrame']")
        cf = [float(node.findtext(k)) for k in ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
        size = [float(props.find("Vector3[@name='size']").findtext(k)) for k in ("X", "Y", "Z")]
        tr = float(props.findtext("float[@name='Transparency']") or 0)
        c3 = props.find("Color3[@name='Color']")
        rgb = tuple(float(c3.findtext(k)) for k in ("R", "G", "B"))
        if tr < 0.95:
            parts.append(("destructible" if folder == "Destructibles" else "static", cls, cf, size, rgb))
    elif props is not None and cls == "PointLight" and parent_cf:
        c3 = props.find("Color3[@name='Color']")
        lights.append((parent_cf[:3], tuple(float(c3.findtext(k)) for k in ("R", "G", "B")),
                       float(props.findtext("float[@name='Brightness']") or 1), float(props.findtext("float[@name='Range']") or 16)))
    for child in item.findall("Item"):
        walk(child, folder, cf)


for item in ET.parse(MAP).getroot().findall("Item"):
    walk(item, "", None)
for z in L.TERRAIN:
    (x0, y0, z0), (x1, y1, z1) = z["min"], z["max"]
    cf = [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, 1, 0, 0, 0, 1, 0, 0, 0, 1]
    parts.append(("static", "Part", cf, [x1 - x0, y1 - y0, z1 - z0], (122 / 255, 98 / 255, 74 / 255)))
for r in PREVIEW["rubble"]:
    a = math.radians(r["yaw"])
    cf = [*r["pos"], math.cos(a), 0, math.sin(a), 0, 1, 0, -math.sin(a), 0, math.cos(a)]
    parts.append(("rubble", "Part", cf, list(r["size"]), (152 / 255, 132 / 255, 108 / 255)))

BOX = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
BOX_F = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)]
WEDGE = [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1), (-1, 1, 1), (1, 1, 1)]
WEDGE_F = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]


def build(name, items, cut):
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    for _, cls, cf, size, rgb in items:
        x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
        verts, faces = (WEDGE, WEDGE_F) if cls == "WedgePart" else (BOX, BOX_F)
        hs = [s / 2 for s in size]
        world = []
        for lx, ly, lz in verts:
            px, py, pz = lx * hs[0], ly * hs[1], lz * hs[2]
            world.append((x + r00 * px + r01 * py + r02 * pz, y + r10 * px + r11 * py + r12 * pz, z + r20 * px + r21 * py + r22 * pz))
        if cut and max(v[1] for v in world) > CUT:
            continue
        vs = [bm.verts.new(rb(*v)) for v in world]
        colour = (lin(rgb[0]), lin(rgb[1]), lin(rgb[2]), 1.0)
        for f in faces:
            try:
                face = bm.faces.new([vs[i] for i in f])
            except ValueError:
                continue
            for loop in face.loops:
                loop[col] = colour
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def stone_material():
    m = bpy.data.materials.new("Stone")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.3
    noise.inputs["Detail"].default_value = 6
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.3
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(attr.outputs["Color"], mix.inputs["A"])
    nt.links.new(noise.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
    amb = nt.nodes.new("ShaderNodeMix")
    amb.data_type, amb.blend_type = "RGBA", "MULTIPLY"
    amb.inputs["Factor"].default_value = 1.0
    amb.inputs["B"].default_value = (lin(0.36), lin(0.33), lin(0.30), 1)
    nt.links.new(mix.outputs["Result"], amb.inputs["A"])
    nt.links.new(amb.outputs["Result"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = AMBIENT
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.2
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 3
    nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])
    nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    p.inputs["Roughness"].default_value = 0.88
    return m


stone = stone_material()
groups = {}
for state in ("before", "after"):
    for cut in (False, True):
        items = [p for p in parts if p[0] == "static" or (p[0] == "destructible") == (state == "before") and p[0] != "static"]
        items = [p for p in parts if p[0] == "static" or (state == "before" and p[0] == "destructible")
                 or (state == "after" and p[0] == "rubble")]
        ob = build(f"Map_{state}_{'cut' if cut else 'full'}", items, cut)
        ob.data.materials.append(stone)
        groups[(state, cut)] = ob

for (x, y, z), rgb, brightness, rng in lights:
    ld = bpy.data.lights.new("MapLight", "POINT")
    ld.color = rgb
    ld.energy = 2200 * brightness * (rng / 44) ** 2
    ld.shadow_soft_size = 2.0
    ob = bpy.data.objects.new("MapLight", ld)
    ob.location = rb(x, y, z)
    scene.collection.objects.link(ob)
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 4.5
sun.color = (1.0, 0.93, 0.82)
sun.angle = math.radians(1.5)
sun_ob = bpy.data.objects.new("Sun", sun)
sun_ob.rotation_euler = (math.radians(22), math.radians(-8), math.radians(35))
scene.collection.objects.link(sun_ob)

world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (lin(0.62), lin(0.58), lin(0.54), 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 16 if TEST else 40
scene.eevee.shadow_ray_count = 2
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = 1.4
scene.render.resolution_x, scene.render.resolution_y = (960, 540) if TEST else (1920, 1080)
scene.render.image_settings.file_format = "PNG"
cam_d = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam
cam_d.clip_end = 2000


def shot(name, eye, target, state="before", cut=False, lens=20, ortho=None):
    if ONLY and not any(name.startswith(o) for o in ONLY):
        return
    for key, ob in groups.items():
        ob.hide_render = key != (state, cut)
    cam_d.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        cam_d.ortho_scale = ortho
    cam_d.lens = lens
    cam.location = rb(*eye)
    cam.rotation_euler = (rb(*target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SHOT", name, flush=True)


VIEWS = [
    ("01-overview-top", (0, 300, 0.01), (0, 0, 0), "before", True, 24, 170),
    ("02-overview-northwest", (-120, 120, -110), (5, 0, 5), "before", True, 22, None),
    ("03-overview-southeast", (125, 115, 110), (-5, 0, -5), "before", True, 22, None),
    ("04-north-spawn", (0, L.MIDDLE + 9, -54), (0, 6, -8), "before", False, 18, None),
    ("05-lower-collapse", (-7, 2.5, -19), (4, 11, 4), "before", False, 15, None),
    ("06-middle-east-shelves", (60, L.MIDDLE + 6, -44), (50, 10, 4), "before", False, 18, None),
    ("07-high-eyrie", (-55, L.HIGH + 6, -5), (10, 16, 4), "before", False, 18, None),
    ("08-route-wallrun", (-48, L.MIDDLE + 6, -50), (-57, 18, 0), "before", False, 18, None),
    ("09-route-lower-passage", (14, L.PIT + 3, 0), (40, L.PIT + 2, 0), "before", False, 16, None),
    ("10-high-spire", (64, L.HIGH + 6, 4), (-10, 10, -2), "before", False, 18, None),
    ("11-centre-before", (-40, 30, -42), (2, 8, 4), "before", False, 18, None),
    ("12-centre-after", (-40, 30, -42), (2, 8, 4), "after", False, 18, None),
    ("13-east-bridge-before", (32, 22, -30), (52, 6, 4), "before", False, 18, None),
    ("14-east-bridge-after", (32, 22, -30), (52, 6, 4), "after", False, 18, None),
    ("15-west-lane-before", (-16, 9, -46), (-40, 6, 6), "before", False, 18, None),
    ("16-west-lane-after", (-16, 9, -46), (-40, 6, 6), "after", False, 18, None),
]
# Cameras were placed on the first 140 x 112 draft; layout.K scales them with the map.
VIEWS = [(n, (e[0] * L.K, e[1], e[2] * L.K), (t[0] * L.K, t[1], t[2] * L.K), st, cut, lens,
          ortho * L.K if ortho else None) for n, e, t, st, cut, lens, ortho in VIEWS]
for v in (VIEWS[1:2] + VIEWS[4:5] if TEST else VIEWS):
    shot(*v)
print("RENDER_DONE")
