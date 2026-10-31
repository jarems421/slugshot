"""Build Floppy in Blender 1:1 from the approved concept (docs/slugs/catalog/evidence/floppy/floppy.html).

The concept is a signed-distance model; this script ports its shape and colour
functions to NumPy, meshes the skin with surface nets, paints the colours into
vertex colours, builds the ring eyes with matching textures, rigs it and keys
the looping idle. Run with Blender 4.5:

`blender --background --factory-startup --disable-autoexec --python-exit-code 1
--python tools/slugs/build_floppy.py`

Writes assets/source/slugs/models/floppy/floppy.blend and its eye textures.
Concept coordinates are y-up with the face toward +z; Blender gets
(x, -z, y), so the face looks toward -Y (Blender's Front view).
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT

OUT = ROOT / "assets/source/slugs/models/floppy"
FPS = 24
LOOP_SECONDS = 12.0
GRID_STEP = 0.0065
TRIANGLE_TARGET = 360000

EL = np.array([-0.37, 1.56, 0.65])
ER = np.array([0.37, 1.56, 0.65])
EYE_DIM = np.array([0.23, 0.23, 0.085])

# Palette (linear), identical to the concept.
BODY = np.array([0.434, 0.457, 0.254])
UPPER_LID = np.array([0.250, 0.280, 0.140])
LOWER_LID = np.array([0.102, 0.096, 0.035])
STONE = np.array([0.694, 0.659, 0.524])
MOSS = np.array([0.144, 0.148, 0.060])
BELLY_EDGE = np.array([0.157, 0.147, 0.048])
MOUTH = np.array([0.16, 0.06, 0.04])
DROOL = np.array([0.80, 0.79, 0.70])
BAG = np.array([0.10, 0.07, 0.05])


# ---------------------------------------------------------------- SDF port

def smoothstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0.0, 1.0)
    return t*t*(3.0 - 2.0*t)


def smin(a, b, k):
    h = np.clip(0.5 + 0.5*(b - a)/k, 0.0, 1.0)
    return b*(1.0 - h) + a*h - k*h*(1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def sd_ell(p, r):
    k0 = np.linalg.norm(p/r, axis=-1)
    k1 = np.linalg.norm(p/(r*r), axis=-1)
    return k0*(k0 - 1.0)/np.maximum(k1, 1e-9)


def normalize(v):
    v = np.asarray(v, float)
    return v/np.linalg.norm(v)


def eye_basis(side):
    ax = normalize([side*0.4, 0.05, 1.0])
    u = normalize(np.cross([0.0, 1.0, 0.0], ax))
    w = np.cross(ax, u)
    return u, w, ax


def eye_local(p, side):
    c = EL if side < 0 else ER
    u, w, ax = eye_basis(side)
    q = p - c
    return np.stack([q @ u, q @ w, q @ ax], axis=-1)


def sd_bezier(pos, A, B, C):
    """Distance to a quadratic Bezier and its parameter, vectorised (after Inigo Quilez)."""
    a = B - A
    b = A - 2.0*B + C
    c = a*2.0
    d = A - pos
    kk = 1.0/np.dot(b, b)
    kx = kk*np.dot(a, b)
    ky = kk*(2.0*np.dot(a, a) + d @ b)/3.0
    kz = kk*(d @ a)
    p = ky - kx*kx
    q = kx*(2.0*kx*kx - 3.0*ky) + kz
    h = q*q + 4.0*p*p*p
    hs = np.sqrt(np.maximum(h, 0.0))
    t1 = np.clip(np.cbrt((hs - q)/2.0) + np.cbrt((-hs - q)/2.0) - kx, 0.0, 1.0)
    e1 = d + (c + b*t1[:, None])*t1[:, None]
    r1 = np.sum(e1*e1, axis=1)
    neg = p < 0
    z = np.sqrt(np.maximum(-p, 1e-12))
    arg = np.where(neg, q/np.where(neg, p*z*2.0, 1.0), 0.0)
    v = np.arccos(np.clip(arg, -1.0, 1.0))/3.0
    m, n = np.cos(v), np.sin(v)*1.732050808
    ta = np.clip((m + m)*z - kx, 0.0, 1.0)
    tb = np.clip((-n - m)*z - kx, 0.0, 1.0)
    ea = d + (c + b*ta[:, None])*ta[:, None]
    eb = d + (c + b*tb[:, None])*tb[:, None]
    ra, rb = np.sum(ea*ea, axis=1), np.sum(eb*eb, axis=1)
    r2 = np.where(rb < ra, rb, ra)
    t2 = np.where(rb < ra, tb, ta)
    use1 = h >= 0
    return np.sqrt(np.where(use1, r1, r2)), np.where(use1, t1, t2)


def antenna(side, sway=0.0):
    A = np.array([side*0.26, 2.10, 0.42])
    B = np.array([side*0.84 + sway*0.3, 2.52, 0.50])
    C = np.array([side*0.90 + sway, 1.44, 0.56 + sway*0.5])
    return A, B, C


def lid(p, side, h):
    slope = 0.24
    l = eye_local(p, side)
    shell = np.abs(sd_ell(l, EYE_DIM + 0.014)) - 0.012
    upper = -(l[:, 1] - h - slope*side*l[:, 0])/math.sqrt(1.0 + slope*slope)
    lower = l[:, 1] + 0.15 - 0.05*side*l[:, 0]
    return np.maximum(shell, np.minimum(upper, lower))


def mouth_local(p):
    q = p - np.array([0.03, 1.15, 0.73])
    x = q[:, 0]
    q = q.copy()
    q[:, 1] -= 1.2*x*x + 0.2*x + 0.4*np.maximum(x, 0.0)**2
    return q


def belly_folds(p):
    belly = smoothstep(0.32, 0.66, p[:, 2])*smoothstep(1.08, 0.55, p[:, 1])
    return smoothstep(0.55, 0.85, belly)*smoothstep(0.08, 0.2, p[:, 1])*(1.0 - smoothstep(0.3, 0.62, np.abs(p[:, 0])))


def fold_roll(p):
    y = (p[:, 1] + 0.22*p[:, 0]**2)*5.6 + 0.35
    y = y + 0.12*np.sin(y*1.7 + 0.8)
    f = y - np.floor(y)
    depth = 0.8 + 0.2*np.sin(np.floor(y)*2.3 + 1.0)
    return depth*smoothstep(0.0, 0.2, f)*(1.0 - smoothstep(0.25, 1.0, f))**0.8


def lobes(th, phase):
    return 1.0 + 0.07*np.sin(3.0*th + 0.7 + phase) + 0.045*np.sin(5.0*th - 1.3 + phase*0.6) + 0.035*np.sin(2.0*th + 2.1)


def skin(p):
    q = p - np.array([0.04, 0.0, -0.02])
    th = np.arctan2(q[:, 2], q[:, 0])
    k = lobes(th, 0.0)
    d = sd_ell(np.stack([q[:, 0]/k, q[:, 1] - 0.24, q[:, 2]/k], -1), np.array([0.64, 0.30, 0.62]))*np.minimum(k, 1.0)
    d = smin(d, sd_ell(p - [0.0, 0.78, 0.0], np.array([0.62, 0.74, 0.58])), 0.50)
    k2 = lobes(th, 1.4)
    d = smin(d, sd_ell(np.stack([q[:, 0]/k2, q[:, 1] - 0.02, q[:, 2]/k2], -1), np.array([0.74, 0.07, 0.71]))*np.minimum(k2, 1.0), 0.26)
    d = smin(d, sd_ell(p - [0.0, 0.66, 0.30], np.array([0.56, 0.46, 0.46])), 0.12)
    d = smin(d, sd_ell(p - [0.0, 1.62, 0.14], np.array([0.78, 0.74, 0.64])), 0.22)
    d = smin(d, sd_ell(p - [0.0, 2.00, 0.10], np.array([0.70, 0.45, 0.56])), 0.22)
    d = smin(d, sd_ell(p - [0.0, 0.10, -0.66], np.array([0.24, 0.11, 0.30])), 0.20)
    for i, s in enumerate((-1.0, 1.0)):
        d = smin(d, sd_ell(p - [s*0.40, 1.30, 0.44], np.array([0.17, 0.12, 0.15])), 0.08)
        d = smax(d, -sd_ell(eye_local(p, s), EYE_DIM + 0.03), 0.04)
        d = smin(d, lid(p, s, 0.03 if i == 0 else -0.03), 0.035)
        A, B, C = antenna(s)
        dist, t = sd_bezier(p, A, B, C)
        rad = 0.12 + (0.05 - 0.12)*smoothstep(0.0, 0.5, t)
        d = smin(d, dist - rad, 0.14)
        d = smin(d, np.linalg.norm(p - C, axis=1) - 0.08, 0.05)
    fm = belly_folds(p)
    d = d - 0.04*fm*(fold_roll(p) - 0.3)
    d = smax(d, -sd_ell(mouth_local(p), np.array([0.14, 0.036, 0.10])), 0.02)
    d = smax(d, -p[:, 1], 0.015)
    return d


def lozenge(p2, c, r):
    q = np.abs((p2 - c)/r)
    return 1.0 - smoothstep(0.8, 1.0, np.linalg.norm(q, axis=1)*0.6 + (q[:, 0] + q[:, 1])*0.4)


def mix(a, b, t):
    return a*(1.0 - t[:, None]) + b*t[:, None]


def skin_albedo(dp, n):
    col = np.tile(BODY, (len(dp), 1))
    x, y, z = dp[:, 0], dp[:, 1], dp[:, 2]
    back = smoothstep(0.1, -0.6, z)*smoothstep(0.3, 1.2, y)
    crown = smoothstep(1.95, 2.35, y)*smoothstep(-0.1, 0.4, n[:, 1])
    col = mix(col, MOSS, 0.18*np.maximum(back, crown))
    belly = smoothstep(0.32, 0.66, z)*smoothstep(1.08, 0.55, y)
    col = mix(col, STONE, 0.9*smoothstep(0.4, 0.6, belly))
    col = mix(col, STONE*0.72, 0.4*belly_folds(dp)*(1.0 - fold_roll(dp))**3)
    col = mix(col, BELLY_EDGE, 0.75*(1.0 - smoothstep(0.02, 0.075, np.abs(belly - 0.5))))
    spine = smoothstep(0.2, -0.15, z)
    p2 = dp[:, :2]
    m = np.zeros(len(dp))
    for c, r in (((0.0, 2.04), (0.17, 0.13)), ((0.02, 1.68), (0.15, 0.12)), ((-0.015, 1.30), (0.125, 0.10)),
                 ((0.01, 0.92), (0.10, 0.085)), ((0.0, 0.55), (0.075, 0.07))):
        m = np.maximum(m, lozenge(p2, np.array(c), np.array(r)))
    col = mix(col, MOSS, 0.92*m*spine)
    for i, s in enumerate((-1.0, 1.0)):
        r = np.linalg.norm(p2 - [s*0.37, 1.56], axis=1)/0.29
        cd = (p2 - [s*0.37, 1.35])/np.array([0.31, 0.21])
        crescent = np.exp(-2.0*np.sum(cd*cd, axis=1))*smoothstep(0.5, 1.05, r)
        bag = crescent*smoothstep(0.35, 0.55, z)
        col = mix(col, BAG, np.clip(1.3*bag, 0.0, 0.7))
        l = eye_local(dp, s)
        near = (1.0 - smoothstep(1.1, 1.3, np.linalg.norm(l[:, :2], axis=1)/0.23))*smoothstep(-0.14, -0.04, l[:, 2])
        h = 0.03 if i == 0 else -0.03
        upper = smoothstep(-0.01, 0.03, l[:, 1] - h - 0.24*s*l[:, 0])
        lower = smoothstep(-0.01, 0.03, -(l[:, 1] + 0.15 - 0.05*s*l[:, 0]))
        col = mix(col, UPPER_LID, near*upper)
        col = mix(col, LOWER_LID, near*lower)
        A, B, C = antenna(s)
        col = mix(col, MOSS, 1.0 - smoothstep(0.075, 0.11, np.linalg.norm(dp - C, axis=1)))
    col = col*(1.0 - 0.5*smoothstep(0.22, 0.0, y)[:, None]) + col*np.array([0.90, 0.90, 0.80])*(0.5*smoothstep(0.22, 0.0, y)[:, None])
    mouth = 1.0 - smoothstep(0.0, 0.2, np.linalg.norm(mouth_local(dp)/np.array([0.15, 0.045, 0.11]), axis=1) - 1.1)
    col = mix(col, MOUTH, mouth)
    a, b = np.array([-0.058, 1.13]), np.array([-0.064, 1.02])
    pa, ba = p2 - a, b - a
    hh = np.clip((pa @ ba)/np.dot(ba, ba), 0.0, 1.0)
    strand = np.linalg.norm(pa - ba*hh[:, None], axis=1) - (0.016 + (0.012 - 0.016)*hh)
    bead = np.linalg.norm((p2 - [-0.066, 1.002])/np.array([1.0, 1.15]), axis=1) - 0.026
    dd = smin(strand, bead, 0.015)
    front = smoothstep(0.52, 0.6, z)
    col = mix(col, MOUTH, front*(1.0 - smoothstep(0.004, 0.008, dd)))
    col = mix(col, DROOL, front*(1.0 - mouth)*(1.0 - smoothstep(-0.009, -0.005, dd)))
    return col


def ring(uv, c, r, w):
    return 1.0 - smoothstep(w*0.5 - 0.012, w*0.5 + 0.012, np.abs(np.linalg.norm(uv - c, axis=-1) - r))


def eye_pattern(uv, side):
    m = np.zeros(uv.shape[:-1])
    if side < 0:
        rings = (((0.00, 0.00), 0.22, 0.17), ((0.07, 0.03), 0.50, 0.11), ((0.13, 0.05), 0.80, 0.15))
        dot = 1.0 - smoothstep(0.08, 0.105, np.linalg.norm(uv, axis=-1))
    else:
        rings = (((0.00, 0.00), 0.17, 0.08), ((-0.04, -0.06), 0.36, 0.11), ((-0.07, -0.11), 0.56, 0.065), ((-0.10, -0.15), 0.78, 0.095))
        dot = 1.0 - smoothstep(0.06, 0.085, np.linalg.norm(uv - [0.02, 0.01], axis=-1))
    for c, r, w in rings:
        m = np.maximum(m, ring(uv, np.array(c), r, w))
    m = np.maximum(m, dot)
    white, green = np.array([0.84, 0.84, 0.76]), np.array([0.04, 0.34, 0.07])
    return white*(1.0 - m[..., None]) + green*m[..., None]


# ---------------------------------------------------------------- meshing

def sample_grid():
    xs = np.arange(-1.25, 1.25 + 1e-9, GRID_STEP)
    ys = np.arange(-0.03, 2.55 + 1e-9, GRID_STEP)
    zs = np.arange(-1.25, 1.20 + 1e-9, GRID_STEP)
    vals = np.empty((len(xs), len(ys), len(zs)), np.float32)
    Y, Z = np.meshgrid(ys, zs, indexing="ij")
    for i, x in enumerate(xs):
        pts = np.stack([np.full(Y.size, x), Y.ravel(), Z.ravel()], -1)
        vals[i] = skin(pts).reshape(Y.shape)
    return xs, ys, zs, vals


def surface_nets(xs, ys, zs, vals):
    inside = vals < 0
    nx, ny, nz = vals.shape
    corners = [(a, b, c) for a in (0, 1) for b in (0, 1) for c in (0, 1)]
    count = np.zeros((nx - 1, ny - 1, nz - 1), np.int8)
    for a, b, c in corners:
        count += inside[a:nx - 1 + a, b:ny - 1 + b, c:nz - 1 + c]
    active = (count > 0) & (count < 8)
    ci, cj, ck = np.nonzero(active)
    vid = np.full(active.shape, -1, np.int32)
    vid[ci, cj, ck] = np.arange(len(ci), dtype=np.int32)
    edges = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]
    total = np.zeros((len(ci), 3))
    hits = np.zeros(len(ci))
    grid = (xs, ys, zs)
    for e0, e1 in edges:
        o0, o1 = corners[e0], corners[e1]
        v0 = vals[ci + o0[0], cj + o0[1], ck + o0[2]].astype(float)
        v1 = vals[ci + o1[0], cj + o1[1], ck + o1[2]].astype(float)
        crossing = (v0 < 0) != (v1 < 0)
        t = np.where(crossing, v0/np.where(crossing, v0 - v1, 1.0), 0.0)
        p0 = np.stack([grid[a][idx + o0[a]] for a, idx in enumerate((ci, cj, ck))], -1)
        p1 = np.stack([grid[a][idx + o1[a]] for a, idx in enumerate((ci, cj, ck))], -1)
        total += np.where(crossing[:, None], p0 + (p1 - p0)*t[:, None], 0.0)
        hits += crossing
    verts = total/np.maximum(hits, 1)[:, None]
    quads = []
    # Grid edges crossing the surface; each joins the four cells around it.
    e = inside[:-1, 1:-1, 1:-1] != inside[1:, 1:-1, 1:-1]
    i, j, k = np.nonzero(e); j += 1; k += 1
    quads.append(np.stack([vid[i, j-1, k-1], vid[i, j, k-1], vid[i, j, k], vid[i, j-1, k]], -1))
    e = inside[1:-1, :-1, 1:-1] != inside[1:-1, 1:, 1:-1]
    i, j, k = np.nonzero(e); i += 1; k += 1
    quads.append(np.stack([vid[i-1, j, k-1], vid[i, j, k-1], vid[i, j, k], vid[i-1, j, k]], -1))
    e = inside[1:-1, 1:-1, :-1] != inside[1:-1, 1:-1, 1:]
    i, j, k = np.nonzero(e); i += 1; j += 1
    quads.append(np.stack([vid[i-1, j-1, k], vid[i, j-1, k], vid[i, j, k], vid[i-1, j, k]], -1))
    faces = np.concatenate(quads)
    assert (faces >= 0).all(), "surface reached the sampling bounds"
    return verts, faces


def gradient(f, p, eps=0.0015):
    g = np.zeros_like(p)
    for a in range(3):
        o = np.zeros(3); o[a] = eps
        g[:, a] = (f(p + o) - f(p - o))/(2*eps)
    return g


def project(p, iterations=3):
    for _ in range(iterations):
        d = skin(p)
        g = gradient(skin, p)
        step = d/np.maximum(np.sum(g*g, axis=1), 1e-6)
        p = p - g*np.clip(step, -0.006, 0.006)[:, None]
    return p


def to_blender(p):
    return np.stack([p[..., 0], -p[..., 2], p[..., 1]], -1)


# ---------------------------------------------------------------- Blender scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.unit_settings.scale_length = 1.0


def mesh_object(name, verts, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts.tolist(), [], faces.tolist())
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", np.ones(len(mesh.polygons), bool))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def principled(mat):
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def set_inputs(node, values):
    for name, value in values.items():
        if name in node.inputs:
            node.inputs[name].default_value = value


def skin_material(image):
    mat = bpy.data.materials.new("FloppySkin")
    mat.use_nodes = True
    shader = principled(mat)
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    # Wet, soft skin: light scattering, a moist coat and broad sheen.
    set_inputs(shader, {"Roughness": 0.42, "Subsurface Weight": 0.15, "Subsurface Scale": 0.08,
                        "Subsurface Radius": (1.0, 0.8, 0.4), "Coat Weight": 0.45, "Coat Roughness": 0.08,
                        "Sheen Weight": 0.08, "Specular IOR Level": 0.4})
    return mat


def save_texture(name, rgb_linear, size):
    srgb = np.where(rgb_linear <= 0.0031308, 12.92*rgb_linear, 1.055*np.power(np.maximum(rgb_linear, 0.0), 1/2.4) - 0.055)
    image = bpy.data.images.new(name, size, size, alpha=False)
    image.pixels.foreach_set(np.concatenate([srgb, np.ones(srgb.shape[:-1] + (1,))], -1).astype(np.float32).ravel())
    path = OUT/"textures"/(name + ".png")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def bake_body_texture(body, concept, normals, size=2048):
    """Colour every texel from the concept's colour rules at its exact rest position.

    Rest position and normal are stored on the mesh, baked into float images
    through emission, decoded, and run through skin_albedo."""
    mesh = body.data
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Emission can't carry negative values, so encode into 0..1.
    for name, data in (("rest", concept*0.25 + 0.5), ("rest_normal", normals*0.5 + 0.5)):
        attr = mesh.attributes.new(name, "FLOAT_VECTOR", "POINT")
        attr.data.foreach_set("vector", data.astype(np.float32).ravel())
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    baked = {}
    for name in ("rest", "rest_normal"):
        image = bpy.data.images.new("bake_" + name, size, size, alpha=True, float_buffer=True)
        image.colorspace_settings.name = "Non-Color"
        image.pixels.foreach_set(np.zeros(size*size*4, np.float32))
        mat = bpy.data.materials.new("Bake_" + name)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        nodes.clear()
        attr = nodes.new("ShaderNodeAttribute")
        attr.attribute_name = name
        emit = nodes.new("ShaderNodeEmission")
        out = nodes.new("ShaderNodeOutputMaterial")
        links.new(attr.outputs["Vector"], emit.inputs["Color"])
        links.new(emit.outputs["Emission"], out.inputs["Surface"])
        target = nodes.new("ShaderNodeTexImage")
        target.image = image
        nodes.active = target
        mesh.materials.clear()
        mesh.materials.append(mat)
        bpy.ops.object.bake(type="EMIT", margin=12, use_clear=False)
        px = np.empty(size*size*4, np.float32)
        image.pixels.foreach_get(px)
        baked[name] = px.reshape(size, size, 4)
        bpy.data.images.remove(image)
        bpy.data.materials.remove(mat)
    mesh.materials.clear()
    ao = bake_occlusion(body, size)
    mask = baked["rest"][..., 3] > 0.5
    pts = (baked["rest"][..., :3][mask].astype(float) - 0.5)/0.25
    ns = baked["rest_normal"][..., :3][mask].astype(float)*2.0 - 1.0
    ns /= np.maximum(np.linalg.norm(ns, axis=1), 1e-9)[:, None]
    rgb = np.tile(BODY, (size, size, 1))
    rgb[mask] = skin_albedo(pts, ns)
    # Depth: baked contact shadow in folds, lids and creases, plus a slightly
    # deeper, richer grade, so the skin doesn't read pale and flat (owner
    # request). Baked in, so it also shows under Roblox's flatter lighting.
    rgb *= (0.5 + 0.5*ao)[..., None]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    rgb = np.clip(lum[..., None] + (rgb - lum[..., None])*1.18, 0.0, 1.0)**1.12
    for name in ("rest", "rest_normal"):
        mesh.attributes.remove(mesh.attributes[name])
    return save_texture("floppy-body", rgb, size)


def bake_occlusion(body, size):
    world = bpy.data.worlds.new("BakeWorld")
    world.light_settings.distance = 0.22
    bpy.context.scene.world = world
    bpy.context.scene.cycles.samples = 96
    image = bpy.data.images.new("bake_ao", size, size, alpha=False, float_buffer=True)
    image.colorspace_settings.name = "Non-Color"
    mat = bpy.data.materials.new("Bake_ao")
    mat.use_nodes = True
    target = mat.node_tree.nodes.new("ShaderNodeTexImage")
    target.image = image
    mat.node_tree.nodes.active = target
    body.data.materials.append(mat)
    bpy.ops.object.bake(type="AO", margin=12)
    px = np.empty(size*size*4, np.float32)
    image.pixels.foreach_get(px)
    body.data.materials.clear()
    bpy.data.materials.remove(mat)
    bpy.data.images.remove(image)
    bpy.context.scene.cycles.samples = 1
    return px.reshape(size, size, 4)[..., 0].astype(float)


def eye_material(side, image):
    mat = bpy.data.materials.new("FloppyEye_" + ("L" if side < 0 else "R"))
    mat.use_nodes = True
    shader = principled(mat)
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    set_inputs(shader, {"Roughness": 0.08, "Coat Weight": 1.0, "Coat Roughness": 0.03})
    return mat


def eye_texture(side, size=512):
    lin = np.linspace(-1.0, 1.0, size)
    U, V = np.meshgrid(lin, lin)
    return save_texture("floppy-eye-" + ("left" if side < 0 else "right"), eye_pattern(np.stack([U, V], -1), side), size)


def eye_object(side, mat):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=1.0)
    local = np.array([v.co[:] for v in bm.verts])*EYE_DIM
    u, w, ax = eye_basis(side)
    c = EL if side < 0 else ER
    world = c + local[:, :1]*u + local[:, 1:2]*w + local[:, 2:3]*ax
    bm.verts.index_update()
    for v, co in zip(bm.verts, to_blender(world)):
        v.co = co
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            lx, ly = local[loop.vert.index, 0], local[loop.vert.index, 1]
            loop[uv_layer].uv = (lx/EYE_DIM[0]*0.5 + 0.5, ly/EYE_DIM[1]*0.5 + 0.5)
    mesh = bpy.data.meshes.new("Eye" + ("L" if side < 0 else "R"))
    bm.to_mesh(mesh)
    bm.free()
    mesh.polygons.foreach_set("use_smooth", np.ones(len(mesh.polygons), bool))
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_rig():
    arm = bpy.data.armatures.new("FloppyRig")
    rig = bpy.data.objects.new("FloppyRig", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {}

    def bone(name, head, tail, parent=None):
        b = arm.edit_bones.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.roll = 0.0
        if parent:
            b.parent = bones[parent]
        bones[name] = b

    bone("root", (0, 0, 0), (0, 0, 0.3))
    bone("body_lower", (0, 0, 0.05), (0, 0, 0.6), "root")
    bone("body_upper", (0, 0, 0.6), (0, 0, 1.05), "body_lower")
    bone("head", (0, 0, 1.05), (0, 0, 1.8), "body_upper")
    for side, tag in ((-1.0, "L"), (1.0, "R")):
        A, _B, C = antenna(side)
        bone("antenna_" + tag, to_blender(A), to_blender(C), "head")
        c = EL if side < 0 else ER
        _u, _w, ax = eye_basis(side)
        bone("eye_" + tag, to_blender(c), to_blender(c + ax*0.12), "head")
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin_weights(obj, concept):
    y = concept[:, 1]
    head = smoothstep(0.9, 1.5, y)
    upper = smoothstep(0.35, 0.95, y)*(1.0 - head)
    lower = 1.0 - head - upper
    weights = {"body_lower": lower, "body_upper": upper, "head": head}
    for side, tag in ((-1.0, "L"), (1.0, "R")):
        A, B, C = antenna(side)
        dist, t = sd_bezier(concept, A, B, C)
        rad = 0.12 + (0.05 - 0.12)*smoothstep(0.0, 0.5, t)
        on = (1.0 - smoothstep(rad + 0.02, rad + 0.09, dist))*smoothstep(0.1, 0.32, t)
        bulb = 1.0 - smoothstep(0.09, 0.15, np.linalg.norm(concept - C, axis=1))
        a = np.maximum(on, bulb)
        for key in list(weights):
            weights[key] = weights[key]*(1.0 - a)
        weights["antenna_" + tag] = a
    for name, w in weights.items():
        group = obj.vertex_groups.new(name=name)
        q = np.round(w, 2)
        for value in np.unique(q):
            if value <= 0:
                continue
            group.add(np.nonzero(q == value)[0].tolist(), float(value), "REPLACE")


def attach(obj, rig, bone=None):
    obj.parent = rig
    if bone:
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.modifiers.new("Armature", "ARMATURE").object = rig


def animate_idle(rig):
    """The concept's idle, at rates rounded so every motion loops in 12 s."""
    rig.animation_data_create()
    action = bpy.data.actions.new("Idle")
    action.use_fake_user = True
    rig.animation_data.action = action
    pose = rig.pose.bones
    frames = int(LOOP_SECONDS*FPS)
    tau = math.tau/LOOP_SECONDS
    breath_w, wobble_x_w, wobble_z_w = 3*tau, 4*tau, 3*tau
    loll_w, antenna_w, eye_w = 1*tau, 2*tau, 1*tau
    for frame in range(0, frames + 1, 2):
        t = frame/FPS
        for b in pose:
            b.rotation_mode = "XYZ"
            b.location, b.rotation_euler, b.scale = (0, 0, 0), (0, 0, 0), (1, 1, 1)
        b_ = math.sin(t*breath_w)
        # Bone axes: X = world X, Y = along the bone (up), Z = toward the face.
        pose["root"].scale = (1 - 0.01*b_, 1 + 0.012*b_, 1 - 0.01*b_)
        pose["body_upper"].scale = (1, 1 + 0.008*b_, 1)
        pose["body_upper"].location = (0.006*math.sin(t*wobble_x_w - 1.6), 0, 0.005*math.sin(t*wobble_z_w - 0.3))
        pose["head"].location = (0.008*math.sin(t*wobble_x_w - 3.0), 0, 0.006*math.sin(t*wobble_z_w - 2.3))
        pose["head"].rotation_euler = (0, 0, 0.04*math.sin(t*loll_w))
        for side, tag in ((-1.0, "L"), (1.0, "R")):
            sw = math.sin(t*antenna_w + side*1.3)
            pose["antenna_" + tag].rotation_euler = (0.025*sw, 0, -0.045*sw)
            pose["eye_" + tag].rotation_euler = (0, (1 if side < 0 else -1)*eye_w*t, 0)
        for b in pose:
            for prop in ("location", "rotation_euler", "scale"):
                b.keyframe_insert(prop, frame=frame + 1, group=b.name)
    for fc in action.fcurves:
        if fc.data_path.endswith("rotation_euler") and "eye_" in fc.data_path:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, frames + 1
    scene.frame_set(1)


