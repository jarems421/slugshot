"""The menus' crystal clusters, rendered from the lobby's real crystals in greys so the game can tint them (owner chose
these over the drawn ones, 2026-11-03). Written to assets/source/ui/goo as fx-crystal(-small).png.
blender -b --factory-startup --python render_crystal.py -- <big|small> <size> <samples>"""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
import cavern_kit as K
which, size, samples = sys.argv[-3:]
out = str(K.ROOT / 'assets/source/ui/goo' / ('fx-crystal.png' if which == 'big' else 'fx-crystal-small.png'))
size, samples = int(size), int(samples)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
WHITE = {'Crystal': (1.0, 1.0, 1.0)}


def stand(key, x, y, s, turn, lean=0.0):
    root, objs = K.load_piece(key, groups={'Crystal'}, tints=WHITE, glow=0.9)
    bpy.context.view_layer.update()
    lo, hi = K.bounds(objs)
    pivot = bpy.data.objects.new('pivot', None)
    scene.collection.objects.link(pivot)
    root.parent = pivot
    root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
    pivot.location = (x, y, -0.6 * s)  # sunk a little, so it grows from below the frame
    pivot.scale = (s,) * 3
    pivot.rotation_euler = (0, lean, turn)


if which == 'big':
    # One tall crystal in the middle, smaller clusters leaning out either side, like the old cluster's outline.
    stand('crystals-11', 0, 0, 1.45, 0.2)
    stand('crystals-1', -2.1, -0.9, 1.05, 1.1, -0.22)
    stand('crystals-11', 2.0, -0.8, 0.9, -0.7, 0.25)
    stand('crystals-1', -3.7, -1.6, 0.6, 2.4, -0.4)
    stand('crystals-10', 3.6, -1.5, 0.55, 1.0, 0.45)
else:
    stand('crystals-1', 0, 0, 1.0, 0.4)
    stand('crystals-11', -1.5, -0.7, 0.6, 1.2, -0.3)
    stand('crystals-10', 1.5, -0.6, 0.5, -0.4, 0.35)
bpy.context.view_layer.update()
lo, hi = K.bounds([o for o in scene.objects if o.type == 'MESH'])
frame = max(hi.x - lo.x, hi.z) * 1.04
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = frame
cam.location = ((lo.x + hi.x) / 2, -40, frame / 2)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.camera = cam
world = bpy.data.worlds.new('w')
scene.world = world
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.05, 0.06, 1)
key = bpy.data.objects.new('key', bpy.data.lights.new('key', 'AREA'))
key.data.energy, key.data.size = 900, 8
key.location = (-8, -12, 14)
key.rotation_euler = (Vector((0, 0, 4)) - key.location).to_track_quat('-Z', 'Y').to_euler()
scene.collection.objects.link(key)
rim = bpy.data.objects.new('rim', bpy.data.lights.new('rim', 'AREA'))
rim.data.energy, rim.data.size = 700, 6
rim.location = (7, 8, 10)
rim.rotation_euler = (Vector((0, 0, 4)) - rim.location).to_track_quat('-Z', 'Y').to_euler()
scene.collection.objects.link(rim)
K.cycles(size, size, samples, transparent=True)
scene.view_settings.view_transform = 'Standard'
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
