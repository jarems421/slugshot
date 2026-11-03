"""Run with the repository's portable Blender, never with system Python.

Creates original seeded rocks, full layout previews, editable .blend and FBX.
Also exports world-space triangles for an upload-free native Roblox greybox.
"""
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from layout import CONFIG, layout
from build import crystal_point


def xyz(point):
    """Roblox X,Y,Z -> Blender X,-Z,Y. Proper rotation, no reflection."""
    return (point[0], -point[2], point[1])


def material(color):
    key = "Stone_" + "_".join(map(str, color))
    mat = bpy.data.materials.get(key)
    if not mat:
        mat = bpy.data.materials.new(key)
        mat.diffuse_color = tuple(v / 255 for v in color) + (1,)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = mat.diffuse_color
        shader.inputs["Roughness"].default_value = 0.9
        # A subtle, original procedural stone grain for the Blender preview;
        # Roblox uses its built-in Slate material on the corresponding facets.
        nodes = mat.node_tree.nodes
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 16
        noise.inputs["Detail"].default_value = 2
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.2
        ramp.color_ramp.elements[0].color = tuple(v/255*0.7 for v in color)+(1,)
        ramp.color_ramp.elements[1].position = 0.8
        ramp.color_ramp.elements[1].color = tuple(min(1,v/255*1.15) for v in color)+(1,)
        mat.node_tree.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        mat.node_tree.links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
    return mat


