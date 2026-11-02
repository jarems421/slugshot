"""Run in Blender with the generated .blend: topology contact sheets + GLB reimport.
This is offline evidence, not a claim of imported Roblox rendering or collisions.
"""
import json
import inspect
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/training'


def stats():
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    points=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
    for obj in meshes:obj.data.calc_loop_triangles()
    return {'objects':len(meshes),'triangles':sum(len(o.data.loop_triangles) for o in meshes),
            'min':[min(v[i] for v in points) for i in range(3)],'max':[max(v[i] for v in points) for i in range(3)],
            'room_parts':sum(o.name.startswith('ROOM_') for o in meshes),
            'missing_materials':[o.name for o in meshes if not o.data.materials]}


before=stats()
sys.path.insert(0,str(Path.home()/'.agents/skills/el4cteo-blender-asset-qa/scripts'))
import review_shots
objects=[o.name for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('ROOM_')]
review_shots.run(objects=objects,out=str(OUT/'qa-random.png'),mode='random',views=['front','bottom','top','three_quarter'],res=512)
# The generic tool scales wire width to the full arena bounds. That gives tiny,
# skinny distance-mark triangles enormous miter spikes. Keep the installed skill
# unchanged and adapt only this review invocation for a thin, non-mitered wire.
wire_source=inspect.getsource(review_shots.run)
wire_source=wire_source.replace('wire_t = _bounds(obs)[1] * 0.006','wire_t = 0.015')
wire_source=wire_source.replace('w.color = (0, 0, 0, 1)', 'w.modifiers["QA_Wire"].use_even_offset = False\n                w.color = (0, 0, 0, 1)')
scope=dict(vars(review_shots));exec(wire_source,scope)
scope['run'](objects=objects,out=str(OUT/'qa-wire.png'),mode='wire',views=['front','bottom','top','three_quarter'],res=512)
# Selection excludes objects hidden for the initial inspection view. Clear datablocks
# explicitly in this disposable process so the reimport cannot retain the hidden room.
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'slugshot-training-arena.glb'))
after=stats()
assert before['objects']==after['objects'],(before['objects'],after['objects'])
assert before['triangles']==after['triangles']
assert before['room_parts']==after['room_parts'] and after['room_parts']>20
assert not after['missing_materials'],after['missing_materials']
error=max(abs(a-b) for key in ['min','max'] for a,b in zip(before[key],after[key]))
assert error<0.005,error
result={'pass':True,'before':before,'after':after,'max_bounds_error_studs':error,
        'limits':'Offline Blender-to-GLB roundtrip only. Not Studio playback, collisions, performance or owner approval.'}
(OUT/'roundtrip.json').write_text(json.dumps(result,indent=2))
print('TRAINING_ROUNDTRIP',json.dumps(result))
