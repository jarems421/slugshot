"""Generate original crystal clusters and their native-part geometry in headless Blender."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/rocklock/crystals"
SOURCE = ROOT / "assets/source/environment/rocklock-crystals-cavern"
EXPORT = ROOT / "assets/exports/environment/rocklock-crystals-cavern"

# Each shape is a distinct cluster, built as pointed pentagonal prisms.
VARIANTS = [
    ("AzureSpears", [51, 162, 220], [(7.8, 1.35, 0, 0, 0.1, 0.0), (5.0, 1.05, -1.3, 0.3, -1.1, 0.1)]),
    ("JadeFan", [62, 193, 160], [(6.3, 1.2, 0, 0, -0.8, 0), (5.7, 1.0, 1.2, 0, 1.4, 0.2), (3.2, 0.8, -1.2, 0.4, -0.8, 0.3)]),
    ("AmethystCrown", [135, 107, 210], [(6.0, 1.35, 0, 0, 0.1, 0), (4.6, 1.0, -1.4, 0, -1.4, 0), (4.4, 1.0, 1.35, 0.2, 1.25, 0)]),
    ("AmberTwin", [219, 153, 75], [(7.2, 1.45, 0, 0, -0.4, 0), (4.4, 1.0, 1.3, 0.1, 0.9, 0.2)]),
    ("FrostSpray", [102, 205, 226], [(6.7, 0.95, 0, 0, 0, 0), (5.1, 0.8, -1.1, 0, -1.7, 0), (4.0, 0.75, 1, 0, 1.5, 0.3)]),
]

# Roots sit on the walls or ceiling, leaving the floor and combat lanes clear.
PLACEMENTS = [
    ("NorthWest", 0, [-42, 20, -88.5], "north", 1), ("NorthEast", 1, [40, 22, -88.5], "north", 1),
    ("SouthWest", 1, [-38, 21, 88.5], "south", 1), ("SouthEast", 0, [43, 20, 88.5], "south", 1),
    ("WestNorth", 4, [-92.3, 22, -47], "west", 1), ("WestMid", 1, [-92.3, 23, 0], "west", 1),
    ("WestSouth", 2, [-92.3, 22, 47], "west", 1), ("EastNorth", 1, [92.3, 22, -47], "east", 1),
    ("EastMid", 0, [92.3, 23, 0], "east", 1), ("EastSouth", 4, [92.3, 22, 47], "east", 1),
    ("ArchNorth", 3, [-23.4, 23, -9.3], "north", 0.85), ("ArchSouth", 2, [23.4, 23, 9.3], "south", 0.85),
    ("UnderWest", 4, [-14.8, 3.4, -7], "west", 0.55), ("UnderEast", 1, [14.8, 3.4, 7], "east", 0.55),
    ("CeilingWest", 0, [-38, 76, -24], "ceiling", 1.1), ("CeilingEast", 4, [38, 76, 25], "ceiling", 1.1),
]

def xyz(v):
    return (v[0], -v[2], v[1])

def shard_mesh(spec):
    height, radius, ox, oz, leanx, leanz = spec
    verts = []
    for y, r, lean in [(0, 0.85, 0), (height * 0.72, 1, 0.72)]:
        for i in range(5):
            a = 2 * math.pi * i / 5 + 0.18 + 0.12*math.sin(height+i*2)
            uneven = 0.84 + 0.22 * (0.5 + 0.5*math.sin(height*2+i*4+ox))
            shoulder = height*0.06*math.sin(i*2.2+height) if lean else 0
            verts.append([ox + math.cos(a)*radius*r*uneven + leanx*lean, y+shoulder, oz + math.sin(a)*radius*r*uneven + leanz*lean])
    verts.append([ox + leanx+radius*0.15, height, oz + leanz-radius*0.08])
    faces = []
    for i in range(5):
        j = (i+1)%5
        faces.extend([[i,j,j+5], [i,j+5,i+5], [i+5,j+5,10]])
    faces.extend([[0,2,1], [0,3,2], [0,4,3]])
    return verts, faces

def main():
    for path in (OUT, SOURCE, EXPORT): path.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    variants = []
    meshes = []
    for index, (name, color, shards) in enumerate(VARIANTS):
        geometry = []
        for shard_index, spec in enumerate(shards):
            vertices, faces = shard_mesh(spec)
            geometry.append(dict(vertices=vertices, triangles=faces))
            mesh = bpy.data.meshes.new(name + str(shard_index))
            mesh.from_pydata([xyz(v) for v in vertices], [], faces)
            mesh.update()
            obj = bpy.data.objects.new(name + "_" + str(shard_index), mesh)
            bpy.context.scene.collection.objects.link(obj)
            obj.location.x = (index-2)*8
            mat = bpy.data.materials.new(name + "_material_" + str(shard_index))
            mat.diffuse_color = tuple(c/255 for c in color) + (1,)
            mat.use_nodes = True
            shader = mat.node_tree.nodes.get("Principled BSDF")
            shader.inputs["Base Color"].default_value = mat.diffuse_color
            shader.inputs["Roughness"].default_value = 0.3
            shader.inputs["Emission Color"].default_value = mat.diffuse_color
            shader.inputs["Emission Strength"].default_value = 0.3
            mesh.materials.append(mat)
            meshes.append(obj)
        variants.append(dict(name=name, color=color, shards=geometry))
    for obj in meshes: obj.select_set(True)
    fbx = EXPORT / "rocklock-crystals.fbx"
    bpy.ops.export_scene.fbx(filepath=str(fbx), use_selection=True, object_types={"MESH"}, axis_forward="-Z", axis_up="Y", global_scale=1.0, apply_unit_scale=False, apply_scale_options="FBX_SCALE_NONE", bake_anim=False, add_leaf_bones=False)
    for obj in meshes: obj.select_set(False)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(fbx), global_scale=1.0, use_anim=False)
    imported = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    assert len(imported) == len(meshes)
    assert sorted(round(v, 3) for o in imported for v in o.dimensions) == sorted(round(v, 3) for o in meshes for v in o.dimensions)
    for obj in list(set(bpy.data.objects)-before): bpy.data.objects.remove(obj, do_unlink=True)
    data = dict(variants=variants, placements=[dict(name=n, variant=VARIANTS[v][0], position=p, orientation=o, scale=s) for n,v,p,o,s in PLACEMENTS], generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), blender=bpy.app.version_string, fbx_roundtrip=dict(objects=len(meshes), dimensions_unchanged=True))
    (OUT / "geometry.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 550
    scene.render.resolution_percentage = 100
    scene.world.color = (0.12, 0.12, 0.16)
    light = bpy.data.lights.new("InspectionSoftbox", "AREA")
    light.energy, light.shape, light.size = 4500, "DISK", 25
    lamp = bpy.data.objects.new("InspectionSoftbox", light)
    scene.collection.objects.link(lamp)
    lamp.location = (0, -12, 16)
    lamp.rotation_euler = (Vector((0, 0, 3))-lamp.location).to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.cameras.new("InspectionCamera")
    camera = bpy.data.objects.new("InspectionCamera", cam)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (0, -42, 15)
    camera.rotation_euler = (Vector((0, 0, 3))-camera.location).to_track_quat("-Z", "Y").to_euler()
    cam.type, cam.ortho_scale = "ORTHO", 42
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "rocklock-crystals.blend"))
    scene.render.filepath = str(OUT / "variants.png")
    bpy.ops.render.render(write_still=True)
    report = dict(creator="Original procedural Slugshot crystal geometry", third_party_art=False, blender=bpy.app.version_string, fbx_roundtrip=data["fbx_roundtrip"], uploaded=False, source_sha256=hashlib.sha256((SOURCE / "rocklock-crystals.blend").read_bytes()).hexdigest(), export_sha256=hashlib.sha256(fbx.read_bytes()).hexdigest())
    (EXPORT / "export.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print("CRYSTALS: five variants, FBX roundtrip passed")

if __name__ == "__main__": main()
