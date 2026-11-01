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
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT
from blender_pipeline import EXPORT_SETTINGS
from build_floppy import EYE_DIM, belly_folds, eye_basis, eye_local, mouth_local, smoothstep

SOURCE = ROOT/"assets/source/slugs/models/floppy/floppy-repaired.blend"
OUT = ROOT/"build/slugs/floppy/roblox"
BODY_TRIANGLES = 8000
EYE_TRIANGLES = 400
TEXTURE = 1024
BULB_GLOW = (0.62, 0.80, 0.28)  # antenna-bulb glow colour, as in build_floppy.BULB_GLOW
BULB_GLOW_STRENGTH = 2.0
# Slugshot look: Floppy carries an inverted-hull ink shell (owner, 2026-11-01: characters are always inked).
INK_WIDTH = 0.011  # studs, at game scale
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
# Rolled or diving, the flat base read as a "sawn off disc" (owner, 2026-11-01). Dome it below the
# ground plane, where it stays hidden while standing. Body colour with folds running straight across
# it like a slug's foot: anything radial or dark converges on the middle and reads as a hole. Source units.
UNDERSIDE_DEPTH = 0.3
FACE_DETAIL_GROUP = "face_detail"
FACE_DETAIL_WEIGHT = 0.85
EYE_INK_CLEAR = 1.3  # in eye radii: no hull at all this close to an eye
EYE_INK_FRONT = 1.6  # and none on front-facing skin out to here; the head's outer outline stays
LID_LINE = 0.014  # painted eyelid rim, source units
LID_LINE_COLOUR = (0.045, 0.045, 0.05)
LID_LINE_FACING = 0.55
LID_CONTOUR_COLOUR = (0.27, 0.29, 0.14)  # the rest of each lid: a soft contour, not an ink ring
LID_CONTOUR_STRENGTH = 0.7
UNDERSIDE_FLAT_Z = 0.012
UNDERSIDE_RINGS = 28
UNDERSIDE_ROW_SPACING = 0.04
UNDERSIDE_BLEND_TOP = 0.03
UNDERSIDE_FOLD_SPACING = 0.2
UNDERSIDE_FOLD_DEPTH = 0.03
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


def reduce(obj, target, keep=None):
    select_only([obj])
    mod = obj.modifiers.new("Reduce", "DECIMATE")
    mod.ratio = min(1.0, target/triangles(obj))
    if keep:
        # Decimate reads a higher weight as easier to collapse, and zero as never collapse.
        mod.vertex_group = keep
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def face_detail_group(high):
    """Weights the reduction away from the lids and mouth, whose rims must stay clean to deform well."""
    co = np.empty(len(high.data.vertices)*3)
    high.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    p = np.stack([co[:, 0], co[:, 2], -co[:, 1]], -1)
    near = np.zeros(len(p), dtype=bool)
    for side in (-1.0, 1.0):
        near |= np.linalg.norm(eye_local(p, side)/EYE_DIM, axis=1) < 1.45
    q = mouth_local(p)
    near |= (np.abs(q[:, 0]) < 0.3) & (np.abs(q[:, 1]) < 0.16) & (p[:, 2] > 0.3)
    group = high.vertex_groups.new(name=FACE_DETAIL_GROUP)
    group.add(np.where(~near)[0].tolist(), 1.0, "REPLACE")
    group.add(np.where(near)[0].tolist(), FACE_DETAIL_WEIGHT, "REPLACE")
    return FACE_DETAIL_GROUP


def low_copy(high, name, target, keep=None):
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    bpy.context.collection.objects.link(low)
    reduce(low, target, keep)
    if keep:
        low.vertex_groups.remove(low.vertex_groups[keep])
    repair_surface(low)
    select_only([low])
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    return low


