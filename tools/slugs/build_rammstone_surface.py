"""Surface pass on Rammstone's approved blockout: the shape is frozen, only the surface and two local areas change.

Owner, 2026-11-07: keep the silhouette and proportions; make the armour solid, faceted, matte volcanic rock with
restrained cracks and darker crevices; give the forehead a heavier V brow with a central angular ridge; smooth the body's
wrinkles while keeping its V markings; make the horns faceted stone. The horizontal bands were geometry (every rock vertex
had one flat colour), so the rock is re-faceted rather than repainted:

- Face and hood (refined, owner, 2026-11-08): the eye zones under a V brow line (`BROW_TIP + BROW_SLOPE*|x|`) are set
  back so the brow overhangs them; rock cheek plates come down beside the face toward the mouth's corners; the hood's
  front is cut into two flat planes meeting at a central ridge, coloured charcoal as the keel. Depth only.
- Armour masses (refined, owner, 2026-11-08): below the hood, the stacked bands are smoothed out of the armour's radius
  and replaced by a few tiers of large, staggered wedge plates in V rows, with a ridge down the spine.
- Body: Laplacian smoothing with volume kept, then the sheet's two V markings as shallow steps.
- Rock and horns: collapsed to large planar facets, shaded flat. Skin is never collapsed.
- Materials: matte rock varied per facet, darkened in crevices (ambient occlusion) and with a few cracks in patches;
  charcoal horns and keel varied per facet; smooth tan skin with dark creases. Procedural for review; they get baked to
  textures before any Roblox export.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_rammstone_surface.py`

Reads assets/source/slugs/models/rammstone/rammstone-blockout.blend (unchanged). Writes rammstone-surface.blend beside it
and build/slugs/rammstone/surface/renders/.
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

SOURCE = ROOT/"assets/source/slugs/models/rammstone"
OUT = ROOT/"build/slugs/rammstone/surface"
CALIB = ROOT/"build/slugs/rammstone/blockout/calibration.json"
ROCK, SKIN, HORN, KEEL = 1, 2, 3, 4

BROW_TIP, BROW_SLOPE = 1.30, 0.85  # the brow's lower edge: lowest between the eyes, rising outward (sheet: eyes at +-0.275)
SOCKET_DEPTH = 0.075  # how far the eye zones sit behind the brow
HOOD_SLOPE = 0.38  # the hood's front: two flat planes set back this much per unit of |x| from the central ridge
CHEEK_PROUD = 0.045  # how far the rock cheek plates stand in front of the face beside them
# Armour masses on the back and sides below the hood: a few tiers of large wedge plates in V rows.
TIER_TOP, TIER_H, TIER_RISE = 1.78, 0.44, 0.20  # first tier at the spine, tier height, rise per radian toward the sides
PLATE_W = 0.95  # radians across one plate
SPINE_RIDGE = 0.05
CHEVRONS = ((0.54, 0.50), (0.15, 0.52))  # belly V markings measured on the sheet: tip height and slope
RIB_SMOOTHING = 12  # the pixel-row ribs go, the plates stay
ROCK_FACET_ANGLE, HORN_FACET_ANGLE = 18.0, 16.0  # faces within this many degrees merge into one flat facet
SCALE = 4


def smoothstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0.0, 1.0)
    return t*t*(3.0 - 2.0*t)


def brow_line(x):
    return BROW_TIP + BROW_SLOPE*np.abs(x)


def keel_half_width(z):
    return 0.006 + 0.11*np.clip((z - 1.30)/0.80, 0.0, 1.0)**1.3  # a wedge from the brow's point, widening to the crown


def arrays(mesh):
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    no = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("normal", no)
    part = np.empty(len(mesh.vertices), np.int32)
    mesh.attributes["part"].data.foreach_get("value", part)
    return co.reshape(-1, 3), no.reshape(-1, 3), part


def cheek_edge(z):
    """Inner edge of the hood's lower corners, the rock cheek plates: at the eyes' outer corners, slanting in a little
    toward the mouth."""
    return np.where(z > 1.30, 0.40, 0.40 - 0.15*(1.30 - z))


def forehead(obj):
    """Frame the face: eye zones set back under a V brow, rock cheek plates beside the face, and the hood's front cut into
    two flat planes meeting at a central ridge. Depth only, so neither the front nor the side silhouette moves."""
    mesh = obj.data
    co, no, part = arrays(mesh)
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    ax = np.abs(x)
    front = (y < -0.35) & (no[:, 1] < -0.2)
    edge = brow_line(x)
    # The hood's ridge line: the front-most point of the middle at each height, before anything moves.
    bins = np.round(z/0.01).astype(int)
    middle = front & (ax < 0.04)
    ridge = {}
    for b in np.unique(bins[middle]):
        ridge[b] = y[middle & (bins == b)].min()
    ridge_y = np.array([ridge.get(b, np.nan) for b in bins])
    # Eye zones: below the brow line, above a floor that curves up toward the corners, inside the cheeks.
    floor = 1.26 + 0.6*(ax - 0.27)**2
    socket = front & (z > floor - 0.08) & (z < edge + 0.01) & (ax < cheek_edge(z) + 0.02)
    w = smoothstep(floor - 0.08, floor + 0.05, z)*(1.0 - smoothstep(edge - 0.02, edge + 0.01, z))
    w *= smoothstep(0.03, 0.10, ax)*(1.0 - smoothstep(cheek_edge(z) - 0.03, cheek_edge(z) + 0.02, ax))
    co[socket, 1] += SOCKET_DEPTH*w[socket]
    part[socket & (w > 0.35) & (part == ROCK)] = SKIN
    # Cheek plates: the hood's lower corners beside the eyes, down to about the mouth. Each is a plate angled forward and
    # out, proudest at its inner edge, ending in a point.
    bottom = 1.08 + 0.35*np.maximum(ax - cheek_edge(z), 0.0)
    cheek = front & (z > bottom - 0.04) & (z < edge + 0.06) & (ax > cheek_edge(z) - 0.005) & (ax < 0.64)
    cw = smoothstep(cheek_edge(z) - 0.005, cheek_edge(z) + 0.025, ax)*smoothstep(bottom - 0.04, bottom + 0.04, z)
    cw *= 1.0 - smoothstep(0.50, 0.64, ax)
    co[cheek, 1] -= (CHEEK_PROUD*cw)[cheek]
    part[cheek & (cw > 0.3)] = ROCK
    # Hood: two flat planes from the central ridge, so the front reads as a cut V rather than a curved band.
    brow = front & (z >= edge - 0.01) & (z < 2.12) & (part == ROCK) & ~np.isnan(ridge_y)
    plane = ridge_y + HOOD_SLOPE*np.minimum(ax, 0.55)
    fade = smoothstep(edge - 0.01, edge + 0.04, z)*(1.0 - smoothstep(1.98, 2.12, z))
    target = np.maximum(y, plane)
    co[brow, 1] = (y + (target - y)*fade)[brow]
    # Smooth out the step the blockout left where the brow band sits in front of the face, under the eyes.
    co_now = co.copy()
    seam = (y < -0.35) & (z > 1.16) & (z < 1.36) & (ax < 0.40)  # any facing: the old band's lip faces down
    seam_w = smoothstep(1.16, 1.22, z)*(1.0 - smoothstep(1.30, 1.36, z))*(1.0 - smoothstep(0.34, 0.40, ax))
    # Pull each seam vertex toward the face line just below the band (its depth at 1.18 for the same |x|).
    below = front & (np.abs(z - 1.18) < 0.012)
    if below.any():
        xs = np.sort(np.unique(np.round(ax[below], 2)))
        depth = np.array([co_now[below & (np.round(ax, 2) == v), 1].min() for v in xs])
        face_y = np.interp(ax, xs, depth)
        lower = seam & (co[:, 1] < face_y)  # only where the band stands in front of the face
        co[lower, 1] = (co[:, 1] + (face_y - co[:, 1])*seam_w)[lower]
    mesh.vertices.foreach_set("co", co.ravel())
    mesh.attributes["part"].data.foreach_set("value", part)
    mesh.update()
    return int(socket.sum()), int(brow.sum()), int(cheek.sum())


def hash2(a, b):
    return (np.sin(a*127.1 + b*311.7)*43758.5453) % 1.0


def armour_masses(obj):
    """Below the hood, on the back and sides: smooth the armour's radius over height to remove the stacked bands, then
    lay a few tiers of large wedge plates in V rows rising toward the sides. Plates are staggered and vary in height,
    width and thickness so they interlock, each thickest at its pointed lower edge and flush where it tucks under the
    one above, with a ridge down the spine. Fades out toward the face and under the hood."""
    mesh = obj.data
    co, _, part = arrays(mesh)
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    # Each height's centre, from the whole cross-section.
    zb = np.round(z/0.02).astype(int)
    centre = {b: 0.5*(y[zb == b].min() + y[zb == b].max()) for b in np.unique(zb)}
    yc = np.array([centre[b] for b in zb])
    a = np.arctan2(x, y - yc)  # 0 down the spine, +-pi down the belly
    r = np.hypot(x, y - yc)
    w = (1.0 - smoothstep(1.55, 1.85, np.abs(a)))*smoothstep(0.02, 0.15, z)*(1.0 - smoothstep(1.62, 1.85, z))
    w *= (part == ROCK)
    region = w > 0
    # Smooth base radius: median per angle and height bin, then smoothed over height so the bands go.
    ab = np.clip(((a + math.pi)/(2*math.pi)*48).astype(int), 0, 47)
    zbin = np.clip((z/0.02).astype(int), 0, 149)
    grid = np.full((48, 150), np.nan)
    for i, j in set(zip(ab[region], zbin[region])):
        grid[i, j] = np.median(r[region & (ab == i) & (zbin == j)])
    for i in range(48):
        row = grid[i]
        good = ~np.isnan(row)
        if good.sum() > 2:
            idx = np.arange(150)
            row[:] = np.interp(idx, idx[good], row[good])
            k = np.exp(-0.5*(np.arange(-24, 25)/8.0)**2)
            row[:] = np.convolve(np.pad(row, 24, mode="edge"), k/k.sum(), mode="valid")
    base = grid[ab, zbin]
    # Plates: tier coordinate along V rows, plate columns staggered per tier, jittered per plate.
    aa = np.abs(a)
    u = (TIER_TOP - z + TIER_RISE*aa)/TIER_H
    tier = np.floor(u)
    col = np.floor(a/PLATE_W + 0.5*np.mod(tier, 2.0) + 0.5)
    centre_a = (col - 0.5*np.mod(tier, 2.0))*PLATE_W
    h1, h2 = hash2(tier, np.abs(centre_a)*3.0), hash2(tier + 4.1, np.abs(centre_a)*5.0)
    u = u + (h1 - 0.5)*0.30  # each plate's own height, so the rows interlock rather than stack
    v = u - np.floor(u)  # 0 under the plate above, 1 at this plate's lower edge
    across = np.clip((a - centre_a)/(0.5*PLATE_W), -1.0, 1.0)
    point = 1.0 - 0.45*np.abs(across)  # the lower edge is a V, pointing down
    T = (0.08 + 0.07*h2)*(1.0 + 0.15*smoothstep(0.6, 1.5, aa))*(1.0 + 0.25*smoothstep(0.8, 1.6, z))
    lift = T*np.clip(v/point, 0.0, 1.0)**0.8*(1.0 - 0.30*np.abs(across))*(v < point)
    spine = SPINE_RIDGE*np.clip(1.0 - aa/0.45, 0.0, 1.0)
    new_r = base - 0.07 + lift + spine
    r_out = r + (new_r - r)*w
    scale = np.where(r > 1e-6, r_out/np.maximum(r, 1e-6), 1.0)
    co[region, 0] = (x*scale)[region]
    co[region, 1] = (yc + (y - yc)*scale)[region]
    mesh.vertices.foreach_set("co", co.ravel())
    mesh.update()
    return int(region.sum())


def tidy_labels(obj, passes=2):
    """Majority vote among each vertex and its neighbours for skin, rock and keel, so part borders run cleanly instead
    of zigzagging between single vertices. Horns are left alone."""
    mesh = obj.data
    _, _, part = arrays(mesh)
    edges = np.empty(len(mesh.edges)*2, np.int32)
    mesh.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    changed = 0
    for _ in range(passes):
        votes = np.zeros((len(part), 5), np.int32)
        np.add.at(votes, (np.arange(len(part)), part), 1)
        np.add.at(votes, (edges[:, 0], part[edges[:, 1]]), 1)
        np.add.at(votes, (edges[:, 1], part[edges[:, 0]]), 1)
        votes[:, HORN] = 0
        new = np.where(part == HORN, part, votes.argmax(1))
        changed += int((new != part).sum())
        part = new
    mesh.attributes["part"].data.foreach_set("value", part.astype(np.int32))
    return changed


def taubin(bm, verts, iterations, lam=0.5, mu=-0.53):
    """Smooth without shrinking (Taubin): each averaging step is followed by a slightly stronger step back, so ripples
    go while the overall surface, and with it the silhouette, stays put. Only `verts` move."""
    bm.verts.index_update()
    co = np.array([v.co[:] for v in bm.verts])
    edges = np.array([(e.verts[0].index, e.verts[1].index) for e in bm.edges])
    move = np.zeros(len(co), bool)
    move[[v.index for v in verts]] = True
    degree = np.bincount(edges.ravel(), minlength=len(co)).astype(float)[:, None]
    for _ in range(iterations):
        for factor in (lam, mu):
            total = np.zeros_like(co)
            np.add.at(total, edges[:, 0], co[edges[:, 1]])
            np.add.at(total, edges[:, 1], co[edges[:, 0]])
            delta = total/np.maximum(degree, 1) - co
            co[move] += factor*delta[move]
    for v in verts:
        v.co = co[v.index]


def body(obj):
    """Smooth the skin's wrinkles without shrinking it, then add the sheet's V markings as shallow steps."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.verts.layers.int["part"]
    crease = bm.verts.layers.float.new("crease")  # before collecting verts: a new layer invalidates held references
    inner = [v for v in bm.verts if v[layer] == SKIN and all(e.other_vert(v)[layer] == SKIN for e in v.link_edges)]
    # The ripples are several vertex rings apart, too wide for Taubin; plain averaging clears them, then the skin is
    # pushed back out by the average amount it shrank, so the face line keeps its place in the silhouette.
    bm.normal_update()
    before = {v: (v.co.copy(), v.normal.copy()) for v in inner}
    for _ in range(15):
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    shrink = float(np.mean([(co - v.co).dot(n) for v, (co, n) in before.items()]))
    for v, (co, n) in before.items():
        v.co += n*shrink
    bm.normal_update()
    for v in inner:
        x, y, z = v.co
        if y > -0.2 or v.normal.y > -0.2:
            continue
        lift, line = 0.0, 0.0
        for tip, slope in CHEVRONS:
            l = tip + slope*abs(x)
            d = z - l
            # The segment above each line laps over the one below: proud just above the line, easing out upward.
            lift += float(smoothstep(-0.006, 0.006, d)*(1.0 - smoothstep(0.03, 0.30, d)))
            line = max(line, float(math.exp(-(d/0.012)**2)))
        side = float(1.0 - smoothstep(0.30, 0.42, abs(x)))
        v.co += v.normal*(0.012*lift - 0.006*line)*side
        v[crease] = line*side
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return len(inner)


