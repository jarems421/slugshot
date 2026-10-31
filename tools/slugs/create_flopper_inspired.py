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
    (0.00,0.02,0.02,-0.03), (0.00,0.38,0.28,-0.03),
    (0.00,0.65,0.47,-0.04), (0.005,0.81,0.58,-0.04),
    (0.025,0.91,0.65,-0.04), (0.065,0.95,0.68,-0.04),
    (0.13,0.96,0.69,-0.04), (0.23,0.94,0.68,-0.04),
    (0.36,0.88,0.65,-0.04), (0.52,0.82,0.62,-0.04),
    (0.70,0.79,0.60,-0.04),
    (0.91,0.78,0.60,-0.04), (1.12,0.76,0.59,-0.04),
    (1.32,0.74,0.58,-0.04), (1.50,0.72,0.57,-0.04),
    (1.68,0.69,0.55,-0.04), (1.84,0.65,0.52,-0.04),
    (1.98,0.59,0.48,-0.04), (2.11,0.49,0.41,-0.04),
    (2.20,0.36,0.30,-0.04), (2.26,0.20,0.17,-0.04),
    (2.28,0.06,0.05,-0.04), (2.29,0.005,0.005,-0.04),
]

ANTENNAE = {
    "left": [(-.42,0,2.09),(-.46,.01,2.26),(-.52,.06,2.43),(-.63,.12,2.49),
             (-.74,.20,2.43),(-.79,.25,2.29),(-.78,.28,2.12)],
    "right": [(.42,0,2.08),(.48,.02,2.24),(.58,.07,2.39),(.69,.14,2.42),
              (.77,.22,2.31),(.76,.27,2.15),(.72,.29,2.04)],
}


def antenna_influence(point, side):
    """Smooth head-to-feeler weights across the fused roots."""
    path = ANTENNAE[side]
    best_distance, best_progress = float("inf"), 0.0
    for index, (a,b) in enumerate(zip(path,path[1:])):
        start, end = Vector(a), Vector(b)
        delta = end-start
        t = max(0,min(1,(point-start).dot(delta)/delta.length_squared))
        distance = (point-(start+t*delta)).length
        if distance < best_distance:
            best_distance = distance
            best_progress = (index+t)/(len(path)-1)
    if best_distance > .19:
        return 0.0
    return min(1.0,max(0.0,best_progress/.30)) * max(0,min(1,(.19-best_distance)/.06))


