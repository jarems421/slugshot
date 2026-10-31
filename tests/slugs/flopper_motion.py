"""Check that the first draft's meaningful motion survives in its saved source."""
from pathlib import Path
import math

import bpy

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "assets/source/slugs/models/flopper-inspired/protoform.blend"))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")


def pose(action, frame):
    rig.animation_data.action = bpy.data.actions[action]
    bpy.context.scene.frame_set(frame)
    return rig.pose.bones


idle = pose("Idle", 13)
assert abs(idle["body_upper"].scale.y - 1) > 0.02, "Idle should visibly breathe"
idle = pose("Idle", 27)
assert idle["eye_left"].scale.y < idle["eye_right"].scale.y - 0.1, "Idle blink must be offset between eyes"
hop = pose("Hop", 13)
assert hop["root"].location.y > 0.3, "Hop should lift the rig"
impact = pose("Impact", 13)
assert impact["root"].scale.y < 0.65, "Impact should squash vertically"
assert impact["root"].scale.x > 1.2, "Impact should spread horizontally"
pose("Idle", 1)
body = bpy.data.objects["SoftBody"]
assert body.get("integrated_antennae"), "Antennae must grow from the body skin"
adjacent = [[] for _ in body.data.vertices]
for edge in body.data.edges:
    a,b = edge.vertices
    adjacent[a].append(b)
    adjacent[b].append(a)
visited, pending = set(), [0]
while pending:
    index = pending.pop()
    if index in visited:
        continue
    visited.add(index)
    pending.extend(other for other in adjacent[index] if other not in visited)
assert len(visited) == len(body.data.vertices), "Head, tail and antennae must be one connected skin"
for side,sign in (("left",-1),("right",1)):
    group = body.vertex_groups["feelers_"+side].index
    antenna = [v for v in body.data.vertices if any(g.group == group and g.weight > .35 for g in v.groups)]
    tips = [v for v in antenna if v.co.y > .35]
    assert tips and max(v.co.z for v in antenna)-min(v.co.z for v in tips) > .15, f"{side} antenna should droop downward"
    assert sum(v.co.y for v in tips)/len(tips) > .4, f"{side} antenna should curl a little forward"
color = body.data.color_attributes.get("Color")
assert color is not None and color.domain == "POINT", "Body needs painted vertex colours"
quadrants = [0, 0, 0, 0]
for vertex, sample in zip(body.data.vertices, color.data):
    if sample.color[1] - sample.color[0] > .18:
        angle = math.atan2(vertex.co.y + .04, vertex.co.x) % math.tau
        quadrants[min(3, int(angle / (math.pi / 2)))] += 1
assert all(value > 5 for value in quadrants), f"Green markings missing around body: {quadrants}"
names = set(obj.name for obj in bpy.context.scene.objects)
assert body.get("integrated_tail") and "tiny-tail" not in names, "Tail must extend from the continuous body"
assert not any("foot" in name.lower() or "base-lobe" in name for name in names), "No feet"
contact = [v for v in body.data.vertices if abs(v.co.z) < .0001]
assert len(contact) > 100, "Soft body needs a broad flat contact patch"
assert max(v.co.x for v in contact)-min(v.co.x for v in contact) > 1.3, "Contact should spread across the base"
assert max(v.co.y for v in contact)-min(v.co.y for v in contact) > .9, "Contact must be broad in depth too"
main_rear = min(v.co.y for v in body.data.vertices if .5 < v.co.z < .8)
tail_tip = min(v.co.y for v in body.data.vertices)
assert .1 < main_rear-tail_tip < .45, "Tail must stay a short extension of the body"
tail_vertices = [v for v in body.data.vertices if v.co.y < main_rear-.15]
assert tail_vertices and max(v.co.z for v in tail_vertices) < .23, "Tail must be a low soft wedge"
for action, frame in (("Idle",1),("Idle",13),("Idle",27),("Impact",13)):
    pose(action, frame)
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    assert max(abs(evaluated.data.vertices[v.index].co.z) for v in contact) < .003, f"{action}: sole must stay relaxed on the ground"
pose("Idle",1)
for name in ("eye-left", "eye-right"):
    eye = bpy.data.objects[name]
    for vertex in list(eye.data.vertices)[::20]:
        hit, point, _normal, _face = body.ray_cast((vertex.co.x, 4, vertex.co.z), (0, -1, 0))
        assert hit and 0 <= vertex.co.y - point.y < .016, f"{name} must follow the head surface"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT / "build/slugs/flopper-inspired/exports/protoform/model.fbx"), automatic_bone_orientation=False)
imported = bpy.data.objects["SoftBody"]
assert imported.data.color_attributes, "FBX roundtrip lost the body colours"
colors = imported.data.color_attributes[0].data
assert max(sample.color[1] - sample.color[0] for sample in colors) > .18, "FBX roundtrip lost green markings"
print("PASS: idle, blink, hop, grounded squash, connected drooping antennae, surface eyes, integrated tail, spots and FBX colours")
