"""Build Rammstone's transformed form: a first concept for the owner, on the final base form.

Owner, 2026-11-13: "it needs arms, because obviously it's gonna be punching stuff... It needs the big horns... big devil
horn, rock things... red armor all over it. Maybe not all around... you can have the belly and some patches... I don't
think it should have a tail... its arms should look like really armored, and I don't know if it should really have
fingers, but it should just look like something that like can punch." "I'll give you the main features I want, and
then you can just build off it."

The final base form (build_rammstone_clean.build) is kept whole: face, hood, crest, cheek shards, plates and belly, so the
transformed form is plainly the same slug. Its horns are replaced and arms added:

- Devil horns: thick faceted charcoal horns from the base horns' roots, sweeping out to the sides, up, and curling in at
  the tips, ridged along their length like rock.
- Massive arms in a ready stance, fists forward and low at the sides, so the face and belly stay clear: a tan skin arm
  under the armour, showing at the elbow
  and armpit; a layered rock pauldron over the shoulder; a bracer on the upper arm; a spike on the elbow; a gauntlet on
  the forearm flaring to the wrist, with fins along its outer edge; and a big blocky rock fist with no fingers, a thumb
  wrapped across the front, and charcoal knuckles cracked with glowing magma.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_rammstone_transformed.py`

Writes assets/source/slugs/models/rammstone/rammstone-transformed.blend and build/slugs/rammstone/transformed/renders/.
No rig or export.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT
import build_rammstone_clean as base
import build_rammstone_surface as surf

OUT = ROOT/"build/slugs/rammstone/transformed"
BLEND = ROOT/"assets/source/slugs/models/rammstone/rammstone-transformed.blend"

# Devil horn: a cubic curve from the base horn's root, out to the side, up, and curling in at the tip (right side; the
# left mirrors it), HORN_ROOT_R thick at the root, with HORN_RIDGES ridges along it.
HORN_OUT = ((0.34, 0.02, 0.16), (0.60, 0.06, 0.58), (0.40, -0.12, 0.95))  # control points relative to the root
HORN_ROOT_R, HORN_RIDGES = 0.23, 7
# The arm (right side): shoulder, elbow and wrist in a ready stance, the fist forward and low at the side. A guard with
# the fists up by the face made them read as small claws; a brawler's arms are massive, the fist about the face's size.
SHOULDER, ELBOW, WRIST = Vector((0.60, -0.04, 1.10)), Vector((1.05, 0.06, 0.78)), Vector((1.02, -0.30, 0.50))
ARM_R = (0.16, 0.14, 0.13)  # skin radius at the shoulder, elbow and wrist
FIST = (0.25, 0.24, 0.215)  # half its depth (along the forearm), width and height
PAULDRON = (0.36, 0.38, 0.28)  # its half depth, width and height
GAUNTLET = (0.20, 0.26)  # its radius below the elbow and at the wrist
JITTER = 0.012  # how far rock vertices are nudged, so the facets are uneven


def smoothstep(a, b, x):
    t = min(max((x - a)/(b - a), 0.0), 1.0)
    return t*t*(3.0 - 2.0*t)


def rng(name):
    return np.random.default_rng(abs(hash(name)) % (2**32))


def frames(points):
    """Tangents and parallel-transported normals along a polyline, so a swept section does not twist."""
    tangents = []
    for i in range(len(points)):
        a, b = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
        tangents.append((b - a).normalized())
    up = Vector((0.0, 0.0, 1.0)) if abs(tangents[0].z) < 0.9 else Vector((1.0, 0.0, 0.0))
    normal = (up - tangents[0]*up.dot(tangents[0])).normalized()
    normals = [normal]
    for i in range(1, len(points)):
        n = normals[-1] - tangents[i]*normals[-1].dot(tangents[i])
        normals.append(n.normalized())
    return tangents, normals


def sweep(name, points, radii, sides, smooth, jitter=0.0, squash=1.0, phase=0.0, cap=True):
    """A closed tube along points with a radius per point; a pointed tip if the last radius is 0."""
    tangents, normals = frames(points)
    r = rng(name)
    verts, faces = [], []
    tip = radii[-1] <= 1e-6
    rings = len(points) - (1 if tip else 0)
    for i in range(rings):
        t, n = tangents[i], normals[i]
        b = t.cross(n)
        for k in range(sides):
            a = 2*math.pi*k/sides + phase
            q = points[i] + n*(radii[i]*math.cos(a)) + b*(radii[i]*squash*math.sin(a))
            if jitter:
                q += Vector(r.uniform(-jitter, jitter, 3))*min(1.0, radii[i]/0.05)
            verts.append(tuple(q))
    for i in range(rings - 1):
        for k in range(sides):
            a, c = i*sides + k, i*sides + (k + 1) % sides
            faces.append((a, c, c + sides, a + sides))
    if tip:
        verts.append(tuple(points[-1]))
        e = (rings - 1)*sides
        faces += [(e + k, e + (k + 1) % sides, len(verts) - 1) for k in range(sides)]
    elif cap:
        faces.append(tuple(range((rings - 1)*sides, rings*sides)))
    if cap:
        faces.append(tuple(range(sides - 1, -1, -1)))
    return base.make_object(name, verts, faces, smooth=smooth, facet=None if smooth else 0.5)


def catmull(controls, per):
    """Catmull-Rom points through controls, per points a span."""
    ext = [controls[0]*2 - controls[1]] + list(controls) + [controls[-1]*2 - controls[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1:i + 3]
        for j in range(per):
            t = j/per
            out.append(0.5*((2*p1) + (-p0 + p2)*t + (2*p0 - 5*p1 + 4*p2 - p3)*t*t + (-p0 + 3*p1 - 3*p2 + p3)*t**3))
    out.append(controls[-1])
    return out


def mirror(v, sign):
    return Vector((v.x*sign, v.y, v.z))


# ---------------------------------------------------------------- horns

def build_devil_horn(s, sign):
    pts, _, _ = base.horn_path(s)
    root = Vector(pts[2])
    root.x = abs(root.x)
    controls = [root] + [root + Vector(c) for c in HORN_OUT]
    centre = []
    for k in range(29):
        u = k/28
        p0, p1, p2, p3 = controls
        centre.append((1 - u)**3*p0 + 3*u*(1 - u)**2*p1 + 3*u*u*(1 - u)*p2 + u**3*p3)
    # Its root continued down into the head, so it grows out of it.
    down = (centre[0] - centre[1]).normalized()
    centre = [centre[0] + down*0.10] + centre
    radii = []
    for k in range(len(centre)):
        u = max(k - 1, 0)/28
        ridge = 1.0 + 0.07*max(0.0, math.cos(2*math.pi*HORN_RIDGES*u))**4*(1.0 - u)
        radii.append(HORN_ROOT_R*(1.0 - u)**0.85*ridge if k < len(centre) - 1 else 0.0)
    centre = [mirror(c, sign) for c in centre]
    return sweep(f"RammstoneDevilHorn.{'R' if sign > 0 else 'L'}", centre, radii, 6, smooth=False, jitter=0.006,
                 squash=0.85, phase=math.pi/6)


# ---------------------------------------------------------------- arms

def superellipsoid(name, centre, axes, half, n=3.0, rows=8, cols=12, jitter=0.0, cut=None):
    """A rounded box (superellipsoid of exponent n) at centre with axes (forward, side, up) and half sizes; with cut,
    only latitudes up to cut (radians from the top) for a cap, its rim at the bottom."""
    f, sd, up = axes
    r = rng(name)
    verts, faces = [], []
    top = math.pi if cut is None else cut
    e = 2.0/n

    def sgnpow(v, p):
        return math.copysign(abs(v)**p, v)

    for i in range(rows + 1):
        th = top*i/rows
        for j in range(cols):
            ph = 2*math.pi*j/cols
            x = sgnpow(math.sin(th), e)*sgnpow(math.cos(ph), e)
            y = sgnpow(math.sin(th), e)*sgnpow(math.sin(ph), e)
            z = sgnpow(math.cos(th), e)
            q = centre + f*(x*half[0]) + sd*(y*half[1]) + up*(z*half[2])
            if jitter and 0 < i < rows:
                q += Vector(r.uniform(-jitter, jitter, 3))
            verts.append(tuple(q))
    for i in range(rows):
        for j in range(cols):
            a, b = i*cols + j, i*cols + (j + 1) % cols
            faces.append((a, b, b + cols, a + cols))
    if cut is not None:
        faces.append(tuple(range(rows*cols + cols - 1, rows*cols - 1, -1)))
    return base.make_object(name, verts, faces, smooth=False, facet=0.5)


def band(name, a, b, r0, r1, sides, thick, jag=0.0, phase=0.0, outer=None):
    """A rock band round the axis a to b, radius r0 to r1, thick; its b end jagged into points jag long. With outer (a
    direction), only the half facing it, as a plate."""
    axis = (b - a)
    length = axis.length
    axis.normalize()
    ref = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    n = (ref - axis*ref.dot(axis)).normalized()
    m = axis.cross(n)
    r = rng(name)
    angles = [2*math.pi*k/sides + phase for k in range(sides)]
    if outer is not None:
        o = (outer - axis*outer.dot(axis)).normalized()
        centre = math.atan2(o.dot(m), o.dot(n))
        angles = [centre - 1.4 + 2.8*k/(sides - 1) for k in range(sides)]
    rows = 3
    verts = []
    for side_r in (0.0, -thick):
        for i in range(rows + 1):
            v = i/rows
            for k, ang in enumerate(angles):
                ext = jag*(1.0 if k % 2 == 0 else 0.25) if i == rows else 0.0
                rad = r0 + (r1 - r0)*v + side_r
                q = a + axis*(length*v + ext) + n*(rad*math.cos(ang)) + m*(rad*math.sin(ang))
                if 0 < i < rows and side_r == 0.0:
                    q += Vector(r.uniform(-JITTER, JITTER, 3))*0.6
                verts.append(tuple(q))
    cols = len(angles)
    closed = outer is None
    per = (rows + 1)*cols
    idx = lambda layer, i, k: layer*per + i*cols + k % cols
    faces = []
    span = cols if closed else cols - 1
    for i in range(rows):
        for k in range(span):
            faces.append((idx(0, i, k), idx(0, i, k + 1), idx(0, i + 1, k + 1), idx(0, i + 1, k)))
            faces.append((idx(1, i + 1, k), idx(1, i + 1, k + 1), idx(1, i, k + 1), idx(1, i, k)))
    for i in (0, rows):
        for k in range(span):
            faces.append((idx(0, i, k), idx(1, i, k), idx(1, i, k + 1), idx(0, i, k + 1)))
    if not closed:
        for k in (0, cols - 1):
            for i in range(rows):
                faces.append((idx(0, i, k), idx(0, i + 1, k), idx(1, i + 1, k), idx(1, i, k)))
    return base.make_object(name, verts, faces, smooth=False, facet=0.5)


def spike(name, root, direction, radius, length, sides=5):
    d = direction.normalized()
    pts = [root - d*0.04, root + d*length*0.35, root + d*length]
    return sweep(name, pts, [radius, radius*0.7, 0.0], sides, smooth=False, jitter=0.004)


def build_arm(sign):
    """One arm: skin, pauldron, bracer, elbow spike, gauntlet with fins, fist, thumb and knuckles. Returns (rock parts,
    skin parts, magma parts)."""
    tag = "R" if sign > 0 else "L"
    S, E, W = (mirror(v, sign) for v in (SHOULDER, ELBOW, WRIST))
    up_dir = (S - E).normalized()  # the upper arm, elbow to shoulder
    fore = (W - E).normalized()
    out_x = Vector((sign, 0.0, 0.0))
    # Skin: a smooth tube from inside the body through the elbow to inside the fist.
    inside = S + (S - E).normalized()*0.16 + Vector((-sign*0.08, 0.0, 0.0))
    path = catmull([inside, S, E, W, W + fore*0.10], 6)
    joints = (ARM_R[0], ARM_R[0], ARM_R[1], ARM_R[2], ARM_R[2])  # at the five controls, 6 points apart
    radii = list(np.interp(np.arange(len(path)), np.arange(0, len(path), 6), joints))
    skin = sweep(f"RammstoneArm.{tag}", path, radii, 14, smooth=True)

    rock = []
    # Pauldron: a cap over the shoulder tilted out and down the arm, and two lames below it, jagged at their edges.
    cap_up = (Vector((sign*0.55, 0.0, 0.85)) + (-up_dir)*0.2).normalized()
    cap_f = Vector((0.0, -1.0, 0.0))
    cap_f = (cap_f - cap_up*cap_f.dot(cap_up)).normalized()
    cap_s = cap_up.cross(cap_f)
    cap_centre = S + Vector((sign*0.07, 0.0, 0.04))
    rock.append(superellipsoid(f"RammstonePauldron.{tag}", cap_centre, (cap_f, cap_s, cap_up), PAULDRON,
                               n=2.4, rows=6, cols=10, jitter=0.01, cut=math.radians(105)))
    for k, (t0, t1, r0, r1) in enumerate(((0.10, 0.42, 0.27, 0.29), (0.30, 0.62, 0.23, 0.25))):
        a, b = S + (E - S)*t0, S + (E - S)*t1
        rock.append(band(f"RammstoneLame{k}.{tag}", a, b, r0, r1, 9, 0.05, jag=0.06, phase=0.3*k,
                         outer=out_x + Vector((0, 0, 0.6))))
    # Elbow: a spike pointing back and out from the bend.
    bend = -((S - E).normalized() + fore).normalized()
    rock.append(spike(f"RammstoneElbow.{tag}", E + bend*0.08, bend + out_x*0.3, 0.11, 0.30))
    # Gauntlet: a band from below the elbow flaring to the wrist, jagged at the wrist, and fins along its outer edge.
    g0, g1 = E + fore*0.10, W + fore*0.02
    rock.append(band(f"RammstoneGauntlet.{tag}", g0, g1, GAUNTLET[0], GAUNTLET[1], 8, 0.09, jag=0.04, phase=0.2))
    fin_side = (out_x - fore*out_x.dot(fore)).normalized()
    for k, t in enumerate((0.25, 0.5, 0.75)):
        root = g0 + (g1 - g0)*t + fin_side*(GAUNTLET[0] + (GAUNTLET[1] - GAUNTLET[0])*t - 0.02)
        rock.append(spike(f"RammstoneFin{k}.{tag}", root, fin_side + (-fore)*0.6 + Vector((0, 0, 0.3)), 0.07, 0.18, 4))
    # Fist: a big rounded block on the forearm, knuckles forward, thumb across the front below them.
    f = fore
    sd = (out_x - f*out_x.dot(f)).normalized()
    up = f.cross(sd)*sign
    if up.z < 0:
        up = -up
    sd = up.cross(f)
    centre = W + f*(FIST[0] + 0.02)
    rock.append(superellipsoid(f"RammstoneFist.{tag}", centre, (f, sd, up), FIST, n=3.2, rows=8, cols=14, jitter=0.008))
    inner = -sd if sd.x*sign > 0 else sd
    thumb = [centre + inner*(FIST[1] + 0.01) - up*0.03 - f*0.08, centre + inner*0.14 - up*(FIST[2] - 0.03) + f*0.10,
             centre - up*(FIST[2] - 0.02) + f*(FIST[0] - 0.02) + inner*0.02]
    rock.append(sweep(f"RammstoneThumb.{tag}", catmull(thumb, 4), [0.085]*8 + [0.07], 6, smooth=False, jitter=0.004))
    # Knuckles: four charcoal blocks set into the fist's front, upper half, standing proud of it and touching, so they
    # read as one knuckle ridge (smaller, apart, they read as a row of pebbles).
    magma = []
    for k in range(4):
        w = (k - 1.5)/1.5
        q = centre + f*(FIST[0] - 0.03) + up*0.06 + sd*(w*FIST[1]*0.70)
        magma.append(superellipsoid(f"RammstoneKnuckle{k}.{tag}", q, (f, sd, up), (0.09, 0.072, 0.095), n=2.8, rows=5,
                                    cols=8, jitter=0.005))
    return rock, [skin], magma


# ---------------------------------------------------------------- materials and render

def magma_material(horn):
    """The horns' charcoal stone with a few glowing magma cracks: Voronoi cell edges where a slow noise is high, a yellow
    core in an orange glow."""
    mat = horn.copy()
    mat.name = "RammstoneMagma"
    tree = mat.node_tree
    shader = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    coords = tree.nodes.new("ShaderNodeTexCoord")
    vor = tree.nodes.new("ShaderNodeTexVoronoi")
    vor.voronoi_dimensions = "3D"
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 13.0
    tree.links.new(coords.outputs["Object"], vor.inputs["Vector"])
    line = tree.nodes.new("ShaderNodeMapRange")
    line.interpolation_type = "SMOOTHSTEP"
    line.inputs["From Max"].default_value = 0.05
    line.inputs["To Min"].default_value = 1.0
    line.inputs["To Max"].default_value = 0.0
    tree.links.new(vor.outputs["Distance"], line.inputs["Value"])
    noise = surf.node(tree, "ShaderNodeTexNoise", Scale=4.0, Detail=2.0)
    tree.links.new(coords.outputs["Object"], noise.inputs["Vector"])
    patch = tree.nodes.new("ShaderNodeMapRange")
    patch.inputs["From Min"].default_value = 0.5
    patch.inputs["From Max"].default_value = 0.6
    tree.links.new(noise.outputs["Fac"], patch.inputs["Value"])
    glow = tree.nodes.new("ShaderNodeMath")
    glow.operation = "MULTIPLY"
    tree.links.new(line.outputs["Result"], glow.inputs[0])
    tree.links.new(patch.outputs["Result"], glow.inputs[1])
    hot = tree.nodes.new("ShaderNodeMix")
    hot.data_type = "RGBA"
    hot.inputs[6].default_value = (1.0, 0.24, 0.02, 1)
    hot.inputs[7].default_value = (1.0, 0.6, 0.14, 1)
    tree.links.new(glow.outputs["Value"], hot.inputs[0])
    strength = tree.nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    strength.inputs[1].default_value = 6.0
    tree.links.new(glow.outputs["Value"], strength.inputs[0])
    tree.links.new(hot.outputs[2], shader.inputs["Emission Color"])
    tree.links.new(strength.outputs["Value"], shader.inputs["Emission Strength"])
    return mat


def render(objects):
    """Front, sides and back orthographic, framed on the whole model; three-quarter, a low hero angle and the face in
    perspective; the base form's review lights."""
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
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objects:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    mid = (lo + hi)/2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    out = OUT/"renders"
    out.mkdir(parents=True, exist_ok=True)
    names = []

    def shot(name):
        scene.render.filepath = str(out/f"{name}.png")
        bpy.ops.render.render(write_still=True)
        names.append(f"{name}.png")

    scene.render.film_transparent = True
    cam.data.type = "ORTHO"
    size = (hi - lo)
    scene.render.resolution_x, scene.render.resolution_y = 900, 1000
    for name, toward, wide in (("front", Vector((0, -1, 0)), size.x), ("side-left", Vector((1, 0, 0)), size.y),
                               ("back", Vector((0, 1, 0)), size.x), ("side-right", Vector((-1, 0, 0)), size.y)):
        cam.data.ortho_scale = max(size.z, wide*1.0/0.9)*1.08
        cam.location = mid + toward*10
        cam.rotation_euler = (-toward).to_track_quat("-Z", "Y").to_euler()
        shot(name)
    scene.render.film_transparent = False
    cam.data.type = "PERSP"
    cam.data.lens = 85
    scene.render.resolution_x = scene.render.resolution_y = 900
    for name, yaw, rise, target, dist in (("three-quarter", 0.62, 0.10, (0, -0.1, 1.45), 12.0), ("hero", -0.45, -0.12, (0, -0.1, 1.5), 11.0),
                                          ("face", 0.0, 0.08, (0, -0.2, 1.4), 7.5)):
        offset = Vector((-math.sin(yaw), -math.cos(yaw), rise))*dist
        cam.location = Vector(target) + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        shot(name)
    for o in [o for o in scene.objects if o.type in {"LIGHT", "CAMERA"}]:
        bpy.data.objects.remove(o)
    return names