def rock_mesh(spec, sides, scale=(1,1)):
    rng = random.Random(spec["seed"])
    w, h, d = spec["size"]
    cx, cy, cz = spec["position"]
    if spec.get("profile") == "stalactite":
        vertices = []
        phase = rng.uniform(0, 1)
        for level, radius in [(0.5, 1.0), (0.05, 0.64)]:
            for i in range(5):
                a = phase + i*2*math.pi/5
                r = radius*rng.uniform(0.85, 1.1)
                vertices.append([cx+math.cos(a)*w*0.5*r, cy+level*h, cz+math.sin(a)*d*0.5*r])
        vertices.append([cx+rng.uniform(-0.15,0.15)*w, cy-h*0.5, cz+rng.uniform(-0.15,0.15)*d])
        faces=[]
        for i in range(5):
            j=(i+1)%5
            faces.extend([[i,j,j+5],[i,j+5,i+5],[i+5,j+5,10]])
        faces.extend([[0,2,1],[0,3,2],[0,4,3]])
        return vertices, faces
    if spec.get("profile") == "stratum":
        bevel = min(2.2 if spec.get("collision", "").startswith(("ArchPier", "Underpass", "WestShelf", "EastShelf")) else 0.6, w * 0.16, d * 0.16)
        boundary = spec.get("collision", "")
        if boundary.startswith("SideBoundary"):
            inner = -math.copysign(w/2, cx)
            outer = -inner
            outline = [(inner, -d/2), (inner, -d/6), (inner, d/6), (inner, d/2),
                       (outer, d/2), (outer, d/6), (outer, -d/6), (outer, -d/2)]
        elif boundary.startswith("EndBoundary"):
            inner = -math.copysign(d/2, cz)
            outer = -inner
            outline = [(-w/2, inner), (-w/6, inner), (w/6, inner), (w/2, inner),
                       (w/2, outer), (w/6, outer), (-w/6, outer), (-w/2, outer)]
        else:
            outline = [(-w/2+bevel, -d/2), (w/2-bevel, -d/2), (w/2, -d/2+bevel),
                       (w/2, d/2-bevel), (w/2-bevel, d/2), (-w/2+bevel, d/2),
                       (-w/2, d/2-bevel), (-w/2, -d/2+bevel)]
        vertices, faces = [], []
        yaw = math.radians(spec["yaw"])
        for ring, level in enumerate([-0.5, 0.05, 0.5]):
            for vertex_index, (x, z) in enumerate(outline):
                if boundary.startswith(("ArchPier", "UnderpassSide")):
                    # Taper exposed pillars into irregular layered stone, while
                    # preserving a wide passage between the two sides.
                    factor = [1.0, 0.92, 0.76][ring]
                    x *= factor
                    z *= [0.94, 1.0, 0.88][ring]
                inset = rng.uniform(0.02, 0.3) if ring == 1 else 0.015
                x -= math.copysign(inset, x)
                z -= math.copysign(inset, z)
                # Recess/overhang only intermediate wall vertices; endpoints stay
                # joined to the corners and low walls retain movement clearance.
                if vertex_index in {1, 2}:
                    amount = (0.05 if ring == 0 else 2.0 if ring == 1 else 4.5) * (0.8 if vertex_index == 1 else 1.0)
                    if boundary.startswith("SideBoundary"):
                        x -= math.copysign(amount, cx)
                    elif boundary.startswith("EndBoundary"):
                        z -= math.copysign(amount, cz)
                px, pz = x * math.cos(yaw) + z * math.sin(yaw), -x * math.sin(yaw) + z * math.cos(yaw)
                vertices.append([cx + px, cy + level * h, cz + pz])
        for ring in range(2):
            for i in range(8):
                a, b = ring*8+i, ring*8+(i+1)%8
                faces.extend([[a,b,b+8],[a,b+8,a+8]])
        for i in range(1,7):
            faces.extend([[0,i+1,i],[16,16+i,16+i+1]])
        return vertices, faces
    phase = rng.uniform(-0.4, 0.4)
    # One angular sample per column keeps strata coherent rather than noisy.
    angles = [2 * math.pi * i / sides + phase + rng.uniform(-0.13, 0.13) for i in range(sides)]
    vertices = []
    for ring, (level, radius) in enumerate([(-0.5, 0.95), (0.12, 1), (0.5, 0.62)]):
        offset_x, offset_z = rng.uniform(-0.08, 0.08) * w, rng.uniform(-0.07, 0.07) * d
        for angle in angles:
            r = radius * rng.uniform(0.87, 1.07)
            x = math.cos(angle) * w * 0.5 * r + offset_x
            z = math.sin(angle) * d * 0.5 * r + offset_z
            y = level * h + (rng.uniform(-0.06, 0.06) * h if ring == 2 else 0)
            tilt = math.radians(spec["tilt"])
            x, y = x * math.cos(tilt) + y * math.sin(tilt), -x * math.sin(tilt) + y * math.cos(tilt)
            px, py, pz = cx + x, cy + y, cz + z
            if spec["group"] == "Shell" and py < 42:
                # Keep decorative wall art outside the playable collision envelope.
                nx,nz = px/scale[0],pz/scale[1]
                envelope = max(abs(nx) / 48, abs(nz) / 43, (abs(nx) + abs(nz)) / 83)
                if envelope < 1.025:
                    px, pz = px * 1.025 / envelope, pz * 1.025 / envelope
            vertices.append([round(px, 5), round(py, 5), round(pz, 5)])
    faces = []
    for ring in range(2):
        for i in range(sides):
            a, b = ring * sides + i, ring * sides + (i + 1) % sides
            faces.extend([[a, b, b + sides], [a, b + sides, a + sides]])
    # Fan triangulation of the convex end caps; no extra centre vertices.
    for i in range(1, sides - 1):
        faces.extend([[0, i + 1, i], [2 * sides, 2 * sides + i, 2 * sides + i + 1]])
    return vertices, faces


