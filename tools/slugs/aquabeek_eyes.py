"""Aquabeek's living eyes for the game model (owner, 2026-11-15: "idle facial expressions especially for aqua beak u need
to bring her eyes to life ... only aqua beak [blinks fully]").

Her face is painted onto one body mesh from the concept shader (tools/slugs/aquabeek_concept/template.html, B, FACE 3),
so nothing in it can move. This keeps the approved look at rest and adds what moves, as Floppy's eyes do:

- the visible eye (below her heavy lid's line, inside the almond) is cut out of the body;
- behind each opening an eyeball (part of a sphere) carries the shader's own eye: white, iris, pupil and highlights,
  computed from the same formulas in the eye's own flat coordinates, so the iris continues past the opening and a
  glance never shows skin. It turns on an `eye_L`/`eye_R` bone;
- just outside the eyeball, tucked under the raised lid edge at rest, a lid shell painted with her lid (liner and
  eyeshadow sampled from the shader just above the lid line). It turns down on a `lid_L`/`lid_R` bone, sliding over
  the eyeball and behind the lower lid for a full blink. BLINK_TURN (radians, printed and reported) closes it.

Everything is built in source Blender coordinates (concept (x, y up, z front) -> (x, -z, y)) before the export turns
and scales the model. L is her left, +x. Her rest pose leans her forward (the shader's rest(): z -= LEAN * a smoothstep
of height), and the face is drawn before the lean, so eye maths runs on un-leaned points and the parts are leaned back
onto the mesh; the lean shears the eyeball slightly, which the gaps allow for.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import build_aquabeek as ba
import export_rammstone_roblox as er
import sample_concept as sc

# Base form, B, FACE 3 (template.html).
EYE_C = np.array([0.310, 1.590, 0.458])
EW, ETOP, EBOT, ETILT = 0.214, 0.118, 0.056, 0.11
CURL, LIDK = 0.095, 0.70
SIDES = (("L", 1.0), ("R", -1.0))
LEAN = 0.11  # PROTO 1
DEPTH = 0.40  # how far behind the eye the eyeball's centre sits: a gentle dome
GAP = 0.006  # the eyeball sits this far inside the cut rim
SHELL = 0.003  # the lid shell sits this far outside the eyeball
TUCK = 0.006  # at rest the lid's edge sits this far above the lid line, under the raised lid
TEXTURE = 512


def smoothstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0.0, 1.0)
    return t*t*(3.0 - 2.0*t)


def eye_mid(x):
    o = np.maximum(x, 0.0)/EW
    return ETILT*x + CURL*o*o


def arch(x, xp, k):
    u = np.where(x < xp, (x - xp)/(EW + xp), (x - xp)/(EW - xp))
    return np.power(np.maximum(0.0, 1.0 - u*u), k)


def top(x):
    return eye_mid(x) + ETOP*arch(x, -EW/3.0, 0.55)


def bottom(x):
    return eye_mid(x) - EBOT*arch(x, EW/3.0, 0.75)


def lid_line(x):
    return eye_mid(x) + ETOP*LIDK*arch(x, -EW/3.0, 0.55)


def frame(s):
    """Eye centre and axes in concept space: u across (sign flipped per side), w up, a out."""
    ax = np.array([s*0.45, 0.02, 1.0])
    ax /= np.linalg.norm(ax)
    u = np.cross([0.0, 1.0, 0.0], ax)
    u /= np.linalg.norm(u)
    w = np.cross(ax, u)
    return EYE_C*np.array([s, 1.0, 1.0]), u, w, ax


def to_local(p, s):
    c, u, w, ax = frame(s)
    q = p - c
    return np.stack([s*(q @ u), q @ w, q @ ax], -1)


def to_concept(l, s):
    c, u, w, ax = frame(s)
    return c + (s*l[..., 0:1])*u + l[..., 1:2]*w + l[..., 2:3]*ax


def unlean(p):
    p = np.array(p, dtype=float)
    p[..., 2] -= LEAN*smoothstep(0.3, 1.9, p[..., 1])
    return p


def lean(p):
    p = np.array(p, dtype=float)
    p[..., 2] += LEAN*smoothstep(0.3, 1.9, p[..., 1])
    return p


def concept(b):
    """Source Blender to concept."""
    return np.stack([b[..., 0], b[..., 2], -b[..., 1]], -1)


def blender(c):
    return np.stack([c[..., 0], -c[..., 2], c[..., 1]], -1)


def visible(l):
    """Inside the eye and below the lid line: what shows of the eye at rest."""
    x, y = l[..., 0], l[..., 1]
    return (np.abs(x) < EW) & (y < lid_line(x)) & (y > bottom(x))


def eye_colour(x, y, s):
    """The shader's eyeShade (B, base form) at eye-local (x, y), as linear albedo."""
    gx, gy = x, y - eye_mid(x)
    lidd = y - lid_line(x)
    c = np.broadcast_to(np.array([0.86, 0.92, 0.97]), x.shape + (3,)).copy()
    c = c + (np.array([0.62, 0.72, 0.86]) - c)*(smoothstep(-0.040, 0.0, lidd)*0.70)[..., None]
    c *= (1.0 - 0.28*smoothstep(0.10, 0.20, np.abs(gx + 0.020)))[..., None]
    qx, qy = gx + 0.020, gy - 0.016
    ir = 0.092
    pd = np.hypot(qx, qy)
    a = np.arctan2(qy, qx)
    iris = 1.0 - smoothstep(ir - 0.0025, ir + 0.0015, pd)
    vy = smoothstep(0.064, -0.071, qy)
    irc = np.array([0.004, 0.075, 0.190]) + (np.array([0.06, 0.80, 0.88]) - np.array([0.004, 0.075, 0.190]))*vy[..., None]
    streak = 0.5 + 0.5*np.sin(a*22.0 + 1.5*np.sin(a*5.0))
    irc *= (1.0 + 0.22*(streak - 0.5)*smoothstep(0.034, ir - 0.015, pd))[..., None]
    ring = np.exp(-((pd - 0.042)/0.011)**2)*0.40
    irc = irc + (np.array([0.20, 0.82, 0.86]) - irc)*ring[..., None]
    rim = smoothstep(ir - 0.018, ir - 0.003, pd)
    irc = irc + (np.array([0.004, 0.030, 0.080]) - irc)*rim[..., None]
    irc *= (1.0 - 0.50*smoothstep(-0.050, 0.0, lidd))[..., None]
    c = c + (irc - c)*iris[..., None]
    pupil = 1.0 - smoothstep(0.93, 1.03, pd/0.034)
    c = c + (np.array([0.003, 0.008, 0.025]) - c)*pupil[..., None]
    wx = s*qx
    hx, hy = wx + 0.020, qy - 0.020
    hq = np.stack([0.86*hx - 0.50*hy, 0.50*hx + 0.86*hy], -1)
    hov = np.hypot(hq[..., 0]/0.017, hq[..., 1]/0.012)
    hdot = np.hypot(wx - 0.027, qy + 0.028)/0.008
    hl = np.maximum(1.0 - smoothstep(0.78, 1.0, hov), 0.70*(1.0 - smoothstep(0.60, 1.0, hdot)))
    c = c + (1.0 - c)*(hl*iris)[..., None]
    return np.clip(c, 0.0, 1.0)


