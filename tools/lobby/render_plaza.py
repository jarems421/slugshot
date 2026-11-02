"""Render the portal plaza options at higher resolution than the library's turntables.

    python tools/lobby/render_plaza.py --out DIR --size 1024 768 --every 2 [--keys portal-plaza-1 ...]   turntable sheets
    python tools/lobby/render_plaza.py --out DIR --size 768 576 --frames 4                               single test frames
Requires Node, moderngl, numpy and Pillow.
"""

import argparse
import sys
from pathlib import Path

import moderngl
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from render_library import desktop_glsl, dump_renders, extract  # noqa: E402

BANDS = 12  # each draw stays short, so the GPU driver never resets


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="docs/art/asset-library.html")
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", nargs=2, type=int, default=[1024, 768])
    ap.add_argument("--every", type=int, default=2)
    ap.add_argument("--frames", nargs="*", type=int)
    ap.add_argument("--keys", nargs="*", default=[f"portal-plaza-{i}" for i in range(1, 9)])
    args = ap.parse_args()
    page = Path(args.page).read_text(encoding="utf-8")
    vs = extract(page, r'<script id="vs" type="x-shader/x-vertex">(.*?)</script>')
    fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
    bank, items = dump_renders(extract(page, r'<script id="lib">(.*?)</script>'), set(args.keys))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    w, h = args.size
    ctx = moderngl.create_standalone_context()
    vbo = ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
    fbo = ctx.simple_framebuffer((w, h))
    prog = ctx.program(*desktop_glsl(vs, fs, items[0]["shader"]))
    if "uBank" in prog:
        prog["uBank"].write(np.array(bank, dtype="f4").tobytes())
    vao = ctx.vertex_array(prog, [(vbo, "2f", "aPos")])

    def shoot(uniforms):
        for name, value in uniforms.items():
            if name in prog:
                prog[name].value = value[0] if len(value) == 1 else tuple(value)
        prog["uRes"].value = (w, h)
        fbo.use()
        fbo.clear(0, 0, 0)
        band = h//BANDS
        for b in range(BANDS):
            ctx.scissor = (0, b*band, w, band if b < BANDS - 1 else h - b*band)
            vao.render()
            ctx.finish()
        ctx.scissor = None
        return Image.frombytes("RGB", (w, h), fbo.read(components=3)).transpose(Image.FLIP_TOP_BOTTOM)

    for item in items:
        if args.frames:
            for f in args.frames:
                shoot(item["frames"][f]).save(out/f"{item['key']}-f{f}.jpg", quality=90)
            print(item["key"], "done", flush=True)
            continue
        chosen = item["frames"][::args.every]
        cols = 6
        rows = (len(chosen) + cols - 1)//cols
        sheet = Image.new("RGB", (w*cols, h*rows))
        for k, uniforms in enumerate(chosen):
            sheet.paste(shoot(uniforms), ((k % cols)*w, (k//cols)*h))
        path = out/f"{item['key']}.jpg"
        sheet.save(path, quality=82, optimize=True)
        print(path.name, path.stat().st_size//1024, "KB", flush=True)


if __name__ == "__main__":
    main()
