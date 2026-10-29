"""Retarget privately downloaded Mixamo FBX clips onto the R15 rig as compact Luau data.

Run inside Blender (portable is fine; nothing is installed):

    blender --background --factory-startup --python tools/mixamo_to_r15.py -- \
        --input private-assets/mixamo --manifest tools/mixamo_manifest.json \
        --output private-assets/generated/MovementClips.luau

Mixamo files and the generated module are restricted (no redistribution of raw
animation data) and must stay in ignored private storage. This script contains no
animation data itself.

Method: every R15 part rests axis-aligned, and its joints' C0/C1 are pure
translations. A part's pose is therefore the source bone's world-rotation delta from
a reference pose matching R15 rest (arms down, legs straight), converted into Roblox
character space (+Y up, facing -Z). Translations are normalized by rest hip height so
the runtime can scale them to any R15 proportion.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

PARTS = {
    "LowerTorso": "Hips",
    "UpperTorso": "Spine2",
    "Head": "Head",
    "LeftUpperArm": "LeftArm",
    "LeftLowerArm": "LeftForeArm",
    "LeftHand": "LeftHand",
    "RightUpperArm": "RightArm",
    "RightLowerArm": "RightForeArm",
    "RightHand": "RightHand",
    "LeftUpperLeg": "LeftUpLeg",
    "LeftLowerLeg": "LeftLeg",
    "LeftFoot": "LeftFoot",
    "RightUpperLeg": "RightUpLeg",
    "RightLowerLeg": "RightLeg",
    "RightFoot": "RightFoot",
}
# R15 joint name -> (parent part, child part).
JOINTS = {
    "Root": (None, "LowerTorso"),
    "Waist": ("LowerTorso", "UpperTorso"),
    "Neck": ("UpperTorso", "Head"),
    "LeftShoulder": ("UpperTorso", "LeftUpperArm"),
    "LeftElbow": ("LeftUpperArm", "LeftLowerArm"),
    "LeftWrist": ("LeftLowerArm", "LeftHand"),
    "RightShoulder": ("UpperTorso", "RightUpperArm"),
    "RightElbow": ("RightUpperArm", "RightLowerArm"),
    "RightWrist": ("RightLowerArm", "RightHand"),
    "LeftHip": ("LowerTorso", "LeftUpperLeg"),
    "LeftKnee": ("LeftUpperLeg", "LeftLowerLeg"),
    "LeftAnkle": ("LeftLowerLeg", "LeftFoot"),
    "RightHip": ("LowerTorso", "RightUpperLeg"),
    "RightKnee": ("RightUpperLeg", "RightLowerLeg"),
    "RightAnkle": ("RightLowerLeg", "RightFoot"),
}
CHAINS = {
    "LeftArm": ("LeftArm", "LeftHand", ["LeftArm", "LeftForeArm", "LeftHand"]),
    "RightArm": ("RightArm", "RightHand", ["RightArm", "RightForeArm", "RightHand"]),
    "LeftLeg": ("LeftUpLeg", "LeftFoot", ["LeftUpLeg", "LeftLeg", "LeftFoot"]),
    "RightLeg": ("RightUpLeg", "RightFoot", ["RightUpLeg", "RightLeg", "RightFoot"]),
}
FEET = ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]
CONTACT = 0.06  # Floor clearance, in hip units, that counts as airborne.
MIRROR = Matrix(((-1, 0, 0), (0, 1, 0), (0, 0, 1)))


def short(name):
    return name.split(":")[-1]


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=False, ignore_leaf_bones=False)
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    bones = {short(b.name): b.name for b in armature.data.bones}
    missing = [b for b in list(PARTS.values()) + FEET if b not in bones]
    if missing:
        raise SystemExit(f"{path.name}: missing Mixamo bones {missing}")
    scene = bpy.context.scene
    fps = scene.render.fps / scene.render.fps_base
    action = armature.animation_data.action if armature.animation_data else None
    if action is None:
        raise SystemExit(f"{path.name}: no animation")
    start, end = (int(round(x)) for x in action.frame_range)
    return armature, bones, fps, start, end


def rest_frame(armature, bones):
    """Character basis and reference rotations from the FBX rest (bind) pose."""
    world = armature.matrix_world
    head = {n: world @ armature.data.bones[full].head_local for n, full in bones.items()}
    tail = {n: world @ armature.data.bones[full].tail_local for n, full in bones.items()}
    rot = {n: (world @ armature.data.bones[full].matrix_local).to_3x3().normalized() for n, full in bones.items()}
    up = (head["Head"] - head["Hips"]).normalized()
    left = head["LeftUpLeg"] - head["RightUpLeg"]
    left = (left - up * left.dot(up)).normalized()
    forward = left.cross(up).normalized()
    toes = (head["LeftToeBase"] - head["LeftFoot"]).normalized()
    if toes.dot(forward) <= 0.3:
        raise SystemExit("Could not establish character facing from rest pose")
    right = -left
    back = -forward
    to_roblox = Matrix((tuple(right), tuple(up), tuple(back)))
    floor = min(min(head[n].dot(up) for n in FEET), min(tail[n].dot(up) for n in FEET))
    hip_height = head["Hips"].dot(up) - floor
    reference = dict(rot)
    for first, last, members in CHAINS.values():
        direction = (head[last] - head[first]).normalized()
        align = direction.rotation_difference(-up).to_matrix()
        for member in members:
            reference[member] = align @ rot[member]
    feet_rest = {n: head[n].dot(up) - floor for n in FEET}
    return to_roblox, up, floor, hip_height, reference, head["Hips"], feet_rest


def capture(path, spec):
    armature, bones, fps, start, end = load(path)
    to_roblox, up, floor, unit, reference, hips_rest, feet_rest = rest_frame(armature, bones)
    world = armature.matrix_world
    inverse = to_roblox.transposed()
    # Self-test: the bind-pose (T-pose) left arm must map to R15 character-left (-X).
    rest_arm = armature.data.bones[bones["LeftArm"]].matrix_local
    rest_arm = to_roblox @ ((world @ rest_arm).to_3x3().normalized() @ reference["LeftArm"].inverted()) @ inverse
    check = rest_arm @ Vector((0, -1, 0))
    if check.x > -0.9:
        raise SystemExit(f"{path.name}: retarget basis failed self-test, T-pose left arm -> {tuple(check)}")
    frames = []
    for frame in range(start, end + 1):
        bpy.context.scene.frame_set(frame)
        pose = armature.pose.bones
        parts = {}
        for part, bone in PARTS.items():
            matrix = (world @ pose[bones[bone]].matrix).to_3x3().normalized()
            parts[part] = to_roblox @ (matrix @ reference[bone].inverted()) @ inverse
        hips = world @ pose[bones["Hips"]].head
        feet = {}
        for name in FEET:
            point = world @ pose[bones[name]].head
            feet[name] = (to_roblox @ (point - hips_rest), point.dot(up) - floor - feet_rest[name])
        frames.append({"parts": parts, "hips": (to_roblox @ (hips - hips_rest)) / unit, "feet": feet})
    trim = spec.get("trim")
    if trim:
        first = max(0, int(round(trim[0] * fps)))
        last = min(len(frames), int(round(trim[1] * fps)) + 1) if trim[1] else len(frames)
        frames = frames[first:last]
    if spec.get("loop") and len(frames) > 2:
        drift = max(
            frames[0]["parts"][p].to_quaternion().rotation_difference(frames[-1]["parts"][p].to_quaternion()).angle
            for p in PARTS
        )
        if drift < math.radians(4):
            frames.pop()  # Mixamo loops repeat the first pose at the end.
    return frames, fps, unit


def yaw_of(matrix):
    facing = matrix @ Vector((0, 0, -1))
    return math.atan2(-facing.x, -facing.z)


def normalize_yaw(frames, align_end):
    # Mixamo exports every clip facing its world forward, which the rest-pose basis
    # already maps to R15 forward; the pelvis turns during strafes and stances, so
    # it is not a facing reference. Turn clips are rotated by their net turn so they
    # end facing forward, matching a root that has already turned.
    if not align_end:
        return
    yaw = yaw_of(frames[-1]["parts"]["LowerTorso"]) - yaw_of(frames[0]["parts"]["LowerTorso"])
    fix = Matrix.Rotation(-yaw, 3, "Y")
    for f in frames:
        f["parts"] = {k: fix @ v for k, v in f["parts"].items()}
        f["hips"] = fix @ f["hips"]
        f["feet"] = {k: (fix @ v[0], v[1]) for k, v in f["feet"].items()}


def mirror(frames):
    swap = lambda name: name.replace("Left", "\0").replace("Right", "Left").replace("\0", "Right")
    out = []
    for f in frames:
        parts = {swap(k): MIRROR @ v @ MIRROR for k, v in f["parts"].items()}
        feet = {swap(k): (MIRROR @ v[0], v[1]) for k, v in f["feet"].items()}
        out.append({"parts": parts, "hips": MIRROR @ f["hips"], "feet": feet})
    return out


STYLE_JOINTS = {"legs": ("LeftHip", "RightHip"), "arms": ("LeftShoulder", "RightShoulder")}


def mean_rotation(quats):
    total = Quaternion((0, 0, 0, 0))
    for q in quats:
        if q.dot(quats[0]) < 0:
            q = -q
        total = Quaternion([a + b for a, b in zip(total, q)])
    return total.normalized()


def scale_about(mean, q, factor):
    """q's rotation away from mean, scaled by factor (above 1 widens the swing)."""
    rel = mean.inverted() @ q
    if rel.w < 0:
        rel = -rel
    axis, angle = rel.to_axis_angle()
    return mean @ Quaternion(axis, angle * factor)


