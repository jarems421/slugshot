"""Paint a lobby asset's colour and glow maps texel by texel from the concept shader.

Reads the texel-position maps baked by tools/lobby/blender_lobby_asset.py, evaluates the asset library
shader's paint (albedo with Slugshot mix ink, emission) at each texel's surface point on the GPU, grows
islands into the bake margin, and writes <Group>-color.png (sRGB) and <Group>-emit.png (0-1 glow mask)
plus each group's emissive strength into build.json.

    python tools/lobby/paint_texels.py <key>
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from render_library import dump_renders, extract  # noqa: E402
from sdf_mesh import Gpu  # noqa: E402


# Groups whose concept paint glows: crystals, stem tops, caps, bolts, gems, energy, bulbs, small caps.
GLOWING = {3, 4, 5, 7, 8, 9, 14, 15}


def to_srgb(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92*x, 1.055*np.power(x, 1/2.4) - 0.055)


def dilate(img, valid, steps=12):
    """Grow covered texels outward so filtering at island edges never pulls in empty texels."""
    img, valid = img.copy(), valid.copy()
    for _ in range(steps):
        acc = np.zeros_like(img)
        cnt = np.zeros(valid.shape, dtype="f4")
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            v = np.roll(valid, (dy, dx), axis=(0, 1))
            acc += np.roll(img, (dy, dx), axis=(0, 1))*v[..., None]
            cnt += v
        grow = (~valid) & (cnt > 0)
        img[grow] = acc[grow]/cnt[grow][:, None]
        valid |= grow
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--page", default="docs/art/asset-library.html")
    args = ap.parse_args()
    out = Path("build/lobby/export")/args.key
    report = json.loads((out/"build.json").read_text())
    page = Path(args.page).read_text(encoding="utf-8")
    bank, items = dump_renders(extract(page, r'<script id="lib">(.*?)</script>'), {args.key})
    gpu = Gpu(page, items[0], bank)
    for g in report["groups"]:
        g.pop("emit", None)
        g.pop("emissiveStrength", None)
        px = np.load(out/g["positions"])[::-1]  # Blender image rows run bottom-up
        # Cycles writes the whole image; texels the mesh does not cover keep an exact zero position.
        valid = np.abs(px[..., :3]).sum(axis=2) > 0
        bpos = px[..., :3][valid]
        pos = np.stack([bpos[:, 0], bpos[:, 2], -bpos[:, 1]], axis=1).astype("f4")  # Blender -> Y-up studs
        a0, a1 = gpu.paint(pos)
        # Small bank-coloured caps (owner round 4: "dull and pale"): the bank is light, and Roblox's glow on
        # top washed it towards white. Square each channel against the brightest one, which keeps hue and
        # peak but deepens the colour.
        small = a0[:, 3] > 14.5
        for a in (a0, a1):
            c = a[small, :3]
            a[small, :3] = c*c/np.maximum(c.max(axis=1, keepdims=True), 1e-4)
        h, w = valid.shape
        alb = np.zeros((h, w, 3), "f4"); emit = np.zeros((h, w, 3), "f4")
        alb[valid] = a0[:, :3]; emit[valid] = a1[:, :3]
        alb, emit = dilate(alb, valid), dilate(emit, valid)
        Image.fromarray((to_srgb(alb)*255 + 0.5).astype("u1")).save(out/"textures"/f"{g['name']}-color.png")
        g["color"] = f"textures/{g['name']}-color.png"
        lum = emit.max(axis=2)
        if g["id"] in GLOWING and (lum[valid] > 0.05).mean() > 0.01:
            peak = float(np.percentile(lum[valid & (lum > 0.05)], 98))
            mask = np.clip(lum/peak, 0, 1)
            Image.fromarray((mask*255 + 0.5).astype("u1")).save(out/"textures"/f"{g['name']}-emit.png")
            base = alb.max(axis=2)[valid & (mask > 0.5)]
            g["emit"] = f"textures/{g['name']}-emit.png"
            # Small caps: round 4 stopped the glow at 1 to save the colour, which the owner found too dim. With the
            # deepened colours the main channel can go to 1.6 while the others stay low, so the hue survives.
            if small.mean() > 0.5:
                peak = min(peak, 1.6)
            g["emissiveStrength"] = round(min(6.0, peak/max(float(np.median(base)), 0.05)), 2)
        print(f"{g['name']}: painted {int(valid.sum())} texels" + (f", glow x{g['emissiveStrength']}" if "emit" in g else ""))
    (out/"build.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
