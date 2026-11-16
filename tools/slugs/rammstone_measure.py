"""Measure Rammstone's sheet for the clean build: body, hood, plate tips and horns, in Blender units.

Reads build/slugs/rammstone/reference/ (tools/slugs/rammstone_reference.py) and reuses the blockout's calibration
helpers. Writes build/slugs/rammstone/clean/measure.json for tools/slugs/build_rammstone_clean.py, which runs in Blender
(numpy only, so the image work happens here).

    python tools/slugs/rammstone_measure.py

Blender axes: x across (the front view's columns), y front-to-back (the face toward -y; the side view's columns), z up.
"""
import json
import sys
from pathlib import Path

import numpy as np
from scipy import ndimage
from skimage import morphology

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rammstone_blockout_volume as v

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"build/slugs/rammstone/clean"
P = v.PIXEL


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    front, front_cls, fi = v.load("front")
    side, side_cls, si = v.load("side-left")
    fcls = v.clean_classes(front_cls)
    cx, cz = v.centre(front), v.centre(side)
    bf, bs = fi["base"], si["base"]
    height = min(bf, bs) + 1
    visor = v.visor_row(side, bs, height)
    split = v.horn_split_row(front, bf, height)
    zf, zb, half = v.body_profile(fcls, side, cz, bf, bs, height, visor)
    rows = []
    for y in range(height):
        fr, sr = front[bf - y], side[bs - y]
        f_parts, s_parts = v.intervals(fr), v.intervals(sr)
        centre_part = [(a, b) for a, b in f_parts if a <= cx <= b]
        row = {"z": y*P}
        if f_parts:
            row["frontHalf"] = max(max(abs(a - cx - 0.5), abs(b - cx + 0.5)) for a, b in f_parts)*P
        if centre_part:
            a, b = centre_part[0]
            row["centreHalf"] = max(abs(a - cx - 0.5), abs(b - cx + 0.5))*P
        if s_parts:
            row["sideFront"] = (min(a for a, _ in s_parts) - cz - 0.5)*P
            row["sideBack"] = (max(b for _, b in s_parts) - cz + 0.5)*P
            # The hood's own extent: the side piece that holds the middle of the head, not a horn beside it.
            main_part = max(s_parts, key=lambda ab: ab[1] - ab[0])
            row["sideMainFront"] = (main_part[0] - cz - 0.5)*P
            row["sideMainBack"] = (main_part[1] - cz + 0.5)*P
        rows.append(row)
    # Plate tips: where the profile's back edge reaches out furthest, below the hood.
    def tips_of(edge):
        smooth = ndimage.gaussian_filter1d(edge, 1.0)
        found = [0]  # every profile flares at the floor
        for y in range(8, visor):
            if smooth[y] == smooth[y - 6:y + 7].max() and smooth[y] - smooth[y - 12:y].min() > 0.025:
                found.append(y)
        return [y*P for y in found]

    tips = tips_of(np.array([r.get("sideBack", 0.0) for r in rows]))
    side_tips = tips_of(np.array([r.get("frontHalf", 0.0) for r in rows]))
    # Horns: the side view's medial axis above the split, set and sized by the front view.
    region = side.copy()
    region[bs - split + 1:] = False
    dist = ndimage.distance_transform_edt(region)
    path = v.longest_path(morphology.skeletonize(region))
    horn = []
    for row_px, col in path:
        y = bs - row_px
        # The outermost piece on the right is the horn; near the root the hood's middle piece sits beside it.
        right = [(a, b) for a, b in v.intervals(front[bf - y]) if (a + b)/2 > cx + 12]
        if right:
            a, b = max(right, key=lambda ab: ab[0])
            horn.append([((a + b)/2 - cx)*P, (col - cz)*P, y*P, (b - a + 1)/2*P, float(dist[row_px, col])*P])
    centre_rows = [r["z"] for r in rows if "centreHalf" in r]
    data = {"pixel": P, "visorZ": visor*P, "splitZ": split*P, "peakZ": max(centre_rows),
            "rows": rows, "body": {"faceY": (zf*P).tolist(), "backY": (zb*P).tolist(), "half": (half*P).tolist()},
            "plateTipsZ": tips, "sidePlateTipsZ": side_tips, "horn": horn}
    (OUT/"measure.json").write_text(json.dumps(data))
    print(json.dumps({"visorZ": data["visorZ"], "splitZ": data["splitZ"], "peakZ": data["peakZ"], "plateTipsZ": [round(t, 3) for t in tips], "sidePlateTipsZ": [round(t, 3) for t in side_tips],
                      "hornPoints": len(horn), "hornRootRadius": horn[0][3:] if horn else None}))


if __name__ == "__main__":
    main()