def repair_surface(obj):
    """Replace tiny self-touching surface-net junctions before UVs and baking.

    Recalculating normals alone cannot orient an edge shared by four faces.
    Open a one-ring patch around those junctions, cap its boundary, then weld
    numerical duplicates. The approved high-detail source is never overwritten.
    """
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv_layer = bm.loops.layers.uv.active
    # Preserve the source's existing paint when repairing the authored variant.
    # Low-poly UVs are subsequently unwrapped and baked again.
    original = obj.data
    original.calc_loop_triangles()
    triangles = list(original.loop_triangles)
    tree = BVHTree.FromPolygons([v.co for v in original.vertices],
                               [t.vertices for t in triangles], all_triangles=True)
    bad = [edge for edge in bm.edges if len(edge.link_faces) > 2]
    faces = {face for edge in bad for face in edge.link_faces}
    for face in list(faces):
        for vertex in face.verts:
            faces.update(vertex.link_faces)
    if faces:
        bmesh.ops.delete(bm, geom=list(faces), context="FACES")
        caps = bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=64)["faces"]
        if uv_layer:
            for face in caps:
                _, _, index, _ = tree.find_nearest(face.calc_center_median())
                triangle = triangles[index]
                points = [original.vertices[i].co for i in triangle.vertices]
                uvs = [Vector((*original.uv_layers.active.data[i].uv, 0)) for i in triangle.loops]
                for loop in face.loops:
                    loop[uv_layer].uv = barycentric_transform(loop.vert.co, *points, *uvs).xy
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-5)
    if any(e.is_boundary for e in bm.edges):
        bmesh.ops.triangle_fill(bm, edges=[e for e in bm.edges if e.is_boundary], use_beauty=True)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    print("repair metrics", obj.name, "boundary", sum(e.is_boundary for e in bm.edges), "overfull", sum(len(e.link_faces)>2 for e in bm.edges), "winding", sum(e.is_manifold and not e.is_contiguous for e in bm.edges))
    assert all(e.is_manifold and e.is_contiguous for e in bm.edges), f"Unrepaired surface: {obj.name}"
    assert all(f.calc_area() > 1e-12 for f in bm.faces), f"Degenerate face: {obj.name}"
    for face in bm.faces:
        face.smooth = True
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


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


def colour_texture(material):
    """The image feeding the skin's base colour (the skin also carries the bulb glow mask)."""
    shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    link = next(ln for ln in material.node_tree.links if ln.to_socket == shader.inputs["Base Color"])
    return link.from_node.image


def glow_texture(material):
    """The antenna-bulb glow mask added by paint_floppy_spores.py / build_floppy.py, if any."""
    return next((n.image for n in material.node_tree.nodes
                 if n.type == "TEX_IMAGE" and n.image and n.image.name.startswith("floppy-body-glow")), None)


def emission_of(material, image=None):
    """A material that emits an image (by default the skin's colour texture), for baking it onto the game body."""
    mat = bpy.data.materials.new("BakeColour")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    t = nodes.new("ShaderNodeTexImage")
    t.image = image or colour_texture(material)
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


def body_heights(body):
    co = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)[:, 2]


def bake_vertex_values(body, name, rgb, precise=False):
    """Bake one colour per vertex onto the body's own UVs; returns the Non-Color image."""
    attr = body.data.color_attributes.new("gloss", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.column_stack([rgb, np.ones(len(rgb))]).astype(np.float32).ravel())
    target = bpy.data.images.new(name, TEXTURE, TEXTURE, float_buffer=True) if precise else image(name, "Non-Color")
    target.colorspace_settings.name = "Non-Color"
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
    return target


def body_roughness_map(body):
    """Roughness by height on the body's own UVs: glossiest at the base, rising toward the head."""
    t = np.clip((body_heights(body) - 0.35)/(1.5 - 0.35), 0.0, 1.0)
    rough = SKIN_ROUGHNESS_LOW + (SKIN_ROUGHNESS - SKIN_ROUGHNESS_LOW)*t*t*(3 - 2*t)
    target = bake_vertex_values(body, "floppy-body-roughness", np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], 1))
    save(target, "floppy-body-roughness.png")
    return target


