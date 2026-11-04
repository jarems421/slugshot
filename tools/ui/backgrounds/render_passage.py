"""The menus' background: a cavern passage running off into the dark, built from the lobby's real art pieces and lit
by its crystals (owner's pick, 2026-11-03, with mixed kinds of stone, moss and more mushrooms).

blender -b --factory-startup --python render_passage.py -- <hex colour> <width> <samples> <out.png>
Writes out.png and out-depth.png (white is far); post.py adds the haze."""
import bpy, sys, math, random
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0, str(Path(__file__).resolve().parent))
import cavern_kit as K

hexcol, width, samples, out = sys.argv[-4:]
width, samples = int(width), int(samples)
srgb = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
lin = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
WALLS = ['rock-wall-1', 'rock-wall-4', 'rock-wall-5', 'rock-wall-6', 'rock-wall-7']
# How often each kind of stone turns up: mostly the painted slate, the rest mixed through it.
KINDS = [('slate', 4), ('basalt', 3), ('strata', 2), ('granite', 2), ('lichen', 2)]
# The lobby's glow-cap mushrooms, each with the light colour the lobby gives it; caps glow at about the lobby's
# strength, as full strength blows them out to white.
SHROOMS = {'mushroom-1': (0.6, 0.85, 1.0), 'mushroom-3': (0.43, 0.65, 1.0), 'mushroom-5': (0.75, 0.47, 1.0),
           'mushroom-12': (0.43, 0.96, 0.59), 'mushroom-13': (0.35, 0.94, 0.88)}
SHROOM_GLOW = 0.45
COOL = (0.46, 0.5, 0.95)
TINT = {'Crystal': lin}
rng = random.Random(7)
GROUP = None  # when set, everything placed is parented to it, so a whole wall can be turned
DEPTH = (40, 240)


def kind():
    return rng.choices([k for k, _ in KINDS], [w for _, w in KINDS])[0]


def put(key, at, s=1.0, turn=0.0, roll=0.0, groups=None, tints=None, glow=1.0, stand=True, stones=None, height=None):
    """Place a piece with its base centred on at. turn spins it about the vertical, roll about the view axis.
    height, when given, sizes it to that many units tall instead of scaling by s."""
    root, objs = K.load_piece(key, groups=groups, tints=tints, glow=glow, stones=stones)
    bpy.context.view_layer.update()
    lo, hi = K.bounds(objs)
    if height:
        s = height / (hi.z - lo.z)
    pivot = bpy.data.objects.new('pivot', None)
    scene.collection.objects.link(pivot)
    root.parent = pivot
    root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z if stand else -(lo.z + hi.z) / 2)
    pivot.location = at
    pivot.scale = (s,) * 3
    pivot.rotation_euler = (0, roll, turn)
    if GROUP:
        pivot.parent = GROUP
    return pivot


def light(at, energy, radius, colour=None):
    l = bpy.data.objects.new('L', bpy.data.lights.new('L', 'POINT'))
    l.data.energy = energy
    l.data.shadow_soft_size = radius
    l.data.color = colour or lin
    l.location = at
    scene.collection.objects.link(l)
    if GROUP:
        l.parent = GROUP


def area(at, aim, energy, size, colour):
    l = bpy.data.objects.new('A', bpy.data.lights.new('A', 'AREA'))
    l.data.energy, l.data.size, l.data.color = energy, size, colour
    l.location = at
    l.rotation_euler = (Vector(aim) - Vector(at)).to_track_quat('-Z', 'Y').to_euler()
    scene.collection.objects.link(l)


def crystal(key, at, s, turn=0.0, roll=0.0):
    put(key, at, s, turn, roll, groups={'Crystal'}, tints=TINT, glow=1.3)
    # The cluster's own light on the rock around it, from inside the cluster. Every glow has a source.
    up = Vector((math.sin(roll), 0, math.cos(roll)))
    light(Vector(at) + up * s * 3.2 + Vector((0, 1.2 * s, 0)), 260 * s * s, s * 0.8)


def wall(rows, cols, step_x, step_z, z0, scale, proud, moss):
    """Boulders packed into a wall facing +Y (the pieces' decorated side), so no gaps show. A few big ones stand
    proud of it as outcrops, so it reads as a cavern wall rather than masonry. Each is its own kind of stone."""
    for row in range(rows):
        for col in range(cols):
            x = (col - (cols - 1) / 2) * step_x + rng.uniform(-3.5, 3.5) + (row % 2) * step_x / 2
            z = z0 + row * step_z + rng.uniform(-2.5, 2.5)
            y = rng.uniform(-2.5, 2.5)
            s = rng.uniform(*scale)
            if rng.random() < 0.14:
                s, y = s * proud, y + 4
            put(rng.choice(WALLS), (x, y, z), s, turn=rng.uniform(-0.35, 0.35) + math.pi,
                roll=rng.uniform(0, 6.28), groups={'Rock'}, stand=False,
                stones={'Rock': (kind(), moss * rng.uniform(0.6, 1.0))})


def backdrop(y):
    bpy.ops.mesh.primitive_plane_add(size=800, location=(0, y, 0), rotation=(math.radians(90), 0, 0))
    m = bpy.data.materials.new('Back')
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (0.01, 0.01, 0.018, 1)
    b.inputs['Roughness'].default_value = 1
    bpy.context.object.data.materials.append(m)