def facet(obj):
    """Cut rock and horn into flat facets that follow their existing shape. First a light smoothing takes out the
    pixel-row ribbing left by the carve; then neighbouring faces within FACET_ANGLE of each other merge into one plane.
    Skin is never touched, and the border between parts is kept."""
    mesh = obj.data
    mesh.calc_loop_triangles()
    before = len(mesh.loop_triangles)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    layer = bm.verts.layers.int["part"]
    hard = [v for v in bm.verts if v[layer] != SKIN and all(e.other_vert(v)[layer] == v[layer] for e in v.link_edges)]
    taubin(bm, hard, RIB_SMOOTHING)
    for part, angle in ((ROCK, ROCK_FACET_ANGLE), (HORN, HORN_FACET_ANGLE)):  # the keel lies on the flat hood plane already
        # Only one ring in from every border, so the facets never reach across a border and zigzag it.
        inner = {v for v in bm.verts if v[layer] == part and all(e.other_vert(v)[layer] == part for e in v.link_edges)}
        verts = [v for v in inner if all(e.other_vert(v) in inner for e in v.link_edges)]
        keep = set(verts)
        edges = [e for e in bm.edges if e.verts[0] in keep and e.verts[1] in keep]
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(angle), verts=verts, edges=edges)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    mesh.calc_loop_triangles()
    return before, len(mesh.loop_triangles)


