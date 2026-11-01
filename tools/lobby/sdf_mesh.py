"""Turn a final asset-library concept into dense, painted mesh data for the Blender build.

Samples the asset's signed-distance shape on the GPU with the asset library's own shader (so the mesh is
the approved concept, not a re-interpretation), extracts the surface with marching cubes, then evaluates
the shader's paint at every vertex: albedo with the Slugshot mix ink lines baked in, emission and material
id. Writes one .npz per material group plus meta.json to build/lobby/meshes/<key>/ for
tools/lobby/blender_lobby_asset.py.

    python tools/lobby/sdf_mesh.py rock-wall-1 [--step 0.06]
Requires Node, moderngl, numpy and scikit-image.
"""

import argparse
import json
import sys
from pathlib import Path

import moderngl
import numpy as np
from skimage.measure import marching_cubes

sys.path.insert(0, str(Path(__file__).parent))
from render_library import dump_renders, extract  # noqa: E402

# Material groups by shader id. Ink widths follow the Slugshot mix rule (studs): rock/floor 0.045 and
# other props 0.07, both times Comic/Inked Cavern's 1.7 width scale; portal energy has no ink. The mushroom
# cap is thinner (0.09): a full-width shell poked through its thin curled lip.
GROUPS = {
    1: ("Rock", 0.045*1.7), 3: ("Crystal", 0.07*1.7), 4: ("Stem", 0.07*1.7), 5: ("Cap", 0.09),
    6: ("Stone", 0.045*1.7), 7: ("Iron", 0.07*1.7), 8: ("Gem", 0.07*1.7), 9: ("Energy", 0.0),
    12: ("Moss", 0.07*1.7), 14: ("Bulb", 0.07*1.7), 15: ("GlowCap", 0.07*1.7),
}

ASSET_MAP = """
vec2 assetMap(vec3 p) {
#if ASSET == 0
  return rockWall(p);
#elif ASSET == 1
  return crystals(p);
#elif ASSET == 2
  return mushroom(p);
#else
  vec2 r = portal(p/GS); r.x *= GS; return r;
#endif
}
vec3 assetNormal(vec3 p) {
  const float h = 0.004;
  return normalize(vec3(assetMap(p + vec3(h, 0, 0)).x - assetMap(p - vec3(h, 0, 0)).x,
                        assetMap(p + vec3(0, h, 0)).x - assetMap(p - vec3(0, h, 0)).x,
                        assetMap(p + vec3(0, 0, h)).x - assetMap(p - vec3(0, 0, h)).x));
}
"""

GRID_MAIN = """
uniform vec3 uOrigin;
uniform float uStep, uSliceZ;
layout(location = 0) out vec4 o0;
void main() {
  vec3 p = uOrigin + vec3(floor(gl_FragCoord.x), floor(gl_FragCoord.y), uSliceZ)*uStep;
  o0 = vec4(assetMap(p), 0.0, 1.0);
}
"""

PAINT_MAIN = """
uniform sampler2D uPos;
layout(location = 0) out vec4 o0;
layout(location = 1) out vec4 o1;
void main() {
  vec3 p = texelFetch(uPos, ivec2(gl_FragCoord.xy), 0).xyz;
  for (int k = 0; k < 3; k++) p -= assetNormal(p)*assetMap(p).x;   // snap onto the exact surface
  vec3 n = assetNormal(p);
  float id = assetMap(p - n*0.01).y;
  vec3 emit; float spec;
  vec3 alb = albedo(id, p, n, emit, spec);
  // Interior ink exactly as the library draws it: creases plus material boundaries.
  float e = 0.09*max(creaseScale(id), 0.6);
  float cs = TR(id).y;
  vec2 s1 = assetMap(p + vec3(e, -e, -e)), s2 = assetMap(p + vec3(-e, -e, e));
  vec2 s3 = assetMap(p + vec3(-e, e, -e)), s4 = assetMap(p + vec3(e, e, e));
  float lap = (s1.x + s2.x + s3.x + s4.x - 4.0*assetMap(p).x)/e;
  float crease = smoothstep(0.5/cs, 1.0/cs, -lap) + 0.5*smoothstep(1.4/cs, 2.4/cs, lap);
  float idEdge = (abs(s1.y - id) + abs(s2.y - id) + abs(s3.y - id) + abs(s4.y - id)) > 0.5 ? 1.0 : 0.0;
  if (abs(id - 9.0) < 0.5) { crease = 0.0; idEdge *= 0.6; }
  float ink = max(clamp(crease, 0.0, 1.0)*step(0.01, inkWidth(id)), idEdge);
  alb = mix(alb, INK(id), ink);
  emit *= 1.0 - ink;
  o0 = vec4(alb, id);
  o1 = vec4(emit, ink);
}
"""

