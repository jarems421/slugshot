"""Cut Rammstone's turnaround views out of the owner's sheet and turn them into calibrated silhouettes.

For each view: crop, model the smooth background gradient, take the figure as whatever differs from it (the charcoal
horns are close to the background, so they are found by their edges and rim light as well as their colour), fill holes,
and label each pixel rock, skin or horn. Every view is scaled to the same body height and aligned on the ground line, so
the masks can be intersected into one volume (tools/slugs/build_rammstone_blockout.py).

    python tools/slugs/rammstone_reference.py

Writes ignored build/slugs/rammstone/reference/: <view>.png (crop), <view>-mask.png, <view>-class.png and views.json.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT/"docs/slugs/catalog/evidence/rammstone/owner-proposal.png"
OUT = ROOT/"build/slugs/rammstone/reference"

# Boxes on the sheet (left, top, right, bottom), each holding one view standing on the floor line.
VIEWS = {
    "front": (590, 22, 760, 322),
    "side-right": (810, 22, 990, 322),
    "side-left": (1020, 22, 1200, 322),
    "back": (1265, 22, 1430, 322),
}
CLASSES = {"background": 0, "rock": 1, "skin": 2, "horn": 3}


def background_model(rgb, fg_guess):
    """Fit a smooth quadratic gradient to the pixels that are surely background."""
    h, w, _ = rgb.shape
    yy, xx = np.mgrid[0:h, 0:w]
    x, y = xx/w - 0.5, yy/h - 0.5
    basis = np.stack([np.ones_like(x), x, y, x*x, y*y, x*y], -1).reshape(-1, 6)
    keep = ~ndimage.binary_dilation(fg_guess, iterations=6).ravel()
    model = np.empty_like(rgb)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(basis[keep], rgb[..., c].ravel()[keep], rcond=None)
        model[..., c] = (basis @ coef).reshape(h, w)
    return model


def segment(rgb):
    lum = rgb.mean(-1)
    sat = rgb.max(-1) - rgb.min(-1)
    guess = (sat > 40) | (lum > 70)
    bg = background_model(rgb, guess)
    diff = np.abs(rgb - bg).sum(-1)
    # Edges find the horns' outlines where their colour is close to the background.
    gx, gy = ndimage.sobel(lum, 1), ndimage.sobel(lum, 0)
    edge = np.hypot(gx, gy)
    fg = (diff > 18) | (edge > 60)
    fg = ndimage.binary_closing(fg, iterations=2)
    fg = ndimage.binary_fill_holes(fg)
    fg = ndimage.binary_opening(fg, iterations=1)
    # Keep the figure: the biggest part, plus any large part touching it (a horn cut off by a thin gap).
    labels, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, labels, range(1, n + 1))
    keep = np.zeros_like(fg)
    for i, s in enumerate(sizes, 1):
        if s >= 0.02*sizes.max():
            keep |= labels == i
    return ndimage.binary_fill_holes(keep)


def classify(rgb, mask):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    cls = np.zeros(mask.shape, np.uint8)
    rock = mask & (r > g*1.9) & (r > 60)
    skin = mask & ~rock & (r > 110) & (g > 60) & (r < g*1.9)
    cls[mask] = CLASSES["horn"]
    cls[rock] = CLASSES["rock"]
    cls[skin] = CLASSES["skin"]
    # Glowing eyes and dark shadows inside the rock count as rock or skin by their neighbours, not as horn.
    horn = cls == CLASSES["horn"]
    lone = horn & ~ndimage.binary_opening(horn, iterations=2)
    if lone.any():
        idx = ndimage.distance_transform_edt(horn, return_distances=False, return_indices=True)
        cls[lone] = cls[idx[0][lone], idx[1][lone]]
    return cls


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = np.asarray(Image.open(SHEET).convert("RGB")).astype(float)
    info = {}
    for name, (l, t, r, b) in VIEWS.items():
        rgb = sheet[t:b, l:r]
        # The floor and the figure's contact shadow sit below the base; stop the figure at its floor line.
        mask = segment(rgb)
        cls = classify(rgb, mask)
        rows = np.nonzero((cls == CLASSES["rock"]).any(1) | (cls == CLASSES["skin"]).any(1))[0]
        base = int(rows.max())
        mask[base + 1:] = False
        cls[base + 1:] = 0
        body = (cls == CLASSES["rock"]) | (cls == CLASSES["skin"])
        top = int(np.nonzero(body.any(1))[0].min())
        cols = np.nonzero(body.any(0))[0]
        Image.fromarray(rgb.astype(np.uint8)).save(OUT/f"{name}.png")
        Image.fromarray((mask*255).astype(np.uint8)).save(OUT/f"{name}-mask.png")
        Image.fromarray(cls*80).save(OUT/f"{name}-class.png")
        info[name] = {"box": [l, t, r, b], "base": base, "bodyTop": top, "bodyLeft": int(cols.min()), "bodyRight": int(cols.max()),
                      "horn": int((cls == CLASSES["horn"]).sum()), "rock": int((cls == CLASSES["rock"]).sum()),
                      "skin": int((cls == CLASSES["skin"]).sum())}
        print(name, info[name])
    (OUT/"views.json").write_text(json.dumps(info, indent=2))


if __name__ == "__main__":
    main()
