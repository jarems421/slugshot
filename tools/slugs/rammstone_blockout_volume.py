"""Carve Rammstone's blockout from the owner's sheet: the volume that fits inside both the front and the side silhouettes.

Reads build/slugs/rammstone/reference/ (tools/slugs/rammstone_reference.py). Three masses:

- The body: a smooth rounded column from the floor up to the visor's underside. Its front is the face line in profile,
  its width the front view's skin, its depth most of the way to the back; all smoothed over height, so plate tips cannot
  ripple it.
- The armour and hood: the carved volume. In each slice every front interval paired with a side interval is a rectangle
  in plan, rounded to a superellipse that still touches all four sides, so both silhouettes are kept. Beside the body it
  stays behind the body's front third, except where the front view shows rock (side plates, the brow). From the visor
  up it is kept whole.
- The horns: tubes swept along the side view's medial axis, set sideways and sized by the front view, above the height
  where the front view shows them apart.

Each vertex takes the part of the mass it lies on: skin, rock or horn. No eyes, cracks or other detail.

    python tools/slugs/rammstone_blockout_volume.py

Writes build/slugs/rammstone/blockout/volume.npz (vertices in Blender units, faces, part per vertex) and calibration.json.
Units: 1 sheet pixel = PIXEL Blender units; z up from the floor line, -y toward the face.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from skimage import measure, morphology

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT/"build/slugs/rammstone/reference"
OUT = ROOT/"build/slugs/rammstone/blockout"
PIXEL = 0.01
ROUND = 2.4  # superellipse exponent for each slice: 2 is an ellipse, higher is boxier
ROCK, SKIN, HORN = 1, 2, 3


def load(name):
    info = json.loads((REF/"views.json").read_text())[name]
    mask = np.asarray(Image.open(REF/f"{name}-mask.png")) > 0
    cls = np.asarray(Image.open(REF/f"{name}-class.png"))//80
    return mask, cls, info


def centre(mask):
    """The body's middle, from the rows below the hood."""
    mids = []
    for r in range(150, 280):
        cols = np.nonzero(mask[r])[0]
        if len(cols):
            mids.append((cols.min() + cols.max())/2)
    return float(np.mean(mids))


def intervals(row):
    edges = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
    return list(zip(np.nonzero(edges == 1)[0], np.nonzero(edges == -1)[0] - 1))


def clean_classes(cls):
    """Skin only in large patches, horn only in solid dark areas, so rims and crevices fall back to rock."""
    out = np.where(cls > 0, ROCK, 0)
    skin = cls == SKIN
    lab, n = ndimage.label(skin)
    if n:
        sizes = ndimage.sum(skin, lab, range(1, n + 1))
        out[np.isin(lab, 1 + np.nonzero(sizes > 0.03*(cls > 0).sum())[0])] = SKIN
    horn = ndimage.binary_opening(cls == HORN, iterations=2)
    out[horn] = HORN
    return out


def face_span(fcls):
    """The front view's skin filled across each row, so the eyes and mouth count as face rather than rock."""
    span = np.zeros(fcls.shape, bool)
    for r in range(fcls.shape[0]):
        cols = np.nonzero(fcls[r] == SKIN)[0]
        if len(cols) > 20:
            span[r, cols.min():cols.max() + 1] = True
    return span


def visor_row(side, base_s, height):
    """Height of the visor's underside: from the visor's tip (the profile's most forward point in its upper half), down
    to where the front edge stops falling back, which is the face."""
    edge = np.array([np.nonzero(side[base_s - y])[0].min() if side[base_s - y].any() else 9999 for y in range(height)])
    lo, hi = int(height*0.45), int(height*0.75)
    y = lo + int(np.argmin(edge[lo:hi]))
    while y > lo and edge[y - 1] > edge[y]:
        y -= 1
    return y


def horn_split_row(front, base_f, height):
    """Height above which the front view shows the two horns apart: the top of the last row that is one wide piece."""
    wide = [y for y in range(height) if any(b - a > 60 for a, b in intervals(front[base_f - y]))]
    return max(wide) + 1


