"""Render an original clip's key table from OriginalClips.luau on the R6 block rig.

The Luau file stays the only source of the poses: this reads a literal key table
(`local name: { Key } = { { t = ..., Joint = { x, y, z }, ... }, ... }`), samples it
with the game's Hermite curves and draws a contact sheet. Tables built by helper
functions (the run, flips, jump) are not literal and cannot be previewed this way.

Mantles can be placed on the client's root path against a ledge, printing where the
hands and feet are relative to the ledge top and face at each sampled time:
  python tools/r6pose/preview.py mantleHigh --ledge 4.5
  python tools/r6pose/preview.py mantleVault --ledge 4.5 --start 3
  python tools/r6pose/preview.py kongVault --vault 3 --depth 1.6
  python tools/r6pose/preview.py stand --times 0 1.2 2.4 3.6 --loop 7.2
Output goes to build/r6pose/<table>.png (ignored). Needs numpy and matplotlib.
"""
import argparse
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
import r6render as r6  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CLIPS = ROOT / "experiments/movement/shared/OriginalClips.luau"
JOINTS = ("Waist", "Neck", "LeftHip", "RightHip", "LeftShoulder", "RightShoulder",
          "LeftElbow", "RightElbow", "LeftKnee", "RightKnee")
r6.COLOURS.update({"Left Arm": "#d96a5a", "Right Arm": "#5a8fd9", "Left Leg": "#2f6b3a",
                   "Right Leg": "#27324a", "Wall": "#b9a88a"})


def read_table(name):
    """The keys of `local <name>: { Key } = {...}` as dicts of numbers and number lists."""
    text = CLIPS.read_text(encoding="utf-8")
    start = re.search(r"^local " + re.escape(name) + r": \{ Key \} =\s*\{", text, re.M)
    if not start:
        raise SystemExit(f"no literal key table named {name} in {CLIPS.name}")
    begin, depth, body = start.end() - 1, 0, ""
    for index in range(begin, len(text)):
        depth += {"{": 1, "}": -1}.get(text[index], 0)
        if depth == 0:
            body = re.sub(r"--[^\n]*", "", text[begin + 1:index])
            break
    if "(" in body:
        raise SystemExit(f"{name} is built by helper functions, not a literal table")
    entries, depth, open_at = [], 0, 0
    for index, char in enumerate(body):
        if char == "{":
            depth += 1
            if depth == 1:
                open_at = index
        elif char == "}":
            depth -= 1
            if depth == 0:
                entries.append(body[open_at + 1:index])
    keys = []
    for entry in entries:
        key = {}
        for field, values in re.findall(r"(\w+) = \{([^}]*)\}", entry):
            key[field] = [float(v) for v in values.split(",") if v.strip()]
        for field, value in re.findall(r"(\w+) = (-?[0-9.]+)\s*,", entry):
            key[field] = float(value)
        keys.append(key)
    return sorted(keys, key=lambda k: k["t"])


