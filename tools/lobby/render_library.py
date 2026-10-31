"""Render the asset library's turntable sprite sheets offline from the page's own shader.

The asset library page shows these renders by default, because the live shader froze Chrome on the
owner's Windows machine. Asset data and uniform maths come from the page's `<script id="lib">` block
(evaluated with Node), so the renders match the live view exactly.

Requires Node on PATH and a Python with moderngl, numpy and Pillow (an isolated venv is fine):
    python tools/lobby/render_library.py [--page docs/art/asset-library.html] [--out build/lobby/renders]
        [--only rock-wall-1 crystals-8 ...]
Writes one JPEG per asset variant: a 4 x 4 sheet of 16 frames (yaw steps of 22.5 degrees).
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import moderngl
import numpy as np
from PIL import Image

FRAME_W, FRAME_H, COLS = 640, 480, 4
TILES = 4  # split each frame into horizontal bands so no single draw runs long on the GPU


def extract(page: str, pattern: str) -> str:
    match = re.search(pattern, page, re.S)
    if not match:
        sys.exit(f"Could not find {pattern!r} in the page")
    return match.group(1)


def dump_renders(lib_js: str, only: set[str]) -> list[dict]:
    script = lib_js + r"""
const L = globalThis.SlugLib, out = [];
for (let i = 0; i < L.ASSETS.length; i++) {
  for (let v = 0; v < L.variantCount(i); v++) {
    const key = L.frameKey(i, v), frames = [];
    for (let f = 0; f < L.FRAMES; f++) {
      frames.push(L.uniformsFor({ asset: i, variant: v, treat: 3, figOn: true, time: 3.0,
        cam: L.renderCam(i, v, f), width: %d, height: %d }));
    }
    out.push({ key, shader: L.shaderIndex(i), frames });
  }
}
process.stdout.write(JSON.stringify({ bank: L.BANK, items: out }));
""" % (FRAME_W, FRAME_H)
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as fh:
        fh.write(script)
        path = fh.name
    data = json.loads(subprocess.run(["node", path], check=True, capture_output=True, text=True).stdout)
    Path(path).unlink()
    items = [it for it in data["items"] if not only or it["key"] in only]
    return data["bank"], items


def desktop_glsl(vs: str, fs: str, shader_index: int) -> tuple[str, str]:
    vs = "#version 330\n" + vs.replace("attribute vec2 aPos;", "in vec2 aPos;")
    fs = fs.replace("precision highp float;",
                    f"precision highp float;\n#define ASSET {shader_index}\nout vec4 fragColor;", 1)
    fs = "#version 330\n" + fs.replace("gl_FragColor", "fragColor")
    return vs, fs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="docs/art/asset-library.html")
    ap.add_argument("--out", default="build/lobby/renders")
    ap.add_argument("--only", nargs="*", default=[])
    args = ap.parse_args()
    page = Path(args.page).read_text(encoding="utf-8")
    vs = extract(page, r'<script id="vs" type="x-shader/x-vertex">(.*?)</script>')
    fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
    lib = extract(page, r'<script id="lib">(.*?)</script>')
    bank, items = dump_renders(lib, set(args.only))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    ctx = moderngl.create_standalone_context()
    print("GPU:", ctx.info["GL_RENDERER"])
    vbo = ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
    fbo = ctx.simple_framebuffer((FRAME_W, FRAME_H))
    programs = {}
    for item in items:
        shader = item["shader"]
        if shader not in programs:
            prog = ctx.program(*desktop_glsl(vs, fs, shader))
            if "uBank" in prog:
                prog["uBank"].write(np.array(bank, dtype="f4").tobytes())
            programs[shader] = (prog, ctx.vertex_array(prog, [(vbo, "2f", "aPos")]))
        prog, vao = programs[shader]
        rows = len(item["frames"])//COLS
        sheet = Image.new("RGB", (FRAME_W*COLS, FRAME_H*rows))
        for k, uniforms in enumerate(item["frames"]):
            for name, value in uniforms.items():
                if name in prog:
                    prog[name].value = value[0] if len(value) == 1 else tuple(value)
            fbo.use()
            fbo.clear(0, 0, 0)
            band = FRAME_H//TILES
            for b in range(TILES):
                ctx.scissor = (0, b*band, FRAME_W, band if b < TILES - 1 else FRAME_H - b*band)
                vao.render()
                ctx.finish()
            ctx.scissor = None
            img = Image.frombytes("RGB", (FRAME_W, FRAME_H), fbo.read(components=3)).transpose(Image.FLIP_TOP_BOTTOM)
            sheet.paste(img, ((k % COLS)*FRAME_W, (k//COLS)*FRAME_H))
        path = out/f"{item['key']}.jpg"
        sheet.save(path, quality=84, optimize=True)
        print(f"{path.name}: {path.stat().st_size//1024} KB")


if __name__ == "__main__":
    main()