def drop(x, y, z_from):
    """The first rock surface straight below (x, y, z_from), skipping ink shells: (point, normal) or None."""
    origin = Vector((x, y, z_from))
    graph = bpy.context.evaluated_depsgraph_get()
    for _ in range(6):
        hit, at, normal, _, obj, _ = scene.ray_cast(graph, origin, Vector((0, 0, -1)))
        if not hit:
            return None
        if not obj.name.split('.')[0].endswith('_Ink') and obj.name != 'Plane':
            return at, normal
        origin = at + Vector((0, 0, -0.05))
    return None


def shrooms(at, size, count):
    """A cluster of mixed glow-cap mushrooms on the rock at at, the biggest in the middle, lit in its colour."""
    main = rng.choice(list(SHROOMS))
    for i in range(count):
        spot = Vector(at) + (Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * size * 0.9 if i else Vector())
        ground = drop(spot.x, spot.y, at[2] + size * 2)
        if not ground or ground[1].z < 0.55 or abs(ground[0].z - at[2]) > size:
            continue
        tall = size * (1.0 if i == 0 else rng.uniform(0.35, 0.7))
        put(main if i == 0 else rng.choice(list(SHROOMS)), ground[0] - Vector((0, 0, tall * 0.04)),
            turn=rng.uniform(0, 6.3), roll=rng.uniform(-0.12, 0.12), height=tall, glow=SHROOM_GLOW)
    light(Vector(at) + Vector((0, 1.5, size * 0.9)), 14 * size * size, size * 0.5, SHROOMS[main])


world = bpy.data.worlds.new('w')
scene.world = world
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.003, 0.003, 0.008, 1)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (0, 100, 4)
cam.rotation_euler = (Vector((0, 0, 2)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 24

# Walls on both sides run away into the dark, so the middle stays calm behind the title and bar.
backdrop(-260)
for side in (-1, 1):
    GROUP = bpy.data.objects.new('wall', None)
    scene.collection.objects.link(GROUP)
    wall(5, 8, 29, 15, -18, (2.0, 2.6), 1.3, 0.55)
    for key, x, z, size in [('crystals-11', -70, -18, 3.0), ('crystals-1', -80, -16, 1.8), ('crystals-10', -60, 16, 1.5),
                            ('crystals-10', -30, -18, 2.3), ('crystals-1', -2, -18, 1.6), ('crystals-11', 30, -18, 2.2),
                            ('crystals-1', 10, 18, 1.2), ('crystals-10', 62, -18, 2.0)]:
        crystal(key, (x * side, 14, z), size, turn=rng.uniform(-0.6, 0.6))
    # Each wall's face (+Y) turns to the middle and its length runs away from the camera, opening slightly toward it.
    GROUP.rotation_euler = (0, 0, side * (math.pi / 2 - 0.18))
    GROUP.location = (side * 30, -70, 0)
    GROUP = None
# The floor: the same boulders laid face up, running down the passage, mossier than the walls.
GROUP = bpy.data.objects.new('floor', None)
scene.collection.objects.link(GROUP)
wall(3, 8, 29, 15, -15, (2.0, 2.6), 1.0, 1.0)
GROUP.matrix_world = Matrix(((0, 0, 1, 0), (1, 0, 0, -70), (0, 1, 0, -30), (0, 0, 0, 1)))
GROUP = None
bpy.context.view_layer.update()

# Mushrooms gather where the floor meets each wall, getting smaller with distance, plus a few on wall ledges.
for side in (-1, 1):
    for y, size, count in [(40, 5.5, 5), (12, 5.5, 4), (-22, 5, 4), (-55, 4.5, 3), (-95, 4.5, 3), (-135, 4, 2)]:
        found = None
        for step in range(40):
            x = side * step * 1.0
            ground = drop(x, y + rng.uniform(-4, 4), 60)
            if not ground:
                continue
            if ground[1].z > 0.6 and ground[0].z < -14:
                found = ground[0]
            elif ground[0].z > -8:
                break  # reached the wall
        if found:
            shrooms(found, size, count)
    for y, z in [(-10, 6), (-60, 10), (-120, 20)]:
        # Just in front of the wall's face, which is 25 units out at the far end and widens toward the camera.
        ground = drop(side * (22 + (70 + y) * 0.182), y, z)
        if ground and ground[1].z > 0.7 and ground[0].z > -10:
            shrooms(ground[0], 3.5, 2)

area((0, 90, 50), (0, -60, 0), 30000, 40, COOL)
K.cycles(width, width * 9 // 16, samples)
scene.render.filepath = out
bpy.ops.render.render(write_still=True)

# A distance pass for the haze, composed afterwards: white is far.
depth = bpy.data.materials.new('Depth')
nodes, links = depth.node_tree.nodes, depth.node_tree.links
for n in list(nodes):
    if n.type != 'OUTPUT_MATERIAL':
        nodes.remove(n)
camdata = nodes.new('ShaderNodeCameraData')
span = nodes.new('ShaderNodeMapRange')
span.inputs['From Min'].default_value, span.inputs['From Max'].default_value = DEPTH
em = nodes.new('ShaderNodeEmission')
links.new(camdata.outputs['View Distance'], span.inputs['Value'])
links.new(span.outputs['Result'], em.inputs['Color'])
links.new(em.outputs['Emission'], next(n for n in nodes if n.type == 'OUTPUT_MATERIAL').inputs['Surface'])
bpy.context.view_layer.material_override = depth
world.node_tree.nodes['Background'].inputs['Color'].default_value = (1, 1, 1, 1)
scene.view_settings.view_transform = 'Standard'
scene.cycles.samples = 4
scene.cycles.use_denoising = False
for o in scene.objects:
    if o.type == 'LIGHT':
        o.hide_render = True
scene.render.filepath = out.replace('.png', '-depth.png')
bpy.ops.render.render(write_still=True)
