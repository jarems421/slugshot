"""Inferno's 3D fire effects, run with Blender (4.5): comic fire along the back edge of each dragon wing, and one
explosion. Both are original shapes with hard ink-style colour bands.

Writes build/slugs/inferno/wing-fire: model.glb, colour with alpha (tips thin out into the air) and glow mask, plus review
views; and build/slugs/inferno/explosion: model.glb, colour and glow mask. It is a separate model on the
same skeleton positions as the dragon (bones of the same names), so the approved dragon model is untouched and the game
can clip it on for flight only. The body's outline runs round it. Nothing is uploaded here; see tools/slugs/upload_wing_fire.py.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_floppy as bf
import build_inferno as bi
import export_floppy_roblox as ef
from build_floppy import smoothstep, to_blender

OUT = bi.BUILD/"wing-fire"
LIFT = np.array([0.0, 1.2, 0.0])
FROM_T, TO_T = 0.07, 0.97  # of the wing's span
INSIDE = 0.74  # the root line sits this far along the wing's chord, so the fire grows out from under it
LENGTH = 2.25  # concept units, at its longest
THICK = 0.17
COLUMNS, ROWS = 96, 12
STATIONS = 7  # ripple bones along the span, two deep
BACK = bi.normalize(0.3*bi.Dragon.C + 0.7*np.array([0.0, 0.0, -1.0]))
# Tip position along the span, half width, height, and how far it curls up off the wing.
# Heights stay close, so the fire is about as long at the wing tip as at the root (owner).
TONGUES = ((0.13, 0.20, 0.92, 0.14), (0.34, 0.23, 1.00, 0.05), (0.57, 0.20, 0.94, 0.16),
           (0.78, 0.17, 1.00, 0.06), (0.93, 0.10, 0.9, 0.10))
TEXTURE_W, TEXTURE_H = bi.TEXTURE, bi.TEXTURE
# Share of the local flame's length where each hard colour band starts. Root blends with the wing's own colour.
BANDS = ((0.0, (222, 62, 22)), (0.12, (255, 128, 26)), (0.26, (255, 204, 62)), (0.36, (255, 240, 165)),
         (0.47, (255, 204, 62)), (0.6, (255, 128, 26)), (0.82, (214, 44, 18)))


def tooth(u):
    """Height of the flame at u along the span, 0 to 1: sharp tongues rising out of a low body."""
    u = np.asarray(u, float)
    best = np.zeros_like(u)
    for at, half, height, _ in TONGUES:
        best = np.maximum(best, height*np.clip(1.0 - np.abs(u - at)/half, 0.0, 1.0)**0.95)
    ends = smoothstep(0.0, 0.05, u)*(1.0 - smoothstep(0.95, 1.0, u))
    return ends*(0.3 + 0.7*best)


def curl(u):
    """How far this part of the span lifts off the wing: tongues alternate, which gives a crown seen from behind."""
    u = np.asarray(u, float)
    total, weight = np.zeros_like(u), np.zeros_like(u)
    for at, half, _, lift in TONGUES:
        w = np.clip(1.0 - np.abs(u - at)/half, 0.0, 1.0)**2 + 1e-4
        total, weight = total + lift*w, weight + w
    return total/weight


def edge(t):
    d = bi.Dragon
    return d.ROOT_W + np.outer(t*d.SPAN, d.S) + np.outer(1.50*(1.0 - t)**0.62*INSIDE, d.C) + LIFT


def surface(side):
    """Vertices (concept space), triangles, uv and (u, rho) for each vertex of one closed wing's fire."""
    d = bi.Dragon
    us = np.linspace(0.0, 1.0, COLUMNS + 1)
    rho = np.linspace(0.0, 1.0, ROWS + 1)
    t = FROM_T + us*(TO_T - FROM_T)
    base = edge(t)
    long = LENGTH*tooth(us)
    verts, uv, coords = [], [], []
    for face in (1.0, -1.0):
        for c, u in enumerate(us):
            for r in rho:
                reach = long[c]*r
                p = base[c] + BACK*reach + d.N*(float(curl(np.array([u]))[0])*(reach/LENGTH)**1.6*LENGTH*0.5)
                # Every lick sweeps out toward the wing tip and wavers, so they read as moving fire, not a row of teeth.
                p = p + d.S*(0.62*(reach/LENGTH)**1.8 + 0.07*math.sin(reach/LENGTH*7.0 + u*11.0)*(reach/LENGTH))
                p = p + d.N*face*THICK*math.sin(math.pi*r**0.72)*min(long[c]/(LENGTH*0.35), 1.0)
                verts.append(p*np.array([side, 1.0, 1.0]))
                uv.append((u, reach/LENGTH))
                coords.append((u, r))
    n = ROWS + 1
    tris = []
    for offset, flip in ((0, False), ((COLUMNS + 1)*n, True)):
        for c in range(COLUMNS):
            for r in range(ROWS):
                a, b = offset + c*n + r, offset + (c + 1)*n + r
                quad = ((a, b, b + 1), (a, b + 1, a + 1))
                tris += [tuple(reversed(q)) if flip else q for q in quad]
    return np.array(verts), np.array(tris), uv, coords


