"""Solid-block R6 renderer for checking original clip poses without Studio.

Poses use the game's R15 joint names and are converted exactly like
Presentation.toR6 (with FoldLimbs' chord for two-segment limbs), then posed on the
lab's R6 rig: standard R6 Motor6D pivots, with the hips moved out by
Config.Avatar.LegSpread. Roblox axes: +Y up, the character faces -Z.
Needs numpy and matplotlib (development only; not part of the game or verify).
"""
import math
import re
from pathlib import Path

import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

CONFIG = Path(__file__).resolve().parents[2] / "experiments/movement/shared/Config.luau"
_spread = re.search(r"LegSpread = ([0-9.]+)", CONFIG.read_text(encoding="utf-8"))
LEG_SPREAD = float(_spread.group(1)) if _spread else 0.0  # Config.Avatar.LegSpread

# R6 parts: size, colour. Joint: parent, C0 position (parent space), C1 position (child space).
SIZES = {
    "Torso": (2, 2, 1), "Head": (1.2, 1.2, 1.2), "Left Arm": (1, 2, 1), "Right Arm": (1, 2, 1),
    "Left Leg": (1, 2, 1), "Right Leg": (1, 2, 1),
}
COLOURS = {
    "Torso": "#e9edf2", "Head": "#f2d7b6", "Left Arm": "#d5dde6", "Right Arm": "#d5dde6",
    "Left Leg": "#27324a", "Right Leg": "#27324a",
}
JOINTS = {  # child: (joint name, parent, c0, c1)
    "Head": ("Neck", "Torso", (0, 1, 0), (0, -0.5, 0)),
    "Left Arm": ("Left Shoulder", "Torso", (-1, 0.5, 0), (0.5, 0.5, 0)),
    "Right Arm": ("Right Shoulder", "Torso", (1, 0.5, 0), (-0.5, 0.5, 0)),
    "Left Leg": ("Left Hip", "Torso", (-1 - LEG_SPREAD, -1, 0), (-0.5, 1, 0)),
    "Right Leg": ("Right Hip", "Torso", (1 + LEG_SPREAD, -1, 0), (0.5, 1, 0)),
}
HIPS, WAIST = np.array([0, -1.0, 0]), np.array([0, -0.6, 0])
STAND = 3.0  # root centre above the floor
UNIT = 2.0  # hip unit on R6 (leg length)


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def angles(x, y, z):  # CFrame.Angles, degrees
    return rx(math.radians(x)) @ ry(math.radians(y)) @ rz(math.radians(z))


def quat(x, y, z, w):
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


class CF:
    def __init__(self, r=None, p=None):
        self.r = np.eye(3) if r is None else r
        self.p = np.zeros(3) if p is None else np.asarray(p, float)

    def __mul__(self, o):
        return CF(self.r @ o.r, self.r @ o.p + self.p)


def T(p):
    return CF(None, p)


def R(m):
    return CF(m)


def about(rot, point):
    return T(point) * R(rot) * T(-point)


FOLD = (("LeftShoulder", "LeftElbow"), ("RightShoulder", "RightElbow"), ("LeftHip", "LeftKnee"), ("RightHip", "RightKnee"))
FOLDING = True


def chord(upper, lower):
    """Aim a two-segment limb as one block from its root to its end (equal segments),
    keeping the upper segment's twist. Mirrors Presentation.chord."""
    down = np.array([0, -1.0, 0])
    along = upper @ down
    target = along + upper @ lower @ down
    if np.linalg.norm(target) < 1e-6:
        return upper
    target /= np.linalg.norm(target)
    axis = np.cross(along, target)
    if np.linalg.norm(axis) < 1e-9:
        return upper
    axis /= np.linalg.norm(axis)
    angle = math.acos(max(-1.0, min(1.0, float(np.dot(along, target)))))
    k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    rot = np.eye(3) + math.sin(angle) * k + (1 - math.cos(angle)) * k @ k
    return rot @ upper


def to_r6(pose):
    """pose: R15 joint -> CF (Root carries position in studs). Mirrors Presentation.toR6."""
    if FOLDING:
        pose = dict(pose)
        for upper, lower in FOLD:
            if upper in pose and lower in pose:
                pose[upper] = R(chord(pose[upper].r, pose[lower].r))
    root = pose.get("Root", CF())
    waist = pose.get("Waist", CF()).r
    out = {
        "RootJoint": T(root.p) * about(root.r, HIPS) * about(waist, WAIST),
        "Neck": pose.get("Neck", CF()),
        "Left Shoulder": pose.get("LeftShoulder", CF()),
        "Right Shoulder": pose.get("RightShoulder", CF()),
        "Left Hip": R(waist.T @ pose.get("LeftHip", CF()).r),
        "Right Hip": R(waist.T @ pose.get("RightHip", CF()).r),
    }
    return out


def solve(r6, lift=True):
    """World frames for each part; feet pushed up out of the floor (never pulled down)."""
    frames = {"Torso": T([0, STAND, 0]) * r6["RootJoint"]}
    for child, (joint, parent, c0, c1) in JOINTS.items():
        frames[child] = frames[parent] * T(c0) * r6[joint] * T(-np.array(c1, float))
    if lift:
        low = min(corners(frames[n], SIZES[n])[:, 1].min() for n in ("Left Leg", "Right Leg"))
        if low < 0:
            frames = {k: T([0, -low, 0]) * v for k, v in frames.items()}
    return frames


def corners(frame, size):
    hx, hy, hz = (s / 2 for s in size)
    pts = np.array([[sx * hx, sy * hy, sz * hz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)])
    return pts @ frame.r.T + frame.p


FACES = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]


def draw(ax, frames, elev, azim, title=None):
    polys, colours = [], []
    light = np.array([0.4, 0.8, -0.45])
    light /= np.linalg.norm(light)
    for name, frame in frames.items():
        c = corners(frame, SIZES[name])
        base = np.array([int(COLOURS[name][i:i + 2], 16) / 255 for i in (1, 3, 5)])
        centre = c.mean(axis=0)
        for face in FACES:
            quad = c[list(face)]
            normal = np.cross(quad[1] - quad[0], quad[2] - quad[0])
            normal /= np.linalg.norm(normal) or 1
            if np.dot(normal, quad.mean(axis=0) - centre) < 0:
                normal = -normal
            shade = 0.55 + 0.45 * max(0.0, float(np.dot(normal, light)))
            polys.append([(x, -z, y) for x, y, z in quad])  # to matplotlib axes (Z up)
            colours.append(np.clip(base * shade, 0, 1))
    coll = Poly3DCollection(polys, facecolors=colours, edgecolors="#111111", linewidths=0.6)
    ax.add_collection3d(coll)
    ax.plot([-3, 3, 3, -3, -3], [-3, -3, 3, 3, -3], [0, 0, 0, 0, 0], color="#7fbf7f", lw=0.6)
    ax.set_xlim(-2.6, 2.6)
    ax.set_ylim(-2.6, 2.6)
    ax.set_zlim(0.2, 5.4)
    ax.set_box_aspect((1, 1, 1))
    ax.view_init(elev=elev, azim=azim)
    ax.set_proj_type("ortho")
    ax.axis("off")
    if title:
        ax.set_title(title, fontsize=8)