def body(rig, mat):
    # Broad flat contact, a softly spread lower body and an integrated tail.
    profile = PROFILE
    n = 48
    verts, faces = [], []
    for z, rx, ry, cy in profile:
        for j in range(n):
            a = math.tau * j / n
            rear_angle = (a + math.pi/2 + math.pi) % math.tau - math.pi
            triangular = max(0.0, 1.0 - abs(rear_angle)/0.52) ** 1.15
            height_fade = math.exp(-max(0.0,z-0.065)**2 / 0.12**2)
            # One continuous low, wide wedge. It is neither a tube nor a nub.
            extension = 0.33 * triangular * height_fade * min(1.0,(rx/0.91)**2)
            relaxed = 1 + math.exp(-(z/.30)**2) * (.035*math.sin(3*a+.7)+.020*math.sin(5*a-.4))
            verts.append((rx * relaxed * math.cos(a), cy + ry * relaxed * math.sin(a) - extension, z))
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
    # Fuse the antenna roots into the head before weighting/colouring. Voxel
    # union removes intersecting shell seams and creates one connected skin.
    antenna_objects = []
    for side,path in ANTENNAE.items():
        antenna = tube("AntennaConstruction_"+side,path,[.15,.125,.105,.09,.08,.065,.045],mat,rig,"feelers_"+side,rings=16)
        antenna.modifiers.clear()
        antenna.vertex_groups.clear()
        antenna.parent = None
        antenna_objects.append(antenna)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for antenna in antenna_objects:
        antenna.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    fusion = obj.modifiers.new("FusedSoftSkin","REMESH")
    fusion.mode = "VOXEL"
    fusion.voxel_size = .045
    fusion.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=fusion.name)
    relax = obj.modifiers.new("RelaxRoots","SMOOTH")
    relax.factor, relax.iterations = .55, 3
    bpy.ops.object.modifier_apply(modifier=relax.name)
    obj.data.calc_loop_triangles()
    reduction = obj.modifiers.new("ExportBudget","DECIMATE")
    reduction.ratio = min(1.0,18000/max(1,len(obj.data.loop_triangles)))
    bpy.ops.object.modifier_apply(modifier=reduction.name)
    mesh = obj.data
    # Subdivision must not turn the flattened underside back into a hovering dome.
    for vertex in mesh.vertices:
        vertex.co.z = max(0.0, vertex.co.z)
        if vertex.co.z < 0.035:
            vertex.co.z = 0.0
    obj["integrated_tail"] = True
    obj["integrated_antennae"] = True
    for face in obj.data.polygons:
        face.use_smooth = True
    groups = {b.name: obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
    for vert in mesh.vertices:
        z = vert.co.z
        if z < 0.92:
            rear_angle = (math.atan2(vert.co.y+.04,vert.co.x) + math.pi/2 + math.pi) % math.tau-math.pi
            tail_weight = .75 * math.exp(-(rear_angle/.40)**2) * max(0,1-z/.36)
            weights = {"body_lower": 1-tail_weight, "tail": tail_weight}
        elif z < 1.28:
            t = (z-0.92)/0.36
            weights = {"body_lower":1-t, "body_upper":t}
        elif z < 1.66:
            t = (z-1.28)/0.38
            weights = {"body_upper":1-t, "head":t}
        else:
            weights = {"head":1}
        if z > 1.9:
            for side in ANTENNAE:
                influence = antenna_influence(vert.co,side)
                if influence > 0:
                    weights = {name:value*(1-influence) for name,value in weights.items()}
                    weights["feelers_"+side] = influence
        for name, value in weights.items():
            if value > 0.00001:
                groups[name].add([vert.index], value, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Skin", "ARMATURE").object = rig
    return obj


def sick_color(obj, mat, base, green):
    """Blend uneven, soft-edged green clusters directly into vertex colours."""
    spots = [
        (0.12,.40,.19,.14),(.48,1.05,.23,.18),(.88,.22,.15,.11),
        (1.17,.67,.23,.17),(1.60,.34,.15,.11),(1.84,1.19,.17,.13),
        (2.22,.53,.20,.14),(2.55,1.42,.16,.13),(2.91,.20,.17,.12),
        (3.28,.83,.23,.16),(3.65,1.68,.18,.14),(4.02,.35,.22,.15),
        (4.38,1.13,.18,.13),(4.76,.64,.23,.17),(5.12,1.54,.17,.13),
        (5.48,.22,.17,.13),(5.81,.93,.22,.16),(6.12,1.48,.16,.12),
        (2.01,.78,.11,.08),(4.57,1.76,.11,.08),(.31,1.75,.12,.09),
    ]
    attrs = obj.data.color_attributes
    colors = attrs.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for vert in obj.data.vertices:
        x,y,z = vert.co
        angle = math.atan2(y+0.04,x) % math.tau
        intensity = 0.0
        for a, h, width, height in spots:
            delta = (angle-a+math.pi) % math.tau-math.pi
            # Uneven merged lobes produce diffuse organic clusters, not flat dots.
            wobble = 1 + .18*math.sin(3*angle+11*z+a) + .11*math.sin(19*z-a)
            d2 = ((delta*.68)/(width*wobble))**2 + ((z-h)/(height*wobble))**2
            intensity += 1.60 * math.exp(-0.85*d2)
        # A soft exponential response avoids flat, square-edged saturated cores.
        intensity = 1 - math.exp(-intensity)
        colors.data[vert.index].color = tuple((1-intensity)*base[i] + intensity*green[i] for i in range(3)) + (1,)
    attrs.active_color = colors
    nodes = mat.node_tree.nodes
    vertex_color = nodes.new("ShaderNodeVertexColor")
    vertex_color.layer_name = "Color"
    mat.node_tree.links.new(vertex_color.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])


def uniform_color(obj, rgba):
    if obj.data.color_attributes.get("Color"):
        return
    attr = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for item in attr.data:
        item.color = rgba
    obj.data.color_attributes.active_color = attr


def on_body(obj, x, z, depth):
    hit, point, _normal, _face = obj.ray_cast(Vector((x,4,z)), Vector((0,-1,0)))
    if not hit:
        raise ValueError(f"Face decoration outside the body: x={x:.3f} z={z:.3f}")
    return (x, point.y+depth, z)


def eye_surface(name, body_obj, center, size, mat, rig, bone):
    """Thin, skinned sclera follows the body's surface; no protruding eyeball."""
    cx, _cy, cz = center
    segments, rings = 40, 6
    verts, faces = [], []
    for depth in (0.012, 0.008):
        for ring in range(rings+1):
            radius = max(.0001, ring/rings)
            for i in range(segments):
                angle = math.tau*i/segments
                verts.append(on_body(body_obj, cx+size[0]*.5*radius*math.cos(angle),
                                     cz+size[2]*.5*radius*math.sin(angle), depth))
    layer = (rings+1)*segments
    for side in (0, 1):
        for ring in range(rings):
            for i in range(segments):
                j = (i+1)%segments
                a = side*layer+ring*segments+i
                b = side*layer+ring*segments+j
                quad = (a,b,b+segments,a+segments)
                faces.append(tuple(reversed(quad)) if side == 0 else quad)
    for i in range(segments):
        a = rings*segments+i
        b = rings*segments+(i+1)%segments
        faces.append((a,b,b+layer,a+layer))
        faces.append((i+layer,(i+1)%segments+layer,(i+1)%segments,i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    skin(obj, rig, bone)
    return obj


def surface_line(name, body_obj, points, thickness, mat, rig, bone, depth=0.019):
    """A narrow coloured strip follows the actual head surface."""
    verts, faces = [], []
    for offset in (depth, depth-.003):
        for i,(x,z) in enumerate(points):
            prev = points[max(0,i-1)]
            nxt = points[min(len(points)-1,i+1)]
            dx,dz = nxt[0]-prev[0], nxt[1]-prev[1]
            length = max(0.00001, math.hypot(dx,dz))
            nx,nz = -dz/length,dx/length
            for sign in (-1,1):
                verts.append(on_body(body_obj,x+sign*nx*thickness,z+sign*nz*thickness,offset))
    layer = 2*len(points)
    for i in range(1,len(points)):
        a,b = 2*i-2,2*i
        faces.extend(((a,a+1,b+1,b),(a+layer,b+layer,b+layer+1,a+layer+1),
                      (a,b,b+layer,a+layer),(a+1,a+layer+1,b+layer+1,b+1)))
    last = layer-2
    faces.extend(((0,layer,layer+1,1),(last,last+1,last+1+layer,last+layer)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    skin(obj, rig, bone)
    return obj


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
                # Compensate for the root's 0.26-unit rest height so the sole
                # stays on the floor while the body spreads during the squash.
                root.location.y = -.26 * (1-root.scale.y)
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
    shader = mats["body"].node_tree.nodes["Principled BSDF"]
    for name, value in (("Roughness",.55), ("Subsurface Weight",.22),
                        ("Subsurface Scale",.14), ("Specular IOR Level",.20),
                        ("Coat Weight",.025), ("Coat Roughness",.35)):
        if name in shader.inputs:
            shader.inputs[name].default_value = value
    body_obj = body(rig, mats["body"])
    sick_color(body_obj, mats["body"], data["palette"]["body"], data["palette"]["feature"])
    specs = rig_spec(form["rig"])
    for side, sign, feature in (("left",-1,form["features"][0]),("right",1,form["features"][1])):
        cx, cy, cz = feature_position(feature, form, specs)
        eye = eye_surface(feature["id"], body_obj, (cx,cy,cz), feature["scale"], mats["white"], rig, "eye_"+side)
        actual = [(min(v.co[i] for v in eye.data.vertices)+max(v.co[i] for v in eye.data.vertices))/2 for i in range(3)]
        print("eye attachment", side, "actual", actual, "expected", [cx,cy,cz], "y offset", actual[1]-cy)
        spiral = []
        for step in range(121):
            t = step/120
            angle = sign*math.tau*2.35*t + .35
            radius = .012 + .165*t
            spiral.append((cx+radius*math.cos(angle),cz+radius*math.sin(angle)))
        surface_line("spiral-"+side, body_obj, spiral, .013, mats["iris"], rig, "eye_"+side)
    # A small downturned mouth supports the queasy expression.
    mouth = [(x,1.35-.055*(x/.19)**2) for x in [-.19+.38*i/30 for i in range(31)]]
    surface_line("mouth", body_obj, mouth, .012, mats["mouth"], rig, "jaw", depth=.014)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            uniform_color(obj, obj.data.materials[0].diffuse_color)
    animate(rig, form)
    validate_scene(data, form)
    destination = ROOT / form["source"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(destination), compress=True)
    print("Created original draft source:", destination)


if __name__ == "__main__":
    main()