def body_profile(fcls, side, cz, base_f, base_s, height, visor):
    """Per row up to the visor: the body column's front edge, half width and the armour's back edge, smoothed."""
    zf = np.full(height, np.nan); zb = np.full(height, np.nan); half = np.full(height, np.nan)
    for y in range(visor + 1):
        cols = np.nonzero(side[base_s - y])[0]
        skin_cols = np.nonzero(fcls[base_f - y] == SKIN)[0]
        if len(cols):
            zf[y], zb[y] = cols.min() - cz - 0.5, cols.max() - cz + 0.5
        if len(skin_cols) > 20:
            half[y] = (skin_cols.max() - skin_cols.min() + 1)/2
    rows = np.arange(height)
    for arr, sigma in ((zf, 2.0), (zb, 6.0), (half, 3.0)):
        good = ~np.isnan(arr)
        arr[:] = np.interp(rows, rows[good], arr[good])
        arr[:] = ndimage.gaussian_filter1d(arr, sigma)
    return zf, zb, half


def longest_path(skeleton):
    """The skeleton's longest pixel path, ordered from its lowest end."""
    pts = {tuple(p) for p in np.argwhere(skeleton)}

    def neighbours(p):
        return [(p[0] + a, p[1] + b) for a in (-1, 0, 1) for b in (-1, 0, 1) if (a or b) and (p[0] + a, p[1] + b) in pts]

    def bfs(start):
        prev, order = {start: None}, [start]
        for cur in order:
            for n in neighbours(cur):
                if n not in prev:
                    prev[n] = cur
                    order.append(n)
        return order[-1], prev

    far, _ = bfs(max(pts))
    end, prev = bfs(far)
    path = []
    while end is not None:
        path.append(end)
        end = prev[end]
    path = np.array(path)
    return path if path[0, 0] > path[-1, 0] else path[::-1]


