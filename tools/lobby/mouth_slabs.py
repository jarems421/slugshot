"""Lay out the big cut slabs framing the far side's cave mouth (owner, 2026-11-06: slabs where the glowing vines were).

Spaces the slabs evenly round the mouth's arch (fcArch in the library's far cave: half width 28, top 37, exponent 2.4, in
concept units of 5 studs), each standing out from the arch along its own direction, and measures the cavern wall's real
surface behind each one (build/lobby/meshes/hub-cavern-01..03), so the slab is set flush into the rock, standing proud of
it by the same amount all round. Prints the table for FC_SLABS in docs/art/asset-library.html and the bounds for the
hub-mouth-slabs piece in tools/lobby/hub_mesh.py, and writes the slabs to build/lobby/mouth_slabs.json, from which
tools/lobby/far_side_sites.py keeps the wall's crystals and dressing out of them.

    python tools/lobby/mouth_slabs.py
"""
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from far_side_sites import surface  # noqa: E402

HALF, TOP, EXP = 28.0, 37.0, 2.4
# Long and short slabs in turn, out from the arch; each about this wide along it, with a clean joint between.
LONG, SHORT, WIDE, JOINT = 8.6, 6.8, 6.4, 0.45
# Each slab's face stands this far in front of the nearest rock behind it (the wall's own ring of blocks round the arch
# included, which it covers), and it reaches at least this far into the wall.
PROUD, SUNK = 1.2, 3.0
# The lining inside the mouth (owner, 2026-11-06: slabs outlining the inside of the mouth as well, to look cleaner): a slab
# against the tunnel's rock behind each slab of the frame, joints in line, starting just behind the frame's face and
# running this deep into the cave, this thick, standing this far out of the rock into the opening. Seeds from 500 up mark
# them, so the paint keeps its face cracks to the frame.
DEPTH_IN, THICK_IN, PROUD_IN = 8.0, 1.6, 0.8


def outline(t):
    c, s = math.cos(t), math.sin(t)
    return np.array([HALF*math.copysign(abs(c)**(2.0/EXP), c), TOP*abs(s)**(2.0/EXP)])


def arch(x, y):
    """fcArch: negative inside the opening."""
    u, v = abs(x), max(y, 0.0)
    e = ((u/HALF)**EXP + (v/TOP)**EXP)**(1.0/EXP)
    return (e - 1.0)*min(HALF, TOP)*0.8