def underside_fold(x, y):
    """Soft rolls with narrow creases, wandering slightly so they do not look ruled: 0 in a crease, 1 on a roll."""
    wander = 0.05*np.sin(x*5.1 + 0.6) + 0.025*np.sin(x*11.3 + y*2.0)
    return np.abs(np.sin((y + wander)*np.pi/UNDERSIDE_FOLD_SPACING))**0.6


def round_underside(high):
    """Replace the flat base with a soft domed belly. The flat faces have almost no interior vertices, so the
    cap is rebuilt as rings from the rim; the rim keeps its place, so the standing silhouette is unchanged."""
    bm = bmesh.new()
    bm.from_mesh(high.data)
    bm.normal_update()
    uv_layer = bm.loops.layers.uv.active
    flat = [f for f in bm.faces if f.normal.z < -0.5 and all(v.co.z < UNDERSIDE_FLAT_Z for v in f.verts)]
    bmesh.ops.delete(bm, geom=flat, context="FACES")
    # Walk the boundary into loops; the longest is the rim, any tiny leftovers are simply closed.
    open_edges = {e for e in bm.edges if e.is_boundary}
    loops = []
    while open_edges:
        start = open_edges.pop()
        loop = [start.verts[0], start.verts[1]]
        while True:
            step = next((e for e in loop[-1].link_edges if e in open_edges), None)
            if step is None:
                break
            open_edges.discard(step)
            loop.append(step.other_vert(loop[-1]))
        if loop[0] == loop[-1]:
            loop.pop()
        loops.append(loop)
    loops.sort(key=len, reverse=True)
    rim = loops[0]
    for extra in loops[1:]:
        bmesh.ops.holes_fill(bm, edges=[e for v in extra for e in v.link_edges if e.is_boundary], sides=0)
    centre = sum((v.co for v in rim), Vector())/len(rim)
    rim_uv = {v: next(l[uv_layer].uv.copy() for l in v.link_loops) for v in rim} if uv_layer else {}
    radius = sum((v.co.xy - centre.xy).length for v in rim)/len(rim)
    source = {v: v for v in rim}
    previous = rim
    faces = []

    def stitch(outer, inner):
        # Walk both rings together. Their counts differ, so rows thin out without gathering at one point.
        i, j = 0, 0
        while i < len(outer) or j < len(inner):
            if j >= len(inner) or (i < len(outer) and (i + 0.5)/len(outer) <= (j + 0.5)/len(inner)):
                faces.append(bm.faces.new((outer[i % len(outer)], outer[(i + 1) % len(outer)], inner[j % len(inner)])))
                i += 1
            else:
                faces.append(bm.faces.new((outer[i % len(outer)], inner[(j + 1) % len(inner)], inner[j % len(inner)])))
                j += 1

    for ring in range(1, UNDERSIDE_RINGS + 1):
        angle = ring/(UNDERSIDE_RINGS + 1)*math.pi/2
        count = min(len(rim), max(8, round(math.tau*radius*math.cos(angle)/UNDERSIDE_ROW_SPACING)))
        current = []
        for k in range(count):
            vert = rim[int(k*len(rim)/count)]
            x = centre.x + (vert.co.x - centre.x)*math.cos(angle)
            y = centre.y + (vert.co.y - centre.y)*math.cos(angle)
            fold = float(underside_fold(x, y))*UNDERSIDE_FOLD_DEPTH*math.sin(angle)**2
            new = bm.verts.new(Vector((x, y, vert.co.z - UNDERSIDE_DEPTH*math.sin(angle) - fold)), vert)
            source[new] = vert
            current.append(new)
        stitch(previous, current)
        previous = current
    fold = float(underside_fold(centre.x, centre.y))*UNDERSIDE_FOLD_DEPTH
    apex = bm.verts.new(Vector((centre.x, centre.y, centre.z - UNDERSIDE_DEPTH - fold)), rim[0])
    source[apex] = rim[0]
    faces += [bm.faces.new((previous[i], previous[(i + 1) % len(previous)], apex)) for i in range(len(previous))]
    # Each new vertex inherits its rim vertex's colour coordinates, weights and material, so the dome joins cleanly.
    for face in faces:
        face.smooth = True
        if uv_layer:
            for loop in face.loops:
                loop[uv_layer].uv = rim_uv[source[loop.vert]]
    bm.normal_update()
    if faces[-1].normal.z > 0:
        bmesh.ops.reverse_faces(bm, faces=faces)
    bm.to_mesh(high.data)
    bm.free()
    high.data.update()
    print("underside", {"rimVerts": len(rim), "extraLoops": len(loops) - 1, "removedFlatFaces": len(flat),
                        "depth": UNDERSIDE_DEPTH}, flush=True)