def grid_mesh(name, xs, ys, point, uv):
    """A quad grid over (xs, ys), placed by point(x, y) -> source position, with uv(x, y)."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    verts = [[bm.verts.new(point(x, y)) for x in xs] for y in ys]
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            f = bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
            for loop, (a, b) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                loop[uvl].uv = uv(xs[a], ys[b])
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def cut_openings(low):
    """Delete the body faces over the visible eyes; returns each side's rim vertices (eye-local)."""
    mesh = low.data
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = unlean(concept(co.reshape(-1, 3)))
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    # A face goes if any corner is in the visible eye: a face straddling the edge would keep a sliver of painted eye
    # white, which shows round the opening once the lid closes.
    inside = np.zeros(len(co), bool)
    for _, s in SIDES:
        l = to_local(co, s)
        inside |= visible(l) & (np.abs(l[:, 2]) < 0.15)
    gone = [f for f in bm.faces if any(inside[v.index] for v in f.verts)]
    rim_ids = {v.index for f in gone for v in f.verts}
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    # The cut follows the mesh's triangles, so its edge is jagged: move each vertex on the opening's edge onto the
    # almond itself (the lid line above, the lower lid below, the corner at either end), so it is as smooth as the
    # painted eye was. They move a few thousandths, which the texture barely notices.
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        if not v.is_boundary:
            continue
        p = unlean(concept(np.array(v.co)))
        for _, s in SIDES:
            l = to_local(p[None], s)[0]
            if abs(l[0]) > EW*1.15 or abs(l[2]) > 0.15:
                continue
            x = float(np.clip(l[0], -EW*0.995, EW*0.995))
            up, down = float(lid_line(x)), float(bottom(x))
            y = up if abs(l[1] - up) < abs(l[1] - down) else down
            moved = to_concept(np.array([x, y, l[2]]), s)
            v.co = Vector(blender(lean(moved)).tolist())
    bm.to_mesh(mesh)
    bm.free()
    rims = {}
    keep = np.array(sorted(rim_ids))
    for tag, s in SIDES:
        l = to_local(co[keep], s)
        rims[tag] = l[(np.abs(l[:, 0]) < EW*1.2) & (np.abs(l[:, 2]) < 0.15)]
    print("cut", len(gone), "eye faces")
    return rims