def main():
    reset()
    print("sampling skin SDF")
    xs, ys, zs, vals = sample_grid()
    verts, faces = surface_nets(xs, ys, zs, vals)
    print("surface nets:", len(verts), "verts", len(faces), "quads")
    body = mesh_object("FloppyBody", to_blender(project(verts)), faces)
    # Fine sampling keeps the thin lid edges smooth; decimate back to a
    # workable density, then snap every vertex onto the exact surface again.
    bpy.context.view_layer.objects.active = body
    reduce = body.modifiers.new("Reduce", "DECIMATE")
    reduce.ratio = TRIANGLE_TARGET/(2.0*len(faces))
    bpy.ops.object.modifier_apply(modifier=reduce.name)
    co = np.empty(len(body.data.vertices)*3)
    body.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    verts = project(np.stack([co[:, 0], co[:, 2], -co[:, 1]], -1))
    body.data.vertices.foreach_set("co", to_blender(verts).astype(np.float32).ravel())
    body.data.update()
    normals = gradient(skin, verts)
    normals /= np.maximum(np.linalg.norm(normals, axis=1), 1e-9)[:, None]
    body.data.materials.append(skin_material(bake_body_texture(body, verts, normals)))
    rig = build_rig()
    skin_weights(body, verts)
    attach(body, rig)
    for side, tag in ((-1.0, "L"), (1.0, "R")):
        eye = eye_object(side, eye_material(side, eye_texture(side)))
        attach(eye, rig, "eye_" + tag)
    animate_idle(rig)
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"floppy.blend"), compress=True)
    print("Saved", OUT/"floppy.blend", "triangles", sum(len(p.vertices) - 2 for p in body.data.polygons))


if __name__ == "__main__":
    main()