def main():
    ts = np.linspace(0.0, math.pi, 4001)
    pts = np.array([outline(t) for t in ts])
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    run = np.concatenate([[0.0], np.cumsum(seg)])
    total = run[-1]
    count = int(round(total/(WIDE + JOINT)))
    pitch = total/count
    cs, ns = [], []
    for key in ("hub-cavern-01", "hub-cavern-02", "hub-cavern-03"):
        c, n = surface(key)
        keep = (c[:, 2] > 35.0) & (np.abs(c[:, 0]) < 52.0) & (c[:, 1] > -4.0) & (c[:, 1] < 50.0)
        cs.append(c[keep])
        ns.append(n[keep])
    rock, normals = np.concatenate(cs), np.concatenate(ns)
    radial = np.hypot(rock[:, 0], rock[:, 2])
    facing = -(normals[:, 0]*rock[:, 0] + normals[:, 2]*rock[:, 2])/np.maximum(radial, 1e-6)
    rows = []
    for i in range(count):
        s = (i + 0.5)*pitch
        k = int(np.searchsorted(run, s))
        a, b = pts[max(k - 1, 0)], pts[min(k + 1, len(pts) - 1)]
        along = (b - a)/np.linalg.norm(b - a)
        out = np.array([along[1], -along[0]])
        if out @ pts[k] < 0.0:
            out = -out
        length = LONG if i % 2 == 0 else SHORT
        width = pitch - JOINT
        # The two at the foot reach down into the floor, so neither stands on nothing.
        foot = 0.9 if i in (0, count - 1) else 0.0
        # The inner end sits just outside the opening; pushed out until no corner of its face reaches into it.
        push = 0.15
        while True:
            centre = pts[k] + out*(length/2.0 + push) - np.array([0.0, foot])
            corners = [centre + out*sx*length/2.0 + along*sy*(width/2.0 + foot) for sx in (-1, 1) for sy in (-1, 1)]
            if min(arch(x, y) for x, y in corners) > 0.12 or push > 3.0:
                break
            push += 0.1
        # The wall behind the slab: the nearest rock facing the hub within its outline, and the wall's usual surface.
        theta = math.atan2(centre[0], 56.0)
        rel_x = rock[:, 0] - centre[0]
        rel_y = rock[:, 1] - centre[1]
        lx = rel_x*math.cos(theta)  # near enough: the slab's own axes in the wall's plane
        u = lx*out[0] + rel_y*out[1]
        v = lx*along[0] + rel_y*along[1]
        near = (np.abs(u) < length/2.0) & (np.abs(v) < width/2.0) & (facing > 0.2) & (radial < 64.0) & (radial > 44.0)
        nearest = float(np.percentile(radial[near], 3)) if near.sum() > 20 else 56.0
        face = float(np.percentile(radial[near], 30)) if near.sum() > 20 else 58.0
        front, back = nearest - PROUD, max(face + SUNK, nearest - PROUD + 4.6)
        depth_mid = (front + back)/2.0
        z = math.sqrt(max(depth_mid**2 - centre[0]**2, 1.0))
        yaw = math.atan2(centre[0], z)
        roll = math.atan2(out[1], out[0])
        if roll > math.pi/2.0:
            roll -= math.pi
        if roll < -math.pi/2.0:
            roll += math.pi
        seed = 17.0 + 7.3*i
        tilt = 0.05*math.sin(i*2.7 + 1.0)
        rows.append(((centre[0], centre[1], z, yaw), (roll, tilt, 0.04*math.cos(i*1.9), seed),
                     (length/2.0, width/2.0 + foot, (back - front)/2.0, face), int(near.sum())))
    # The lining: the tunnel through the wall runs straight along z, its sides near 26.5 units out and its roof near 36.5.
    hall, hall_n = surface("hub-cave-hall")
    keep = (hall[:, 2] > 35.0) & (np.abs(hall[:, 0]) < 52.0) & (hall[:, 1] > -4.0) & (hall[:, 1] < 50.0)
    tunnel, tunnel_n = np.concatenate([rock, hall[keep]]), np.concatenate([normals, hall_n[keep]])
    for i in range(count):
        s = (i + 0.5)*pitch
        k = int(np.searchsorted(run, s))
        a, b = pts[max(k - 1, 0)], pts[min(k + 1, len(pts) - 1)]
        along = (b - a)/np.linalg.norm(b - a)
        out = np.array([along[1], -along[0]])
        if out @ pts[k] < 0.0:
            out = -out
        width = pitch - JOINT
        foot = 0.9 if i in (0, count - 1) else 0.0
        frame_z, frame_half = rows[i][0][2], rows[i][2][2]
        z0 = frame_z - frame_half + 0.6
        z1 = z0 + DEPTH_IN
        rel_x, rel_y = tunnel[:, 0] - pts[k][0], tunnel[:, 1] - pts[k][1]
        u = rel_x*out[0] + rel_y*out[1]
        v = rel_x*along[0] + rel_y*along[1]
        facing_in = -(tunnel_n[:, 0]*out[0] + tunnel_n[:, 1]*out[1])
        near = (np.abs(v) < width/2.0) & (tunnel[:, 2] > z0) & (tunnel[:, 2] < z1) & (u > -4.0) & (u < 6.0) & (facing_in > 0.3)
        reveal = float(np.percentile(u[near], 10)) if near.sum() > 20 else 0.0
        inner = reveal - PROUD_IN
        centre = pts[k] + out*(inner + THICK_IN/2.0) - np.array([0.0, foot])
        roll = math.atan2(out[1], out[0])
        if roll > math.pi/2.0:
            roll -= math.pi
        if roll < -math.pi/2.0:
            roll += math.pi
        rows.append(((centre[0], centre[1], (z0 + z1)/2.0, 0.0), (roll, 0.02*math.sin(i*1.3), 0.02*math.cos(i*2.1), 500.0 + 7.3*i),
                     (THICK_IN/2.0, width/2.0 + foot, DEPTH_IN/2.0, z0), int(near.sum())))
    total_rows = len(rows)
    print(f"// {count} slabs round the mouth and {total_rows - count} lining it, pitch {pitch:.2f}, round {total:.1f} units of arch")
    print(f"const int FC_SLAB_COUNT = {total_rows};")
    for name, idx in (("FC_SLAB_P", 0), ("FC_SLAB_R", 1), ("FC_SLAB_S", 2)):
        body = ", ".join("vec4(" + ", ".join(f"{v:.3f}" for v in r[idx]) + ")" for r in rows)
        print(f"const vec4 {name}[{total_rows}] = vec4[{total_rows}]({body});")
    reach = [math.hypot(r[2][0], r[2][1]) + 0.5 for r in rows]
    lo = np.min([[r[0][0] - q, r[0][1] - q, r[0][2] - r[2][2] - q] for r, q in zip(rows, reach)], axis=0)
    hi = np.max([[r[0][0] + q, r[0][1] + q, r[0][2] + r[2][2] + q] for r, q in zip(rows, reach)], axis=0)
    print("# bounds", np.round(lo, 1).tolist(), np.round(hi, 1).tolist())
    Path("build/lobby/mouth_slabs.json").write_text(json.dumps([{"p": r[0], "r": r[1], "s": r[2]} for r in rows]), encoding="utf-8")
    for i, r in enumerate(rows):
        print(f"# {i:2d} at ({r[0][0]:6.1f}, {r[0][1]:5.1f}) wall {r[2][3]:.1f} from {r[3]} faces")


if __name__ == "__main__":
    main()
