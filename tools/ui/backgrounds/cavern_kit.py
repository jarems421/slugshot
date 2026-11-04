"""Shared helpers for the menu backgrounds: load the lobby's real art pieces with their painted textures and ink
shells. The pieces come from ignored build folders: this worktree's training sources and the lobby worktree's export."""
import bpy, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
SOURCES = [ROOT / 'build/training/source', ROOT.parent / 'slugshot-lobby/build/lobby/export']
INK = (14 / 255 * 0.25, 14 / 255 * 0.25, 18 / 255 * 0.25)
_mats = {}
_pieces = {}


def folder(key):
    return next(s / key for s in SOURCES if (s / key / f'{key}.glb').exists())


def tex(nodes, path, colour=True):
    n = nodes.new('ShaderNodeTexImage')
    n.image = bpy.data.images.load(str(path), check_existing=True)
    if not colour:
        n.image.colorspace_settings.name = 'Non-Color'
    return n


def recolour(nodes, links, socket, tint, lift=1.0):
    """Greyscale the painted colour and multiply it by the place's colour, keeping the paint's shading."""
    bw = nodes.new('ShaderNodeRGBToBW')
    links.new(socket, bw.inputs['Color'])
    gain = nodes.new('ShaderNodeMath')
    gain.operation = 'MULTIPLY'
    gain.inputs[1].default_value = lift
    links.new(bw.outputs['Val'], gain.inputs[0])
    mul = nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    links.new(gain.outputs['Value'], mul.inputs[6])
    mul.inputs[7].default_value = (*tint, 1)
    return mul.outputs[2]


# Kinds of stone a boulder can be, so a wall reads as many rocks rather than one repeated (owner, 2026-11-03).
# tint/lift recolour the painted shading; the rest are patterns in the boulder's own coordinates.
STONES = {
    'slate': {},
    'basalt': dict(tint=(0.24, 0.26, 0.42), lift=1.0, veins=(0.5, 0.8, 0.85)),
    'strata': dict(tint=(0.78, 0.56, 1.0), lift=2.0, strata=0.6),
    'granite': dict(tint=(0.85, 0.82, 0.8), lift=1.9, speckle=0.08),
    'lichen': dict(tint=(0.42, 0.72, 0.64), lift=2.0, mottle=(0.6, 1.0, 0.45)),
}


def _math(nodes, links, op, *values):
    n = nodes.new('ShaderNodeMath')
    n.operation = op
    for i, v in enumerate(values):
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            links.new(v, n.inputs[i])
    return n.outputs['Value']


def _band(nodes, links, socket, lo, hi):
    """0 below lo, 1 above hi, smoothly between."""
    n = nodes.new('ShaderNodeMapRange')
    n.interpolation_type = 'SMOOTHSTEP'
    n.inputs['From Min'].default_value, n.inputs['From Max'].default_value = lo, hi
    links.new(socket, n.inputs['Value'])
    return n.outputs['Result']


def _mix(nodes, links, fac, a, b, blend='MIX'):
    n = nodes.new('ShaderNodeMix')
    n.data_type = 'RGBA'
    n.blend_type = blend
    for i, (socket, v) in enumerate(((n.inputs['Factor'], fac), (n.inputs[6], a), (n.inputs[7], b))):
        if isinstance(v, (int, float)):
            socket.default_value = v if i == 0 else (v, v, v, 1)
        elif isinstance(v, tuple):
            socket.default_value = (*v, 1)
        else:
            links.new(v, socket)
    return n.outputs[2]


def _noise(nodes, links, coords, scale, detail=2.0):
    n = nodes.new('ShaderNodeTexNoise')
    n.inputs['Scale'].default_value, n.inputs['Detail'].default_value = scale, detail
    links.new(coords, n.inputs['Vector'])
    return n.outputs['Fac']


def _wave(nodes, links, coords, scale, distortion, direction):
    n = nodes.new('ShaderNodeTexWave')
    n.bands_direction = direction
    n.inputs['Scale'].default_value, n.inputs['Distortion'].default_value = scale, distortion
    n.inputs['Detail'].default_value = 3.0
    links.new(coords, n.inputs['Vector'])
    return n.outputs['Fac']


