"""Create original, editable first-slug draft. Blender 4.5, no downloaded assets.

Run through `blender --background --factory-startup --disable-autoexec --python-exit-code 1
--python tools/slugs/create_flopper_inspired.py`. Re-running replaces the authored
blend; preserve manual edits first.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT
from blender_pipeline import FPS, armature_for, feature_position, material, reset, rig_spec, skin, validate_scene


def sphere(name, center, size, mat, rig, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = [x / 2 for x in size]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    skin(obj, rig, bone)
    return obj


def tube(name, points, radii, mat, rig, bone, rings=12):
    # Catmull-Rom samples give the flexible appendages smooth bends without
    # keeping an unsupported modifier in the export-ready asset.
    control_points, control_radii = points, radii
    points, radii = [], []
    for i in range(len(control_points)-1):
        p0 = Vector(control_points[max(0, i-1)])
        p1 = Vector(control_points[i])
        p2 = Vector(control_points[i+1])
        p3 = Vector(control_points[min(len(control_points)-1, i+2)])
        for j in range(4):
            t = j / 4
            point = 0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
            points.append(tuple(point))
            radii.append((1-t)*control_radii[i]+t*control_radii[i+1])
    points.append(control_points[-1])
    radii.append(control_radii[-1])
    verts, faces = [], []
    for i, point in enumerate(points):
        tangent = Vector(points[min(i + 1, len(points)-1)]) - Vector(points[max(i-1, 0)])
        u = tangent.normalized().cross(Vector((0, 1, 0))).normalized()
        v = tangent.normalized().cross(u).normalized()
        for n in range(rings):
            a = math.tau * n / rings
            verts.append(Vector(point) + radii[i] * (u * math.cos(a) + v * math.sin(a)))
    for j in range(len(points)-1):
        for n in range(rings):
            nxt = (n + 1) % rings
            faces.append((j*rings+n, j*rings+nxt, (j+1)*rings+nxt, (j+1)*rings+n))
    faces.append(tuple(reversed(range(rings))))
    faces.append(tuple((len(points)-1)*rings+n for n in range(rings)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    skin(obj, rig, bone)
    return obj


PROFILE = [
    (0.03,0.06,0.06,-0.02), (0.06,0.57,0.38,-0.02),
    (0.14,0.78,0.49,-0.03), (0.27,0.78,0.52,-0.04),
    (0.45,0.67,0.47,-0.04), (0.65,0.56,0.42,-0.03),
    (0.85,0.49,0.40,-0.01), (1.04,0.48,0.40,0.00),
    (1.20,0.55,0.44,0.00), (1.34,0.67,0.49,-0.01),
    (1.49,0.81,0.57,-0.02), (1.65,0.92,0.61,-0.03),
    (1.83,0.97,0.63,-0.03), (2.01,0.93,0.60,-0.03),
    (2.17,0.78,0.52,-0.04), (2.29,0.54,0.37,-0.04),
    (2.36,0.20,0.16,-0.04), (2.37,0.005,0.005,-0.04),
]


def body(rig, mat):
    # A hand-shaped profile, made from rings: broad head, pinched waist,
    # and flared foot. It is original geometry, not a converted reference mesh.
    profile = PROFILE
    n = 48
    verts, faces = [], []
    for z, rx, ry, cy in profile:
        for j in range(n):
            a = math.tau * j / n
            verts.append((rx * math.cos(a), cy + ry * math.sin(a), z))
    for i in range(len(profile)-1):
        for j in range(n):
            k = (j+1) % n
            faces.append((i*n+j, i*n+k, (i+1)*n+k, (i+1)*n+j))
    faces.extend([tuple(reversed(range(n))), tuple((len(profile)-1)*n+j for j in range(n))])
    mesh = bpy.data.meshes.new("SoftBody")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("SoftBody", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    # Bake one subdivision level so the saved/exported result is smooth and
    # still contains only the armature modifier required by the pipeline.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    smooth = obj.modifiers.new("SculptSmooth", "SUBSURF")
    smooth.levels = 1
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    mesh = obj.data
    for face in obj.data.polygons:
        face.use_smooth = True
    groups = {b.name: obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
    for vert in mesh.vertices:
        z = vert.co.z
        if z < 0.92:
            weights = {"body_lower": 1}
        elif z < 1.28:
            t = (z-0.92)/0.36
            weights = {"body_lower":1-t, "body_upper":t}
        elif z < 1.66:
            t = (z-1.28)/0.38
            weights = {"body_upper":1-t, "head":t}
        else:
            weights = {"head":1}
        for name, value in weights.items():
            if value > 0.00001:
                groups[name].add([vert.index], value, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Skin", "ARMATURE").object = rig


def belly_mark(rig, mat):
    # A thin closed shell following the body's curved surface, rather than a
    # floating intersecting ellipsoid. Uses the same original body profile.
    rows, columns = 16, 16
    verts, faces = [], []
    for depth in (0.012, -0.012):
        for row in range(rows + 1):
            t = -0.995 + 1.99 * row / rows
            z = 0.57 + 0.40*t
            a, b = next((a,b) for a,b in zip(PROFILE, PROFILE[1:]) if a[0] <= z <= b[0])
            u = (z-a[0])/(b[0]-a[0])
            rx, ry, cy = [(1-u)*a[i] + u*b[i] for i in (1,2,3)]
            width = 0.45 * math.sqrt(max(0,1-t*t))
            for col in range(columns + 1):
                x = width * (2*col/columns-1)
                y = cy + ry * math.sqrt(max(0,1-(x/rx)**2)) + depth
                verts.append((x,y,z))
    layer = (rows+1)*(columns+1)
    for offset in (0, layer):
        for row in range(rows):
            for col in range(columns):
                a=offset+row*(columns+1)+col
                quad=(a,a+1,a+columns+2,a+columns+1)
                faces.append(tuple(reversed(quad)) if offset == 0 else quad)
    edges = (list(range(columns+1)) + [r*(columns+1)+columns for r in range(1,rows+1)]
             + [rows*(columns+1)+c for c in range(columns-1,-1,-1)]
             + [r*(columns+1) for r in range(rows-1,0,-1)])
    for a,b in zip(edges, edges[1:]+edges[:1]):
        faces.append((a,b,b+layer,a+layer))
    mesh = bpy.data.meshes.new("BellyMark")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("BellyMark", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = True
    skin(obj, rig, "body_lower")


def animate(rig, form):
    rig.animation_data_create()
    for slot, desc in form["animations"].items():
        action = bpy.data.actions.new(desc["action"])
        action.use_fake_user = True
        rig.animation_data.action = action
        duration_frames = 48 if slot == "idle" else 24
        for frame in range(1, duration_frames + 2):
            t = (frame-1) / duration_frames
            for bone in rig.pose.bones:
                bone.rotation_mode = "XYZ"
                bone.location = (0, 0, 0)
                bone.rotation_euler = (0, 0, 0)
                bone.scale = (1, 1, 1)
            root = rig.pose.bones["root"]
            head = rig.pose.bones["head"]
            upper = rig.pose.bones["body_upper"]
            left, right = rig.pose.bones["eye_left"], rig.pose.bones["eye_right"]
            if slot == "idle":
                head.rotation_euler[2] = 0.08 * math.sin(t * math.tau)
                upper.rotation_euler[2] = 0.035 * math.sin(t * math.tau)
                breath = 1 + 0.025 * math.sin(t * math.tau)
                upper.scale = (breath, 1 / breath**2, breath)
                rig.pose.bones["feelers_left"].rotation_euler[0] = 0.10 * math.sin(t * math.tau)
                rig.pose.bones["feelers_right"].rotation_euler[0] = -0.12 * math.sin(t * math.tau + 0.4) + 0.12 * math.sin(0.4)
                left_blink = max(0, 1 - abs(t - 0.57) / 0.06)
                right_blink = max(0, 1 - abs(t - 0.60) / 0.07)
                left.scale.y, right.scale.y = 1 - 0.94*left_blink, 1 - 0.94*right_blink
            elif slot == "blink":
                left_blink = max(0, 1 - abs(t - 0.40) / 0.25)
                right_blink = max(0, 1 - abs(t - 0.50) / 0.25)
                left.scale.y, right.scale.y = 1 - 0.94*left_blink, 1 - 0.94*right_blink
            elif slot == "hop":
                bounce = math.sin(math.pi*t)
                root.location.y = 0.35 * bounce
                root.scale = (1 - 0.10*bounce, 1 + 0.18*bounce, 1 - 0.10*bounce)
                head.rotation_euler[2] = 0.12 * math.sin(math.tau*t)
            elif slot in {"launch", "impact"}:
                squash = math.sin(math.pi*t) * (0.27 if slot == "impact" else 0.18)
                root.scale = (1+squash, 1/(1+squash)**2, 1+squash)
                head.rotation_euler[0] = 0.15 * math.sin(math.pi*t)
            for bone in rig.pose.bones:
                for prop in ("location", "rotation_euler", "scale"):
                    bone.keyframe_insert(data_path=prop, frame=frame, group=bone.name)
    rig.animation_data.action = bpy.data.actions["Idle"]
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 49
    bpy.context.scene.frame_set(1)


def main():
    config = ROOT / "assets/source/slugs/species/flopper-inspired.json"
    data = json.loads(config.read_text(encoding="utf-8"))
    form = data["forms"]["protoform"]
    reset()
    rig = armature_for(form)
    rig["placeholder"] = False
    mats = {name: material(name, rgb) for name, rgb in data["palette"].items()}
    body(rig, mats["body"])
    # Low, broad base with small side lobes rather than separate human-like feet.
    for side, sign in (("left", -1), ("right", 1)):
        sphere("base-lobe-"+side, (sign*0.66, -0.02, 0.19), (0.48,0.72,0.26), mats["body"], rig, "body_lower")
        tube("side-fin-"+side,
             [(sign*.53,0,1.22),(sign*.70,.03,1.12),(sign*.76,.04,.94),(sign*.73,.06,.86)],
             [.12,.10,.07,.015], mats["body"], rig, "body_upper")
        # Offset short, leaf-tipped feelers give the draft its own silhouette.
        x = sign*.53
        bend = 0.04 if side == "left" else -0.05
        pts = [(x,0.07,2.15),(x+sign*.03,0.06,2.36),(x+sign*.10,0.04,2.58+bend),
               (x+sign*.20,0.04,2.65+bend),(x+sign*.27,0.05,2.59+bend)]
        tube("feeler-"+side, pts, [.085,.07,.055,.04,.008], mats["feature"], rig, "feelers_"+side)
    belly_mark(rig, mats["feature"])
    specs = rig_spec(form["rig"])
    for side, sign, feature in (("left",-1,form["features"][0]),("right",1,form["features"][1])):
        cx, cy, cz = feature_position(feature, form, specs)
        sphere("eye-patch-"+side, (cx,0.52,cz), (0.77,0.10,0.76), mats["feature"], rig, "head")
        sphere(feature["id"], (cx,cy,cz), feature["scale"], mats["white"], rig, "eye_"+side)
        sphere("iris-"+side, (cx-sign*.025,0.716,cz+0.02), (0.30,0.055,0.35), mats["iris"], rig, "eye_"+side)
        sphere("pupil-"+side, (cx-sign*.025,0.746,cz+0.04), (0.22,0.035,0.26), mats["eye"], rig, "eye_"+side)
        sphere("glint-"+side, (cx-sign*.06,0.766,cz+0.105), (0.065,0.018,0.07), mats["white"], rig, "eye_"+side)
        sphere("cheek-"+side, (sign*.75,0.51,1.48), (0.16,0.07,0.10), mats["cheek"], rig, "head")
    # A small asymmetric curved smile gives this version a warmer expression.
    points = [(x,0.624,1.47 + 0.10*(x/.33)**2 + 0.015*x) for x in (-.33,-.22,-.11,0,.11,.22,.33)]
    tube("smile", points, [.008,.025,.03,.03,.03,.025,.008], mats["mouth"], rig, "jaw", rings=8)
    animate(rig, form)
    validate_scene(data, form)
    destination = ROOT / form["source"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(destination), compress=True)
    print("Created original draft source:", destination)


if __name__ == "__main__":
    main()
