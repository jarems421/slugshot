"""Tormato's spinning storm eyes for the game model (owner, 2026-11-16, through the slug-idle session: "animate Tormato's
eyes ... Make them have a spin").

His eyes are painted into the body from the concept shader (tools/slugs/tormato_concept/template.html, eyeShade), so
they can't move. This keeps the painted almond and its ink line at rest and adds what spins, as Aquabeek's eyes do
(aquabeek_eyes.py):

- the open part of each eye (below the lid line, inside the almond) is cut out of the body and the cut's edge is moved
  onto the almond, so the opening is as smooth as the painted eye was;
- behind each opening a round disc, a surface of revolution about the eye's axis through the storm's centre, carries
  the storm: rings of wind wheeling round a calm bright middle, from the shader's own formulas. It is skinned wholly to
  `eye_L`/`eye_R`, whose head sits on the disc's centre and whose Y axis is the eye's axis, so turning the bone about Y
  spins the storm in place behind the fixed almond. SlugIdle turns them.

Differences from the concept, forced by the spin: the storm's rings are round, not squashed to the almond (a squashed
pattern would wobble as it turns), and the lid's shadow over the top of the eye isn't painted (it would turn with the
disc). The rings no longer slide with the view, and no longer drift outward.

Built in source Blender coordinates (concept (x, y up, z front) -> (x, -z, y)) before the export turns and scales the
model. L is his left, +x. His rest pose leans him forward (the shader's deform: z -= LEAN * a smoothstep of height) and
the face is drawn before the lean, so the cut runs on un-leaned points; the discs are fitted to the actual (leaned) rim,
in the eye's frame moved by the lean at its centre, so the disc stays a true surface of revolution.
"""
import bmesh
import bpy
import numpy as np
from mathutils import Vector

import export_rammstone_roblox as er

# Base form (template.html, eyes).
EYE_C = np.array([0.340, 1.700, 0.525])
EW, ETOP, EBOT, CANTHAL = 0.262, 0.178, 0.128, 0.075
ECEN = np.array([-0.02, 0.012])   # the storm's centre in the eye's own x (inner to outer corner) and y
SCALE = 0.185   # the storm's size: between the concept's 0.225 across and 0.138 up, now one round scale
LEAN = 0.10
SIDES = (("L", 1.0), ("R", -1.0))
GAP = 0.005   # the disc sits this far behind the cut's edge
DOME = 0.030   # how far the disc's middle rises above the line through its nearest rim points
OVER = 0.025   # the disc reaches this far past the farthest point of the opening
TEXTURE = 1024
TUCK = 0.008   # the ink strips reach this far under the skin's edge
LIFT = 0.003   # and sit this far in front of the disc
INK = np.array([0.014, 0.006, 0.006])
PATCH = 40   # texels of flat ink in a corner of each half, outside the disc's circle
AIR = np.array([0.400, 0.480, 0.580])
WIND = np.array([0.860, 0.910, 0.950])
CALM = np.array([1.0, 0.99, 0.96])


def smoothstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0.0, 1.0)
    return t*t*(3.0 - 2.0*t)


def eye_mid(x):
    return 0.022*(np.maximum(x, 0.0)/EW)**2 + CANTHAL*x


def inner_round(x):
    return smoothstep(0.0, -1.0, x/EW)


def eye_open(x):
    u = x/EW
    return np.power(np.maximum(0.0, 1.0 - u*u), 0.58 + (0.44 - 0.58)*inner_round(x))*(1.0 - 0.16*u)


def eye_low(x):
    u = x/EW
    return np.power(np.maximum(0.0, 1.0 - u*u), 0.75 + (0.46 - 0.75)*inner_round(x))*(1.0 + 0.10*u)


def lid_line(x):
    return eye_mid(x) + ETOP*0.80*eye_open(x)


def bottom(x):
    return eye_mid(x) - EBOT*eye_low(x)


def frame(s, leaned=False):
    """Eye centre and axes in concept space (eyeLocal): u across (sign flipped per side), w up, a out."""
    ax = np.array([s*0.47, 0.06, 1.0])
    ax /= np.linalg.norm(ax)
    u = np.cross([0.0, 1.0, 0.0], ax)
    u /= np.linalg.norm(u)
    w = np.cross(ax, u)
    c = EYE_C*np.array([s, 1.0, 1.0])
    return (lean(c) if leaned else c), u, w, ax


def to_local(p, s, leaned=False):
    c, u, w, ax = frame(s, leaned)
    q = p - c
    return np.stack([s*(q @ u), q @ w, q @ ax], -1)