def build(low, rig, out):
    """Adds the eyes and lids: their meshes, bones and weights. Returns the new mesh objects and a report."""
    rims = cut_openings(low)
    xs = np.linspace(-EW*1.30, EW*1.30, 56)
    report = {}
    eye_objs, lid_objs = [], []
    lid_rows = {}
    bpy.context.view_layer.objects.active = rig
    for tag, s in SIDES:
        rim = rims[tag]
        cy = float(eye_mid(0.0) + (ETOP - EBOT)/2)
        centre = np.array([0.0, cy, -DEPTH])
        radius = float(np.min(np.linalg.norm(rim - centre, axis=1))) - GAP
        lid_r = radius + SHELL
        y0, y1 = float(bottom(xs).min()) - 0.06, float(top(xs).max()) + 0.06

        def on_sphere(x, y, r):
            dx, dy = x - centre[0], y - centre[1]
            z = centre[2] + math.sqrt(max(r*r - dx*dx - dy*dy, 1e-6))
            return Vector(blender(lean(to_concept(np.array([x, y, z]), s))).tolist())

        ys = np.linspace(y0, y1, 40)
        half = 0.0 if tag == "L" else 0.5   # both eyes share one texture, L on the left half
        eye = grid_mesh(f"Eye{tag}", xs, ys, lambda x, y: on_sphere(x, y, radius),
                        lambda x, y: (half + 0.5*(x - xs[0])/(xs[-1] - xs[0]), (y - y0)/(y1 - y0)))
        if s < 0:   # mirrored side: keep the faces pointing out
            eye.data.flip_normals()
        eye_objs.append((eye, f"eye_{tag}"))
        # The blink: the lid's edge must travel from just above the lid line to past the lowest point of the
        # lower lid, everywhere along it.
        travel = float(np.max(lid_line(xs) + TUCK - bottom(xs))) + 0.012
        turn = travel/lid_r
        height = travel + 0.03
        ts = np.linspace(0.0, height, 24)
        edge = lid_line(xs) + TUCK
        lid = grid_mesh(f"Lid{tag}", np.arange(len(xs)), ts,
                        lambda i, t: on_sphere(xs[int(i)], float(edge[int(i)] + t), lid_r),
                        lambda i, t: (half + 0.5*i/(len(xs) - 1), t/height))
        if s < 0:
            lid.data.flip_normals()
        lid_objs.append((lid, f"lid_{tag}"))
        lid_rows[tag] = (xs, height)
        c, u, w, ax = frame(s)
        centre_c = to_concept(centre, s)
        report[tag] = {"eyeRadius": round(radius, 4), "lidRadius": round(lid_r, 4), "blinkTurn": round(turn, 4),
                       "rimPoints": int(len(rim))}
        # Bones: at the eyeball's centre, pointing up the eye (bone Y), Z out of it.
        bpy.ops.object.mode_set(mode="EDIT")
        head = rig.data.edit_bones["head"]
        for name in (f"eye_{tag}", f"lid_{tag}"):
            b = rig.data.edit_bones.new(name)
            b.head = Vector(blender(lean(centre_c)).tolist())
            b.tail = Vector(blender(lean(centre_c + w*0.08)).tolist())
            b.align_roll(Vector(blender(lean(centre_c + ax*0.08) - lean(centre_c)).tolist()))
            b.parent = head
        bpy.ops.object.mode_set(mode="OBJECT")
    # Textures, one each for the eyes and the lids, L on the left half: the eye from the formulas; the lid from
    # the shader just above the lid line. Rows run bottom up, as UV v does.
    half = TEXTURE//2
    u, v = np.meshgrid(np.linspace(0, 1, half), np.linspace(0, 1, TEXTURE))
    y0, y1 = float(bottom(xs).min()) - 0.06, float(top(xs).max()) + 0.06
    eye_rgb = np.concatenate([eye_colour(xs[0] + u*(xs[-1] - xs[0]), y0 + v*(y1 - y0), s) for _, s in SIDES], 1)
    eye_img = er.write("aquabeek-eyes-color", eye_rgb, out)
    lid_parts = []
    for tag, s in SIDES:
        _, height = lid_rows[tag]
        cols, rows = 64, 32
        X, T = np.meshgrid(np.linspace(xs[0], xs[-1], cols), np.linspace(0.0, height, rows))
        # The lid painting compressed onto the shell: liner at the edge, eyeshadow above.
        Y = lid_line(X) + 0.0015 + T*0.35
        pts = lean(to_concept(np.stack([X, Y, np.zeros_like(X)], -1).reshape(-1, 3), s))
        val = sc.sample_points(ba.PAGE, *ba.probe("base", 20), pts)[:, :3].astype(float)/255.0
        lid = (val*val).reshape(rows, cols, 3)
        # Smoothed along each row, so her lashes (drawn just above the lid line) don't streak the closed lid; the
        # liner at the edge and the eyeshadow above it stay.
        k = np.exp(-0.5*(np.arange(-12, 13)/5.0)**2)
        k /= k.sum()
        padded = np.pad(lid, ((0, 0), (12, 12), (0, 0)), mode="edge")
        lid = np.stack([np.stack([np.convolve(padded[r, :, c], k, mode="valid") for c in range(3)], -1)
                        for r in range(rows)])
        lid *= 0.85   # the closed lid read lighter than the skin round it
        lid[:2] = lid[:2]*0.35   # a dark lash line along the edge
        lid_parts.append(_resize(lid, TEXTURE, half))
    lid_img = er.write("aquabeek-lids-color", np.concatenate(lid_parts, 1), out)
    eyes = [(obj, bone, eye_img) for obj, bone in eye_objs]
    lids = [(obj, bone, lid_img) for obj, bone in lid_objs]
    meshes = []
    for name, parts in (("AquabeekEyes", eyes), ("AquabeekLids", lids)):
        # One material for both sides: Roblox splits a mesh by material.
        mat = bpy.data.materials.new(name + "Skin")
        mat.use_nodes = True
        shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = parts[0][2]
        mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = 0.15
        objs = []
        for obj, bone, _ in parts:
            obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
            obj.data.materials.append(mat)
            objs.append(obj)
        meshes.append(er.join(objs, name))
    return meshes, report


def _resize(rgb, height, width):
    """Bilinear resize of an (h, w, 3) array, without PIL (Blender's Python has none)."""
    h, w, _ = rgb.shape
    yi, xi = np.linspace(0, h - 1, height), np.linspace(0, w - 1, width)
    rows = np.stack([np.stack([np.interp(xi, np.arange(w), rgb[r, :, c]) for c in range(3)], -1) for r in range(h)])
    return np.stack([np.stack([np.interp(yi, np.arange(h), rows[:, col, c]) for c in range(3)], -1)
                     for col in range(width)], 1)