def main():
    s = base.Sheet(json.loads(base.MEASURE.read_text()))
    built = base.build(s, horns=False)
    rock_mat, skin_mat, horn_mat = (bpy.data.materials[n] for n in ("RammstoneRock", "RammstoneSkin", "RammstoneHorn"))
    rock_edge, horn_edge = bpy.data.materials["RammstoneRockEdge"], bpy.data.materials["RammstoneHornEdge"]
    magma = magma_material(horn_mat)
    added = []
    for sign in (1.0, -1.0):
        horn = build_devil_horn(s, sign)
        base.bevel(horn)
        horn.data.materials.append(horn_mat)
        horn.data.materials.append(horn_edge)
        rock, skin, knuckles = build_arm(sign)
        for o in rock:
            base.bevel(o)
            o.data.materials.append(rock_mat)
            o.data.materials.append(rock_edge)
        for o in skin:
            o.data.materials.append(skin_mat)
        for o in knuckles:
            base.bevel(o)
            o.data.materials.append(magma)
            o.data.materials.append(horn_edge)
        added += [horn] + rock + skin + knuckles
    for o in added:
        o.parent = built["rig"]
    built["rig"].name = "RammstoneTransformed"
    everything = built["parts"] + added
    renders = render(everything)
    report = {"tool": bpy.app.version_string, "triangles": base.triangles(everything), "renders": renders}
    (OUT/"report.json").write_text(json.dumps(report, indent=2))
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