def to_concept(l, s, leaned=False):
    c, u, w, ax = frame(s, leaned)
    return c + (s*l[..., 0:1])*u + l[..., 1:2]*w + l[..., 2:3]*ax


def lean(p):
    p = np.array(p, dtype=float)
    p[..., 2] += LEAN*smoothstep(0.3, 1.9, p[..., 1])
    return p


def unlean(p):
    p = np.array(p, dtype=float)
    p[..., 2] -= LEAN*smoothstep(0.3, 1.9, p[..., 1])
    return p


def concept(b):
    """Source Blender to concept."""
    return np.stack([b[..., 0], b[..., 2], -b[..., 1]], -1)


def blender(c):
    return np.stack([c[..., 0], -c[..., 2], c[..., 1]], -1)


def ink(x):
    """The bold ink line's width along the top edge (skinAlbedo's `upper`): heaviest in the middle, closing at the
    corners."""
    taper = 0.40 + 0.60*(1.0 - smoothstep(EW*0.45, EW, np.abs(x)))
    return 0.016*taper*(1.0 - smoothstep(EW*0.80, EW, np.abs(x)))


def fine(x):
    """The fine line's width along the bottom edge (skinAlbedo's `lower`), fading before either corner."""
    return 0.005*(1.0 - smoothstep(EW*0.75, EW*0.98, x))*(1.0 - smoothstep(EW*0.94, EW*1.02, -x))


def top_edge(x):
    """The opening's top: the lid line plus the ink above it, which a fixed strip carries now (it can't spin)."""
    return lid_line(x) + ink(x)


def visible(l):
    x, y = l[..., 0], l[..., 1]
    return (np.abs(x) < EW) & (y < top_edge(x)) & (y > bottom(x)) & (np.abs(l[..., 2]) < 0.15)


def outline(n=400):
    """The opening's edge in eye-local (x, y): along the top, then back along the bottom."""
    xs = EW*np.sin(np.linspace(-np.pi/2, np.pi/2, n))   # denser toward the corners
    return np.concatenate([np.stack([xs, top_edge(xs)], -1), np.stack([xs[::-1], bottom(xs[::-1])], -1)])


def storm(x, y):
    """The shader's eyeShade (eye of the storm) at eye-local (x, y), round and still: linear colour and glow."""
    e = (np.stack([x, y], -1) - ECEN)/SCALE
    r = np.linalg.norm(e, axis=-1)
    a = np.arctan2(e[..., 1], e[..., 0])
    c = AIR + (AIR*0.45 - AIR)*smoothstep(0.25, 1.15, r)[..., None]
    ring = 0.5 + 0.5*np.sin(r*15.0 + 1.4*np.sin(a*3.0))
    light = smoothstep(0.50, 0.95, ring)*smoothstep(0.30, 0.48, r)*(1.0 - smoothstep(0.9, 1.15, r)*0.6)
    heart = 1.0 - smoothstep(0.10, 0.34, r)
    c = c + (WIND - c)*light[..., None]
    c = c + (CALM - c)*heart[..., None]
    glow = (AIR*0.12 + WIND*0.22*light[..., None] + CALM*0.30*heart[..., None])*0.85
    return c, glow