def assign(obj):
    """Material per face from its vertices' parts; the keel is the ridge's middle strip, found by face position.
    Rock, horn and keel faces are shaded flat, skin smooth. Each face also gets a random value for per-facet variation."""
    mesh = obj.data
    _, _, part = arrays(mesh)
    n = len(mesh.polygons)
    centre = np.empty(n*3)
    mesh.polygons.foreach_get("center", centre)
    centre = centre.reshape(-1, 3)
    counts = np.zeros((n, 5), np.int32)
    for f in mesh.polygons:
        for vi in f.vertices:
            counts[f.index, part[vi]] += 1
    face_part = counts.argmax(1)
    cx, cy, cz = centre[:, 0], centre[:, 1], centre[:, 2]
    index = {ROCK: 0, SKIN: 1, HORN: 2, KEEL: 2}
    mesh.polygons.foreach_set("material_index", np.array([index[int(p)] for p in face_part], np.int32))
    mesh.polygons.foreach_set("use_smooth", face_part == SKIN)
    rnd = np.random.default_rng(7).random(n).astype(np.float32)
    attr = mesh.attributes.new("facet", "FLOAT", "FACE")
    attr.data.foreach_set("value", rnd)
    return {name: int((face_part == p).sum()) for name, p in (("rock", ROCK), ("skin", SKIN), ("horn", HORN), ("keel", KEEL))}