def stone(nodes, links, col, kind, moss):
    """The painted rock colour as one kind of stone, with moss on the faces that look up. Returns the colour and,
    when there is moss, its mask and fibre noise."""
    spec = STONES[kind]
    obj = nodes.new('ShaderNodeTexCoord').outputs['Object']
    if 'tint' in spec:
        bw = nodes.new('ShaderNodeRGBToBW')
        links.new(col, bw.inputs['Color'])
        col = _mix(nodes, links, 1.0, _math(nodes, links, 'MULTIPLY', bw.outputs['Val'], spec['lift']), spec['tint'],
                   'MULTIPLY')
    # Every stone has broad lighter and darker patches, so no two boulders match.
    col = _mix(nodes, links, 1.0, col, _math(nodes, links, 'MULTIPLY_ADD', _noise(nodes, links, obj, 0.35, 3), 0.7, 0.65),
               'MULTIPLY')
    if 'strata' in spec:
        bands = _wave(nodes, links, obj, 0.35, 2.5, 'Z')
        col = _mix(nodes, links, 1.0, col, _math(nodes, links, 'MULTIPLY_ADD', bands, spec['strata'],
                                                 1 - spec['strata'] / 2), 'MULTIPLY')
    if 'veins' in spec:
        line = _band(nodes, links, _wave(nodes, links, obj, 0.45, 7.0, 'DIAGONAL'), 0.88, 0.98)
        col = _mix(nodes, links, _math(nodes, links, 'MULTIPLY', line, 0.8), col,
                   tuple(c * 0.16 for c in spec['veins']))
    if 'speckle' in spec:
        light = _band(nodes, links, _noise(nodes, links, obj, 22, 0), 0.66, 0.7)
        col = _mix(nodes, links, _math(nodes, links, 'MULTIPLY', light, 0.6), col, (spec['speckle'],) * 3)
        dark = _band(nodes, links, _noise(nodes, links, obj, 17, 0), 0.68, 0.72)
        col = _mix(nodes, links, _math(nodes, links, 'MULTIPLY', dark, 0.6), col, (0.008, 0.008, 0.012))
    if 'mottle' in spec:
        blot = _band(nodes, links, _noise(nodes, links, obj, 0.9, 4), 0.48, 0.6)
        col = _mix(nodes, links, blot, col, _mix(nodes, links, 1.0, col, spec['mottle'], 'MULTIPLY'))
    if not moss:
        return col, None
    # Moss: on faces turned upward, in patches shared across neighbouring boulders, fuzzy at the edges.
    geo = nodes.new('ShaderNodeNewGeometry')
    normal = nodes.new('ShaderNodeSeparateXYZ')
    links.new(geo.outputs['Normal'], normal.inputs['Vector'])
    facing = _band(nodes, links, normal.outputs['Z'], 0.05, 0.5)
    fine = _noise(nodes, links, geo.outputs['Position'], 2.2, 6)
    reach = _math(nodes, links, 'MULTIPLY_ADD', fine, 0.25, _noise(nodes, links, geo.outputs['Position'], 0.045, 4))
    covered = _band(nodes, links, reach, 0.68 - 0.2 * moss, 0.76 - 0.2 * moss)
    mask = _math(nodes, links, 'MULTIPLY', facing, covered)
    green = _mix(nodes, links, _noise(nodes, links, geo.outputs['Position'], 0.6, 3), (0.04, 0.09, 0.04),
                 (0.11, 0.2, 0.07))
    green = _mix(nodes, links, _band(nodes, links, fine, 0.5, 0.72), green, (0.2, 0.32, 0.1))
    return _mix(nodes, links, mask, col, green), (mask, fine)


