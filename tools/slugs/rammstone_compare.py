"""Compare Rammstone's blockout renders with the owner's sheet, view by view.

For each orthographic view: the sheet crop, the render, a silhouette comparison (white both, red only the sheet, cyan
only the model) and a half-transparent overlay of the render on the sheet, with the silhouettes' intersection over union.
Front and left side carve the volume, so they match by construction; the back and right side are the honest checks.

    python tools/slugs/rammstone_compare.py [stage]

`stage` is the build folder holding renders/: blockout (default) or surface. Writes <stage>/compare-<view>.png,
compare.png and compare.json.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT/"build/slugs/rammstone/reference"
OUT = ROOT/"build/slugs/rammstone"/(sys.argv[1] if len(sys.argv) > 1 else "blockout")
VIEWS = ("front", "side-left", "back", "side-right")
ZOOM = 2


def main():
    scores, panels = {}, []
    for name in VIEWS:
        ref = Image.open(REF/f"{name}.png").convert("RGB")
        ref_mask = np.asarray(Image.open(REF/f"{name}-mask.png")) > 0
        render = Image.open(OUT/"renders"/f"{name}.png").convert("RGBA").resize(ref.size, Image.LANCZOS)
        model = np.asarray(render)[..., 3] > 127
        iou = float((ref_mask & model).sum()/(ref_mask | model).sum())
        scores[name] = {"iou": round(iou, 3), "sheetOnly": int((ref_mask & ~model).sum()), "modelOnly": int((model & ~ref_mask).sum())}
        sil = np.zeros(ref_mask.shape + (3,), np.uint8)
        sil[ref_mask & model] = (235, 235, 235)
        sil[ref_mask & ~model] = (230, 40, 40)
        sil[model & ~ref_mask] = (40, 210, 230)
        on_bg = Image.new("RGB", ref.size, (37, 34, 37))
        on_bg.paste(render, (0, 0), render)
        overlay = Image.blend(ref, on_bg, 0.5)
        row = [ref, on_bg, Image.fromarray(sil), overlay]
        w, h = ref.size
        panel = Image.new("RGB", (w*4*ZOOM + 30, h*ZOOM + 26), (24, 22, 26))
        for k, im in enumerate(row):
            panel.paste(im.resize((w*ZOOM, h*ZOOM), Image.NEAREST), (k*(w*ZOOM + 10), 26))
        ImageDraw.Draw(panel).text((6, 6), f"{name}: sheet | blockout | silhouettes (red sheet only, cyan model only) | overlay   IoU {iou:.3f}", fill=(230, 230, 230))
        panel.save(OUT/f"compare-{name}.png")
        panels.append(panel)
    sheet = Image.new("RGB", (max(p.width for p in panels), sum(p.height for p in panels)), (24, 22, 26))
    y = 0
    for p in panels:
        sheet.paste(p, (0, y))
        y += p.height
    sheet.save(OUT/"compare.png")
    (OUT/"compare.json").write_text(json.dumps(scores, indent=2))
    print(json.dumps(scores))


if __name__ == "__main__":
    main()
