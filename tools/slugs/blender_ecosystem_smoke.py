"""Disposable modelling/rigging/render/export smoke example.

Run: blender --background --factory-startup --python-exit-code 1 --python
tools/slugs/blender_ecosystem_smoke.py -- <ignored-output-directory>
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if len(args) != 1:
        raise SystemExit("Pass one disposable output directory after --")
    out = Path(args[0]).resolve()
    out.mkdir(parents=True, exist_ok=True)

    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16)
    body = bpy.context.object
    body.name = "DisposableOrganicProbe"
    for vertex in body.data.vertices:
        z = vertex.co.z
        vertex.co.x *= 0.75 + 0.12 * z * z
        vertex.co.y *= 0.7 + 0.1 * z
        vertex.co.z = 0.85 * z + 0.09 * math.sin(3 * vertex.co.x) * (1 - z * z)
    for polygon in body.data.polygons:
        polygon.use_smooth = True
    body.data.update()
    assert all(math.isfinite(value) for vertex in body.data.vertices for value in vertex.co)
    assert len(body.data.polygons) > 200

    material = bpy.data.materials.new("DisposableSeaGlass")
    material.diffuse_color = (0.19, 0.7, 0.57, 1)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (0.19, 0.7, 0.57, 1)
    principled.inputs["Roughness"].default_value = 0.45
    body.data.materials.append(material)

    bpy.ops.object.armature_add(enter_editmode=False)
    armature = bpy.context.object
    armature.name = "DisposableRig"
    armature.data.bones[0].name = "SoftRoot"
    group = body.vertex_groups.new(name="SoftRoot")
    group.add(list(range(len(body.data.vertices))), 1, "REPLACE")
    modifier = body.modifiers.new("DisposableSkin", "ARMATURE")
    modifier.object = armature
    body.parent = armature
    bone = armature.pose.bones["SoftRoot"]
    bone.scale = (1, 1, 1)
    bone.keyframe_insert(data_path="scale", frame=1)
    bone.scale = (1.12, 1.12, 0.84)
    bone.keyframe_insert(data_path="scale", frame=8)
    bone.scale = (1, 1, 1)
    bone.keyframe_insert(data_path="scale", frame=16)
    bpy.context.scene.frame_end = 16
    bpy.context.scene.frame_set(1)
    assert armature.animation_data and armature.animation_data.action

    camera_data = bpy.data.cameras.new("DisposableCamera")
    camera = bpy.data.objects.new("DisposableCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 3
    bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
    bpy.context.scene.render.resolution_x = 256
    bpy.context.scene.render.resolution_y = 256
    bpy.context.scene.render.resolution_percentage = 100
    bpy.context.scene.render.image_settings.file_format = "PNG"
    for label, location in {
        "front": (0, -4, 1.2),
        "side": (4, 0, 1.2),
        "back": (0, 4, 1.2),
        "three-quarter": (3, -3, 1.5),
    }.items():
        camera.location = location
        direction = Vector((0, 0, 0)) - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.render.filepath = str(out / f"{label}.png")
        bpy.ops.render.render(write_still=True)
        assert (out / f"{label}.png").stat().st_size > 1000

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.fbx(filepath=str(out / "probe.fbx"), use_selection=True, add_leaf_bones=False)
    assert (out / "probe.fbx").stat().st_size > 1000
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "probe.blend"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.open_mainfile(filepath=str(out / "probe.blend"))
    assert "DisposableOrganicProbe" in bpy.data.objects
    assert "DisposableRig" in bpy.data.objects
    assert bpy.data.objects["DisposableRig"].animation_data.action
    report = {
        "blender": bpy.app.version_string,
        "mesh_vertices": len(bpy.data.objects["DisposableOrganicProbe"].data.vertices),
        "render_views": 4,
        "rig_bones": len(bpy.data.objects["DisposableRig"].data.bones),
        "fbx_bytes": (out / "probe.fbx").stat().st_size,
        "restore": "passed",
    }
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("SMOKE_REPORT", json.dumps(report))


if __name__ == "__main__":
    main()