def paint_underside(body, colour, normal):
    """Fade the dome to the body's own colour with painted folds. Its rings only stretch rim texture, which
    would streak, so the colour is drawn per texel from baked positions rather than kept."""
    co = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    z = co[:, 2]
    t = np.clip((UNDERSIDE_BLEND_TOP - z)/(UNDERSIDE_BLEND_TOP + UNDERSIDE_DEPTH*0.3), 0.0, 1.0)
    baked = bake_vertex_values(body, "floppy-underside-coords",
                               np.column_stack([(co[:, 0] + 1.2)/2.4, (co[:, 1] + 1.2)/2.4, t*t*(3 - 2*t)]), precise=True)
    wall = ((z > 0.06) & (z < 0.4)).astype(float)
    band = bake_vertex_values(body, "floppy-underside-band", np.repeat(wall[:, None], 3, axis=1))
    data = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    baked.pixels.foreach_get(data)
    data = data.reshape(TEXTURE, TEXTURE, 4)
    x, y, amount = data[:, :, 0]*2.4 - 1.2, data[:, :, 1]*2.4 - 1.2, data[:, :, 2]
    # Grow the mask a few texels so UV-island seams on the dome cannot show the skin behind them.
    for _ in range(4):
        amount = np.maximum.reduce([amount, np.roll(amount, 1, 0), np.roll(amount, -1, 0), np.roll(amount, 1, 1), np.roll(amount, -1, 1)])
    side = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    band.pixels.foreach_get(side)
    side = side.reshape(TEXTURE, TEXTURE, 4)[:, :, 0] > 0.9
    pixels = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    colour.pixels.foreach_get(pixels)
    pixels = pixels.reshape(TEXTURE, TEXTURE, 4)
    # The median of the lower walls is the plain skin: spots and the cream belly panel are the minority.
    skin = np.median(pixels[side][:, :3], axis=0)
    painted = skin[None, None, :]*(0.8 + 0.25*underside_fold(x, y))[:, :, None]
    pixels[:, :, :3] += amount[:, :, None]*(painted - pixels[:, :, :3])
    colour.pixels.foreach_set(pixels.ravel())
    colour.update()
    # The folds are gentle, so any steep normal here is a bake miss at a UV seam, which would sparkle.
    bent = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    normal.pixels.foreach_get(bent)
    bent = bent.reshape(TEXTURE, TEXTURE, 4)
    bad = (amount > 0.01) & ((np.abs(bent[:, :, 0] - 0.5) > 0.3) | (np.abs(bent[:, :, 1] - 0.5) > 0.3) | (bent[:, :, 2] < 0.75))
    bent[bad, :3] = (0.5, 0.5, 1.0)
    normal.pixels.foreach_set(bent.ravel())
    normal.update()
    print("underside seam texels fixed", int(bad.sum()), flush=True)
    bpy.data.images.remove(baked)
    bpy.data.images.remove(band)
    print("underside skin", [round(float(v), 3) for v in skin], flush=True)