def stylize(quats, spec):
    """Optional pose styling: "amplitude" scales the hip ("legs") and shoulder ("arms")
    swing about the clip's mean pose; "elbows" scales the elbow bend (0 straight)."""
    for group, factor in spec.get("amplitude", {}).items():
        for joint in STYLE_JOINTS[group]:
            mean = mean_rotation(quats[joint])
            quats[joint] = [scale_about(mean, q, factor) for q in quats[joint]]
    if "elbows" in spec:
        for joint in ("LeftElbow", "RightElbow"):
            quats[joint] = [Quaternion().slerp(q, spec["elbows"]) for q in quats[joint]]


def floor_curve(frames):
    return [min(f["feet"][n][1] for n in FEET) for f in frames]


def air_segment(frames, unit):
    floor = [h / unit for h in floor_curve(frames)]
    best, run_start = None, None
    for i, h in enumerate(floor + [0]):
        if h > CONTACT and run_start is None:
            run_start = i
        elif h <= CONTACT and run_start is not None:
            if best is None or i - run_start > best[1] - best[0]:
                best = (run_start, i)
            run_start = None
    return best


def loop_analysis(frames, fps, unit):
    def height(i, foot):
        return f_h[foot][i]

    f_h = {foot: [f["feet"][foot][1] / unit for f in frames] for foot in ("LeftFoot", "RightFoot")}
    n = len(frames)
    contact = None
    for i in range(n):
        if f_h["LeftFoot"][i - 1] > CONTACT * 0.5 >= f_h["LeftFoot"][i]:
            contact = i
            break
    if contact is None:
        contact = min(range(n), key=lambda i: height(i, "LeftFoot"))
    speeds = []
    for foot in ("LeftFoot", "RightFoot"):
        lowest = sorted(f_h[foot])[: max(2, n // 3)]
        limit = lowest[-1]
        for i in range(n):
            if f_h[foot][i] <= limit:
                a, b = frames[i - 1]["feet"][foot][0], frames[i]["feet"][foot][0]
                speeds.append(math.hypot(b.x - a.x, b.z - a.z) * fps / unit)
    speeds.sort()
    speed = speeds[len(speeds) // 2] if speeds else 0
    return contact, speed


def build(name, frames, fps, unit, spec):
    loop = bool(spec.get("loop"))
    events = {}
    motion = None
    direction = (0, -1)
    hips = [f["hips"].copy() for f in frames]
    drift = None
    if loop and len(hips) > 2:
        # Loops downloaded without In Place travel: remove the steady drift (least
        # squares) and use it as the clip's natural speed.
        n = len(hips)
        mean_i = (n - 1) / 2
        denom = sum((i - mean_i) ** 2 for i in range(n))
        slope = Vector((
            sum((i - mean_i) * h.x for i, h in enumerate(hips)) / denom,
            0,
            sum((i - mean_i) * h.z for i, h in enumerate(hips)) / denom,
        ))
        if slope.length * fps > 0.3:
            drift = slope
            centre_x = sum(h.x for h in hips) / n
            centre_z = sum(h.z for h in hips) / n
            for i, h in enumerate(hips):
                h.x -= slope.x * (i - mean_i) + centre_x
                h.z -= slope.z * (i - mean_i) + centre_z
    if loop:
        contact, speed = loop_analysis(frames, fps, unit)
        if drift is not None:
            speed = drift.length * fps  # planted feet do not slide in travelling clips
        frames = frames[contact:] + frames[:contact]
        hips = hips[contact:] + hips[:contact]
        if spec.get("idle"):
            speed = 0
    else:
        speed = 0
    if spec.get("rootMotion") or spec.get("air"):
        origin = hips[0].copy()
        motion = [(h.x - origin.x, h.z - origin.z) for h in hips]
        net = Vector((motion[-1][0], 0, motion[-1][1]))
        if net.length > 0.05:
            net.normalize()
            direction = (net.x, net.z)
        for h in hips:
            h.x, h.z = 0.0, 0.0
    if drift is not None:
        direction = (drift.x / drift.length, drift.z / drift.length)
    climb = None
    if spec.get("traversal") or spec.get("vault"):
        # The controller moves the root along the ledge; keep the clip's own path
        # as normalized progress (over, up) and remove it from the hips. A vault
        # goes over and back down: up is its peak lift, and dips below the start
        # (the landing crouch) stay in the hips.
        origin = hips[0].copy()
        over = Vector((hips[-1].x - origin.x, 0, hips[-1].z - origin.z))
        up = max(h.y for h in hips) - origin.y if spec.get("vault") else hips[-1].y - origin.y
        if over.length < 0.05 or up < 0.05:
            raise SystemExit(f"{name}: traversal clip must move forward and up (got {over.length:.2f}, {up:.2f})")
        heading = over.normalized()
        climb = []
        for h in hips:
            offset = Vector((h.x - origin.x, 0, h.z - origin.z))
            advance, rise = offset.dot(heading) / over.length, (h.y - origin.y) / up
            if spec.get("vault"):
                lift = max(rise, 0.0)
                climb += [round(advance, 4), round(lift, 4)]
                h.x, h.y, h.z = 0.0, origin.y + (h.y - origin.y) - lift * up, 0.0
            else:
                climb += [round(advance, 4), round(rise, 4)]
                h.x, h.y, h.z = 0.0, origin.y * (1 - rise), 0.0  # starting crouch fades out
    elif not loop and not motion:
        # One-shot clips (starts, stops, turns, landings, reactions) play on the
        # physics root, so their own travel is removed.
        for h in hips:
            h.x, h.z = 0.0, 0.0
    segment = air_segment(frames, unit) if spec.get("air") else None
    if segment:
        takeoff, land = segment
        events["takeoff"] = takeoff / fps
        events["land"] = land / fps
        apex = max(range(takeoff, land), key=lambda i: hips[i].y)
        events["apex"] = apex / fps
        if spec.get("air"):
            # Physics supplies the ballistic arc; keep only the hips' motion relative to it.
            y0, y1 = hips[takeoff].y, hips[min(land, len(hips) - 1)].y
            span = max(1, land - takeoff)
            s = [(i - takeoff) / span for i in range(takeoff, land)]
            base = [y0 + (y1 - y0) * x for x in s]
            shape = [x * (1 - x) for x in s]
            num = sum((hips[i].y - base[k]) * shape[k] for k, i in enumerate(range(takeoff, land)))
            den = sum(v * v for v in shape) or 1
            curve = num / den
            for k, i in enumerate(range(takeoff, land)):
                hips[i].y -= curve * shape[k]
    elif not loop and not climb and not motion:
        floor = [h / unit for h in floor_curve(frames)]
        if floor[0] > CONTACT:
            events["contact"] = next((i for i, h in enumerate(floor) if h <= CONTACT), 0) / fps
    if motion and spec.get("rootMotion"):
        speeds = [math.hypot(motion[i][0] - motion[i - 1][0], motion[i][1] - motion[i - 1][1]) * fps for i in range(1, len(motion))]
        peak = max(range(len(speeds)), key=lambda i: speeds[i])
        settle = next((i for i in range(peak, len(speeds)) if speeds[i] < speeds[peak] * 0.2), None)
        low = min(range(len(hips)), key=lambda i: hips[i].y)
        rise = next((i for i in range(low, len(hips)) if hips[i].y > -0.15), len(hips) - 1)
        # Rolls that run out never settle: they recover once the hips are back up.
        events["recover"] = (rise if settle is None else max(settle, rise)) / fps
    quats = {}
    for joint, (parent, child) in JOINTS.items():
        quats[joint] = [
            (f["parts"][child] if parent is None else f["parts"][parent].transposed() @ f["parts"][child]).to_quaternion()
            for f in frames
        ]
    stylize(quats, spec)
    if loop and speed:
        speed *= spec.get("amplitude", {}).get("legs", 1)  # a wider stride covers more ground
    joints = {}
    for joint, values in quats.items():
        out = []
        for i, q in enumerate(values):
            if joint == "Root":
                out += [round(hips[i].x, 4), round(hips[i].y, 4), round(hips[i].z, 4)]
            out += [round(q.x, 4), round(q.y, 4), round(q.z, 4), round(q.w, 4)]
        joints[joint] = out
    data = {
        "fps": fps,
        "frames": len(frames),
        "loop": loop,
        "speed": round(speed, 4),
        "direction": [round(direction[0], 4), round(direction[1], 4)],
        "events": {k: round(v, 4) for k, v in events.items()},
        "floor": [round(h / unit, 4) for h in floor_curve(frames)],
        "joints": joints,
    }
    if spec.get("rootMotion"):
        data["contact"] = "body"
    elif not spec.get("air") and not climb and name.split(".")[0] != "Fall":
        data["contact"] = "feet"
    if motion:
        data["motion"] = [round(v, 4) for pair in motion for v in pair]
    if climb:
        data["climb"] = climb
    return data


def lua(value, indent=""):
    if isinstance(value, dict):
        inner = indent + "\t"
        items = [f"{inner}{k} = {lua(v, inner)}," if k.isidentifier() else f'{inner}["{k}"] = {lua(v, inner)},' for k, v in value.items()]
        return "{\n" + "\n".join(items) + "\n" + indent + "}"
    if isinstance(value, list):
        return "{ " + ", ".join(lua(v, indent) for v in value) + " }"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return repr(round(value, 4))
    return str(value)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    clips, report = {}, {}
    for name, spec in manifest["clips"].items():
        path = args.input / spec["file"]
        if not path.exists():
            report[name] = "missing"
            continue
        frames, fps, unit = capture(path, spec)
        normalize_yaw(frames, bool(spec.get("alignEnd")))
        if spec.get("mirrored"):
            frames = mirror(frames)
        variants = [(name, frames)]
        if spec.get("mirror"):
            variants.append((spec["mirror"], mirror(frames)))
        for variant, data in variants:
            clips[variant] = build(variant, data, fps, unit, spec)
            info = {k: clips[variant][k] for k in ("fps", "frames", "speed", "direction", "events")}
            info["source"] = spec["file"]
            report[variant] = info
    if not clips:
        print(json.dumps(report, indent=2))
        raise SystemExit("No clips converted; output left unchanged")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    header = "-- Generated by tools/mixamo_to_r15.py from privately downloaded Mixamo clips.\n-- Restricted: never commit, publish or redistribute this file.\n"
    args.output.write_text(header + "return " + lua(clips) + "\n", encoding="utf-8")
    text = json.dumps(report, indent=2)
    if args.report:
        args.report.write_text(text, encoding="utf-8")
    print(text)


main()