def hermite(times, values, t, loop=None):
    """OriginalClips' sampler: Catmull-Rom tangents, flat ends unless looped."""
    n = len(times)

    def at(i):
        if loop:
            return times[i % n] + (i // n) * loop, values[i % n]
        k = max(0, min(n - 1, i))
        return times[k], values[k]

    if loop:
        t %= loop
    i = 0
    while i < n - 1 and times[i + 1] <= t:
        i += 1
    if not loop and i == n - 1:
        return values[-1]
    t0, v0 = at(i)
    t1, v1 = at(i + 1)
    tp, vp = at(i - 1)
    tn, vn = at(i + 2)
    m0 = (v1 - vp) / (t1 - tp) if loop or i > 0 else 0
    m1 = (vn - v0) / (tn - t0) if loop or i + 1 < n - 1 else 0
    h = t1 - t0
    s = (t - t0) / h
    return ((2 * s**3 - 3 * s**2 + 1) * v0 + (s**3 - 2 * s**2 + s) * h * m0
            + (-2 * s**3 + 3 * s**2) * v1 + (s**3 - s**2) * h * m1)


def channel(keys, t, field, index=None, loop=None):
    times = [k["t"] for k in keys]
    if index is None:
        values = [k.get(field, 0.0) for k in keys]
    else:
        values = [k.get(field, [0.0, 0.0, 0.0])[index] for k in keys]
    return hermite(times, values, t, loop)


def place(keys, t, args):
    """Frames of the rig at time t: on the floor, or on the client's mantle path."""
    def vector(field):
        return [channel(keys, t, field, i, args.loop) for i in range(3)]

    pose = {"Root": r6.CF(r6.angles(*vector("Root")), [0, vector("RootPos")[1] * r6.UNIT, 0])}
    for joint in JOINTS:
        if any(joint in k for k in keys):
            pose[joint] = r6.R(r6.angles(*vector(joint)))
    on_path = args.ledge is not None or args.vault is not None
    frames = r6.solve(r6.to_r6(pose), lift=not on_path)
    advance, rise = channel(keys, t, "advance"), channel(keys, t, "rise")
    if args.vault is not None:
        # Client: (to - from) * advance + lift * rise; the wall face is at z = -0.8.
        start = np.array([0.0, r6.STAND, args.approach - 0.8])
        target = np.array([0.0, r6.STAND, -(0.8 + args.depth + 2.4)])
        position = start + (target - start) * advance + np.array([0, (args.vault + 0.7) * rise, 0])
    elif args.ledge is not None:
        # Client: rises with the clip from 0.8 off the face to 1.52 past the edge on top.
        start_y = r6.STAND + args.start
        target = np.array([0.0, args.ledge + r6.STAND + 0.12, -(0.8 + 1.52)])
        position = np.array([0.0, start_y + (target[1] - start_y) * rise, target[2] * advance])
    else:
        return frames, advance, rise
    shift = r6.T(position - np.array([0, r6.STAND, 0]))
    return {name: shift * frame for name, frame in frames.items()}, advance, rise


def tip(frame):
    return frame.p + frame.r @ np.array([0, -1.0, 0])


def offsets(points, measure):
    return "/".join(f"{measure(p):+.2f}" for p in points)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("table", help="literal key table name in OriginalClips.luau")
    parser.add_argument("--times", type=float, nargs="*", help="times to draw (default: keys and midpoints)")
    parser.add_argument("--loop", type=float, help="loop duration, for looping clips")
    parser.add_argument("--ledge", type=float, help="mantle onto a ledge this high")
    parser.add_argument("--start", type=float, default=0.0, help="mantle start height above the floor")
    parser.add_argument("--vault", type=float, help="vault over a wall this high")
    parser.add_argument("--depth", type=float, default=1.6, help="vault wall thickness")
    parser.add_argument("--approach", type=float, default=2.0, help="vault start distance from the wall")
    parser.add_argument("--out", type=Path, help="output image")
    args = parser.parse_args()
    keys = read_table(args.table)
    stamps = [k["t"] for k in keys]
    times = args.times or sorted(set(stamps + [(a + b) / 2 for a, b in zip(stamps, stamps[1:])]))
    beside = args.ledge is not None or args.vault is not None
    views = [(6, 180, "side")] if beside else [(8, 60, "front-left"), (6, 180, "side")]
    fig = plt.figure(figsize=(len(times) * 2.2, len(views) * 2.7))
    for column, t in enumerate(times):
        frames, advance, rise = place(keys, t, args)
        line = f"t={t:.2f}"
        if beside:
            height = args.vault if args.vault is not None else args.ledge
            depth = args.depth if args.vault is not None else 6
            r6.SIZES["Wall"] = (5, height, depth)
            frames["Wall"] = r6.T([0, height / 2, -(0.8 + depth / 2)])
            hands = [tip(frames[n]) for n in ("Left Arm", "Right Arm")]
            feet = [tip(frames[n]) for n in ("Left Leg", "Right Leg")]
            line += (f" advance={advance:.2f} rise={rise:.2f}"
                     f" hands above top {offsets(hands, lambda p: p[1] - height)}"
                     f" past face {offsets(hands, lambda p: -(p[2] + 0.8))}"
                     f" | feet above top {offsets(feet, lambda p: p[1] - height)}")
        print(line)
        for row, (elev, azim, label) in enumerate(views):
            ax = fig.add_subplot(len(views), len(times), row * len(times) + column + 1, projection="3d")
            r6.draw(ax, frames, elev, azim, f"{args.table} {label} {t:.2f}")
            if beside:
                ax.set_xlim(-3.5, 3.5)
                ax.set_ylim(-4.5, 4.5)
                ax.set_zlim(-0.2, 9.0)
                ax.set_box_aspect((7, 9, 9.2), zoom=1.25)
            else:
                ax.set_box_aspect((1, 1, 1), zoom=1.3)
    out = args.out or ROOT / "build/r6pose" / f"{args.table}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out, dpi=60)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