def paint_lid_lines(body, colour, normal):
    """Paint the lids. A hull outline shifts with the viewing angle in these hollows; a painted rim stays exactly on
    them and moves with them when they blink. Each lid gets one clean colour and a flat normal, because the bake
    leaves pits along these thin rims. The lid darkens toward its rim so it reads heavy."""
    co = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    baked = bake_vertex_values(body, "floppy-lid-coords", np.column_stack(
        [(co[:, 0] + 1.2)/2.4, (co[:, 1] + 1.2)/2.4, co[:, 2]/2.6]), precise=True)
    data = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    baked.pixels.foreach_get(data)
    data = data.reshape(-1, 4)
    x, y, z = data[:, 0]*2.4 - 1.2, data[:, 1]*2.4 - 1.2, data[:, 2]*2.6
    # How far each texel faces out of its eye, so rim lines stay off the lids' steep undersides.
    vertex_normals = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("normal", vertex_normals)
    vertex_normals = vertex_normals.reshape(-1, 3)
    n = np.stack([vertex_normals[:, 0], vertex_normals[:, 2], -vertex_normals[:, 1]], -1)
    faces = bake_vertex_values(body, "floppy-lid-facing", np.column_stack(
        [(n @ eye_basis(-1.0)[2] + 1)/2, (n @ eye_basis(1.0)[2] + 1)/2, np.zeros(len(n))]), precise=True)
    facing = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    faces.pixels.foreach_get(facing)
    facing = facing.reshape(-1, 4)*2 - 1
    bpy.data.images.remove(faces)
    p = np.stack([x, z, -y], -1)
    # Includes the lids' hidden undersides, baked near-black, which stretch into view as they close.
    pixels = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    colour.pixels.foreach_get(pixels)
    pixels = pixels.reshape(-1, 4)
    bent = np.empty(TEXTURE*TEXTURE*4, dtype=np.float32)
    normal.pixels.foreach_get(bent)
    bent = bent.reshape(-1, 4)
    for index, (side, height) in enumerate(((-1.0, 0.03), (1.0, -0.03))):
        l = eye_local(p, side)
        front = l[:, 2] > -0.03
        visible = facing[:, index] > LID_LINE_FACING
        radius = np.linalg.norm(l[:, :2]/(EYE_DIM[:2] + 0.03), axis=1)
        upper = height + 0.24*side*l[:, 0]
        lower = -0.15 - 0.05*side*l[:, 0]
        inside = (1.0 - smoothstep(0.97, 1.03, radius))*(l[:, 2] > -0.2)
        # The upper zone reaches under the rim: that dark inner face stretches into view mid-blink, so it must be lid.
        for zone, away in ((l[:, 1] > upper - 0.07, l[:, 1] - upper), (l[:, 1] < lower, lower - l[:, 1])):
            fill = inside*zone
            solid = (fill > 0.9) & front & (away > 0.03)
            if solid.any():
                base = np.median(pixels[solid][:, :3], axis=0)
                heavy = base[None, :]*(0.8 + 0.2*smoothstep(0.0, 0.13, np.maximum(away, 0.0)))[:, None]
                pixels[:, :3] += fill[:, None]*(heavy - pixels[:, :3])
                bent[:, :3] += fill[:, None]*(np.array((0.5, 0.5, 1.0), dtype=np.float32) - bent[:, :3])
        contour = (1.0 - smoothstep(0.012, 0.045, np.abs(radius - 1.01)))*front*((l[:, 1] > upper) | (l[:, 1] < lower))
        pixels[:, :3] += (contour*LID_CONTOUR_STRENGTH)[:, None]*(np.array(LID_CONTOUR_COLOUR, dtype=np.float32) - pixels[:, :3])
        # Each rim line lies on the lid's visible face, where it does not stretch.
        for centre in (upper + LID_LINE*0.6, lower - LID_LINE*0.6):
            rim = (1.0 - smoothstep(LID_LINE*0.4, LID_LINE*0.8, np.abs(l[:, 1] - centre)))*front*visible*(radius < 1.04)
            pixels[:, :3] += rim[:, None]*(np.array(LID_LINE_COLOUR, dtype=np.float32) - pixels[:, :3])
    colour.pixels.foreach_set(pixels.ravel())
    colour.update()
    normal.pixels.foreach_set(bent.ravel())
    normal.update()
    bpy.data.images.remove(baked)


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