def mesh_object(name, vertices, faces, color, collection):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([xyz(v) for v in vertices], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mesh.materials.append(material(color))
    # Recalculate winding for export; original JSON triangles are two-sided in Roblox.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


def collection(name):
    found = bpy.data.collections.get(name)
    if not found:
        found = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(found)
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--config", default=str(CONFIG))
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    config_path = Path(args.config)
    config_bytes = config_path.read_bytes()
    data = layout(json.loads(config_bytes))
    sx, sz = data["config"]["width"]/100, data["config"]["depth"]/90
    def world(point): return [point[0]*sx,point[1],point[2]*sz]
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"  # Coordinates are studs; importer must use Studs.
    all_art = []
    for spec in data["rocks"]:
        vertices, faces = rock_mesh(spec, data["config"]["rock_sides"], (sx,sz))
        spec["vertices"], spec["triangles"] = vertices, faces
        obj = mesh_object(spec["name"], vertices, faces, spec["color"], collection(spec["group"]))
        all_art.append(obj)
    for spec in data["boxes"]:
        if spec.get("kind") == "WedgePart":
            w,h,d = [v/2 for v in spec["size"]]
            cx,cy,cz=spec["position"]
            yaw=math.radians(spec["yaw"])
            vertices=[]
            for x,y,z in [(-w,-h,-d),(w,-h,-d),(-w,-h,d),(w,-h,d),(-w,h,d),(w,h,d)]:
                vertices.append([cx+x*math.cos(yaw)+z*math.sin(yaw),cy+y,cz-x*math.sin(yaw)+z*math.cos(yaw)])
            mesh_object(spec["name"],vertices,[[0,1,3,2],[2,3,5,4],[0,2,4],[1,5,3],[0,4,5,1]],spec["color"],collection("Collision_Ramp"))
            continue
        bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(spec["position"]))
        obj = bpy.context.object
        obj.name = spec["name"]
        obj.dimensions = (spec["size"][0], spec["size"][2], spec["size"][1])
        obj.rotation_euler = (math.radians(spec["pitch"]), 0, math.radians(spec["yaw"]))
        obj.data.materials.append(material(spec["color"]))
        obj.hide_render = bool(spec.get("stone_skin"))
        target = collection("Collision_" + spec["role"])
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        target.objects.link(obj)
        obj.select_set(False)
    # A standing R6-scale silhouette is an inspection aid, excluded from mesh exports.
    for name, p, s in [("ScaleTorso", [16, 3, -10], [2, 2, 1]),
                       ("ScaleHead", [16, 4.5, -10], [1, 1, 1]),
                       ("ScaleLegL", [15.5, 1, -10], [1, 2, 1]),
                       ("ScaleLegR", [16.5, 1, -10], [1, 2, 1])]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(world(p)))
        obj = bpy.context.object
        obj.name, obj.dimensions = name, (s[0], s[2], s[1])
        obj.data.materials.append(material([190, 160, 105]))
        obj.select_set(False)

    # Export just the original art; collision comes from the same structured layout.
    for obj in all_art:
        obj.select_set(True)
    export_path = out / "rocklock-rocks.fbx"
    bpy.ops.export_scene.fbx(filepath=str(export_path), use_selection=True, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", global_scale=1.0,
                             apply_unit_scale=False, apply_scale_options="FBX_SCALE_NONE",
                             bake_anim=False, add_leaf_bones=False, use_mesh_modifiers=True)
    for obj in all_art:
        obj.select_set(False)
    # Offline FBX roundtrip verifies exporter axis/scale/count, not Studio importer access.
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(export_path), global_scale=1.0, use_anim=False)
    imported = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    assert len(imported) == len(all_art), "FBX roundtrip changed object count"
    original_bounds = sorted(round(v, 3) for obj in all_art for v in obj.dimensions)
    imported_bounds = sorted(round(v, 3) for obj in imported for v in obj.dimensions)
    assert original_bounds == imported_bounds, "FBX roundtrip changed dimensions"
    for obj in list(set(bpy.data.objects) - before):
        bpy.data.objects.remove(obj, do_unlink=True)

    data["tool"] = bpy.app.version_string
    data["config_sha256"] = hashlib.sha256(config_bytes).hexdigest()
    data["generator_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    data["layout_sha256"] = hashlib.sha256(Path(__file__).with_name("layout.py").read_bytes()).hexdigest()
    data["fbx_roundtrip"] = dict(objects=len(all_art), dimensions_unchanged=True,
                                  axes="Blender (X,-Z,Y), FBX -Z forward/Y up", units="studs")
    (out / "geometry.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 48
    scene.render.resolution_x, scene.render.resolution_y = 1280, 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.12, 0.15, 0.23)
    scene.view_settings.view_transform = "AgX"
    # The inspection scene includes the same crystal meshes and positions as the
    # place. The point lights are attached to those crystals, not floating fills.
    crystal_path = out / "crystals/geometry.json"
    crystal_data = json.loads(crystal_path.read_text(encoding="utf-8"))
    variants = {v["name"]: v for v in crystal_data["variants"]}
    for placement in crystal_data["placements"]:
        variant = variants[placement["variant"]]
        for index, shard in enumerate(variant["shards"]):
            vertices = [crystal_point(v, placement) for v in shard["vertices"]]
            obj = mesh_object(placement["name"]+"_crystal"+str(index), vertices, shard["triangles"], variant["color"], collection("Crystals"))
            mat = material(variant["color"])
            shader = mat.node_tree.nodes.get("Principled BSDF")
            shader.inputs["Emission Color"].default_value = tuple(c/255 for c in variant["color"])+(1,)
            shader.inputs["Emission Strength"].default_value = 0.5
        light = bpy.data.lights.new(placement["name"]+"_crystal_light", "POINT")
        light.energy = 5000 if placement["scale"] > 0.6 else 1200
        light.color = tuple(min(1, (c/255)*0.65+0.35) for c in variant["color"])
        lamp = bpy.data.objects.new(light.name, light)
        collection("CrystalLights").objects.link(lamp)
        lamp.location = xyz(crystal_point([0,2,0], placement))
        lamp.data.shadow_soft_size = 6
    # Softbox fill is an offline inspection aid only, to reveal surface forms in
    # renders; the playable map's local lights are attached to crystals.
    for i, (position, energy, tint) in enumerate([
        ([-8, 58, -12], 35000, (0.67, 0.78, 1)),
        ([0, 26, -35], 14000, (0.55, 0.78, 1)),
        ([0, 28, 35], 14000, (0.60, 0.72, 1))]):
        light = bpy.data.lights.new(f"InspectionFill{i}", "AREA")
        light.energy, light.shape, light.size, light.color = energy, "DISK", 45, tint
        lamp = bpy.data.objects.new(light.name, light)
        scene.collection.objects.link(lamp)
        lamp.location = xyz(world(position))
    cam_data = bpy.data.cameras.new("InspectionCamera")
    camera = bpy.data.objects.new("InspectionCamera", cam_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    views = [
        ("01-topdown-cutaway", [0, 150, 0.01], [0, 0, 0], 50, True),
        ("02-establishing", [28, 34, 31], [-5, 16, -5], 18, False),
        ("03-player-centre", [18, 5.5, -17], [0, 13, 0], 21, False),
        ("04-west-route", [-36, 16, -18], [-34, 18, 17], 22, False),
        ("05-east-route", [36, 16, 18], [33, 17, -19], 22, False),
        ("06-collapse", [22, 22, 26], [0, 36, 0], 24, False),
        ("07-north-spawn", [10, 7, -38], [0, 5, -27], 22, False),
        ("08-south-spawn", [-10, 7, 38], [0, 5, 27], 22, False),
        ("09-ceiling", [-35, 32, -15], [-42, 64, -32], 20, False),
    ]
    if args.render:
        for name, position, target, lens, cutaway in views:
            for col in bpy.data.collections:
                if col.name in {"Roof", "Shell", "Collision_Boundary", "Collapse", "Stalactite"}:
                    col.hide_render = cutaway
            for spec in data["rocks"]:
                if "Boundary" in spec.get("collision", ""):
                    bpy.data.objects[spec["name"]].hide_render = cutaway
            camera.location = xyz(world(position))
            camera.rotation_euler = (Vector(xyz(world(target))) - camera.location).to_track_quat("-Z", "Y").to_euler()
            cam_data.type = "ORTHO" if cutaway else "PERSP"
            cam_data.ortho_scale, cam_data.lens = max(data["config"]["width"]*1.2,data["config"]["depth"]*1.85), lens
            cam_data.clip_end = 500
            scene.render.filepath = str(out / (name + ".png"))
            bpy.ops.render.render(write_still=True)
    for col in bpy.data.collections:
        col.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "rocklock.blend"))
    print(f"ROCKLOCK: {len(all_art)} rocks, {len(data['boxes'])} collision parts; FBX roundtrip passed")


if __name__ == "__main__":
    main()
