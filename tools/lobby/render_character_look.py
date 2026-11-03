"""Render a character or prop (Floppy, the blaster) in the Slugshot look as a 36-frame turntable.

Matches what the look pack does in Roblox: an inverted-hull ink shell on each part (near-black, back faces
culled, so only the rim shows), the asset's own colours, its glowing parts emitting, a faint colour-matched
self-glow on Floppy (the Roblox emissive floor), and a dark cavern with a crisp cool key, a warm fill and a
violet rim. Frames go to <out dir>/<name>-NN.png for tools/lobby/sheet_frames.py.

    blender --background --factory-startup --python tools/lobby/render_character_look.py -- <blend> <out dir> <name> <blaster|floppy> [frame count]
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, NAME, KIND = Path(ARGS[0]).resolve(), Path(ARGS[1]).resolve(), ARGS[2], ARGS[3]
FRAMES, W, H = 36, 640, 480
COUNT = int(ARGS[4]) if len(ARGS) > 4 else FRAMES  # render only the first frames (look tuning)
INK = (0.006, 0.006, 0.008)

# The blaster's accepted finish (tools/slugs/refit_floppy_blaster.py): colour, roughness, metallic, glows.
FINISH = {
    "Orange": ("A9572C", 0.43, 0.0), "BodyGrey": ("363F48", 0.40, 1.0), "DarkGrey": ("252D34", 0.48, 1.0),
    "Steel": ("A2ABB1", 0.30, 1.0), "Black": ("20252A", 0.65, 0.0), "GripNavy": ("252C31", 0.80, 0.0),
    "GripBand": ("677078", 0.44, 1.0), "White": ("BAC0BC", 0.48, 0.0), "ChargerBlack": ("343D43", 0.42, 1.0),
}
GLOWS = {"ChargerVane": ("EBF0ED", 6.0), "CyanGlow": ("A5CDD0", 5.0)}
# Ink widths in source units: the blaster is about 2.1 long, Floppy about 0.92 tall.
INK_WIDTH = {"blaster": 0.016, "floppy": 0.011}
THIN_PARTS = {"Steel", "White", "ChargerVane", "GripBand"}


def srgb(h):
    c = [int(h[i:i + 2], 16)/255 for i in (0, 2, 4)]
    return tuple(x/12.92 if x <= 0.04045 else ((x + 0.055)/1.055)**2.4 for x in c) + (1.0,)


def principled(mat):
    mat.use_nodes = True
    return next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def style_blaster(objs):
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if m is None:
                continue
            key = m.name.split(".")[0]
            b = principled(m)
            if key in FINISH:
                col, rough, metal = FINISH[key]
                b.inputs["Base Color"].default_value = srgb(col)
                b.inputs["Roughness"].default_value = rough
                b.inputs["Metallic"].default_value = metal
            elif key in GLOWS:
                col, strength = GLOWS[key]
                b.inputs["Base Color"].default_value = srgb(col)
                b.inputs["Emission Color"].default_value = srgb(col)
                b.inputs["Emission Strength"].default_value = strength
            elif key == "CanisterTeal":
                # The slug canister: teal glass with a soft inner glow (the "mystical glow").
                base = b.inputs["Base Color"].default_value
                b.inputs["Emission Color"].default_value = (base[0]*1.4, base[1]*1.4, base[2]*1.4, 1.0)
                b.inputs["Emission Strength"].default_value = 1.6
                b.inputs["Roughness"].default_value = 0.15


# FloppyAppearance's glow tint (sRGB 215, 240, 160, as linear) and emissive floor.
GLOW_TINT = (0.68, 0.87, 0.35)
EMISSIVE_FLOOR = 0.05


def style_floppy(objs):
    """Keep the baked textures and glow the way FloppyAppearance does in Roblox: emission = albedo x mask x strength x
    tint, where the mask is the exported glow mask floored at 0.05 (plain skin keeps a faint visibility floor) and
    the strength is that floor's 0.12 divided by 0.05."""
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if m is None:
                continue
            nt = m.node_tree
            b = principled(m)
            link = next((ln for ln in nt.links if ln.to_socket == b.inputs["Base Color"]), None)
            if not link:
                continue
            tint = nt.nodes.new("ShaderNodeVectorMath")
            tint.operation = "MULTIPLY"
            tint.inputs[1].default_value = GLOW_TINT
            nt.links.new(link.from_socket, tint.inputs[0])
            glow = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and n.image.name.startswith("floppy-body-glow")), None)
            strength = nt.nodes.new("ShaderNodeMath")
            strength.operation = "MULTIPLY"
            strength.inputs[1].default_value = 0.12/EMISSIVE_FLOOR
            if glow:
                floor = nt.nodes.new("ShaderNodeMath")
                floor.operation = "MAXIMUM"
                floor.inputs[1].default_value = EMISSIVE_FLOOR
                nt.links.new(glow.outputs["Color"], floor.inputs[0])
                nt.links.new(floor.outputs["Value"], strength.inputs[0])
            else:
                strength.inputs[0].default_value = EMISSIVE_FLOOR
            nt.links.new(tint.outputs["Vector"], b.inputs["Emission Color"])
            nt.links.new(strength.outputs["Value"], b.inputs["Emission Strength"])