KEEL_TOP, KEEL_PROUD, KEEL_THICK = 2.08, 0.010, 0.03


def keel_plate(obj):
    """The keel as its own charcoal plate: a thin closed wedge lying on the hood's two planes, a little proud, from the
    brow's point to the crown, creased down the middle. Straight edges that a painted border on this mesh cannot give."""
    bpy.context.view_layer.update()
    zs = np.linspace(BROW_TIP + 0.07, KEEL_TOP, 28)

    def surface_y(x, z):
        """Where the finished hood's surface is at (x, z), seen straight from the front."""
        hit, loc, _, _ = obj.ray_cast(Vector((x, -3.0, z)), Vector((0.0, 1.0, 0.0)))
        return loc.y if hit else np.nan

    verts, faces = [], []
    for z in zs:
        w = float(keel_half_width(z))
        for depth in (-KEEL_PROUD, KEEL_THICK):  # front skin, then the back face sunk into the rock
            for x in (-w, 0.0, w):
                verts.append((x, surface_y(x, z) + depth, z))
    verts = np.array(verts)
    bad = np.isnan(verts[:, 1])
    if bad.any():
        verts[bad, 1] = np.nanmax(verts[:, 1])
    verts = [tuple(v) for v in verts]
    n = len(zs)
    idx = lambda k, back, col: k*6 + back*3 + col
    for k in range(n - 1):
        for back in (0, 1):
            for c in (0, 1):
                a, b = idx(k, back, c), idx(k, back, c + 1)
                a2, b2 = idx(k + 1, back, c), idx(k + 1, back, c + 1)
                faces.append((a, b, b2, a2) if back == 0 else (a, a2, b2, b))
        for c, flip in ((0, True), (2, False)):  # the two sides
            q = (idx(k, 0, c), idx(k + 1, 0, c), idx(k + 1, 1, c), idx(k, 1, c))
            faces.append(q if flip else q[::-1])
    for k, flip in ((0, False), (n - 1, True)):  # the two ends
        for c in (0, 1):
            q = (idx(k, 0, c), idx(k, 0, c + 1), idx(k, 1, c + 1), idx(k, 1, c))
            faces.append(q[::-1] if flip else q)
    mesh = bpy.data.meshes.new("RammstoneKeel")
    mesh.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(obj.data.materials[2])
    plate = bpy.data.objects.new("RammstoneKeel", mesh)
    plate.parent = obj
    bpy.context.collection.objects.link(plate)
    attr = mesh.attributes.new("facet", "FLOAT", "FACE")
    attr.data.foreach_set("value", np.full(len(mesh.polygons), 0.6, np.float32))
    return len(mesh.polygons)