def game_skin_material(colour, normal, rough, glow=None):
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
    if glow:
        # Antenna bulbs glow softly (owner, 2026-11-01); Roblox gets the same mask as its emissive mask.
        g = nodes.new("ShaderNodeTexImage")
        g.image = glow
        mul = nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = BULB_GLOW_STRENGTH
        links.new(g.outputs["Color"], mul.inputs[0])
        links.new(mul.outputs["Value"], shader.inputs["Emission Strength"])
        shader.inputs["Emission Color"].default_value = BULB_GLOW + (1.0,)
    return mat


def ink_shell(body, open_verts):
    """A skinned copy of the game body pushed out along its normals with reversed faces: Roblox culls back faces,
    so only a dark rim shows around Floppy, and it bends with him because it keeps his skin weights. A hull also
    shows inside carved hollows, which drew thick broken lines round the eyes, so those faces are removed."""
    shell = body.copy()
    shell.data = body.data.copy()
    shell.name = shell.data.name = "FloppyBody_Ink"
    for c in body.users_collection:
        c.objects.link(shell)
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal*INK_WIDTH
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if any(open_verts[v.index] for v in f.verts)], context="FACES")
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(shell.data)
    bm.free()
    ink = bpy.data.materials.new("FloppyInk")
    ink.diffuse_color = (0.006, 0.006, 0.008, 1.0)
    shell.data.materials.clear()
    shell.data.materials.append(ink)
    return shell


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