def cut_openings(low):
    """Deletes the body faces over the open eyes and moves the cut's edge onto the almond. Run before the body is
    unwrapped and painted, so the skin round the opening is painted where it ends up. Returns the rim vertices."""
    mesh = low.data
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = unlean(concept(co.reshape(-1, 3)))
    inside = np.zeros(len(co), bool)
    for _, s in SIDES:
        inside |= visible(to_local(co, s))
    bm = bmesh.new()
    bm.from_mesh(mesh)
    # A face goes if any corner is in the open eye: one straddling the edge would keep a sliver of painted storm.
    gone = [f for f in bm.faces if any(inside[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    rims = {tag: [] for tag, _ in SIDES}
    edge = outline()
    for v in bm.verts:
        if not v.is_boundary:
            continue
        p = unlean(concept(np.array(v.co)))
        for tag, s in SIDES:
            l = to_local(p[None], s)[0]
            gap = np.linalg.norm(edge - l[:2], axis=1)
            if gap.min() > 0.06 or abs(l[2]) > 0.15:
                continue
            # Onto the nearest point of the outline, so the corners close cleanly instead of folding.
            x, y = edge[np.argmin(gap)]
            v.co = Vector(blender(lean(to_concept(np.array([x, y, l[2]]), s))).tolist())
            rims[tag].append(np.array(v.co))
    bm.to_mesh(mesh)
    bm.free()
    print("cut", len(gone), "eye faces; rim vertices", {t: len(r) for t, r in rims.items()})
    return {t: np.array(r) for t, r in rims.items()}


def profile(rim, skin):
    """The disc's height along the eye's axis at each distance from the storm's centre: just behind the lowest rim point
    at that distance, a gentle dome inside the nearest rim (the concept's glassy cap), falling away past the farthest.
    Turning, every part of the disc passes every angle, so at each distance it also stays behind the lowest skin round
    the eye (the brow over it sits deeper than the rim beside the corners)."""
    d = np.linalg.norm(rim[:, :2] - ECEN, axis=1)
    near, far = float(d.min()), float(d.max())
    radius = far + OVER
    rs = np.linspace(0.0, radius, 64)
    z = np.full(len(rs), np.nan)
    for i, r in enumerate(rs):
        band = np.abs(d - r) < 0.012
        if band.any():
            z[i] = rim[band, 2].min() - GAP
    base = rim[d < near + 0.012, 2].min() - GAP
    inner = rs < near
    z[inner] = base + DOME*(1.0 - (rs[inner]/near)**2)
    known = ~np.isnan(z) & (rs <= far)
    z = np.interp(rs, rs[known], z[known])
    last = float(z[rs <= far][-1])
    z[rs > far] = last - 1.2*(rs[rs > far] - far)
    ds = np.linalg.norm(skin[:, :2] - ECEN, axis=1)
    for i, r in enumerate(rs):
        band = np.abs(ds - r) < 0.015
        if band.any():
            z[i] = min(z[i], skin[band, 2].min() - GAP)
    # Smoothed, but only ever lowered, so it stays behind every rim point.
    k = np.exp(-0.5*(np.arange(-3, 4)/1.5)**2)
    k /= k.sum()
    z = np.minimum(z, np.convolve(np.pad(z, 3, mode="edge"), k, mode="valid"))
    return rs, z, radius


def grid(name, rs, zs, s, rings=40, segments=96):
    """A round disc about the axis through the storm's centre, its UV the eye-local x and y over the disc's square."""
    radius = rs[-1]
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    half = 0.0 if s > 0 else 0.5   # both eyes share one texture, L on the left half

    def place(r, t):
        x, y = ECEN[0] + r*np.cos(t), ECEN[1] + r*np.sin(t)
        z = float(np.interp(r, rs, zs))
        return Vector(blender(to_concept(np.array([x, y, z]), s, True)).tolist()), (x, y)

    def uv(x, y):
        return (half + 0.5*(x - ECEN[0] + radius)/(2*radius), (y - ECEN[1] + radius)/(2*radius))

    centre, cxy = place(0.0, 0.0)
    middle = bm.verts.new(centre)
    ring_r = np.linspace(0.0, radius, rings + 1)[1:]
    ts = np.linspace(0.0, 2*np.pi, segments, endpoint=False)
    verts, xy = [], []
    for r in ring_r:
        row = [place(r, t) for t in ts]
        verts.append([bm.verts.new(p) for p, _ in row])
        xy.append([q for _, q in row])
    def face(vs, qs):
        f = bm.faces.new(vs)
        for loop, q in zip(f.loops, qs):
            loop[uvl].uv = uv(*q)
    for j in range(segments):
        k = (j + 1) % segments
        face((middle, verts[0][j], verts[0][k]), (cxy, xy[0][j], xy[0][k]))
        for i in range(rings - 1):
            face((verts[i][j], verts[i + 1][j], verts[i + 1][k], verts[i][k]),
                 (xy[i][j], xy[i + 1][j], xy[i + 1][k], xy[i][k]))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    # Faces must point out of the eye.
    _, _, _, ax = frame(s, True)
    out = Vector(blender(ax[None])[0].tolist())
    if sum(p.normal.dot(out) for p in mesh.polygons) < 0:
        mesh.flip_normals()
    return obj


def face_out(obj, s):
    """Smooth faces pointing out of the eye."""
    for p in obj.data.polygons:
        p.use_smooth = True
    _, _, _, ax = frame(s, True)
    out = Vector(blender(ax[None])[0].tolist())
    if sum(p.normal.dot(out) for p in obj.data.polygons) < 0:
        obj.data.flip_normals()


def strips(name, rs, zs, s):
    """The ink lines, fixed to the head just in front of the disc: the bold one under the top of the opening, the fine
    one along the bottom. Each samples a flat patch in a corner of its eye's half of the texture."""
    half = 0.0 if s > 0 else 0.5
    xs = EW*np.sin(np.linspace(-np.pi/2, np.pi/2, 90))
    rows = {"top": ([lid_line(xs) - 0.001, top_edge(xs), top_edge(xs) + TUCK], (half + 0.02, 0.01)),
            "low": ([bottom(xs) - TUCK, bottom(xs), bottom(xs) + fine(xs)], (half + 0.02, 0.99))}
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for ys, uv in rows.values():
        grid_v = []
        for y in ys:
            r = np.linalg.norm(np.stack([xs, y], -1) - ECEN, axis=1)
            z = np.interp(r, rs, zs) + LIFT
            pts = blender(to_concept(np.stack([xs, y, z], -1), s, True))
            grid_v.append([bm.verts.new(q.tolist()) for q in pts])
        for j in range(len(ys) - 1):
            for i in range(len(xs) - 1):
                f = bm.faces.new((grid_v[j][i], grid_v[j][i + 1], grid_v[j + 1][i + 1], grid_v[j + 1][i]))
                for loop in f.loops:
                    loop[uvl].uv = uv
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    face_out(obj, s)
    return obj


def check_hidden(disc, body, s):
    """Every disc vertex outside the opening must lie behind the body's skin: a ray out along the eye's axis hits it."""
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    _, _, _, ax = frame(s, True)
    out = Vector(blender(ax[None])[0].tolist())
    bad = 0
    for v in disc.data.vertices:
        l = to_local(unlean(concept(np.array(v.co))), s)
        if visible(l):
            continue
        hit, *_ = tree.ray_cast(v.co, out, 0.5)
        bad += hit is None
    return bad


def build(low, rig, out, rims):
    """Adds the eyes behind the openings cut_openings made: one mesh for both discs and their ink lines, the eye bones
    and weights. Returns the mesh and a report."""
    co = np.empty(len(low.data.vertices)*3)
    low.data.vertices.foreach_get("co", co)
    co = concept(co.reshape(-1, 3))
    report, discs, pictures, glows = {}, [], [], []
    for tag, s in SIDES:
        rim = to_local(concept(rims[tag]), s, True)
        skin = to_local(co, s, True)
        skin = skin[(np.abs(skin[:, 2]) < 0.2) & (np.linalg.norm(skin[:, :2] - ECEN, axis=1) < 0.36)]
        rs, zs, radius = profile(rim, skin)
        disc = grid(f"Eye{tag}", rs, zs, s)
        bad = check_hidden(disc, low, s)
        assert bad == 0, f"{bad} vertices of eye {tag} poke out of the skin"
        disc.vertex_groups.new(name=f"eye_{tag}").add(list(range(len(disc.data.vertices))), 1.0, "REPLACE")
        discs.append(disc)
        lines = strips(f"Ink{tag}", rs, zs, s)
        lines.vertex_groups.new(name="head").add(list(range(len(lines.data.vertices))), 1.0, "REPLACE")
        discs.append(lines)
        # The bone: its head on the disc's centre, its Y axis (head to tail) the eye's axis.
        c = to_concept(np.array([ECEN[0], ECEN[1], zs[0]]), s, True)
        _, _, w, ax = frame(s, True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        b = rig.data.edit_bones.new(f"eye_{tag}")
        b.head = Vector(blender(c).tolist())
        b.tail = Vector(blender(c + ax*0.08).tolist())
        b.align_roll(Vector(blender(w).tolist()))
        b.parent = rig.data.edit_bones["head"]
        bpy.ops.object.mode_set(mode="OBJECT")
        report[tag] = {"discRadius": round(float(radius), 4), "rimPoints": len(rim), "centreDepth": round(float(zs[0]), 4)}
        # Its half of the texture, rows bottom up as UV v runs.
        n = TEXTURE
        X, Y = np.meshgrid(ECEN[0] + np.linspace(-radius, radius, n//2), ECEN[1] + np.linspace(-radius, radius, n))
        col, glow = storm(X, Y)
        pictures.append(col)
        glows.append(glow)
    glow = np.concatenate(glows, 1)
    col = np.clip(np.concatenate(pictures, 1)*0.92 + glow, 0.0, 1.0)
    for half in (0, TEXTURE//2):
        glow[:PATCH, half:half + PATCH] = glow[-PATCH:, half:half + PATCH] = 0.0
        col[:PATCH, half:half + PATCH] = INK
        col[-PATCH:, half:half + PATCH] = INK*0.75 + AIR*0.45*0.25
    amount = np.clip(np.max(glow, axis=-1, keepdims=True)/0.5, 0.0, 1.0)
    image = er.write("tormato-eyes-color", col, out)
    er.write("tormato-eyes-glow", np.repeat(amount, 3, -1), out, True)
    mat = bpy.data.materials.new("TormatoEyesSkin")
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.15
    for d in discs:
        d.data.materials.append(mat)
    eyes = er.join(discs, "TormatoEyes")
    return eyes, report
