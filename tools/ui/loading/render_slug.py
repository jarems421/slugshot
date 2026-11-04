"""Comic render of a slug: its own colour texture, three flat light bands, a crisp highlight and a thick ink hull.

blender -b <file> --python toon_render.py -- <slug> <yaw> <out.png>
slug is floppy (opens the .blend) or inferno (imports the GLB).
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

slug, yaw, out = sys.argv[sys.argv.index('--') + 1:][:3]
yaw = math.radians(float(yaw))
scene = bpy.context.scene
if slug == 'inferno':
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    bpy.ops.import_scene.gltf(filepath=r'C:/Users/runni/slugshot-slug-pipeline/build/slugs/inferno/base/model.glb')
    for o in [o for o in scene.objects if o.name.startswith('Icosphere')]:
        bpy.data.objects.remove(o, do_unlink=True)
    tex = Path(r'C:/Users/runni/slugshot-slug-pipeline/build/slugs/inferno/base/textures')
    paint = {'InfernoBody': 'inferno-base-color.png',
             'InfernoMouth': 'inferno-base-mouth.png'}
    flat = {'InfernoEyes': (0.62, 0.36, 0.08), 'InfernoMouthInk': (0.01, 0.01, 0.012), 'InfernoMouthLine': (0.01, 0.01, 0.012)}
    hull_of = []  # its hard-edged mesh splits a hull apart; the outline is drawn from the silhouette instead
else:
    tex = Path(r'C:/Users/runni/slugshot-slide-shot/build/slugs/floppy/flat-sole/textures')
    paint = {'FloppyBody': 'floppy-body-color.png', 'EyeL': 'floppy-eye-left.png', 'EyeR': 'floppy-eye-right.png'}
    flat = {}
    hull_of = []
    shell = scene.objects.get('FloppyBody_Ink')
    if shell:
        bpy.data.objects.remove(shell, do_unlink=True)
    hull_of = []

ink = bpy.data.materials.new('Ink')
ink.use_nodes = True
nodes = ink.node_tree.nodes
nodes.clear()
emit = nodes.new('ShaderNodeEmission')
emit.inputs['Color'].default_value = (0.004, 0.004, 0.006, 1)
outn = nodes.new('ShaderNodeOutputMaterial')
ink.node_tree.links.new(emit.outputs[0], outn.inputs['Surface'])
ink.use_backface_culling = True


def toon(name, image=None, colour=None):
    mat = bpy.data.materials.new(name + 'Toon')
    mat.use_nodes = True
    n, l = mat.node_tree.nodes, mat.node_tree.links
    n.clear()
    diffuse = n.new('ShaderNodeBsdfDiffuse')
    to_rgb = n.new('ShaderNodeShaderToRGB')
    l.new(diffuse.outputs[0], to_rgb.inputs[0])
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'CONSTANT'
    stops = ramp.color_ramp.elements
    stops[0].position, stops[0].color = 0.0, (0.62, 0.62, 0.68, 1)
    stops[1].position, stops[1].color = 0.12, (0.92, 0.92, 0.94, 1)
    third = stops.new(0.45)
    third.color = (1.12, 1.12, 1.1, 1)
    top = stops.new(0.9)
    top.color = (1.45, 1.45, 1.4, 1)
    bw = n.new('ShaderNodeRGBToBW')
    l.new(to_rgb.outputs['Color'], bw.inputs[0])
    l.new(bw.outputs[0], ramp.inputs['Fac'])
    mix = n.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1
    if image:
        t = n.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(str(tex / image))
        l.new(t.outputs['Color'], mix.inputs['A'])
    else:
        mix.inputs['A'].default_value = (*colour, 1)
    l.new(ramp.outputs['Color'], mix.inputs['B'])
    e = n.new('ShaderNodeEmission')
    l.new(mix.outputs['Result'], e.inputs['Color'])
    o = n.new('ShaderNodeOutputMaterial')
    l.new(e.outputs[0], o.inputs['Surface'])
    return mat


for o in scene.objects:
    if o.type != 'MESH':
        continue
    if o.name in paint:
        m = toon(o.name, image=paint[o.name])
    elif o.name in flat:
        m = toon(o.name, colour=flat[o.name])
    else:
        continue
    o.data.materials.clear()
    o.data.materials.append(m)

meshes = [o for o in scene.objects if o.type == 'MESH']
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector(tuple(min(p[i] for p in pts) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in pts) for i in range(3)))
c, size = (lo + hi) / 2, max(hi - lo)
# Thick outline for a small on-screen character: an inverted hull.
for name in hull_of:
    body = scene.objects[name]
    body.data.materials.append(ink)
    mod = body.modifiers.new('Ink', 'SOLIDIFY')
    mod.thickness = size * 0.035
    mod.offset = 1
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = len(body.data.materials) - 1
for o in list(scene.objects):
    if o.type in ('LIGHT', 'CAMERA'):
        bpy.data.objects.remove(o, do_unlink=True)
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
scene.collection.objects.link(sun)
sun.data.energy = 3.2
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = size * 1.25
front = -1 if slug == 'inferno' else 1
cam.location = c + Vector((math.sin(yaw) * size * 4, front * math.cos(yaw) * size * 4, size * 0.1))
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
# Key light from up and toward the camera's left, as on the crystals.
side = cam.matrix_world.to_quaternion() @ Vector((-1, 0.9, 0.7))
sun.rotation_euler = (-side).to_track_quat('-Z', 'Y').to_euler()
scene.world = scene.world or bpy.data.worlds.new('w')
scene.world.use_nodes = True
next(n for n in scene.world.node_tree.nodes if n.type == 'BACKGROUND').inputs['Strength'].default_value = 0
scene.render.resolution_x = scene.render.resolution_y = 480
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = out
try:
    scene.render.engine = 'BLENDER_EEVEE'
except TypeError:
    pass
scene.eevee.taa_render_samples = 16
scene.view_settings.view_transform = 'Standard'
bpy.ops.render.render(write_still=True)
print('RENDERED', out)