def add_face_rig(rig, body):
    """Face bones under the head (owner, 2026-11-01): gaze parents each eye, lids close over it, and the sculpted
    mouth is skinned to its corners and lower lip. Roblox bones only move, so all expressions are bone motion."""
    select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    edit = rig.data.edit_bones
    head = edit["head"]

    def new_bone(name, position, parent):
        bone = edit.new(name)
        bone.head = position
        bone.tail = position + Vector((0.0, 0.0, 0.08))
        bone.parent = parent
        bone.use_connect = False
        return bone

    for tag in ("L", "R"):
        eye = edit["eye_" + tag]
        centre = eye.head.copy()
        eye.parent = new_bone("gaze_" + tag, centre, head)
        new_bone("lid_" + tag, centre, head)
    # Concept space is x, up, toward the face; Blender source is x, -toward the face, up.
    mouth_at = {"mouth_L": (-0.14, 0.0), "mouth_R": (0.14, 0.0), "mouth_low": (0.0, -0.03)}
    for name, (x, down) in mouth_at.items():
        y = 1.15 + down + 1.2*x*x + 0.2*x + 0.4*max(x, 0.0)**2
        new_bone(name, Vector((0.03 + x, -0.73, y)), head)
    bpy.ops.object.mode_set(mode="OBJECT")

    co = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    p = np.stack([co[:, 0], co[:, 2], -co[:, 1]], -1)
    weights = {}
    for tag, side, height in (("L", -1.0, 0.03), ("R", 1.0, -0.03)):
        l = eye_local(p, side)
        norm = np.linalg.norm(l/EYE_DIM, axis=1)
        edge = height + 0.24*side*l[:, 0]
        # Like a real lid: the rim moves fully and the sheet stretches from an anchored top, so the eye stays covered.
        stretch = 1.0 - np.clip((l[:, 1] - edge)/np.maximum(EYE_DIM[1] + 0.03 - edge, 0.05), 0.0, 1.0)
        weights["lid_" + tag] = smoothstep(-0.055, -0.02, l[:, 1] - edge)*stretch*(1.0 - smoothstep(1.0, 1.25, norm))*(l[:, 2] > -0.02)
    q = mouth_local(p)
    front = p[:, 2] > 0.3
    near = lambda x, y, rx, ry: np.exp(-((q[:, 0] - x)/rx)**2 - ((q[:, 1] - y)/ry)**2)*front
    weights["mouth_L"] = near(-0.14, 0.0, 0.11, 0.1)
    weights["mouth_R"] = near(0.14, 0.0, 0.11, 0.1)
    weights["mouth_low"] = near(0.0, -0.05, 0.13, 0.07)*smoothstep(0.012, -0.012, q[:, 1])
    total = np.clip(sum(weights.values()), 0.0, 0.98)
    groups = {name: body.vertex_groups.new(name=name) for name in weights}
    for index, vertex in enumerate(body.data.vertices):
        if total[index] <= 0.01:
            continue
        for existing in vertex.groups:
            existing.weight *= 1.0 - total[index]
        share = total[index]/max(sum(float(w[index]) for w in weights.values()), 1e-6)
        for name, values in weights.items():
            if values[index] > 0.005:
                groups[name].add([index], float(values[index])*share, "REPLACE")
    select_only([body])
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    # The eye area keeps no hull (its outlines are painted); side-facing skin further out is still the head's outline.
    normals = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("normal", normals)
    facing = -normals.reshape(-1, 3)[:, 1]
    # Measured across the face: the eyes are so flat that a 3D distance misses the lids in front of them.
    radii = [np.linalg.norm(eye_local(p, side)[:, :2]/EYE_DIM[:2], axis=1) for side in (-1.0, 1.0)]
    # The belly folds are hollows too: a hull drew black dashes along them.
    near = (radii[0] < EYE_INK_CLEAR) | (radii[1] < EYE_INK_CLEAR)
    wide = (radii[0] < EYE_INK_FRONT) | (radii[1] < EYE_INK_FRONT)
    ink_open = near | (wide & (facing > 0.05)) | ((belly_folds(p) > 0.15) & (facing > 0.2))
    print("face ink cleared verts", int(ink_open.sum()), flush=True)
    print("face rig", {name: int((values > 0.05).sum()) for name, values in weights.items()}, flush=True)
    return ink_open


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
    # Standing height sits above the ground plane; the domed underside below it stays hidden on the floor.
    report["heightStuds"] = round(hi[2], 3)
    report["undersideDepthStuds"] = round(-lo[2], 3)
    assert 0.88 <= report["heightStuds"] <= 0.97, f"Floppy should be about 0.93 studs tall: {report['heightStuds']}"
    assert 0.05 <= report["undersideDepthStuds"] <= 0.14, f"unexpected underside depth: {report['undersideDepthStuds']}"
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
    round_underside(high)

    body = low_copy(high, "FloppyBody", BODY_TRIANGLES, face_detail_group(high))
    select_only([body])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    colour = image("floppy-body-color", "sRGB")
    normal = image("floppy-body-normal", "Non-Color")
    bake_to(body, high, "EMIT", colour, emission_of(skin))
    bake_to(body, high, "NORMAL", normal)
    paint_underside(body, colour, normal)
    paint_lid_lines(body, colour, normal)
    paths = [save(colour, "floppy-body-color.png"), save(normal, "floppy-body-normal.png")]
    glow = None
    if glow_texture(skin):
        glow = image("floppy-body-glow", "Non-Color")
        bake_to(body, high, "EMIT", glow, emission_of(skin, glow_texture(skin)))
        paths.append(save(glow, "floppy-body-glow.png"))
    body.data.materials.append(game_skin_material(colour, normal, body_roughness_map(body), glow))

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
    ink_open = add_face_rig(rig, body)
    stretch_torso(rig, meshes)
    face_plus_y(rig, meshes)
    scale_to_blaster(rig, meshes)
    idle = roblox_idle(rig)
    for b in rig.pose.bones:
        b.matrix_basis.identity()
    meshes.append(ink_shell(body, ink_open))
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