def material(key, group, info, tint=None, glow=1.0, lift=1.6, kind=None, moss=0.0):
    name = f'{key}-{group}-{tint}-{glow}-{kind}-{moss}'
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
    f = folder(key)
    col = tex(nodes, f / info['color']).outputs['Color']
    col = recolour(nodes, links, col, tint, lift) if tint else col
    grown = None
    if kind:
        col, grown = stone(nodes, links, col, kind, moss)
    links.new(col, bsdf.inputs['Base Color'])
    nm = nodes.new('ShaderNodeNormalMap')
    links.new(tex(nodes, f / info['normal'], False).outputs['Color'], nm.inputs['Color'])
    links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    bsdf.inputs['Roughness'].default_value = 0.85
    if grown:
        # Moss is soft: rougher, with a little sheen on its fibres and a fine bump.
        mask, fine = grown
        links.new(_math(nodes, links, 'MULTIPLY_ADD', mask, 0.15, 0.85), bsdf.inputs['Roughness'])
        links.new(_math(nodes, links, 'MULTIPLY', mask, 0.5), bsdf.inputs['Sheen Weight'])
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value, bump.inputs['Distance'].default_value = 0.6, 0.05
        links.new(_math(nodes, links, 'MULTIPLY', mask, fine), bump.inputs['Height'])
        links.new(nm.outputs['Normal'], bump.inputs['Normal'])
        links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    if 'emit' in info:
        e = tex(nodes, f / info['emit']).outputs['Color']
        # As in Roblox, the emit map is a mask over the piece's own colour, so a blue cap glows blue.
        links.new(recolour(nodes, links, e, tint, 1.4) if tint else _mix(nodes, links, 1.0, col, e, 'MULTIPLY'),
                  bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = info.get('emissiveStrength', 2) * glow
    if tint:
        bsdf.inputs['Roughness'].default_value = 0.2
        bsdf.inputs['Coat Weight'].default_value = 0.6
    _mats[name] = m
    return m


def ink_material():
    if 'Ink' in _mats:
        return _mats['Ink']
    m = bpy.data.materials.new('Ink')
    nodes, links = m.node_tree.nodes, m.node_tree.links
    for n in list(nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nodes.remove(n)
    out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
    em = nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*INK, 1)
    tr = nodes.new('ShaderNodeBsdfTransparent')
    geo = nodes.new('ShaderNodeNewGeometry')
    mix = nodes.new('ShaderNodeMixShader')
    links.new(geo.outputs['Backfacing'], mix.inputs['Fac'])
    links.new(em.outputs['Emission'], mix.inputs[1])
    links.new(tr.outputs['BSDF'], mix.inputs[2])
    links.new(mix.outputs['Shader'], out.inputs['Surface'])
    _mats['Ink'] = m
    return m


def _import(key, tints, glow):
    info = {g['name']: g for g in json.loads((folder(key) / 'build.json').read_text())['groups']}
    before = set(bpy.data.objects[:])
    bpy.ops.import_scene.gltf(filepath=str(folder(key) / f'{key}.glb'))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = {}
    for o in new:
        if o.type != 'MESH':
            continue
        base = o.name.split('.')[0]
        o.data.materials.clear()
        if base.endswith('_Ink'):
            o.data.materials.append(ink_material())
        elif base in info:
            o.data.materials.append(material(key, base, info[base], tint=(tints or {}).get(base), glow=glow))
        meshes[base] = o
    for o in new:
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    for o in meshes.values():
        for c in list(o.users_collection):
            c.objects.unlink(o)
    return meshes


def load_piece(key, groups=None, tints=None, glow=1.0, stones=None):
    """tints: {group: linear rgb} recolours that group to the place. stones: {group: (kind, moss)} makes that group
    of this copy one of STONES, with moss from 0 (none) to 1 (a lot)."""
    k = (key, tuple(sorted((tints or {}).items())), glow)
    if k not in _pieces:
        _pieces[k] = _import(key, tints, glow)
    root = bpy.data.objects.new(key, None)
    bpy.context.scene.collection.objects.link(root)
    keep = []
    for base, src in _pieces[k].items():
        if groups is not None and base.replace('_Ink', '') not in groups:
            continue
        o = src.copy()
        bpy.context.scene.collection.objects.link(o)
        o.parent = root
        if base.endswith('_Ink'):
            # Ink only shows to the camera; it must not shade what it wraps.
            o.visible_shadow = o.visible_diffuse = o.visible_glossy = o.visible_transmission = o.visible_volume_scatter = False
        elif stones and base in stones:
            # The copies share one mesh, so the stone goes on the object, not the mesh.
            info = {g['name']: g for g in json.loads((folder(key) / 'build.json').read_text())['groups']}
            kind, moss = stones[base]
            o.material_slots[0].link = 'OBJECT'
            o.material_slots[0].material = material(key, base, info[base], kind=kind, moss=moss)
        keep.append(o)
    return root, keep


def bounds(objs):
    from mathutils import Vector
    pts = [o.matrix_world @ Vector(v) for o in objs if not o.name.split('.')[0].endswith('_Ink') for v in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def cycles(w, h, samples=32, transparent=False):
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.render.threads_mode = 'FIXED'
    s.render.threads = 8  # leave the owner some of the machine
    s.render.resolution_x, s.render.resolution_y = w, h
    s.render.resolution_percentage = 100
    s.render.film_transparent = transparent
    s.view_settings.view_transform = 'AgX'
    s.cycles.max_bounces = 4
