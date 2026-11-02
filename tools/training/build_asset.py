"""Blender 5.2 asset-only arena draft. Never modifies the source lobby or uploads.

blender -b --factory-startup --python tools/training/build_asset.py -- --source C:/.../build/lobby/export
Generated .blend, GLB, texture and review renders live under ignored build/training.
One scene unit represents one Roblox stud; glTF remains Y-up with no implicit rescale.
"""
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/training"
LAYOUT = json.loads((ROOT / "assets/source/environments/training/layout.json").read_text())
RNG = random.Random(42017)
NEW = []
IMPORTS = []
SOURCE_MATERIALS = {}


def material(name, color, metal=0, rough=0.8, glow=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metal
    if glow:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = glow
    mat.diffuse_color = (*color, 1)
    return mat


def apply(obj):
    if obj.type == 'MESH' and obj.data.users > 1:
        obj.data = obj.data.copy()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def mesh(name, verts, faces, mat, collection):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    data.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    # Planar UVs are valid for the painted stone and plain prop materials.
    uv = data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = [i for i in range(3) if i != axis]
        for li in poly.loop_indices:
            co = data.vertices[data.loops[li].vertex_index].co
            uv.data[li].uv = ((co[axes[0]] + 110) / 220, (co[axes[1]] + 110) / 220)
    NEW.append(obj.name)
    return obj


def block(name, location, size, mat, collection, bevel=0.18):
    x, y, z = (v / 2 for v in size)
    verts = [(a*x, b*y, c*z) for a, b, c in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
    faces = [(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
    obj = mesh(name, verts, faces, mat, collection)
    obj.location = location
    if bevel:
        mod = obj.modifiers.new("Soft hand-built edges", "BEVEL")
        mod.width, mod.segments = min(bevel, min(size) / 4), 2
        mod.affect = "EDGES"
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)
        # Bevel produces planar n-gons; export-ready triangulation is explicit.
        bm = bmesh.new(); bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=list(bm.faces)); bm.to_mesh(obj.data); bm.free()
    return obj


def cylinder(name, location, radius, depth, mat, collection, vertices=32):
    verts = [(math.cos(a*math.tau/vertices)*radius, math.sin(a*math.tau/vertices)*radius, z) for z in [-depth/2,depth/2] for a in range(vertices)]
    faces = [tuple(reversed(range(vertices))),tuple(range(vertices,2*vertices))]
    faces += [(i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices)]
    obj = mesh(name, verts, faces, mat, collection); obj.location = location
    return obj


def text(name, words, location, size, mat, collection, rotation=(0,0,0)):
    data = bpy.data.curves.new(name, "FONT"); data.body = words
    data.align_x, data.align_y, data.size = "CENTER", "CENTER", size
    data.extrude, data.bevel_depth, data.resolution_u = 0.012, 0.002, 3
    obj = bpy.data.objects.new(name, data); collection.objects.link(obj)
    obj.location, obj.rotation_euler = location, rotation
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    bpy.ops.object.convert(target="MESH"); obj.select_set(False)
    # Letter faces are handled by Blender's font tessellator. Kept separate from collision geometry.
    return obj


def collection(name):
    col = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(col); return col


def import_asset(source, key, col, keep=None):
    path = source / key / f"{key}.glb"
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = [o for o in bpy.data.objects if o not in before]
    report = json.loads((source/key/'build.json').read_text())
    groups = {g['name']:g for g in report['groups']}
    result = []
    for obj in imported:
        original = obj.name.split(".")[0]
        if obj.type != "MESH" or (keep and original not in keep):
            bpy.data.objects.remove(obj, do_unlink=True); continue
        world = obj.matrix_world.copy(); obj.parent = None; obj.matrix_world = world
        for old in list(obj.users_collection): old.objects.unlink(obj)
        col.objects.link(obj)
        obj.name = key + "_" + original
        cache_key = (key,original)
        if cache_key not in SOURCE_MATERIALS:
            if original.endswith('_Ink'):
                mat = material(key+'_'+original,(0.008,0.009,0.013),rough=1)
            else:
                info=groups[original]
                mat=material(key+'_'+original,(1,1,1),rough=0.9)
                nodes=mat.node_tree.nodes;links=mat.node_tree.links
                bsdf=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
                color=nodes.new('ShaderNodeTexImage');color.image=bpy.data.images.load(str(source/key/info['color']),check_existing=True)
                links.new(color.outputs['Color'],bsdf.inputs['Base Color'])
                if 'normal' in info:
                    normal=nodes.new('ShaderNodeTexImage');normal.image=bpy.data.images.load(str(source/key/info['normal']),check_existing=True);normal.image.colorspace_settings.name='Non-Color'
                    convert=nodes.new('ShaderNodeNormalMap');links.new(normal.outputs['Color'],convert.inputs['Color']);links.new(convert.outputs['Normal'],bsdf.inputs['Normal'])
                if 'emit' in info:
                    emit=nodes.new('ShaderNodeTexImage');emit.image=bpy.data.images.load(str(source/key/info['emit']),check_existing=True);emit.image.colorspace_settings.name='Non-Color'
                    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
                    links.new(color.outputs['Color'],mix.inputs[1]);links.new(emit.outputs['Color'],mix.inputs[2]);links.new(mix.outputs['Color'],bsdf.inputs['Emission Color']);bsdf.inputs['Emission Strength'].default_value=info.get('emissiveStrength',0)
            mat.use_backface_culling=True
            SOURCE_MATERIALS[cache_key]=mat
        obj.data.materials.clear();obj.data.materials.append(SOURCE_MATERIALS[cache_key])
        for mat in obj.data.materials:
            if mat:
                mat.use_backface_culling = True
        result.append(obj)
    IMPORTS.append({"key":key,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"kept":[o.name for o in result]})
    return result


def transformed(obj, matrix):
    obj.matrix_world = matrix @ obj.matrix_world
    apply(obj)


def target(name, x, y, z, col, mats, yaw=0):
    ink, stone, orange, pale, teal = mats
    home = Matrix.Translation((x,y,z)) @ Matrix.Rotation(yaw,4,'Z')
    pieces = []
    pieces.append(cylinder(name+"_Foot", (0,0,0.16), 2.4, 0.32, ink, col))
    for xx in [-0.55,0.55]:
        pieces.append(block(name+"_Leg", (xx,0,1.15), (0.72,0.8,1.8), stone,col,0.1))
    pieces.append(block(name+"_Body", (0,0,3.0), (2.35,1.1,2.0), orange,col,0.25))
    pieces.append(block(name+"_Head", (0,0,4.75), (1.5,1.1,1.35), pale,col,0.25))
    for xx in [-1.65,1.65]:
        pieces.append(block(name+"_Arm", (xx,0,3.05), (0.65,0.85,1.75), stone,col,0.16))
    for radius, mat in [(0.76,ink),(0.56,pale),(0.25,teal)]:
        disc = cylinder(name+"_Bullseye", (0,-0.59-(0.76-radius)*0.06,3.0), radius,0.035,mat,col)
        disc.rotation_euler[0]=math.pi/2; pieces.append(disc)
    for obj in pieces: transformed(obj,home)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--renders',action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.source=args.source.resolve()
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene; scene.unit_settings.system='NONE'; scene.unit_settings.scale_length=1
    island=collection('ISLAND'); rubble=collection('DEBRIS'); props=collection('TRAINING'); walls=collection('ROOM'); presentation=collection('PRESENTATION')
    ink=material('Ink charcoal',(0.022,0.028,0.035),rough=0.95)
    stone=material('Quiet blue grey stone',(0.18,0.205,0.205),rough=0.92)
    orange=material('Warm terracotta enamel',(0.44,0.19,0.085),metal=0.12,rough=0.55)
    pale=material('Warm bone lettering',(0.73,0.76,0.65),rough=0.8)
    teal=material('Focused teal accent',(0.15,0.48,0.43),rough=0.5,glow=0.3)
    wallmat=material('Deep cavern shell',(0.055,0.07,0.078),rough=1)
    metal=material('Course graphite',(0.055,0.075,0.085),metal=0.25,rough=0.65)
    s=LAYOUT['island_scale']
    body=import_asset(args.source,'hub-rock',island,{'Upper','Lower','Upper_Ink','Lower_Ink'})
    for obj in body: transformed(obj,Matrix.Diagonal((s,s,s,1)))
    # An original, fully closed cap follows the source rim but contains no grooves.
    rim=json.loads((ROOT/'experiments/lobby/scale/shared/rim_shape.json').read_text())['rock']
    count=len(rim); points=[]
    for i,r in enumerate(rim):
        # The reference's +Z maps to Blender -Y.
        a=i*math.tau/count; points.append((math.sin(a)*r*s,math.cos(a)*r*s))
    verts=[(0,0,0.5)]+[(x,y,0.5) for x,y in points]+[(x,y,-1.5) for x,y in points]+[(0,0,-1.5)]
    faces=[]
    for i in range(count):
        j=(i+1)%count
        faces.extend([(0,1+i,1+j),(1+i,1+count+i,1+count+j,1+j),(len(verts)-1,1+count+j,1+count+i)])
    cap=mesh('ISLAND_UnbrokenTop',verts,faces,stone,island)
    # Baked, subtle variation; no procedural nodes that disappear on glTF export.
    dim=1024; yy,xx=np.mgrid[:dim,:dim]/dim
    rng=np.random.default_rng(617)
    variation=0.018*np.sin(xx*19+np.sin(yy*10)*2)+0.012*np.cos(yy*27)+rng.normal(0,0.003,(dim,dim))
    pixels=np.ones((dim,dim,4),dtype='f4')
    for i,base in enumerate([0.185,0.209,0.197]): pixels[:,:,i]=np.clip(base+variation,0,1)
    image=bpy.data.images.new('Training slate paint',width=dim,height=dim,alpha=False)
    image.pixels.foreach_set(pixels.ravel());image.filepath_raw=str(OUT/'training-stone.png');image.file_format='PNG';image.save();image.pack()
    node=stone.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
    shader=next(n for n in stone.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    stone.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
    # A denser cloud below the island, reused from the approved original rubble.
    originals=import_asset(args.source,'hub-rock-debris',rubble)
    templates=[o for o in originals]
    for k in range(LAYOUT['debris_copies']):
        a=k*math.tau/LAYOUT['debris_copies']+0.15
        scale=RNG.uniform(0.75,1.22)
        transform=Matrix.Translation((math.cos(a)*38,math.sin(a)*38,-32-k*3.3)) @ Matrix.Rotation(a,4,'Z') @ Matrix.Diagonal((scale,scale,scale,1))
        for src in templates:
            obj=src.copy();obj.data=src.data;obj.name=f'DEBRIS_{k:02d}_{src.name}';rubble.objects.link(obj)
            transformed(obj,transform)
    for obj in originals: bpy.data.objects.remove(obj,do_unlink=True)
    # Open firing lanes on the right, independent movement loop on the left.
    block('RANGE_FiringLine',(24,-52,0.56),(58,0.3,0.08),teal,props,0)
    for index,d in enumerate(LAYOUT['target_distances']):
        y=-52+d; x=[10,30,5,37,13,27][index]
        target(f'TARGET_{d:03d}',x,y,0.5,props,(ink,stone,orange,pale,teal))
        block(f'RANGE_Mark_{d}',(24,y,0.55),(46,0.16,0.06),teal,props,0)
        text(f'LABEL_{d}',f'{d} STUDS',(49,y,0.62),1.35,pale,props)
    block('TARGET_RaisedBase',(55,22,5.5),(10,10,10),stone,props,0.6)
    target('TARGET_ELEVATED',55,22,10.5,props,(ink,stone,orange,pale,teal))
    target('TARGET_STRAFE',44,-7,0.5,props,(ink,stone,orange,pale,teal))
    block('RANGE_StrafeTrack',(44,-7,0.56),(22,0.35,0.1),metal,props,0)
    # At asset-review stage these are static examples, not pretend running mechanics.
    for i in range(3):
        h=2.6+i*0.8
        block(f'COURSE_Vault_{i}',(-40,-27+i*13,h/2+0.5),(15,2.8,h),stone,props,0.35)
        block(f'COURSE_VaultStripe_{i}',(-40,-27+i*13,h+0.53),(13,1.5,0.09),orange,props,0)
    for i in range(4):
        h=2+i*2
        block(f'COURSE_Jump_{i}',(-43+(i%2)*12,19+i*11,h/2+0.5),(8,8,h),stone,props,0.35)
        block(f'COURSE_JumpCap_{i}',(-43+(i%2)*12,19+i*11,h+0.55),(7.4,7.4,0.1),teal,props,0)
    for x,y,length in [(-65,7,70),(-19,16,38)]:
        block('COURSE_WallRun',(x,y,9.5),(2.8,length,18),stone,props,0.45)
        block('COURSE_WallRunBand',(x,y,11.7),(2.9,length-1,0.35),teal,props,0)
    for x in [-48,-32]: block('COURSE_SlidePost',(x,-43,3.5),(1.6,3,6),metal,props,0.2)
    block('COURSE_SlideLintel',(-40,-43,6.3),(18,3.5,1.5),orange,props,0.3)
    text('LABEL_Movement','MOVEMENT',(-41,-57,0.65),3,pale,props)
    text('LABEL_Range','OPEN RANGE',(22,-63,0.65),3,pale,props)
    text('LABEL_Training','TRAINING',(-2,-73,0.65),4.3,pale,props)
    # Low chunky equipment console; future all-slug selector belongs here.
    block('STATION_Base',(-2,-62,1.5),(7,4,2),metal,props,0.4)
    block('STATION_Console',(-2,-62,3.0),(7,3.6,1.2),orange,props,0.3)
    for i in range(5): cylinder(f'STATION_SlugSocket_{i}',(-4.6+i*1.3,-62,3.7),0.48,0.12,teal,props,24)
    # Continuous distant room, backed by a watertight shell. Only source Rock groups are reused:
    # no enormous mushrooms, roots, hero crystals, doorway, well, or spiral.
    radius=LAYOUT['room_radius_studs']; ceiling=LAYOUT['ceiling_height_studs']
    for i in range(16):
        a=i*math.tau/16
        key=f'rock-wall-{4+i%4}'
        pieces=import_asset(args.source,key,walls,{'Rock','Rock_Ink'})
        pts=[o.matrix_world@Vector(v) for o in pieces if not o.name.endswith('_Ink') for v in o.bound_box]
        lo=Vector(tuple(min(v[j] for v in pts) for j in range(3)));hi=Vector(tuple(max(v[j] for v in pts) for j in range(3)))
        center=(lo+hi)/2;scale=390/(hi.z-lo.z)
        # Source wall faces Blender -Y. Rotate its front inward.
        transform=Matrix.Translation((math.sin(a)*radius,math.cos(a)*radius,10)) @ Matrix.Rotation(-a,4,'Z') @ Matrix.Diagonal((scale,scale,scale,1)) @ Matrix.Translation(-center)
        for obj in pieces:
            obj.name=f'ROOM_Wall_{i:02d}_{obj.name}';transformed(obj,transform)
    # The ceiling is closed in the delivered asset; inspection controls can hide it.
    block('ROOM_CeilingShell',(0,0,ceiling+10),(700,700,20),wallmat,walls,0)
    block('ROOM_Bottom',(0,0,-225),(700,700,20),wallmat,walls,0)
    # Ceiling tiles use the same stone wall design, turned inward/downward, without a sky opening.
    for i,(x,y) in enumerate(( (x,y) for x in [-225,0,225] for y in [-225,0,225] )):
        pieces=import_asset(args.source,f'rock-wall-{4+i%4}',walls,{'Rock','Rock_Ink'})
        pts=[o.matrix_world@Vector(v) for o in pieces if not o.name.endswith('_Ink') for v in o.bound_box]
        lo=Vector(tuple(min(v[j] for v in pts) for j in range(3)));hi=Vector(tuple(max(v[j] for v in pts) for j in range(3)))
        scale=260/(hi.z-lo.z);center=(lo+hi)/2
        transform=Matrix.Translation((x,y,ceiling)) @ Matrix.Rotation(math.pi/2,4,'X') @ Matrix.Diagonal((scale,scale,scale,1)) @ Matrix.Translation(-center)
        for obj in pieces:obj.name=f'ROOM_Ceiling_{i:02d}_{obj.name}';transformed(obj,transform)
    # Backing plates seal gaps even where a natural wall silhouette is concave.
    for i in range(16):
        a=i*math.tau/16
        obj=block(f'ROOM_Shell_{i:02d}',(math.sin(a)*(radius+25),math.cos(a)*(radius+25),-5),(150,25,440),wallmat,walls,0)
        obj.rotation_euler.z=-a;apply(obj)
    # Review rendering. No edits to any running Blender session.
    scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1500;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.world.color=(0.18,0.2,0.23)
    world=scene.world;world.use_nodes=True
    next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs['Color'].default_value=(0.18,0.21,0.26,1)
    next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value=0.7
    scene.view_settings.view_transform='AgX'
    for name,loc,power,size,color in [('Key',(-80,-130,130),240000,180,(1,0.9,0.75)),('Fill',(95,25,110),180000,150,(0.7,0.86,1)),('Rim',(-30,100,45),170000,90,(0.5,0.8,0.85))]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
        obj=bpy.data.objects.new(name,data);presentation.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,0,-10))-obj.location).to_track_quat('-Z','Y').to_euler()
    camdata=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',camdata);presentation.objects.link(cam);scene.camera=cam;camdata.clip_end=2500
    poses={'island':((210,-290,180),(0,0,-12),48),'underside':((210,-270,-65),(0,0,-34),50),'above':((0,-65,285),(0,0,0),48),'inside':((3,-76,8),(2,30,7),23)}
    # Save with an exterior inspection camera and room hidden in the viewport; render/export can restore it.
    for obj in walls.objects:obj.hide_set(True)
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=330;area.spaces.active.region_3d.view_location=(0,0,-15)
    cam.location=poses['island'][0];cam.rotation_euler=(Vector(poses['island'][1])-cam.location).to_track_quat('-Z','Y').to_euler();camdata.lens=48
    scene['asset_status']='Owner inspection draft: static layout; no gameplay or new asset upload.'
    scene['units']='1 unit = 1 Roblox stud; Blender Z up; glTF Y up.'
    for image in bpy.data.images:
        if image.source=='FILE':image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'SlugshotTrainingArena.blend'))
    for obj in walls.objects:obj.hide_set(False)
    # Export full asset, including ceiling. Punctual lights/camera are omitted from asset geometry.
    for obj in scene.objects:obj.select_set(obj.type=='MESH')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'slugshot-training-arena.glb'),export_format='GLB',use_selection=True,export_apply=True,export_extras=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    if args.renders:
        for name,(loc,aim,lens) in poses.items():
            for obj in walls.objects:obj.hide_render=name!='inside'
            cam.location=loc;cam.rotation_euler=(Vector(aim)-cam.location).to_track_quat('-Z','Y').to_euler();camdata.lens=lens
            scene.render.filepath=str(OUT/f'{name}.png');bpy.ops.render.render(write_still=True)
    # QA selected authored components. Imported split meshes and deliberate inverse ink shells are catalogued separately.
    sys.path.insert(0,str(Path.home()/'.agents/skills/el4cteo-blender-asset-qa/scripts'))
    import qa_check
    # Logical assemblies deliberately touch/intersect and floating rubble is intentional. Run per component
    # to catch actual topology/normal/UV errors without treating the arena's void as an assembly fault.
    qa=[]
    for name in NEW:
        report=qa_check.run(objects=[name],profile='game',max_tris=50000)
        qa.append({'object':name,'pass':report['pass'],'errors':report['errors'],'warnings':report['warnings']})
    (OUT/'qa.json').write_text(json.dumps(qa,indent=2))
    for obj in scene.objects:
        if obj.type == 'MESH': obj.data.calc_loop_triangles()
    metrics={'blender':bpy.app.version_string,'units':'1 scene unit = 1 Roblox stud','imports':IMPORTS,'new_components':len(NEW),'qa_errors':[q for q in qa if not q['pass']],'objects':len([o for o in scene.objects if o.type=='MESH']),'triangles':sum(len(o.data.loop_triangles) for o in scene.objects if o.type=='MESH'),'glb_bytes':(OUT/'slugshot-training-arena.glb').stat().st_size,'limits':['Static owner-review asset; no gameplay or runtime collision proof.','Imported source art has intentional split boundaries and inverse ink shells.','Debris is intentionally detached; wall shell/tile overlaps are intentional.']}
    (OUT/'build-report.json').write_text(json.dumps(metrics,indent=2))
    print('TRAINING_ASSET',json.dumps({k:v for k,v in metrics.items() if k!='imports'}),flush=True)
    if metrics['qa_errors']:raise RuntimeError('Authored component QA errors; inspect qa.json')


if __name__=='__main__': main()