def node(tree, kind, **inputs):
    n = tree.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def patch_cracks(tree, coords):
    """A few dark cracks in patches: Voronoi cell edges where a slow noise is high. Returns factor, blend, colour."""
    vor = tree.nodes.new("ShaderNodeTexVoronoi")
    vor.voronoi_dimensions = "3D"
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 5.5
    tree.links.new(coords.outputs["Object"], vor.inputs["Vector"])
    line = tree.nodes.new("ShaderNodeMapRange")
    line.inputs["From Min"].default_value = 0.0
    line.inputs["From Max"].default_value = 0.018
    line.inputs["To Min"].default_value = 1.0
    line.inputs["To Max"].default_value = 0.0
    tree.links.new(vor.outputs["Distance"], line.inputs["Value"])
    noise = node(tree, "ShaderNodeTexNoise", Scale=1.6)
    tree.links.new(coords.outputs["Object"], noise.inputs["Vector"])
    patch = tree.nodes.new("ShaderNodeMapRange")
    patch.inputs["From Min"].default_value = 0.52
    patch.inputs["From Max"].default_value = 0.62
    tree.links.new(noise.outputs["Fac"], patch.inputs["Value"])
    cracks = tree.nodes.new("ShaderNodeMath")
    cracks.operation = "MULTIPLY"
    tree.links.new(line.outputs["Result"], cracks.inputs[0])
    tree.links.new(patch.outputs["Result"], cracks.inputs[1])
    return cracks.outputs["Value"], "MIX", (0.05, 0.006, 0.004)


