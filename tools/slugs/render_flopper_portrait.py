"""Render review stills from the original authored slug; never changes the source."""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ROOT


def light(name, location, power, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size = power, "DISK", size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0,0,1.1)) - obj.location).to_track_quat("-Z", "Y").to_euler()


def main():
    source = ROOT / "assets/source/slugs/models/flopper-inspired/protoform.blend"
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    rig = next(obj for obj in scene.objects if obj.type == "ARMATURE")
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("PortraitWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.38,0.38,0.38,1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
    scene.world = world
    light("Key", (4,5,7), 300, 5)
    light("Fill", (-4,4,4), 140, 4)
    light("Rim", (0,-4,6), 280, 3)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,0))
    floor = bpy.context.object
    floor.name = "ReviewBackdrop"
    floor_mat = bpy.data.materials.new("Backdrop")
    floor_mat.diffuse_color = (0.32,0.32,0.32,1)
    floor.data.materials.append(floor_mat)
    data = bpy.data.cameras.new("ReviewCamera")
    data.type, data.ortho_scale = "ORTHO", 3.7
    camera = bpy.data.objects.new("ReviewCamera", data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    output = ROOT / "build/slugs/flopper-inspired/previews"
    output.mkdir(parents=True, exist_ok=True)
    for name, position in (("portrait",(4.2,7,3.5)), ("portrait-front",(0,8,1.45)), ("portrait-rear",(4,-7,3.1))):
        camera.location = position
        camera.rotation_euler = (Vector((0,0,1.32))-camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(output / f"{name}.png")
        bpy.ops.render.render(write_still=True)
    print("PASS: rendered original slug review portraits")


if __name__ == "__main__":
    main()