VS = "#version 330\nin vec2 aPos; void main(){ gl_Position = vec4(aPos, 0.0, 1.0); }"


class Gpu:
    def __init__(self, page: str, item: dict, bank: list[float]):
        fs = extract(page, r'<script id="fs" type="x-shader/x-fragment">(.*?)</script>')
        prefix = fs[:fs.rindex("\nvoid main() {")]
        prefix = prefix.replace("precision highp float;", f"precision highp float;\n#define ASSET {item['shader']}", 1)
        self.ctx = moderngl.create_standalone_context()
        self.vbo = self.ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
        self.progs = {}
        for name, main in (("grid", GRID_MAIN), ("paint", PAINT_MAIN)):
            prog = self.ctx.program(vertex_shader=VS, fragment_shader="#version 330\n" + prefix + ASSET_MAP + main)
            for uname, value in item["frames"][0].items():
                if uname in prog:
                    prog[uname].value = value[0] if len(value) == 1 else tuple(value)
            if "uBank" in prog:
                prog["uBank"].write(np.array(bank, dtype="f4").tobytes())
            if "uFig" in prog:
                prog["uFig"].value = (0.0, -100.0, 0.0, 0.0)  # no scale figure in the mesh
            self.progs[name] = (prog, self.ctx.vertex_array(prog, [(self.vbo, "2f", "aPos")]))

    def grid(self, origin, step, shape) -> np.ndarray:
        prog, vao = self.progs["grid"]
        nx, ny, nz = shape
        tex = self.ctx.texture((nx, ny), 4, dtype="f4")
        fbo = self.ctx.framebuffer(color_attachments=[tex])
        prog["uOrigin"].value = tuple(origin)
        prog["uStep"].value = step
        out = np.empty((nz, ny, nx, 2), dtype="f4")
        for k in range(nz):
            prog["uSliceZ"].value = float(k)
            fbo.use()
            vao.render()
            out[k] = np.frombuffer(fbo.read(components=4, dtype="f4"), dtype="f4").reshape(ny, nx, 4)[..., :2]
        fbo.release(); tex.release()
        return out.transpose(2, 1, 0, 3)  # -> x, y, z

    def paint(self, verts: np.ndarray):
        prog, vao = self.progs["paint"]
        w = 2048
        h = (len(verts) + w - 1)//w
        pos = np.zeros((h*w, 4), dtype="f4")
        pos[:len(verts), :3] = verts
        ptex = self.ctx.texture((w, h), 4, data=pos.tobytes(), dtype="f4")
        ptex.filter = (moderngl.NEAREST, moderngl.NEAREST)
        ptex.use(0)
        prog["uPos"].value = 0
        t0, t1 = self.ctx.texture((w, h), 4, dtype="f4"), self.ctx.texture((w, h), 4, dtype="f4")
        fbo = self.ctx.framebuffer(color_attachments=[t0, t1])
        out0, out1 = np.empty((h, w, 4), "f4"), np.empty((h, w, 4), "f4")
        band = 128  # bands of rows keep each draw short on the GPU
        for y in range(0, h, band):
            fbo.use()
            self.ctx.scissor = (0, y, w, min(band, h - y))
            vao.render()
            self.ctx.finish()
        self.ctx.scissor = None
        out0[:] = np.frombuffer(fbo.read(components=4, attachment=0, dtype="f4"), "f4").reshape(h, w, 4)
        out1[:] = np.frombuffer(fbo.read(components=4, attachment=1, dtype="f4"), "f4").reshape(h, w, 4)
        n = len(verts)
        return out0.reshape(-1, 4)[:n], out1.reshape(-1, 4)[:n]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("key", help="asset key as in the library renders, e.g. rock-wall-1, crystals-1, gate-pvp-1")
    ap.add_argument("--page", default="docs/art/asset-library.html")
    ap.add_argument("--out", default="build/lobby/meshes")
    ap.add_argument("--step", type=float, default=0.06)
    args = ap.parse_args()
    page = Path(args.page).read_text(encoding="utf-8")
    lib = extract(page, r'<script id="lib">(.*?)</script>')
    bank, items = dump_renders(lib, {args.key})
    if not items:
        sys.exit(f"Unknown asset key {args.key}")
    gpu = Gpu(page, items[0], bank)

    # Coarse pass finds the asset's bounds; the fine pass samples just that box.
    c0, cstep = np.array([-24.0, -1.0, -14.0]), 0.5
    coarse = gpu.grid(c0, cstep, (97, 60, 57))[..., 0]
    near = np.argwhere(coarse < cstep*1.5)
    lo = c0 + near.min(axis=0)*cstep - 1.0
    hi = c0 + near.max(axis=0)*cstep + 1.0
    lo[1] = max(lo[1], -0.3)
    shape = tuple(int(v) for v in np.ceil((hi - lo)/args.step) + 1)
    print(f"bounds {lo.round(2)} .. {hi.round(2)}, grid {shape}")
    fine = gpu.grid(lo, args.step, shape)
    dist = fine[..., 0].copy()
    dist[:, 0, :] = np.maximum(dist[:, 0, :], 0.01)  # close the mesh where it meets the floor plane
    verts, faces, _, _ = marching_cubes(dist, level=0.0, spacing=(args.step,)*3, allow_degenerate=False)
    verts = (verts + lo).astype("f4")
    faces = faces.astype("i4")  # scikit-image winding is already outward for this SDF
    print(f"marching cubes: {len(verts)} verts, {len(faces)} faces")
    a0, a1 = gpu.paint(verts)
    ids = np.floor(a0[:, 3] + 0.5)
    ids[ids >= 15] = 15
    face_ids = ids[faces]
    # Each face goes to the group most of its corners belong to.
    major = np.where(face_ids[:, 1] == face_ids[:, 2], face_ids[:, 1], face_ids[:, 0])

    out = Path(args.out)/args.key
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.npz"):
        old.unlink()
    meta = {"key": args.key, "step": args.step, "bounds": [lo.tolist(), hi.tolist()], "groups": []}
    for gid, (name, ink) in GROUPS.items():
        sel = faces[major == gid]
        if len(sel) < 20:
            continue
        used, remap = np.unique(sel, return_inverse=True)
        np.savez_compressed(out/f"{name}.npz", verts=verts[used], faces=remap.reshape(-1, 3).astype("i4"),
                            albedo=np.clip(a0[used, :3], 0, 1).astype("f4"), emit=a1[used, :3].astype("f4"))
        emissive = float(np.percentile(a1[used, :3].max(axis=1), 95))
        meta["groups"].append({"name": name, "id": gid, "faces": int(len(sel)), "ink": ink, "emit95": emissive})
        print(f"  {name:8s} {len(sel):8d} faces  ink {ink:.3f}  emit95 {emissive:.2f}")
    (out/"meta.json").write_text(json.dumps(meta, indent=1))


if __name__ == "__main__":
    main()
