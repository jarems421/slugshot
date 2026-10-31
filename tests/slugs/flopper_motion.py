"""Check that the first draft's meaningful motion survives in its saved source."""
from pathlib import Path

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
print("PASS: first slug idle breathing, uneven blink, hop and impact squash")
