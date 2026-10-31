"""Numerical gesture review, using the shipped Luau keys and R6 block rig.

Mesh bounds are optional private input, rendered as boxes rather than final art.
This does not execute Roblox or prove Studio playback/skin compatibility.
"""
import argparse
import json
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

import r6render as rig

ROOT = Path(__file__).resolve().parents[2]


def tracks(path):
    source = path.read_text(encoding="utf-8")
    result = {}
    for name in ("Draw", "Holster"):
        body = re.search(rf"Motion\.{name} = \{{(.*?)\n\}}", source, re.S)[1]
        result[name] = np.array([
            [float(v) for v in row.split(",") if v.strip()]
            for row in re.findall(r"\{([^{}]+)\}", body)
        ])
    return result


def sample(track, time):
    i = min(len(track) - 2, max(0, np.searchsorted(track[:, 0], time, side="left") - 1))
    first, last = track[i], track[i + 1]
    before, after = track[max(0, i - 1)], track[min(len(track) - 1, i + 2)]
    duration = last[0] - first[0]
    x = np.clip((time - first[0]) / duration, 0, 1)
    m0 = 0 if i == 0 else (last[1:] - before[1:]) / (last[0] - before[0]) * duration
    m1 = 0 if i + 1 == len(track) - 1 else (after[1:] - first[1:]) / (after[0] - first[0]) * duration
    value = ((2*x**3 - 3*x*x + 1)*first[1:] + (x**3 - 2*x*x + x)*m0
             + (-2*x**3 + 3*x*x)*last[1:] + (x**3 - x*x)*m1)
    return np.clip(value, np.minimum(first[1:], last[1:]), np.maximum(first[1:], last[1:]))


def inverse(frame):
    return rig.CF(frame.r.T, -frame.r.T @ frame.p)


def pose(values):
    idle = {joint: rig.CF() for joint, *_ in rig.JOINTS.values()}
    idle["RootJoint"] = rig.CF()
    # Existing Rocklock Gunslinger carry, independent of transient gesture.
    idle["Right Shoulder"] = rig.R(rig.angles(*values[3:6]) @ rig.rx(.7) @ rig.ry(.14) @ rig.rz(-.08))
    frames = rig.solve(idle)
    hand = frames["Right Arm"] * rig.T([0, -1, 0]) * rig.R(rig.rx(-np.pi/2)) * rig.R(rig.rx(.32))
    grip = rig.T([0, -np.sin(.2)*.14, -np.cos(.2)*.14]) * rig.R(rig.rx(-.2))
    gun = hand * rig.R(rig.angles(*values[:3])) * inverse(grip)
    return frames, hand, gun, grip


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--motion", type=Path, default=ROOT / "experiments/creatures/floppy/client/BlasterMotion.luau")
    parser.add_argument("--mesh-specs", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "build/blaster-motion")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    data = tracks(args.motion)
    specs = json.loads(args.mesh_specs.read_text()) if args.mesh_specs else []
    report = {"scope": "Numerical R6 Gunslinger approximation; mesh bounds only; not Roblox execution", "tracks": {}}
    fig = plt.figure(figsize=(16, 8))
    for row, (name, track) in enumerate(data.items()):
        assert np.all(np.diff(track[:, 0]) > 0)
        assert track[-1, 0] <= .45
        assert np.max(np.abs(track[:, 1:7])) < 180
        maximum_error = 0
        for time in np.linspace(0, track[-1, 0], 1001):
            value = sample(track, time)
            _, hand, gun, grip = pose(value)
            maximum_error = max(maximum_error, float(np.linalg.norm((gun * grip).p - hand.p)))
            assert 0 <= value[6] <= 1
        assert maximum_error < 1e-12
        for fps in (30, 60, 144):
            assert np.allclose(sample(track, np.ceil(track[-1, 0]*fps)/fps), track[-1, 1:])
        if name == "Draw":
            assert np.allclose(sample(track, 10), [0, 0, 0, 0, 0, 0, 1])
        else:
            assert sample(track, .27)[-1] == 0
            assert np.allclose(sample(track, 10)[3:6], 0)
        report["tracks"][name] = {"seconds": track[-1, 0], "palm_error_studs": maximum_error,
                                  "sampled_poses": 1001, "terminal_sampling_fps": [30, 60, 144]}
        for col, time in enumerate(track[:, 0]):
            value = sample(track, time)
            frames, hand, gun, _ = pose(value)
            ax = fig.add_subplot(2, 5, row*5 + col + 1, projection="3d")
            rig.draw(ax, frames, 14, -56, f"{name} {time:.2f}s | visibility {value[6]:.0%}")
            for spec in specs:
                scale = np.array([1.5625, 1.25, 1.25])*.88
                corners = rig.corners(gun * rig.T(np.array(spec["centre"])*scale), np.array(spec["size"])*scale)
                polygons = [[(x, -z, y) for x, y, z in corners[list(face)]] for face in rig.FACES]
                ax.add_collection3d(Poly3DCollection(polygons, facecolors="#"+spec["color"],
                    alpha=max(.08, value[6])*.7, edgecolors="#202631", linewidths=.25))
            point = hand.p
            ax.scatter([point[0]], [-point[2]], [point[1]], color="#f23265", s=12)
    fig.suptitle("Original draw / holster — R6 pose and gun BOUNDS review (not final mesh or Studio playback)")
    fig.tight_layout()
    fig.savefig(args.output / "r6-contact-sheet.png", dpi=150)
    (args.output / "numerical-report.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
