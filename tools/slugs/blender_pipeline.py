"""Headless Blender implementation; original placeholder geometry only.

One Blender unit = one intended Roblox stud. Blender +Y forward/+Z up;
FBX -Z forward/+Y up. Bone positions in rig JSON are normalized to form size.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT, SOURCE, digest, feature_position, load_species, require, rig_spec

FPS = 24
EXPORT_SETTINGS = dict(use_selection=True, object_types={"ARMATURE", "MESH"}, global_scale=1.0,
    apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
    add_leaf_bones=False, use_armature_deform_only=True, bake_anim_use_all_actions=False,
    bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0.0, bake_anim_step=1.0,
    use_mesh_modifiers=True, path_mode="AUTO")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = FPS


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = tuple(color) + (1,)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = mat.diffuse_color
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.65
    return mat


def shape(name, position, size, mat, kind="sphere"):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=position)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1, radius2=0, depth=2, location=position)
    else:
        bpy.ops.mesh.primitive_cube_add(size=2, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.scale = tuple(v / 2 for v in size)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = kind == "sphere"
    return obj


def skin(obj, armature, fixed=None, length=1):
    groups = {b.name: obj.vertex_groups.new(name=b.name) for b in armature.data.bones}
    for v in obj.data.vertices:
        if fixed:
            groups[fixed].add([v.index], 1, "REPLACE")
        else:
            y = v.co.y / length
            # Smooth two-bone weights, normalized and bounded; no automatic weights.
            if y < -0.2:
                names, factor = ("tail", "body_lower"), min(1, max(0, (y + 0.5) / 0.3))
            else:
                names, factor = ("body_lower", "body_upper"), min(1, max(0, (y + 0.2) / 0.4))
            for name, weight in zip(names, (1 - factor, factor)):
                if weight > 0:
                    groups[name].add([v.index], weight, "REPLACE")
    obj.parent = armature
    modifier = obj.modifiers.new("Skin", "ARMATURE")
    modifier.object = armature


def armature_for(form):
    rig = rig_spec(form["rig"])
    data = bpy.data.armatures.new(form["rig"])
    armature = bpy.data.objects.new("CreatureRig", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for spec in rig["bones"]:
        bone = data.edit_bones.new(spec["name"])
        bone.head = [a * b for a, b in zip(spec["position"], form["size"])]
        bone.tail = bone.head + Vector((0, 0, max(0.1, form["size"][2] * 0.15)))
        if spec["parent"]:
            bone.parent = data.edit_bones[spec["parent"]]
    bpy.ops.object.mode_set(mode="OBJECT")
    armature.show_in_front = True
    armature["rig_id"] = form["rig"]
    armature["placeholder"] = True
    return armature


def create_geometry(species, form, armature):
    w, length, h = form["size"]
    mats = {name: material(name, color) for name, color in species["palette"].items()}
    if form["generator"] == "protoform-placeholder":
        obj = shape("Body_PLACEHOLDER", (0, -length * 0.12, h * 0.38), (w, length * 0.9, h * 0.68), mats["body"])
        skin(obj, armature, length=length)
        head_size = [v * form["headScale"] for v in (w * 0.95, length * 0.5, h * 0.62)]
        skin(shape("Head_PLACEHOLDER", (0, length * 0.28, h * 0.68), head_size, mats["body"]), armature, "head")
        skin(shape("Jaw_PLACEHOLDER", (0, length * 0.4, h * 0.52), (w * 0.6, length * 0.3, h * 0.14), mats["feature"]), armature, "jaw")
    else:
        skin(shape("Core_PLACEHOLDER", (0, 0, h * 0.4), (w * 0.65, length * 0.8, h * 0.75), mats["body"]), armature, "core")
        skin(shape("Crest_PLACEHOLDER", (0, length * 0.25, h * 0.7), (w * 0.5, length * 0.4, h * 0.5), mats["body"], "cube"), armature, "crest")
        for side, sign in (("left", -1), ("right", 1)):
            skin(shape(f"Wing_{side}_PLACEHOLDER", (sign * w * 0.48, 0, h * 0.55), (w * 0.65, length * 0.45, h * 0.14), mats["feature"], "cube"), armature, f"wing_{side}")
    rig = rig_spec(form["rig"])
    for feature in form["features"]:
        kind = "sphere" if feature["kind"] == "eye" else "cone"
        obj = shape(feature["id"], feature_position(feature, form, rig), feature["scale"], mats[feature["material"]], kind)
        skin(obj, armature, rig["sockets"][feature["socket"]]["bone"])
    if species["pattern"] == "bands":
        for obj in [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.endswith("PLACEHOLDER")]:
            obj.data.materials.append(mats["feature"])
            for poly in obj.data.polygons:
                poly.material_index = int(math.floor(poly.center.y * 4) % 2)


def key_actions(form, armature):
    # Demonstrator actions only. Slots not produced here remain optional conventions.
    supported = {"Idle", "Launch", "Spin", "Prepare", "Reveal", "Attack"}
    armature.animation_data_create()
    for animation in form["animations"].values():
        name = animation["action"]
        require(name in supported, f"Placeholder generator cannot author action {name}; use an authored .blend")
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        armature.animation_data.action = action
        for frame in range(1, FPS + 2):
            t = (frame - 1) / FPS
            for bone in armature.pose.bones:
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = (0, 0, 0)
                bone.location = (0, 0, 0)
                bone.scale = (1, 1, 1)
            root = armature.pose.bones["root"]
            expressive = armature.pose.bones.get("head") or armature.pose.bones.get("crest")
            if name == "Idle":
                expressive.rotation_euler[1] = 0.12 * math.sin(t * math.tau)
                armature.pose.bones["body_upper"].scale = (1 + 0.04 * math.sin(t * math.tau), 1, 1 - 0.04 * math.sin(t * math.tau))
            elif name == "Spin":
                root.rotation_euler[2] = math.tau * t
            elif name in {"Launch", "Prepare"}:
                squash = math.sin(math.pi * t) * 0.2
                root.scale = (1 + squash, 1 / (1 + squash) ** 2, 1 + squash)
            elif name == "Reveal":
                # Different skeleton from the protoform; no shared bone assumptions.
                for side, sign in (("left", -1), ("right", 1)):
                    armature.pose.bones[f"wing_{side}"].rotation_euler[1] = sign * 0.8 * (1 - t)
            elif name == "Attack":
                expressive.rotation_euler[0] = -0.6 * math.sin(math.pi * t)
            for bone in armature.pose.bones:
                for prop in ("location", "rotation_euler", "scale"):
                    bone.keyframe_insert(data_path=prop, frame=frame, group=bone.name)
    armature.animation_data.action = bpy.data.actions[form["animations"][next(iter(form["animations"]))]["action"]]
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, FPS + 1
    bpy.context.scene.frame_set(1)


def rig_object():
    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    require(len(rigs) == 1, "Expected one custom armature per source form")
    return rigs[0]


def validate_scene(species, form):
    require(abs(bpy.context.scene.unit_settings.scale_length - 1) < 0.0001, "Source unit scale must be 1")
    require(bpy.context.scene.render.fps == FPS and bpy.context.scene.render.fps_base == 1, "Source actions must use 24 FPS")
    rig = rig_object()
    expected = rig_spec(form["rig"])
    actual = {b.name: b for b in rig.data.bones}
    require(set(actual) == {b["name"] for b in expected["bones"]}, f"Missing/extra bones in {form['rig']}")
    for b in expected["bones"]:
        bone = actual[b["name"]]
        require((bone.parent.name if bone.parent else None) == b["parent"], f"Incorrect parent: {b['name']}")
        rest = Vector([a * s for a, s in zip(b["position"], form["size"])])
        require((bone.head_local - rest).length < 0.001, f"Incorrect orientation/scale/rest position: {b['name']}")
        require((bone.tail_local - bone.head_local).normalized().dot(Vector((0, 0, 1))) > 0.999, f"Incorrect bone rest orientation: {b['name']}")
        require(bone.matrix_local.to_3x3().col[0].dot(Vector((1, 0, 0))) > 0.999, f"Incorrect bone roll: {b['name']}")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    require(meshes, "Missing skinned geometry")
    total = 0
    per_mesh = {}
    for obj in [rig] + meshes:
        require(max(abs(v - 1) for v in obj.scale) < 0.0001 and obj.location.length < 0.0001 and obj.rotation_euler.to_matrix().to_quaternion().angle < 0.0001, f"Unapplied scale/orientation: {obj.name}")
        if obj.type != "MESH":
            continue
        require(obj.parent == rig and len(obj.modifiers) == 1 and obj.modifiers[0].type == "ARMATURE" and obj.modifiers[0].object == rig, f"Incorrect skin dependency: {obj.name}")
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        require(triangles <= species["budgets"]["trianglesPerMesh"], f"Excessive polygon count: {obj.name}: {triangles}")
        total += triangles
        per_mesh[obj.name] = triangles
        for vertex in obj.data.vertices:
            weights = [g for g in vertex.groups if g.weight > 0.00001]
            require(1 <= len(weights) <= species["budgets"]["maxInfluences"] and abs(sum(g.weight for g in weights) - 1) < 0.001, f"Invalid skin weights: {obj.name} vertex {vertex.index}")
            require(all(obj.vertex_groups[g.group].name in actual for g in weights), f"Weight references missing bone: {obj.name}")
    require(total <= species["budgets"]["totalTriangles"], f"Total polygon budget exceeded: {total}")
    for feature in form["features"]:
        obj = bpy.context.scene.objects.get(feature["id"])
        require(obj is not None, f"Missing anatomy mesh: {feature['id']}")
        intended = Vector(feature_position(feature, form, expected))
        # Cone centroid differs from its bounds centre, so measure its bounds.
        # Read vertices directly: cached bound_box can be stale after bpy edits.
        center = Vector([(min(v.co[i] for v in obj.data.vertices) + max(v.co[i] for v in obj.data.vertices)) / 2 for i in range(3)])
        require((center - intended).length < 0.001, f"Incorrect attachment position: {feature['id']}")
    for animation in form["animations"].values():
        action = bpy.data.actions.get(animation["action"])
        require(action is not None and action.frame_range[1] > action.frame_range[0], f"Missing/empty animation action: {animation['action']}")
    require(len(rig.data.bones) <= species["budgets"]["maxBones"], "Excessive bone count")
    return {"triangles": total, "meshes": per_mesh, "bones": len(actual), "actions": sorted({a["action"] for a in form["animations"].values()})}


def generate(species, output):
    for name, form in species["forms"].items():
        reset()
        if form["source"]:
            bpy.ops.wm.open_mainfile(filepath=str(ROOT / form["source"]))
        else:
            armature = armature_for(form)
            create_geometry(species, form, armature)
            key_actions(form, armature)
        validate_scene(species, form)
        bpy.context.scene["species_configuration"] = json.dumps(species, sort_keys=True)
        bpy.context.scene["pipeline_tool_hash"] = digest(Path(__file__)) + digest(Path(__file__).with_name("common.py"))
        bpy.context.scene["rig_hash"] = digest(SOURCE / "rigs" / f"{form['rig']}.json")
        directory = output / "source"
        directory.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(directory / f"{name}.blend"))


def source_matches(species, form):
    scene = bpy.context.scene
    require(scene.get("species_configuration") == json.dumps(species, sort_keys=True), "Stale Blender source: configuration changed; run generate")
    require(scene.get("pipeline_tool_hash") == digest(Path(__file__)) + digest(Path(__file__).with_name("common.py")), "Stale Blender source: tooling changed; run generate")
    require(scene.get("rig_hash") == digest(SOURCE / "rigs" / f"{form['rig']}.json"), "Stale Blender source: rig changed; run generate")


def input_hashes(config, species):
    paths = [config, Path(__file__), Path(__file__).with_name("common.py")]
    paths += [SOURCE / "rigs" / f"{form['rig']}.json" for form in species["forms"].values()]
    paths += [ROOT / form["source"] for form in species["forms"].values() if form["source"]]
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in paths}


def bounds(objects):
    coords = [o.matrix_world @ Vector(c) for o in objects if o.type == "MESH" for c in o.bound_box]
    return [max(v[i] for v in coords) - min(v[i] for v in coords) for i in range(3)]


def export(species, config, output):
    report = {"species": species["id"], "placeholder": species["placeholder"], "tool": bpy.app.version_string,
        "inputs": input_hashes(config, species), "units": "1 Blender unit = 1 intended Roblox stud; Studio roundtrip pending",
        "axes": {"source": "+Y forward, +Z up", "fbx": "-Z forward, +Y up"},
        "settings": {k: sorted(v) if isinstance(v, set) else v for k, v in EXPORT_SETTINGS.items()},
        "provenance": species["provenance"], "forms": {}, "files": {}, "studioImportVerified": False}
    for name, form in species["forms"].items():
        source = output / "source" / f"{name}.blend"
        require(source.is_file(), f"Missing generated Blender source: {source}; run generate")
        bpy.ops.wm.open_mainfile(filepath=str(source))
        source_matches(species, form)
        stats = validate_scene(species, form)
        rig = rig_object()
        rig.animation_data.action = None
        for bone in rig.pose.bones:
            bone.matrix_basis.identity()
        bpy.context.view_layer.update()
        rest_bounds = bounds(list(bpy.context.scene.objects))
        directory = output / "exports" / name
        directory.mkdir(parents=True, exist_ok=True)
        bpy.ops.object.select_all(action="SELECT")
        model_path = directory / "model.fbx"
        bpy.ops.export_scene.fbx(filepath=str(model_path), bake_anim=False, **EXPORT_SETTINGS)
        durations = {}
        for slot, animation in form["animations"].items():
            rig.animation_data.action = bpy.data.actions[animation["action"]]
            start, end = rig.animation_data.action.frame_range
            durations[slot] = (end - start) / FPS
            bpy.context.scene.frame_start, bpy.context.scene.frame_end = int(start), int(end)
            bpy.ops.export_scene.fbx(filepath=str(directory / f"{slot}.fbx"), bake_anim=True, **EXPORT_SETTINGS)
        sockets = {}
        for socket, spec in rig_spec(form["rig"])["sockets"].items():
            sockets[socket] = {"bone": spec["bone"], "positionBlender": [p * s for p, s in zip(spec["position"], form["size"])]}
        stats["sockets"] = sockets
        stats["restBoundsBlender"] = rest_bounds
        # Offline roundtrip: mesh/weights/hierarchy/rest positions and animation timing.
        reset()
        bpy.ops.import_scene.fbx(filepath=str(model_path), automatic_bone_orientation=False)
        imported_rig = rig_object()
        require(set(b.name for b in imported_rig.data.bones) == {b["name"] for b in rig_spec(form["rig"])["bones"]}, "FBX roundtrip lost bones")
        for spec in rig_spec(form["rig"])["bones"]:
            bone = imported_rig.data.bones[spec["name"]]
            require((bone.parent.name if bone.parent else None) == spec["parent"], "FBX roundtrip changed hierarchy")
            expected = Vector([a * b for a, b in zip(spec["position"], form["size"])])
            require((imported_rig.matrix_world @ bone.head_local - expected).length < 0.005, "FBX roundtrip changed rest scale/orientation")
        actual_bounds = bounds(list(bpy.context.scene.objects))
        require(max(abs(a - b) for a, b in zip(rest_bounds, actual_bounds)) < 0.005, f"FBX roundtrip changed dimensions: {name}")
        imported_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        require(len(imported_meshes) == len(stats["meshes"]), "FBX roundtrip lost meshes")
        for obj in imported_meshes:
            require(all(v.groups and abs(sum(g.weight for g in v.groups) - 1) < 0.001 for v in obj.data.vertices), "FBX roundtrip lost normalized skin weights")
        animation_checks = {}
        for slot in form["animations"]:
            reset()
            bpy.ops.import_scene.fbx(filepath=str(directory / f"{slot}.fbx"), automatic_bone_orientation=False)
            imported_rig = rig_object()
            action = imported_rig.animation_data.action if imported_rig.animation_data else None
            require(action is not None, f"FBX roundtrip lost action: {slot}")
            require(abs((action.frame_range[1] - action.frame_range[0]) / bpy.context.scene.render.fps - durations[slot]) < 0.02, f"FBX roundtrip changed timing: {slot}")
            # Measure actual evaluated bone deformation, not just action presence.
            bpy.context.scene.frame_set(int(action.frame_range[0]))
            first = [b.matrix.copy() for b in imported_rig.pose.bones]
            max_delta = 0
            for fraction in (0.25, 0.5, 0.75, 1):
                bpy.context.scene.frame_set(round(action.frame_range[0] + fraction * (action.frame_range[1] - action.frame_range[0])))
                max_delta = max(max_delta, max(abs(a[i][j] - b.matrix[i][j]) for a, b in zip(first, imported_rig.pose.bones) for i in range(4) for j in range(4)))
            require(max_delta > 0.01, f"FBX roundtrip has no motion: {slot}")
            seam_delta = max(abs(a[i][j] - b.matrix[i][j]) for a, b in zip(first, imported_rig.pose.bones) for i in range(4) for j in range(4))
            if form["animations"][slot]["loop"]:
                require(seam_delta < 0.001, f"Animation loop seam discontinuity: {slot}: {seam_delta}")
            animation_checks[slot] = {"durationSeconds": durations[slot], "maxBoneMatrixDelta": round(max_delta, 5), "loopSeamDelta": round(seam_delta, 6)}
        stats["offlineRoundtrip"] = {"model": True, "animations": animation_checks}
        report["forms"][name] = stats
    for path in sorted(output.rglob("*")):
        if path.is_file() and path.suffix in {".blend", ".fbx"}:
            report["files"][path.relative_to(output).as_posix()] = digest(path)
    (output / "export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def camera(position, target, span):
    data = bpy.data.cameras.new("PreviewCamera")
    obj = bpy.data.objects.new("PreviewCamera", data)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    data.ortho_scale = span
    bpy.context.scene.camera = obj
    return obj


def render_setup():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = 360, 360
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.background_type = "WORLD"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.055, 0.055, 0.07)


def render_frame(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def set_action(rig, action, t):
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions[action]
    start, end = rig.animation_data.action.frame_range
    bpy.context.scene.frame_set(round(start + max(0, min(1, t)) * (end - start)))


def render(species, output, frames):
    previews = output / "previews"
    proto = species["forms"]["protoform"]
    for name, form in species["forms"].items():
        bpy.ops.wm.open_mainfile(filepath=str(output / "source" / f"{name}.blend"))
        source_matches(species, form)
    bpy.ops.wm.open_mainfile(filepath=str(output / "source/protoform.blend"))
    rig = rig_object()
    animated_modes = [slot for slot in ("blink", "hop", "launch", "impact") if slot in proto["animations"]]
    modes = ["turntable", "idle"] + animated_modes + (["transformation"] if species["transformation"]["enabled"] else [])
    durations = {"turntable": 2.0}
    for slot in ["idle"] + animated_modes:
        action = bpy.data.actions[proto["animations"][slot]["action"]]
        durations[slot] = (action.frame_range[1] - action.frame_range[0]) / FPS
    if species["transformation"]["enabled"]:
        durations["transformation"] = species["transformation"]["duration"]
    render_setup()
    span = max(proto["size"]) * 1.35
    h = proto["size"][2] * 0.5
    views = {"front": (0, 10, h), "side": (10, 0, h), "three-quarter": (7, 10, h + 3)}
    cam = camera(views["front"], (0, 0, h), span)
    for name, pos in views.items():
        cam.location = pos
        cam.rotation_euler = (Vector((0, 0, h)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        render_frame(previews / f"{name}.png")
    for index in range(frames):
        angle = index / frames * math.tau
        cam.location = (10 * math.sin(angle), 10 * math.cos(angle), h + 3)
        cam.rotation_euler = (Vector((0, 0, h)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        render_frame(previews / "turntable" / f"{index:03}.png")
    cam.location = views["three-quarter"]
    cam.rotation_euler = (Vector((0, 0, h)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    for index in range(frames):
        set_action(rig, proto["animations"]["idle"]["action"], index / frames)
        render_frame(previews / "idle" / f"{index:03}.png")
    for slot in animated_modes:
        for index in range(frames):
            set_action(rig, proto["animations"][slot]["action"], index / (frames - 1))
            render_frame(previews / slot / f"{index:03}.png")
    # Bone-only diagnostic view (actual rest hierarchy, distinct from skin previews).
    rig.animation_data.action = None
    for b in rig.pose.bones:
        b.matrix_basis.identity()
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            obj.hide_render = True
    bone_mat = material("RigDiagnostic", (1, 0.7, 0.12))
    for bone in rig.data.bones:
        pos = (bone.head_local + bone.tail_local) / 2
        shape("diagnostic_" + bone.name, pos, (0.06, 0.06, (bone.tail_local - bone.head_local).length), bone_mat, "cube")
        if bone.parent:
            delta = bone.head_local - bone.parent.head_local
            connector = shape("link_" + bone.name, (bone.head_local + bone.parent.head_local) / 2, (0.025, 0.025, delta.length), bone_mat, "cube")
            connector.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    render_frame(previews / "rig.png")
    if species["transformation"]["enabled"]:
        bpy.ops.wm.open_mainfile(filepath=str(output / "source/protoform.blend"))
        small_rig = rig_object()
        small_objects = list(bpy.context.scene.objects)
        with bpy.data.libraries.load(str(output / "source/transformed.blend"), link=False) as (available, selected):
            selected.objects = list(available.objects)
        for obj in selected.objects:
            if obj:
                bpy.context.collection.objects.link(obj)
        large_objects = [o for o in selected.objects if o]
        large_rig = next(o for o in large_objects if o.type == "ARMATURE")
        render_setup()
        large_form = species["forms"]["transformed"]
        h = large_form["size"][2] * 0.5
        camera((10, 13, h + 5), (0, 0, h), max(large_form["size"]) * 1.8)
        profile = species["transformation"]
        for index in range(frames):
            p = index / (frames - 1)
            transformed = p >= profile["transitionFraction"]
            for obj in small_objects:
                obj.hide_render = transformed
            for obj in large_objects:
                obj.hide_render = not transformed
            small_rig.animation_data.action = None
            for b in small_rig.pose.bones:
                b.matrix_basis.identity()
            small_rig.rotation_euler[1] = -p * profile["duration"] * profile["spinTurnsPerSecond"] * math.tau
            squeeze = math.sin(min(1, p / profile["transitionFraction"]) * math.pi) * 0.18
            small_rig.scale = (1 + squeeze, 1 + squeeze, 1 / (1 + squeeze) ** 2)
            reveal_t = max(0, min(1, (p - profile["transitionFraction"]) / (1 - profile["transitionFraction"])))
            set_action(large_rig, large_form["animations"]["reveal"]["action"], reveal_t)
            render_frame(previews / "transformation" / f"{index:03}.png")
    # Browser viewer of PNG sequences needs no dependency or local server.
    options = "".join(f"<option>{mode}</option>" for mode in modes)
    title = "Technical placeholder" if species["placeholder"] else "Slug design — owner review draft"
    html = f'''<!doctype html><meta charset="utf-8"><title>{species['id']} pipeline preview</title>
<style>body{{background:#202129;color:#eee;font:16px system-ui;max-width:750px;margin:30px auto}}img{{width:360px}}label{{display:block;margin:10px}}</style>
<h1>{title}</h1><p>Blender preview. Use the controls to inspect the shape and motion.</p>
<img id="view" alt="Generated creature preview"><label>Sequence <select id="mode">{options}</select></label>
<label><input id="play" type="checkbox" checked> Play</label><label>Frame <input id="frame" type="range" min="0" max="{frames - 1}" value="0"></label>
<p><a href="front.png">Front</a> · <a href="side.png">Side</a> · <a href="three-quarter.png">Three quarter</a> · <a href="rig.png">Rig</a></p>
<script>const mode=document.querySelector('#mode'), frame=document.querySelector('#frame'), play=document.querySelector('#play'), view=document.querySelector('#view'), durations={json.dumps(durations)};
function draw(){{view.src=mode.value+'/'+String(frame.value).padStart(3,'0')+'.png'}};
frame.oninput=draw;mode.onchange=()=>{{frame.value=0;draw()}};
function tick(){{if(play.checked){{frame.value=(Number(frame.value)+1)%{frames};draw()}};setTimeout(tick,1000*durations[mode.value]/{frames})}};draw();setTimeout(tick,1000*durations[mode.value]/{frames});</script>'''
    (previews / "index.html").write_text(html, encoding="utf-8")
    (previews / "preview-report.json").write_text(json.dumps({"frames": frames, "sourceFps": FPS, "modes": modes, "durations": durations, "sources": {name: digest(output / "source" / f"{name}.blend") for name in species["forms"]}, "renderer": "Blender Workbench", "note": "Action sequences sampled over their authored durations; transformation is an inspection sequence"}, indent=2), encoding="utf-8")


def validate_outputs(species, config, output):
    report_path = output / "export-report.json"
    require(report_path.is_file(), "Missing export-report.json; run export")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    require(report["inputs"] == input_hashes(config, species), "Stale output: source/config/tool hashes changed; regenerate and export")
    for rel, expected in report["files"].items():
        path = (output / rel).resolve()
        require(path.is_relative_to(output.resolve()) and path.is_file(), f"Broken export path: {rel}")
        require(digest(path) == expected, f"Export/source hash mismatch: {rel}")
    for name, form in species["forms"].items():
        require(f"source/{name}.blend" in report["files"] and f"exports/{name}/model.fbx" in report["files"], f"Missing form source/export: {name}")
        for slot in form["animations"]:
            require(f"exports/{name}/{slot}.fbx" in report["files"], f"Missing animation export: {name}.{slot}")
        bpy.ops.wm.open_mainfile(filepath=str(output / "source" / f"{name}.blend"))
        source_matches(species, form)
        validate_scene(species, form)
    preview_report = json.loads((output / "previews/preview-report.json").read_text(encoding="utf-8"))
    require(preview_report["sources"] == {name: digest(output / "source" / f"{name}.blend") for name in species["forms"]}, "Stale previews: source changed; run render")
    extra_modes = [slot for slot in ("blink", "hop", "launch", "impact") if slot in species["forms"]["protoform"]["animations"]]
    require(preview_report["modes"] == ["turntable", "idle"] + extra_modes + (["transformation"] if species["transformation"]["enabled"] else []), "Missing required preview sequences")
    for name in ("front", "side", "three-quarter", "rig"):
        require((output / "previews" / f"{name}.png").is_file(), f"Missing preview: {name}")
    for mode in preview_report["modes"]:
        for frame in range(preview_report["frames"]):
            require((output / "previews" / mode / f"{frame:03}.png").is_file(), f"Missing preview frame: {mode}/{frame}")
    print("PASS: source, configuration, rigs, weights, anatomy, actions, FBX roundtrip, hashes and previews")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("generate", "export", "render", "validate", "all"))
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--frames", type=int, default=24)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    species = load_species(args.config)
    require(args.output.resolve() == (ROOT / "build/slugs" / species["id"]).resolve(), "Output must be this species' isolated build directory")
    for command, operation in (("generate", lambda: generate(species, args.output)), ("export", lambda: export(species, args.config, args.output)), ("render", lambda: render(species, args.output, args.frames)), ("validate", lambda: validate_outputs(species, args.config, args.output))):
        if args.command in (command, "all"):
            operation()


if __name__ == "__main__":
    main()