def ink_material():
    m = bpy.data.materials.new("SlugshotInk")
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = INK + (1.0,)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(em.outputs["Emission"], mix.inputs[1])
    nt.links.new(tr.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return m


def ink_shell(o, width, mat):
    """Inflated copy along welded vertex normals with reversed faces: the same shell the Roblox pipeline ships."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal*width
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    me = bpy.data.meshes.new(o.name + "_Ink")
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    me.materials.append(mat)
    shell = o.copy()
    shell.data = me
    shell.name = o.name + "_Ink"
    for c in o.users_collection:
        c.objects.link(shell)
    return shell


def bounds(objs):
    lo, hi = Vector((1e9,)*3), Vector((-1e9,)*3)
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        ev = o.evaluated_get(dg)
        for v in ev.to_mesh().vertices:
            w = ev.matrix_world @ v.co
            lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo, hi


def sun(name, rot, color, strength, angle=2.0):
    s = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
    s.data.energy, s.data.color, s.data.angle = strength, color, math.radians(angle)
    s.rotation_euler = rot
    bpy.context.scene.collection.objects.link(s)
    return s


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SRC))
    scene = bpy.context.scene
    if KIND == "floppy" and bpy.data.actions:
        scene.frame_set(1)
    for o in list(scene.objects):
        if o.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(o)
    objs = [o for o in scene.objects if o.type == "MESH" and not o.hide_render]
    (style_blaster if KIND == "blaster" else style_floppy)(objs)
    ink = ink_material()
    for o in objs:
        if o.name.endswith("_Ink"):
            o.data.materials.clear()  # an exported model's own ink shell: style it, don't shell it again
            o.data.materials.append(ink)
            continue
        if any(x.name == o.name + "_Ink" for x in objs):
            continue  # the model ships its own shell for this part
        if KIND == "floppy" and o.name.startswith("Eye"):
            continue  # the ring eyes already carry their own dark rims
        key = (o.material_slots[0].material.name.split(".")[0] if o.material_slots and o.material_slots[0].material else "")
        if key == "CyanGlow":
            continue  # a thin glowing strip; an outline would swallow it
        ink_shell(o, INK_WIDTH[KIND]*(0.7 if key in THIN_PARTS else 1.0), ink)

    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            pass
    scene.eevee.taa_render_samples = 48
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    world = bpy.data.worlds.new("Cavern")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.02, 0.024, 0.05, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world

    lo, hi = bounds(objs)
    centre, size = (lo + hi)/2, (hi - lo).length
    sun("Key", (math.radians(50), 0, math.radians(-35)), (0.82, 0.88, 1.0), 4.8)
    sun("Fill", (math.radians(75), 0, math.radians(120)), (1.0, 0.62, 0.32), 0.8, angle=10)
    sun("Rim", (math.radians(60), 0, math.radians(165)), (0.62, 0.45, 1.0), 2.6)
    if KIND == "blaster":
        glow = bpy.data.objects.new("CanisterGlow", bpy.data.lights.new("CanisterGlow", "POINT"))
        glow.data.energy, glow.data.color, glow.data.shadow_soft_size = 6.0, (0.35, 0.95, 1.0), 0.05
        can = bpy.data.objects.get("CanisterTeal")
        clo, chi = bounds([can]) if can else (centre, centre)
        glow.location = (clo + chi)/2
        scene.collection.objects.link(glow)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=size*0.75, depth=0.02, location=(centre.x, centre.y, lo.z - 0.01))
        ground = bpy.context.active_object
        gm = bpy.data.materials.new("CavernFloor")
        gb = principled(gm)
        gb.inputs["Base Color"].default_value = (0.03, 0.033, 0.05, 1)
        gb.inputs["Roughness"].default_value = 0.9
        ground.data.materials.append(gm)

    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    scene.compositing_node_group = ng
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl, glare, gout = ng.nodes.new("CompositorNodeRLayers"), ng.nodes.new("CompositorNodeGlare"), ng.nodes.new("NodeGroupOutput")
    for sock, value in (("Threshold", 1.0), ("Strength", 0.6), ("Size", 0.6)):
        if sock in glare.inputs:
            try:
                glare.inputs[sock].default_value = value
            except TypeError:
                pass
    if "Type" in glare.inputs:
        try:
            glare.inputs["Type"].default_value = "Bloom"
        except (TypeError, ValueError):
            pass
    ng.links.new(rl.outputs["Image"], glare.inputs["Image"])
    ng.links.new(glare.outputs["Image"], gout.inputs[0])

    rig = bpy.data.objects.new("Orbit", None)
    rig.location = centre
    scene.collection.objects.link(rig)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    cam.parent = rig
    vfov = 2*math.atan(18*H/W/50)  # vertical field of view: the tighter one at 4:3
    dist = (size*(0.42 if KIND == "blaster" else 0.72))/math.tan(vfov/2)
    pitch = math.radians(12)
    # Frame 0: the blaster from its side (barrel to the right) turned slightly toward its muzzle; Floppy three-quarter front.
    yaw0 = math.radians(25) if KIND == "blaster" else math.radians(35)
    scene.camera = cam
    OUT.mkdir(parents=True, exist_ok=True)
    for f in range(COUNT):
        yaw = yaw0 + f*2*math.pi/FRAMES
        if KIND == "blaster":
            d = Vector((math.cos(yaw)*math.cos(pitch), math.sin(yaw)*math.cos(pitch), math.sin(pitch)))
        else:
            d = Vector((math.sin(yaw)*math.cos(pitch), math.cos(yaw)*math.cos(pitch), math.sin(pitch)))
        cam.location = d*dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT/f"{NAME}-{f:02d}.png")
        bpy.ops.render.render(write_still=True)
    print("LOOK_DONE", NAME)


main()
