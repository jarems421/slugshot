"""Mouth bones for a slug whose mouth is painted into its body texture (owner, 2026-11-16: "a lot of the slugs don't have
... any mouth movement at all ... It makes them look very stationary and static in the face").

Adds three bones under `head`: `mouth_L` and `mouth_R` at the corners (L is the slug's left, +x) and `mouth_low` at the
middle of the lower lip, each weighted to the skin round it with a soft falloff, so moving them bends the painted mouth:
corners up for a smile, one corner for a smirk, the lower lip down and forward for a pout or a little mouthing. The
mesh's other weights give way by the same share, so weights stay normalised and nothing else moves.

Points are concept coordinates (x across, y up, z toward the face) of the mouth's corners and lower lip; each is put
on the front of the actual mesh (the front-most vertex at that x and y), so the caller needs only the drawing's numbers.
Call on the game mesh in source Blender coordinates ((x, -z, y)), after its rig exists and before it is skinned.
SlugIdle drives the bones (experiments/combat/client/SlugIdle.luau).
"""
import bpy
import numpy as np
from mathutils import Vector

BONES = ("mouth_L", "mouth_R", "mouth_low")


def add(obj, rig, points, radius, parent="head"):
    """points: {bone: (x, y)} in concept units; radius: the falloff's reach in concept units. Returns the bone names."""
    count = len(obj.data.vertices)
    co = np.empty(count*3)
    obj.data.vertices.foreach_get("co", co)
    b = co.reshape(-1, 3)
    c = np.stack([b[:, 0], b[:, 2], -b[:, 1]], 1)  # concept
    targets = {}
    for name, (x, y) in points.items():
        near = (np.abs(c[:, 0] - x) < 0.04) & (np.abs(c[:, 1] - y) < 0.04)
        assert near.any(), f"no mesh at the {name} point {(x, y)}"
        targets[name] = np.array([x, y, c[near, 2].max()])
    front = min(t[2] for t in targets.values()) - 0.15
    weights = {}
    for name, t in targets.items():
        d = np.linalg.norm(c - t, axis=1)
        weights[name] = np.where(c[:, 2] > front, np.exp(-(d/radius)**2), 0.0)
    total = sum(weights.values())
    scale = np.where(total > 0.9, 0.9/np.maximum(total, 1e-9), 1.0)
    for name in weights:
        weights[name] *= scale
    keep = 1.0 - np.minimum(total, 0.9)
    # Existing groups give way by the mouth's share.
    for v in obj.data.vertices:
        if keep[v.index] < 1.0:
            for g in v.groups:
                g.weight *= keep[v.index]
    for name, w in weights.items():
        group = obj.vertex_groups.new(name=name)
        for i in np.nonzero(w > 1e-3)[0]:
            group.add([int(i)], float(w[i]), "REPLACE")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    head = rig.data.edit_bones[parent]
    for name, t in targets.items():
        bone = rig.data.edit_bones.new(name)
        bone.head = Vector((t[0], -t[2], t[1]))
        bone.tail = Vector((t[0], -t[2], t[1] + 0.05))
        bone.parent = head
    bpy.ops.object.mode_set(mode="OBJECT")
    print("mouth bones", {n: [round(float(v), 3) for v in t] for n, t in targets.items()},
          "weighted vertices", int((total > 1e-3).sum()))
    return list(BONES)