# Glow strength for each band, in the same order: the hot middle glows most.
BAND_GLOW = (0.55, 0.8, 1.0, 1.0, 1.0, 0.8, 0.55)


def paint():
    """Colour, glow and alpha by where a point falls along its own lick, so the bands follow the tongues."""
    v, u = np.mgrid[0.0:1.0:TEXTURE_H*1j, 0.0:1.0:TEXTURE_W*1j]
    long = np.maximum(tooth(u), 1e-3)
    share = v/long + 0.03*np.sin(u*47.0) + 0.02*np.sin(u*91.0 + v*20.0)
    rgb = np.zeros((TEXTURE_H, TEXTURE_W, 3))
    glow = np.zeros((TEXTURE_H, TEXTURE_W))
    for (start, colour), strength in zip(BANDS, BAND_GLOW):
        rgb[share >= start] = colour
        glow[share >= start] = strength
    # Solid. Fading the tips washed them pale against the sky, and the outline traced the fade's edge in steps; a ragged
    # fade also cut a saw edge into every lick. The glow and cinders round it do the blending into the air.
    alpha = np.ones_like(share)
    return rgb/255.0, glow, alpha


def write_rgba(name, rgb, alpha, out):
    """An sRGB colour image with alpha. `rgb` is already display colour."""
    size = rgb.shape[0]
    image = bpy.data.images.new(name, size, size, alpha=True)
    image.alpha_mode = "STRAIGHT"
    # Blender rows run bottom up; the texture is laid out with v = 0 at the root, which is the bottom row.
    image.pixels.foreach_set(np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1).astype(np.float32).ravel())
    path = out/"textures"/(name + ".png")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def bones():
    d = bi.Dragon
    out = []
    root = next(b for b in d().bones() if b[0] == "root")
    out.append(root)
    for side, tag in ((-1.0, "L"), (1.0, "R")):
        for b in d().bones():
            if b[0] in ("wing_" + tag, "wing_tip_" + tag):
                out.append(b)
        sign = np.array([side, 1.0, 1.0])
        for i in range(STATIONS):
            u = i/(STATIONS - 1)
            t = FROM_T + u*(TO_T - FROM_T)
            base = edge(np.array([t]))[0]
            parent = "wing_" + tag if t < 0.5 else "wing_tip_" + tag
            for row, share in ((1, 0.45), (2, 0.9)):
                head = base + BACK*(LENGTH*share*float(tooth(np.array([u]))[0]))
                name = f"wfire_{tag}_{i + 1}_{row}"
                out.append((name, tuple(to_blender(head*sign)), tuple(to_blender((head + BACK*0.2)*sign)), parent))
                parent = name
    return out


def weights(coords, tag):
    out = {}

    def add(name, index, value):
        if value > 1e-3:
            out.setdefault(name, []).append((index, float(value)))
    for index, (u, r) in enumerate(coords):
        t = FROM_T + u*(TO_T - FROM_T)
        tip = float(smoothstep(0.42, 0.58, t))
        at = u*(STATIONS - 1)
        low = min(int(at), STATIONS - 2)
        along = at - low
        if r <= 0.5:
            share = r*2.0
            add("wing_" + tag, index, (1.0 - share)*(1.0 - tip))
            add("wing_tip_" + tag, index, (1.0 - share)*tip)
            add(f"wfire_{tag}_{low + 1}_1", index, share*(1.0 - along))
            add(f"wfire_{tag}_{low + 2}_1", index, share*along)
        else:
            share = r*2.0 - 1.0
            add(f"wfire_{tag}_{low + 1}_1", index, (1.0 - share)*(1.0 - along))
            add(f"wfire_{tag}_{low + 2}_1", index, (1.0 - share)*along)
            add(f"wfire_{tag}_{low + 1}_2", index, share*(1.0 - along))
            add(f"wfire_{tag}_{low + 2}_2", index, share*along)
    return out