def horn_field(front, side, cx, cz, base_f, base_s, split, shape):
    """Both horns as tubes: the centreline is the side view's medial axis, its sideways position and width come from the
    front view, and it continues a little below the split along its starting direction so the root sinks into the hood."""
    region = side.copy()
    region[base_s - split + 1:] = False
    dist = ndimage.distance_transform_edt(region)
    path = longest_path(morphology.skeletonize(region))
    pts = []
    for row, col in path:
        y = base_s - row
        right = [(a, b) for a, b in intervals(front[base_f - y]) if (a + b)/2 > cx]
        if right:
            a, b = right[0]
            pts.append(((a + b)/2 - cx, y, col - cz, max((b - a + 1)/2, 1.5), max(dist[row, col], 1.5)))
    pts = np.array(pts)
    d = pts[min(8, len(pts) - 1), :3] - pts[0, :3]
    d = d/np.linalg.norm(d)
    root = [np.concatenate([pts[0, :3] - d*k, pts[0, 3:]]) for k in range(21, 0, -2)]
    pts = np.concatenate([np.array(root), pts])
    field = np.zeros(shape, np.float32)
    for x0, y0, z0, rf, rs in pts:
        for xc in (cx + x0, cx - x0):
            yc, zc = y0 + 1, z0 + cz
            lo = [int(max(0, c - r - 2)) for c, r in ((xc, rf), (yc, rs), (zc, rs))]
            hi = [int(min(n, c + r + 3)) for c, r, n in ((xc, rf, shape[0]), (yc, rs, shape[1]), (zc, rs, shape[2]))]
            X, Y, Z = np.meshgrid(*(np.arange(a, b) for a, b in zip(lo, hi)), indexing="ij")
            inside = (((X - xc)/rf)**2 + ((Y - yc)**2 + (Z - zc)**2)/rs**2 <= 1.0).astype(np.float32)
            sub = field[lo[0]:hi[0], lo[1]:hi[1], lo[2]:hi[2]]
            np.maximum(sub, inside, out=sub)
    return field, len(pts)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    front, front_cls, fi = load("front")
    side, side_cls, si = load("side-left")
    fcls = clean_classes(front_cls)
    cx, cz = centre(front), centre(side)
    base_f, base_s = fi["base"], si["base"]
    height = min(base_f, base_s) + 1
    visor = visor_row(side, base_s, height)
    split = horn_split_row(front, base_f, height)
    zf, zb, half = body_profile(fcls, side, cz, base_f, base_s, height, visor)
    # Grid in sheet pixels: x across the front view, z across the side view (front of the face toward -z), y up.
    xs = np.arange(front.shape[1]) - cx
    zs = np.arange(side.shape[1]) - cz
    shape = (len(xs), height + 2, len(zs))
    body, rock = np.zeros(shape, np.float32), np.zeros(shape, np.float32)
    X, Z = np.meshgrid(xs, zs, indexing="ij")
    column = np.clip(np.round(X + cx).astype(int), 0, front.shape[1] - 1)
    skin_front = ndimage.binary_dilation(face_span(fcls), iterations=2)
    split_side = intervals(side[base_s - split + 1])
    for y in range(height):
        fr, sr = front[base_f - y], side[base_s - y]
        front_parts, side_parts = intervals(fr), intervals(sr)
        if y >= split:
            # Above the split only the hood's dome continues, between the horns: the front piece over the middle,
            # paired with the profile's pieces that overlap the hood where the horns separate.
            front_parts = [(a, b) for a, b in front_parts if a <= cx <= b]
            side_parts = [(c, d) for c, d in side_parts if any(c <= q and p <= d for p, q in split_side)]
        hull = np.zeros(X.shape, bool)
        for a, b in front_parts:
            xa, xb = a - cx - 0.5, b - cx + 0.5
            for c, d in side_parts:
                za, zb_ = c - cz - 0.5, d - cz + 0.5
                u = np.abs(2*(X - (xa + xb)/2)/(xb - xa))
                v = np.abs(2*(Z - (za + zb_)/2)/(zb_ - za))
                hull |= u**ROUND + v**ROUND <= 1.0
        if y <= visor:
            # The body: a rounded column whose front is the face line. The armour stays behind the body's front third,
            # except where the front view shows rock (the side plates and the brow), where it may come forward.
            depth = 0.85*(zb[y] - zf[y])
            body[:, y + 1, :] = np.abs(X/half[y])**2.2 + np.abs((Z - zf[y] - depth/2)/(depth/2))**2.2 <= 1.0
            rock_here = ~skin_front[base_f - y][column]
            rock[:, y + 1, :] = hull & ((Z > zf[y] + 0.30*(zb[y] - zf[y])) | rock_here)
        else:
            rock[:, y + 1, :] = hull
    horn, horn_points = horn_field(front, side, cx, cz, base_f, base_s, split, shape)
    fb, fa, fh = (ndimage.gaussian_filter(f, 1.0) for f in (body, rock, horn))
    verts, faces, _, _ = measure.marching_cubes(np.maximum(np.maximum(fb, fa), fh), 0.5)
    idx = np.round(verts).astype(int)
    for a in range(3):
        idx[:, a] = np.clip(idx[:, a], 0, shape[a] - 1)
    vb, va, vh = (f[idx[:, 0], idx[:, 1], idx[:, 2]] for f in (fb, fa, fh))
    part = np.where((vb >= va) & (vb >= vh), SKIN, np.where((vh > va) & (vh > vb), HORN, ROCK))
    # Grid indices to Blender: x across, -y toward the face (the side view's -z), z up.
    blender = np.stack([verts[:, 0] - cx, verts[:, 2] - cz, verts[:, 1] - 1], -1)*PIXEL
    np.savez_compressed(OUT/"volume.npz", verts=blender.astype(np.float32), faces=faces.astype(np.int32), part=part.astype(np.int8))
    calib = {"pixel": PIXEL, "front": {"centreColumn": cx, "baseRow": base_f, "size": list(front.shape)},
             "side-left": {"centreColumn": cz, "baseRow": base_s, "size": list(side.shape)}, "round": ROUND,
             "visorRow": int(visor), "hornSplitRow": int(split), "hornPoints": int(horn_points),
             "vertices": int(len(verts)), "faces": int(len(faces))}
    for name in ("back", "side-right"):
        mask, _, info = load(name)
        calib[name] = {"centreColumn": centre(mask), "baseRow": info["base"], "size": list(mask.shape)}
    (OUT/"calibration.json").write_text(json.dumps(calib, indent=2))
    print(json.dumps(calib))


if __name__ == "__main__":
    main()
