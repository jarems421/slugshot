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
color = body.data.color_attributes.get("Color")
assert color is not None and color.domain == "POINT", "Body needs painted vertex colours"
quadrants = [0, 0, 0, 0]
for vertex, sample in zip(body.data.vertices, color.data):
    if sample.color[1] - sample.color[0] > .18:
        angle = math.atan2(vertex.co.y + .04, vertex.co.x) % math.tau
        quadrants[min(3, int(angle / (math.pi / 2)))] += 1
assert all(value > 5 for value in quadrants), f"Green markings missing around body: {quadrants}"
names = set(obj.name for obj in bpy.context.scene.objects)
assert "tiny-tail" in names and not any("foot" in name.lower() or "base-lobe" in name for name in names), "Expected a tiny tail and no feet"
tail = bpy.data.objects["tiny-tail"]
tail_back = min(v.co.y for v in tail.data.vertices)
body_back = min(v.co.y for v in body.data.vertices)
assert 0 < body_back - tail_back < .25, "Tail must protrude less than a quarter unit behind the body"
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
print("PASS: idle, uneven blink, hop, squash, surface eyes, tiny tail, all-around spots and FBX vertex colours")