def materials(obj, cracks=patch_cracks):
    mesh = obj.data
    mesh.materials.clear()

    def base(name):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        return mat, mat.node_tree, shader

    def facet_colour(tree, dark, light):
        attr = tree.nodes.new("ShaderNodeAttribute")
        attr.attribute_type = "GEOMETRY"
        attr.attribute_name = "facet"
        mix = tree.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs[6].default_value = (*dark, 1)
        mix.inputs[7].default_value = (*light, 1)
        tree.links.new(attr.outputs["Fac"], mix.inputs[0])
        return mix.outputs[2]

    def crevices(tree, colour, strength):
        """Darken colour in crevices with ambient occlusion."""
        ao = tree.nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.08
        ao.samples = 16
        ramp = tree.nodes.new("ShaderNodeMapRange")
        ramp.inputs["From Min"].default_value = 0.35
        ramp.inputs["To Min"].default_value = 1.0 - strength
        tree.links.new(ao.outputs["AO"], ramp.inputs["Value"])
        mul = tree.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        tree.links.new(colour, mul.inputs[6])
        tree.links.new(ramp.outputs["Result"], mul.inputs[7])
        return mul.outputs[2]

    # Rock: matte, varied per facet, dark crevices and cracks.
    rock, tree, shader = base("RammstoneRock")
    colour = facet_colour(tree, (0.19, 0.016, 0.012), (0.32, 0.032, 0.022))
    coords = tree.nodes.new("ShaderNodeTexCoord")
    factor, blend, crack_colour = cracks(tree, coords)
    crack_mix = tree.nodes.new("ShaderNodeMix")
    crack_mix.data_type = "RGBA"
    crack_mix.blend_type = blend
    crack_mix.inputs[7].default_value = (*crack_colour, 1)
    tree.links.new(factor, crack_mix.inputs[0])
    tree.links.new(colour, crack_mix.inputs[6])
    tree.links.new(crevices(tree, crack_mix.outputs[2], 0.65), shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.92
    shader.inputs["Specular IOR Level"].default_value = 0.18

    # Skin: smooth tan, darker in the V creases.
    skin, tree, shader = base("RammstoneSkin")
    crease = tree.nodes.new("ShaderNodeAttribute")
    crease.attribute_name = "crease"
    mix = tree.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = (0.62, 0.33, 0.20, 1)
    mix.inputs[7].default_value = (0.34, 0.15, 0.08, 1)
    tree.links.new(crease.outputs["Fac"], mix.inputs[0])
    tree.links.new(crevices(tree, mix.outputs[2], 0.35), shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.55
    shader.inputs["Specular IOR Level"].default_value = 0.3

    # Horns and keel: charcoal stone, varied per facet.
    horn, tree, shader = base("RammstoneHorn")
    tree.links.new(crevices(tree, facet_colour(tree, (0.030, 0.026, 0.026), (0.075, 0.066, 0.064)), 0.5), shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.78
    shader.inputs["Specular IOR Level"].default_value = 0.25
    for mat in (rock, skin, horn):
        mesh.materials.append(mat)


VIEWS = {
    "front": (Vector((0, -1, 0)), Vector((1, 0, 0))),
    "side-left": (Vector((1, 0, 0)), Vector((0, 1, 0))),
    "back": (Vector((0, 1, 0)), Vector((-1, 0, 0))),
    "side-right": (Vector((-1, 0, 0)), Vector((0, -1, 0))),
}


def render(calib):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Review")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.05, 0.045, 0.05, 1)
    scene.world = world
    for name, energy, colour, rot in (("Key", 1.6, (1, 0.97, 0.93), (50, -30, -25)), ("Fill", 0.35, (0.75, 0.75, 1.0), (70, 20, 140)),
                                      ("Rim", 1.3, (1.0, 0.5, 0.3), (65, 0, 200)), ("Front", 0.6, (1, 0.95, 0.9), (75, 0, 0))):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.data.color = colour
        light.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(light)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    paths = []
    scene.render.film_transparent = True
    for name, (toward, right) in VIEWS.items():
        c = calib[name]
        rows, cols = c["size"]
        centre = right*(((cols - 1)/2 - c["centreColumn"])*calib["pixel"]) + Vector((0, 0, (c["baseRow"] - (rows - 1)/2)*calib["pixel"]))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = max(rows, cols)*calib["pixel"]
        scene.render.resolution_x, scene.render.resolution_y = cols*SCALE, rows*SCALE
        cam.location = centre + toward*10
        cam.rotation_euler = (-toward).to_track_quat("-Z", "Y").to_euler()
        paths.append(shot(scene, OUT/"renders"/f"{name}.png"))
    scene.render.film_transparent = False
    cam.data.type = "PERSP"
    cam.data.lens = 85
    scene.render.resolution_x = scene.render.resolution_y = 900
    for name, yaw, target, dist in (("three-quarter", 0.62, (0, 0, 1.45), 9.5), ("face", 0.0, (0, 0, 1.50), 5.0),
                                     ("face-three-quarter", 0.55, (0, 0, 1.50), 5.0)):
        offset = Vector((-math.sin(yaw), -math.cos(yaw), 0.10))*dist
        cam.location = Vector(target) + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        paths.append(shot(scene, OUT/"renders"/f"{name}.png"))
    for o in [o for o in scene.objects if o.type in {"LIGHT", "CAMERA"}]:
        bpy.data.objects.remove(o)
    return paths


def shot(scene, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path.name


def main():
    calib = json.loads(CALIB.read_text())
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/"rammstone-blockout.blend"))
    obj = bpy.data.objects["RammstoneBlockout"]
    obj.name = "Rammstone"
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    report = {"tool": bpy.app.version_string}
    report["armourMassVerts"] = armour_masses(obj)
    report["face"] = dict(zip(("socketVerts", "hoodVerts", "cheekVerts"), forehead(obj)))
    report["labelsChanged"] = tidy_labels(obj)
    report["bodySmoothedVerts"] = body(obj)
    report["triangles"] = dict(zip(("before", "after"), facet(obj)))
    # Materials first: clearing a mesh's material slots resets every face's material index.
    materials(obj)
    report["facesByPart"] = assign(obj)
    report["keelFaces"] = keel_plate(obj)
    report["renders"] = render(calib)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/"report.json").write_text(json.dumps(report, indent=2))
    # Open with the reference sheets hidden, so they never block the model; one click in the Outliner shows them.
    bpy.context.view_layer.layer_collection.children["Reference"].hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"rammstone-surface.blend"), compress=True)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
