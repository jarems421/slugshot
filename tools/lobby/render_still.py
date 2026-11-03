"""Render large stills of one library asset from chosen cameras, in many thin bands so no GPU job runs long.

    render_still.py <asset-id> <out-dir> <width> <height> <name:variant:yaw:pitch:dist:tx:ty:tz> ...
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import moderngl
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from render_library import desktop_glsl, extract  # noqa: E402

BANDS = 24


def main():
    asset_id, out, w, h = sys.argv[1], Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
    shots = [a.split(":") for a in sys.argv[5:]]
    page = Path("docs/art/asset-library.html").read_text(encoding="utf-8")
    vs = extract(page, r'<script id="vs" type="x-shader/x-vertex">(.*?)</script>')
    fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
    lib = extract(page, r'<script id="lib">(.*?)</script>')
    js = lib + """
const L = globalThis.SlugLib, i = L.ASSETS.findIndex(a => a.id === %s), out = [];
for (const s of %s) {
  out.push({ name: s[0], u: L.uniformsFor({ asset: i, variant: +s[1], treat: 3, figOn: true, time: s[8] !== undefined ? +s[8] : 3.0,
    cam: { yaw: +s[2], pitch: +s[3], dist: +s[4], tx: +s[5], ty: +s[6], tz: +s[7] }, width: %d, height: %d }) });
}
process.stdout.write(JSON.stringify({ bank: L.BANK, shader: L.shaderIndex(i), shots: out }));
""" % (json.dumps(asset_id), json.dumps(shots), w, h)
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as fh:
        fh.write(js)
        path = fh.name
    data = json.loads(subprocess.run(["node", path], check=True, capture_output=True, text=True).stdout)
    Path(path).unlink()
    ctx = moderngl.create_standalone_context()
    prog = ctx.program(*desktop_glsl(vs, fs, data["shader"]))
    if "uBank" in prog:
        prog["uBank"].write(np.array(data["bank"], dtype="f4").tobytes())
    vbo = ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
    vao = ctx.vertex_array(prog, [(vbo, "2f", "aPos")])
    fbo = ctx.simple_framebuffer((w, h))
    out.mkdir(parents=True, exist_ok=True)
    for shot in data["shots"]:
        for name, value in shot["u"].items():
            if name in prog:
                prog[name].value = value[0] if len(value) == 1 else tuple(value)
        fbo.use()
        fbo.clear(0, 0, 0)
        band = h//BANDS
        for b in range(BANDS):
            ctx.scissor = (0, b*band, w, band if b < BANDS - 1 else h - b*band)
            vao.render()
            ctx.finish()
        ctx.scissor = None
        img = Image.frombytes("RGB", (w, h), fbo.read(components=3)).transpose(Image.FLIP_TOP_BOTTOM)
        img.save(out/f"{shot['name']}.jpg", quality=88)
        print(shot["name"])


if __name__ == "__main__":
    main()
