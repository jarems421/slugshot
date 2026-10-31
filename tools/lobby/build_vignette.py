"""Build the Phase 1 lobby style-test vignette in Blender (first-pass concept assets).

Run headless with Blender 5.2:
    blender --background --factory-startup --python tools/lobby/build_vignette.py -- <out_dir> [floppy.blend]

Units: 1 Blender unit = 1 Roblox stud. Outlines are inverted-hull Solidify shells (outward, flipped
normals, backface-culled charcoal material), the method that carries over to Roblox meshes.
Writes <out_dir>/vignette.blend, vignette.png and turnaround_<asset>_<view>.png.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = Path(ARGS[0] if ARGS else "build/lobby/vignette")
FLOPPY = Path(ARGS[1]) if len(ARGS) > 1 else None
OUT.mkdir(parents=True, exist_ok=True)

INK = (0.035, 0.032, 0.045)  # dark charcoal, not pure black (style guide §1)
OUTLINE = {"hero": 0.09, "prop": 0.07, "architecture": 0.05}


# ---------------------------------------------------------------- materials


def _socket(sockets, identifier):
    return next(s for s in sockets if s.identifier == identifier)


def _mix(nt, blend, fac, a, b):
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type, node.blend_type = "RGBA", blend
    if isinstance(fac, float):
        node.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, node.inputs["Factor"])
    for ident, value in (("A_Color", a), ("B_Color", b)):
        sock = _socket(node.inputs, ident)
        if isinstance(value, tuple):
            sock.default_value = (*value, 1.0)
        else:
            nt.links.new(value, sock)
    return _socket(node.outputs, "Result_Color")


def painted(name, dark, light, scale=0.35, top=None, top_amount=0.0, rough=0.85, metal=0.0,
            emit=None, emit_strength=0.0, under_emit=None, spots=None):
    """Stylised painted look: broad two-tone noise variation, cavity darkening, optional top tint,
    optional emissive underside and spots. Real lighting stays on top (not flat toon)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = 1.5
    nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value, ramp.inputs["From Max"].default_value = 0.38, 0.62
    nt.links.new(tex.outputs["Fac"], ramp.inputs["Value"])
    color = _mix(nt, "MIX", ramp.outputs["Result"], dark, light)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    if top:
        up = nt.nodes.new("ShaderNodeMapRange")
        up.inputs["From Min"].default_value, up.inputs["From Max"].default_value = 0.55, 0.9
        up.inputs["To Max"].default_value = top_amount
        nt.links.new(sep.outputs["Z"], up.inputs["Value"])
        color = _mix(nt, "MIX", up.outputs["Result"], color, top)
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 1.2
    color = _mix(nt, "MULTIPLY", 0.55, color, ao.outputs["AO"])
    nt.links.new(color, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    emission = None
    if emit:
        emission = (emit, emit_strength)
    if under_emit:  # glow on downward-facing surfaces (mushroom gills)
        down = nt.nodes.new("ShaderNodeMapRange")
        down.inputs["From Min"].default_value, down.inputs["From Max"].default_value = -0.1, -0.6
        nt.links.new(sep.outputs["Z"], down.inputs["Value"])
        glow = _mix(nt, "MIX", down.outputs["Result"], (0.0, 0.0, 0.0), under_emit[0])
        nt.links.new(glow, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = under_emit[1]
    if spots:  # soft glowing spots on top surfaces (mushroom cap)
        vor = nt.nodes.new("ShaderNodeTexVoronoi")
        vor.feature = "DISTANCE_TO_EDGE" if False else "F1"
        vor.inputs["Scale"].default_value = spots[2]
        nt.links.new(coord.outputs["Object"], vor.inputs["Vector"])
        dots = nt.nodes.new("ShaderNodeMapRange")
        dots.inputs["From Min"].default_value, dots.inputs["From Max"].default_value = 0.22, 0.14
        nt.links.new(vor.outputs["Distance"], dots.inputs["Value"])
        spotted = _mix(nt, "MIX", dots.outputs["Result"], color, spots[0])
        nt.links.new(spotted, bsdf.inputs["Base Color"])
        if not under_emit:
            glow = _mix(nt, "MIX", dots.outputs["Result"], (0.0, 0.0, 0.0), spots[0])
            nt.links.new(glow, bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = spots[1]
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission[0], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    return mat


def crystal_mat(name, deep, bright, strength):
    """Faceted crystal: dark root grading to a bright glowing tip along object Z."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs["Vector"])
    grad = nt.nodes.new("ShaderNodeMapRange")
    grad.inputs["From Min"].default_value, grad.inputs["From Max"].default_value = 0.0, 4.5
    nt.links.new(sep.outputs["Z"], grad.inputs["Value"])
    color = _mix(nt, "MIX", grad.outputs["Result"], deep, bright)
    nt.links.new(color, bsdf.inputs["Base Color"])
    nt.links.new(color, bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength
    bsdf.inputs["Roughness"].default_value = 0.25
    return mat


def energy_mat(name, core, edge, strength):
    """Portal membrane: swirling emissive surface, brighter at the centre."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type, wave.rings_direction = "RINGS", "SPHERICAL"
    wave.inputs["Scale"].default_value = 0.6
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 1.0
    nt.links.new(coord.outputs["Object"], wave.inputs["Vector"])
    color = _mix(nt, "MIX", wave.outputs["Fac"], edge, core)
    nt.links.new(color, bsdf.inputs["Base Color"])
    nt.links.new(color, bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def ink_material():
    mat = bpy.data.materials.new("M_Ink")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*INK, 1.0)
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(emit.outputs[0], mix.inputs[1])
    nt.links.new(clear.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mat.use_backface_culling = True
    return mat


INK_MAT = None


def outline(obj, width):
    """Inverted-hull ink shell; one per object, width in studs by importance."""
    obj.data.materials.append(INK_MAT)
    md = obj.modifiers.new("Ink", "SOLIDIFY")
    md.thickness, md.offset = width, 1.0
    md.use_flip_normals, md.use_rim, md.use_quality_normals = True, False, True
    md.material_offset = len(obj.data.materials) - 1  # indices beyond the last slot clamp to ink
    obj["ink_width_studs"] = width


# ---------------------------------------------------------------- geometry helpers


def to_object(bm, name, mat, collection, smooth_angle=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mesh.materials.append(mat)
    if smooth_angle is None:
        for p in mesh.polygons:
            p.use_smooth = False
    else:
        for p in mesh.polygons:
            p.use_smooth = True
        mesh.set_sharp_from_angle(angle=math.radians(smooth_angle))
    return obj


def chunky_rock_bm(size, seed, cuts=10, wobble=0.07):
    """Rounded mass with a few broad fracture planes: big readable shapes, not scan noise."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for _ in range(cuts):
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.5, 1.0))).normalized()
        d = rnd.uniform(0.62, 0.86)
        res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                                     plane_co=n * d, plane_no=n, clear_outer=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut:
            bmesh.ops.holes_fill(bm, edges=cut, sides=0)
    for v in bm.verts:
        v.co += v.co.normalized() * noise.noise(v.co * 1.4 + Vector((seed, 0, 0))) * wobble
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.beautify_fill(bm, faces=bm.faces[:], edges=bm.edges[:])
    return bm


def add_bevel(obj, width, segments=2, angle=30):
    md = obj.modifiers.new("Soften", "BEVEL")
    md.width, md.segments, md.limit_method = width, segments, "ANGLE"
    md.angle_limit = math.radians(angle)
    md.harden_normals = False
    obj.modifiers.move(len(obj.modifiers) - 1, 0)


def merge_rocks(parts, name, mat, collection):
    bm = bmesh.new()
    for part_bm, matrix in parts:
        part_bm.transform(matrix)
        mesh = bpy.data.meshes.new("tmp")
        part_bm.to_mesh(mesh)
        part_bm.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    return to_object(bm, name, mat, collection, smooth_angle=38)


def place(loc, rot=(0, 0, 0), scale=1.0):
    return (Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot[2], 4, "Z")
            @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X") @ Matrix.Scale(scale, 4))


def lathe_bm(profile, segments, shape=None):
    """Revolve (r, z) profile around Z. shape(theta, r, z, index) -> (r, z) allows waves/droop/gills."""
    bm = bmesh.new()
    rings = []
    for i, (r, z) in enumerate(profile):
        ring = []
        for s in range(segments):
            th = 2 * math.pi * s / segments
            rr, zz = shape(th, r, z, i) if shape else (r, z)
            ring.append(bm.verts.new((rr * math.cos(th), rr * math.sin(th), zz)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(segments):
            t = (s + 1) % segments
            bm.faces.new((a[s], a[t], b[t], b[s]))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        if profile[[0, -1][not flip]][0] > 1e-4:
            face = bm.faces.new(ring[::-1] if flip else ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


# ---------------------------------------------------------------- assets


def build_floor(col):
    mat = painted("M_CaveFloor", (0.10, 0.11, 0.14), (0.17, 0.18, 0.21), scale=0.12,
                  top=(0.13, 0.17, 0.12), top_amount=0.25)
    parts = []
    rnd = random.Random(3)
    for i in range(16):
        ang = rnd.uniform(0, 2 * math.pi)
        rad = rnd.uniform(0, 17)
        sx, sy = rnd.uniform(5, 9), rnd.uniform(4, 7)
        parts.append((chunky_rock_bm((sx, sy, 1.2), 100 + i, cuts=6, wobble=0.05),
                      place((rad * math.cos(ang), rad * math.sin(ang) * 0.7 + 2, -1.0 + rnd.uniform(-0.15, 0.15)),
                            (0, 0, rnd.uniform(0, 3)))))
    floor = merge_rocks(parts, "SM_CaveFloor", mat, col)
    add_bevel(floor, 0.25)
    outline(floor, OUTLINE["architecture"])
    return floor


def build_rock_wall(col):
    """Modular cavern wall: tiers of overlapping chunky masses; each mass gets its own ink line,
    so the seams between masses read as inked fractures."""
    mat = painted("M_CaveRock", (0.12, 0.13, 0.17), (0.22, 0.23, 0.27), scale=0.18,
                  top=(0.18, 0.24, 0.15), top_amount=0.45)
    rnd = random.Random(11)
    parts = []
    x = -10.0
    while x < 10.0:  # base tier: big blocky masses
        w = rnd.uniform(3.8, 5.5)
        parts.append((chunky_rock_bm((w * 0.6, 2.6, rnd.uniform(3.2, 4.2)), 200 + int(x * 10)),
                      place((x + w * 0.5, rnd.uniform(-0.3, 0.3), 3.0), (0, 0, rnd.uniform(-0.2, 0.2)))))
        x += w * 0.92
    x = -9.0
    while x < 9.0:  # upper tier: narrower, leaning back
        w = rnd.uniform(3.0, 4.6)
        parts.append((chunky_rock_bm((w * 0.55, 2.2, rnd.uniform(2.6, 3.6)), 300 + int(x * 10)),
                      place((x + w * 0.5, 0.8 + rnd.uniform(-0.2, 0.2), 8.3 + rnd.uniform(-0.4, 0.6)),
                            (rnd.uniform(-0.15, -0.05), 0, rnd.uniform(-0.3, 0.3)))))
        x += w * 0.9
    for i in range(4):  # cap stones and a slight overhang
        parts.append((chunky_rock_bm((rnd.uniform(2.0, 3.0), 2.0, 1.6), 400 + i),
                      place((-7 + i * 4.6 + rnd.uniform(-0.6, 0.6), 0.2, 11.8 + rnd.uniform(-0.3, 0.3)),
                            (0.25, 0, rnd.uniform(-0.4, 0.4)))))
    for i in range(5):  # fallen rubble at the foot breaks the straight base line
        s = rnd.uniform(0.7, 1.5)
        parts.append((chunky_rock_bm((s * 1.3, s, s * 0.8), 500 + i),
                      place((-9 + i * 4.2 + rnd.uniform(-1, 1), -2.9 + rnd.uniform(-0.5, 0.3), s * 0.5),
                            (0, 0, rnd.uniform(0, 3)))))
    wall = merge_rocks(parts, "SM_RockWall_A", mat, col)
    add_bevel(wall, 0.22)
    outline(wall, OUTLINE["architecture"])
    return wall


def crystal_bm(height, radius, seed, sides=6):
    rnd = random.Random(seed)
    bm = bmesh.new()
    off = rnd.uniform(0, math.pi)
    def ring(r, z):
        return [bm.verts.new((r * (1 + rnd.uniform(-0.08, 0.08)) * math.cos(off + 2 * math.pi * k / sides),
                              r * (1 + rnd.uniform(-0.08, 0.08)) * math.sin(off + 2 * math.pi * k / sides), z))
                for k in range(sides)]
    base, shoulder = ring(radius, -0.4), ring(radius * 0.9, height * rnd.uniform(0.62, 0.75))
    apex = bm.verts.new((rnd.uniform(-0.1, 0.1) * radius, rnd.uniform(-0.1, 0.1) * radius, height))
    bm.faces.new(base[::-1])
    for k in range(sides):
        j = (k + 1) % sides
        bm.faces.new((base[k], base[j], shoulder[j], shoulder[k]))
        bm.faces.new((shoulder[k], shoulder[j], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def build_crystals(col, origin):
    mat = crystal_mat("M_CrystalCyan", (0.02, 0.10, 0.16), (0.45, 0.95, 1.0), 2.2)
    rock_mat = bpy.data.materials["M_CaveRock"]
    rnd = random.Random(21)
    bm = bmesh.new()
    specs = [(4.6, 0.75, 0.0, 0.0), (3.2, 0.55, 0.45, 0.8), (2.6, 0.5, 0.5, 2.6), (3.6, 0.6, 0.35, 4.0),
             (1.8, 0.4, 0.7, 1.7), (2.1, 0.42, 0.65, 5.2), (1.3, 0.3, 0.8, 3.3)]
    for i, (h, r, tilt, yaw) in enumerate(specs):
        part = crystal_bm(h, r, 600 + i)
        part.transform(place((0.35 * math.cos(yaw), 0.35 * math.sin(yaw), 0), (tilt, 0, yaw + rnd.uniform(-0.2, 0.2))))
        mesh = bpy.data.meshes.new("tmp")
        part.to_mesh(mesh)
        part.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    crystals = to_object(bm, "SM_CrystalCluster_A", mat, col)
    crystals.location = origin
    add_bevel(crystals, 0.04, segments=1, angle=20)
    outline(crystals, OUTLINE["prop"])
    base = merge_rocks([(chunky_rock_bm((1.8, 1.5, 0.7), 650), place((0, 0, 0)))], "SM_CrystalCluster_A_Base",
                       rock_mat, col)
    base.location = origin
    add_bevel(base, 0.12)
    outline(base, OUTLINE["prop"])
    light = bpy.data.lights.new("L_CrystalGlow", "POINT")
    light.color, light.energy, light.shadow_soft_size = (0.45, 0.9, 1.0), 900, 1.0
    lo = bpy.data.objects.new("L_CrystalGlow", light)
    lo.location = Vector(origin) + Vector((0, -0.8, 2.5))
    col.objects.link(lo)
    return crystals


def build_mushroom(col, origin):
    """Original giant cave mushroom: leaning, slightly twisting stem with a root flare, a lopsided
    drooping cap with a curled lip, glowing radial gills underneath and soft glowing spots on top."""
    stem_mat = painted("M_MushroomStem", (0.55, 0.50, 0.40), (0.72, 0.68, 0.55), scale=0.5,
                       under_emit=((0.25, 0.9, 0.7), 0.0))
    cap_mat = painted("M_MushroomCap", (0.20, 0.30, 0.42), (0.30, 0.44, 0.55), scale=0.25,
                      under_emit=((0.30, 1.0, 0.75), 3.0), spots=((0.55, 1.0, 0.85), 1.6, 0.9))
    stem_h = 13.0
    def spine(t):
        return Vector((1.6 * math.sin(t * 1.4) * t, 0.6 * t * t, t * stem_h))
    def stem_r(t):
        flare = 1.9 * math.exp(-t * 9)
        bulge = 0.18 * math.sin(t * math.pi)
        return 1.05 + flare + bulge - 0.12 * t
    seg, rows = 20, 26
    bm = bmesh.new()
    rings = []
    for i in range(rows + 1):
        t = i / rows
        c = spine(t)
        twist = t * 0.9
        ring = []
        for s in range(seg):
            th = 2 * math.pi * s / seg + twist
            r = stem_r(t) * (1 + 0.06 * noise.noise(Vector((math.cos(th) * 2, math.sin(th) * 2, t * 4))))
            if t < 0.12:  # root lobes
                r *= 1 + 0.35 * max(0.0, math.sin(3 * th)) * (1 - t / 0.12)
            ring.append(bm.verts.new(c + Vector((r * math.cos(th), r * math.sin(th), 0))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(seg):
            t2 = (s + 1) % seg
            bm.faces.new((a[s], a[t2], b[t2], b[s]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    stem = to_object(bm, "SM_GiantMushroom_A_Stem", stem_mat, col, smooth_angle=80)
    stem.location = origin
    sub = stem.modifiers.new("Smooth", "SUBSURF")
    sub.levels = sub.render_levels = 1
    outline(stem, OUTLINE["hero"])

    R, H = 7.0, 3.6
    profile = [(0.0, H), (0.3 * R, 0.97 * H), (0.55 * R, 0.86 * H), (0.76 * R, 0.66 * H), (0.9 * R, 0.4 * H),
               (0.99 * R, 0.1 * H), (1.03 * R, -0.12 * H), (0.98 * R, -0.24 * H), (0.9 * R, -0.18 * H),
               (0.75 * R, -0.04 * H), (0.55 * R, 0.06 * H), (0.32 * R, 0.12 * H), (0.13 * R, 0.14 * H), (0.0, 0.14 * H)]
    underside = set(range(8, len(profile)))
    def shape(th, r, z, i):
        k = (r / R) ** 2
        r2 = r * (1 + k * (0.07 * math.sin(5 * th + 0.6) + 0.035 * math.sin(9 * th + 2.0)))
        z2 = z - 0.9 * (r / R) ** 3 * (0.6 + 0.4 * math.sin(2 * th + 1.0))  # lopsided droop
        if i in underside and 0.2 * R < r < 0.95 * R:
            z2 += 0.22 * abs(math.sin(14 * th))  # radial gill ridges
        return r2, z2
    cap = to_object(lathe_bm(profile, 72, shape), "SM_GiantMushroom_A_Cap", cap_mat, col, smooth_angle=70)
    top = spine(1.0)
    cap.location = Vector(origin) + top + Vector((0, 0, -0.6))
    cap.rotation_euler = (0.12, -0.16, 0.4)
    outline(cap, OUTLINE["hero"])
    light = bpy.data.lights.new("L_MushroomGlow", "POINT")
    light.color, light.energy, light.shadow_soft_size = (0.35, 1.0, 0.75), 1400, 3.0
    lo = bpy.data.objects.new("L_MushroomGlow", light)
    lo.location = cap.location + Vector((0, 0, -2.5))
    col.objects.link(lo)
    return cap


def chunky_box_bm(size, seed, jitter=0.08):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] * (1 + rnd.uniform(-jitter, jitter)),
                       v.co.y * size[1] * (1 + rnd.uniform(-jitter, jitter)),
                       v.co.z * size[2] * (1 + rnd.uniform(-jitter, jitter))))
    return bm


def build_portal(col, origin):
    """Cartoon-industrial gate: chunky stone voussoirs held by graphite iron bands with oversized
    bolts, an orange keystone plate, and a swirling energy membrane."""
    stone = painted("M_PortalStone", (0.24, 0.22, 0.24), (0.36, 0.33, 0.33), scale=0.4)
    iron = painted("M_Graphite", (0.10, 0.10, 0.11), (0.17, 0.17, 0.18), scale=1.2, rough=0.45, metal=0.8)
    orange = painted("M_BurntOrange", (0.55, 0.20, 0.05), (0.80, 0.33, 0.08), scale=1.0, rough=0.5, metal=0.3)
    energy = energy_mat("M_PortalEnergy", (1.0, 0.62, 0.25), (0.75, 0.18, 0.05), 4.0)
    half_w, spring, depth = 5.2, 6.5, 2.0
    path = []
    for k in range(4):  # uprights
        path.append((Vector((-half_w, 0, 0.9 + k * 1.6)), 0.0))
    n_arch = 9
    for k in range(n_arch):
        a = math.pi - math.pi * k / (n_arch - 1)
        path.append((Vector((half_w * math.cos(a), 0, spring + half_w * math.sin(a))), a - math.pi / 2))
    for k in reversed(range(4)):
        path.append((Vector((half_w, 0, 0.9 + k * 1.6)), 0.0))
    bm_stone, bm_iron, bm_orange = bmesh.new(), bmesh.new(), bmesh.new()
    def add(bm_target, part, matrix):
        part.transform(matrix)
        mesh = bpy.data.meshes.new("tmp")
        part.to_mesh(mesh)
        part.free()
        bm_target.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    for i, (p, a) in enumerate(path):
        keystone = i == 4 + n_arch // 2
        size = (0.95, depth * 0.5, 0.78) if not keystone else (0.8, depth * 0.62, 1.15)
        add(bm_stone, chunky_box_bm((size[2], size[1], size[0]), 700 + i),
            place(p, (0, -a, 0)) @ Matrix.Rotation(random.Random(i).uniform(-0.05, 0.05), 4, "Y"))
        if keystone:
            add(bm_orange, chunky_box_bm((0.7, 0.12, 0.9), 790, jitter=0.02),
                place(p + Vector((0, -depth * 0.66, 0)), (0, -a, 0)))
        if i in (1, 3, 6, 10, 13, 15):  # iron bands with chunky bolts
            add(bm_iron, chunky_box_bm((1.05, depth * 0.56, 0.28), 800 + i, jitter=0.01), place(p, (0, -a, 0)))
            for side in (-1, 1):
                bolt = bmesh.new()
                bmesh.ops.create_cone(bolt, cap_ends=True, segments=8, radius1=0.17, radius2=0.17, depth=0.16)
                add(bm_orange, bolt, place(p + Vector((0, side * depth * 0.58, 0)), (math.pi / 2, 0, 0))
                    @ Matrix.Translation((0.45 * side, 0, 0)))
    for side in (-1, 1):  # plinths
        add(bm_stone, chunky_box_bm((1.5, depth * 0.7, 0.55), 850 + side), place((side * half_w, 0, 0.0)))
    objs = []
    for bm_part, mat, name, width, ang in ((bm_stone, stone, "SM_PortalFrame_A_Stone", OUTLINE["hero"], 35),
                                           (bm_iron, iron, "SM_PortalFrame_A_Iron", OUTLINE["prop"], 35),
                                           (bm_orange, orange, "SM_PortalFrame_A_Trim", OUTLINE["prop"], 35)):
        obj = to_object(bm_part, name, mat, col, smooth_angle=ang)
        obj.location = origin
        add_bevel(obj, 0.07, segments=2, angle=40)
        outline(obj, width)
        objs.append(obj)
    inner = []
    r_in = half_w - 0.75
    for k in range(25):
        a = math.pi * k / 24
        inner.append((r_in * math.cos(a), spring + r_in * math.sin(a)))
    pts = [(r_in, 0.4)] + inner + [(-r_in, 0.4)]
    bm = bmesh.new()
    verts = [bm.verts.new((x, 0, z)) for x, z in pts]
    bm.faces.new(verts)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    membrane = to_object(bm, "SM_PortalFrame_A_Energy", energy, col)
    membrane.location = Vector(origin) + Vector((0, 0, 0))
    light = bpy.data.lights.new("L_PortalGlow", "AREA")
    light.color, light.energy, light.size = (1.0, 0.55, 0.22), 2500, 7.0
    lo = bpy.data.objects.new("L_PortalGlow", light)
    lo.location = Vector(origin) + Vector((0, -1.0, 6.5))
    lo.rotation_euler = (math.radians(90), 0, 0)
    col.objects.link(lo)
    return objs


def build_scale_refs(col, origin):
    """R6-proportioned block figure (5 studs) for scale, plus Floppy if its source is available."""
    mat = painted("M_RefFigure", (0.55, 0.56, 0.6), (0.62, 0.63, 0.67), scale=1.0)
    bm = bmesh.new()
    for size, loc in (((2, 1, 2), (0, 0, 3)), ((1, 1, 2), (-0.5, 0, 1)), ((1, 1, 2), (0.5, 0, 1)),
                      ((1, 1, 2), (-1.5, 0, 3)), ((1, 1, 2), (1.5, 0, 3)), ((1.2, 1.2, 1.0), (0, 0, 4.5))):
        part = bmesh.new()
        bmesh.ops.create_cube(part, size=1.0)
        part.transform(place(loc) @ Matrix.Diagonal((*size, 1)))
        mesh = bpy.data.meshes.new("tmp")
        part.to_mesh(mesh)
        part.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    fig = to_object(bm, "REF_R6Figure", mat, col)
    fig.location = origin
    outline(fig, OUTLINE["hero"])
    if FLOPPY and FLOPPY.is_file():
        with bpy.data.libraries.load(str(FLOPPY), link=False) as (src, dst):
            dst.objects = list(src.objects)
        meshes = [o for o in dst.objects if o is not None]
        for o in meshes:
            col.objects.link(o)
        roots = [o for o in meshes if o.parent is None]
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        bpy.context.view_layer.update()
        for o in meshes:
            if o.type == "MESH":
                for c in o.bound_box:
                    w = o.matrix_world @ Vector(c)
                    lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
        scale = 0.92 / max(hi.z - lo.z, 1e-3)  # ground Floppy is ~0.92 studs tall
        for r in roots:
            r.scale = r.scale * scale
            r.location = Vector(origin) + Vector((2.2, -0.6, -lo.z * scale))
            r.rotation_euler.z += math.radians(-150)
        for o in meshes:
            if o.type == "MESH":
                outline(o, OUTLINE["hero"] * 0.35)
    return fig


# ---------------------------------------------------------------- scene, light, cameras


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Base Contrast"
    except TypeError:
        pass
    world = bpy.data.worlds.new("Cavern")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.012, 0.014, 0.03, 1.0)  # deep blue-violet cavern ambience
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    eevee = scene.eevee
    for attr, value in (("use_shadows", True), ("use_raytracing", True), ("taa_render_samples", 64)):
        if hasattr(eevee, attr):
            setattr(eevee, attr, value)
    return scene


def key_lights(col):
    sky = bpy.data.lights.new("L_SkyShaft", "SPOT")  # cool light from above (Sky Well mood)
    sky.color, sky.energy, sky.spot_size, sky.shadow_soft_size = (0.6, 0.7, 1.0), 60000, math.radians(70), 3.0
    so = bpy.data.objects.new("L_SkyShaft", sky)
    so.location, so.rotation_euler = (-4, -6, 40), (math.radians(8), math.radians(-6), 0)
    col.objects.link(so)
    warm = bpy.data.lights.new("L_WarmPocket", "POINT")  # amber pocket of an inhabited area
    warm.color, warm.energy, warm.shadow_soft_size = (1.0, 0.62, 0.3), 2600, 1.5
    wo = bpy.data.objects.new("L_WarmPocket", warm)
    wo.location = (-12, -8, 5)
    col.objects.link(wo)
    rim = bpy.data.lights.new("L_VioletRim", "AREA")  # violet back light separates forms
    rim.color, rim.energy, rim.size = (0.55, 0.4, 1.0), 6000, 12
    ro = bpy.data.objects.new("L_VioletRim", rim)
    ro.location, ro.rotation_euler = (6, 14, 16), (math.radians(-125), 0, math.radians(20))
    col.objects.link(ro)


def camera(name, loc, target, lens=30):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_end = 500
    obj = bpy.data.objects.new(name, cam)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return obj


def render(cam, path, res=(1600, 900)):
    scene = bpy.context.scene
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    global INK_MAT
    setup_scene()
    INK_MAT = ink_material()
    root = bpy.context.scene.collection
    cols = {}
    for name in ("Environment", "RockWall", "Crystals", "Mushroom", "Portal", "ScaleRefs", "Lights"):
        cols[name] = bpy.data.collections.new(name)
        root.children.link(cols[name])
    build_floor(cols["Environment"])
    build_rock_wall(cols["RockWall"])
    for o in cols["RockWall"].objects:
        o.location = (0, 12, 0)
    build_crystals(cols["Crystals"], (-10.5, 1.5, 0.0))
    build_mushroom(cols["Mushroom"], (9.5, 5.0, 0.0))
    build_portal(cols["Portal"], (-1.5, 7.5, 0.0))
    build_scale_refs(cols["ScaleRefs"], (0.5, -3.0, 0.0))
    key_lights(cols["Lights"])
    bpy.context.view_layer.update()

    render(camera("CAM_Vignette", (2, -30, 10), (0, 4, 5.5), lens=28), OUT / "vignette.png")
    render(camera("CAM_ThirdPerson", (0.5, -12, 7), (0.5, 6, 4.5), lens=24), OUT / "third_person.png")

    targets = {"rockwall": ("RockWall", (0, 12, 6), 30), "crystals": ("Crystals", (-10.5, 1.5, 2.2), 11),
               "mushroom": ("Mushroom", (9.5, 5.5, 8.5), 32), "portal": ("Portal", (-1.5, 7.5, 6), 22)}
    for key, (col_name, centre, dist) in targets.items():
        for other in cols:
            if other not in (col_name, "Lights", "Environment"):
                cols[other].hide_render = True
        for view, ang in (("front", -90), ("right", 0), ("back", 90), ("threequarter", -50)):
            a = math.radians(ang)
            loc = Vector(centre) + Vector((dist * math.cos(a), dist * math.sin(a), dist * 0.25))
            render(camera(f"CAM_{key}_{view}", loc, centre, lens=35), OUT / f"turnaround_{key}_{view}.png",
                   res=(800, 800))
        for other in cols:
            cols[other].hide_render = False
    bpy.context.scene.camera = bpy.data.objects["CAM_Vignette"]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "vignette.blend"))
    print("VIGNETTE_DONE", OUT)


main()