class Rig:
    name = "wingFire"

    @staticmethod
    def bones():
        return bones()


def review(out):
    """Light renders against the real dragon, from the views the player gets, with no GPU path tracing."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(bi.BUILD/"dragon/model.glb"))
    bpy.ops.import_scene.gltf(filepath=str(out/"model.glb"))
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (0.45, 0.72, 0.82)
    scene.render.resolution_x, scene.render.resolution_y = 640, 480
    points = [o.matrix_world @ v.co for o in scene.objects if o.type == "MESH" and o.name.startswith("Inferno") for v in o.data.vertices]
    centre = sum(points, type(points[0])())/len(points)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 60
    scene.collection.objects.link(cam)
    scene.camera = cam
    from mathutils import Vector
    for name, way in (("back", (0, -1, 0.12)), ("back-high", (0, -1, 0.5)), ("three-quarter-back", (0.7, -1, 0.3)), ("side", (1, -0.05, 0.1)),
                      ("top", (0, -0.2, 1)), ("front", (0.2, 1, 0.1))):
        offset = Vector(way).normalized()*5.2
        cam.location = centre + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out/"renders"/(name + ".png"))
        bpy.ops.render.render(write_still=True)


EXPLOSION_OUT = bi.BUILD/"explosion"
# Direction (azimuth, elevation in turns) and length of each point: uneven, so it reads as a burst, not a star.
# Points spread evenly round the sphere (a golden-angle spiral), each its own length, so it reads as a burst, not a star.
POINTS = tuple((((k*0.618034) % 1.0), (1.0 - 2.0*(k + 0.5)/22)*0.5, (1.0, 0.7, 0.88, 0.62, 0.95, 0.76)[k % 6]) for k in range(22))
# The core runs pale to yellow along each lobe, in the left half of the texture. Rims are inside-out shells of growing size,
# so they show only round the edge from any side, as the drawn bands did: thickness, colour and glow.
EXPLOSION_CORE = ((0.0, (255, 240, 165)),)
EXPLOSION_RIMS = ((0.05, (255, 204, 62), 1.0), (0.1, (255, 128, 26), 0.85), (0.15, (214, 44, 18), 0.6),
                  (0.175, (58, 12, 14), 0.0))
CORE = 0.4  # radius of the body the points grow out of
LOBE = 0.44  # radians: how broad each point is at its base


def build_explosion():
    """One spiky fireball, coloured in bands from a pale core out to inked points. About 2 units across."""
    import bmesh
    bf.reset()
    EXPLOSION_OUT.mkdir(parents=True, exist_ok=True)
    mesh = bpy.data.meshes.new("InfernoExplosion")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=5, radius=1.0)
    ways = []
    for azimuth, elevation, length in POINTS:
        a, e = azimuth*2*math.pi, math.asin(max(-1.0, min(1.0, elevation*2.0)))
        ways.append((np.array([math.cos(e)*math.cos(a), math.cos(e)*math.sin(a), math.sin(e)]), length))
    bm.verts.index_update()
    share = {}
    for v in bm.verts:
        d = np.array(v.co)/max(v.co.length, 1e-6)
        # Broad lobes that merge into each other, each pinched to a point, like the drawn explosion's petals.
        total = 0.0
        for way, length in ways:
            angle = math.acos(max(-1.0, min(1.0, float(d @ way))))
            total += (length*max(0.0, 1.0 - angle/LOBE)**1.8)**4
        best = total**0.25
        v.co = tuple(d*(CORE + (1.0 - CORE)*best))
        # How far along its own lobe this point is, so every lobe runs pale to red whatever its length.
        reach = max(length*max(0.0, 1.0 - math.acos(max(-1.0, min(1.0, float(d @ way))))/LOBE)**1.8 > 0 and length or 0.0
                    for way, length in ways)
        share[v.index] = best/max(reach, 1e-3) if reach > 0 else 0.0
    layer = bm.loops.layers.uv.new()
    for f in bm.faces:
        for loop in f.loops:
            loop[layer].uv = (min(max(share[loop.vert.index], 0.0), 1.0)*0.48 + 0.01, 0.5)
    core = list(bm.faces)
    bm.normal_update()
    for index, (offset, _, _) in enumerate(EXPLOSION_RIMS):
        rim = bmesh.ops.duplicate(bm, geom=list(bm.verts[:]) if False else [f for f in core] + list({v for f in core for v in f.verts}) + list({e for f in core for e in f.edges}))
        made = [g for g in rim["geom"] if isinstance(g, bmesh.types.BMVert)]
        # Straight out from the centre, not along the surface: every direction keeps one surface, so no shell folds over.
        for v in made:
            v.co = v.co*(1.0 + offset/max(v.co.length, 1e-6))
        faces = [g for g in rim["geom"] if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=faces)
        u = 0.5 + (index + 0.5)/len(EXPLOSION_RIMS)*0.5
        for f in faces:
            for loop in f.loops:
                loop[layer].uv = (u, 0.5)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("InfernoExplosion", mesh)
    bpy.context.collection.objects.link(obj)
    size = 256
    u = np.tile(np.linspace(0.0, 1.0, size), (size, 1))
    rgb, glow = np.zeros((size, size, 3)), np.zeros((size, size))
    for start, colour in EXPLOSION_CORE:
        rgb[u >= start*0.5] = colour
        glow[u >= start*0.5] = 1.0
    for index, (_, colour, strength) in enumerate(EXPLOSION_RIMS):
        band = u >= 0.5 + index/len(EXPLOSION_RIMS)*0.5
        rgb[band] = colour
        glow[band] = strength
    image = write_rgba("explosion-color", rgb/255.0, np.ones((size, size)), EXPLOSION_OUT)
    bi.write_image("explosion-glow", np.repeat(glow[..., None], 3, -1), EXPLOSION_OUT, "Non-Color")
    mat = bpy.data.materials.new("InfernoExplosionMat")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    obj.data.materials.append(mat)
    ef.select_only([obj])
    bpy.ops.object.shade_smooth()
    bpy.ops.export_scene.gltf(filepath=str(EXPLOSION_OUT/"model.glb"), export_format="GLB", use_selection=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = scene.render.resolution_y = 480
    scene.display.shading.show_backface_culling = True  # as Roblox draws it, or the rims cover the core
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    from mathutils import Vector
    for name, way in (("front", (0, -1, 0.2)), ("top", (0.2, -0.3, 1)), ("side", (1, 0.3, -0.2))):
        offset = Vector(way).normalized()*5.5
        cam.location = offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(EXPLOSION_OUT/"renders"/(name + ".png"))
        bpy.ops.render.render(write_still=True)
    print("PASS: explosion built", len(mesh.polygons), "faces")


def main():
    if "--explosion" in sys.argv:
        build_explosion()
        return
    OUT.mkdir(parents=True, exist_ok=True)
    ef.OUT = OUT
    ef.GAME_SCALE = bi.GAME_SCALE
    bf.reset()
    rig = bi.build_rig(Rig)
    colour, glow, alpha = paint()
    image = write_rgba("wing-fire-color", colour, alpha, OUT)
    bi.write_image("wing-fire-glow", np.repeat(glow[..., None], 3, -1), OUT, "Non-Color")
    meshes = []
    for side, tag in ((-1.0, "L"), (1.0, "R")):
        verts, tris, uv, coords = surface(side)
        centre = verts.mean(axis=0)
        meshes.append(bi.skinned_sheet(f"InfernoWingFire{tag}", verts, tris, uv, weights(coords, tag),
                                       lambda _index: np.array([0.0, 1.0, 0.0]), rig, image))
        obj = meshes[-1]
        # Weld the seams between its two faces, then turn every face outward: Roblox culls back faces.
        ef.select_only([obj])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-4)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        ef.select_only([obj])
        bpy.ops.object.shade_smooth()
        print(obj.name, "centre", centre.round(2), "triangles", len(obj.data.polygons))
    ef.face_plus_y(rig, meshes)
    ef.scale_to_blaster(rig, meshes)
    ef.select_only([rig] + meshes, active=rig)
    glb = OUT/"model.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    names = sorted(b.name for b in rig.data.bones)
    review(OUT)
    # The reimport inside review keeps every bone name the game will drive.
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    assert any(sorted(b.name for b in a.data.bones) == names for a in armatures), "bones changed on reimport"
    for m in bpy.context.scene.objects:
        if m.type == "MESH" and m.name.startswith("InfernoWingFire"):
            worst = max(len([g for g in v.groups if g.weight > 1e-5]) for v in m.data.vertices)
            assert worst <= 4, (m.name, worst)
    print("PASS: wing fire built", len(names), "bones")


if __name__ == "__main__":
    main()
