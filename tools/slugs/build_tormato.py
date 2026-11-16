"""Build Tormato's two final forms in Blender from his concept page (docs/slugs/catalog/evidence/tormato/).

Owner, 2026-11-15: both forms final; "build this design out in blendere too like u did with boon doc". As for
Boon Doc and Aquabeek (ADR 0033), the page's own shader is evaluated through headless Chrome (sample_concept.py)
rather than ported by hand: its distance field on a grid, meshed with surface nets; each vertex snapped onto the
surface; its colour and glow; and which part it belongs to (wings, horns, tail), for the rig later. The page's
time uniform is left at 0, and `REST 1` holds the transformed form straight with its wings level (at time 0 its
body wave and wing flap would still bend it), so this is the rest pose. The base form keeps its slight lean.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_tormato.py [-- base transformed]`

Writes assets/source/slugs/models/tormato/tormato-{base,transformed}.blend and ignored build/slugs/tormato/source/:
renders and report.json. Nothing is uploaded. Concept coordinates are y-up with the face toward +z; Blender gets
(x, -z, y).
"""
import json
import sys
import time
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_aquabeek as ba
import export_rammstone_roblox as er
import sample_concept as sc
from build_floppy import surface_nets
from common import ROOT

PAGE = ROOT/"docs/slugs/catalog/evidence/tormato/tormato.html"
TEMPLATE = ROOT/"tools/slugs/tormato_concept/template.html"
SOURCE = ROOT/"assets/source/slugs/models/tormato"
BUILD = ROOT/"build/slugs/tormato/source"
# Bounds: a 0.03 pass found base x -0.68..0.76, y 0.02..2.33, z -0.83..0.73 and transformed x -2.46..2.46,
# y 0.90..2.61, z -3.08..0.61; these add a margin. The base form stands on the ground (y 0).
FORMS = {
    "base": {
        "defines": {"PLAIN": 0, "XF": 0, "REST": 1},
        "bounds": ((-0.80, 0.86), (-0.04, 2.42), (-0.93, 0.83)),
        "step": 0.008,
        "name": "TormatoBody",
    },
    "transformed": {
        "defines": {"PLAIN": 0, "XF": 1, "REST": 1},
        "bounds": ((-2.56, 2.56), (0.80, 2.71), (-3.18, 0.71)),
        # A little coarser than the base, so the 5 x 2 x 4 box (51 million samples) stays within the owner's
        # free memory; still more than two samples across the thinnest wing membrane (0.020).
        "step": 0.009,
        "name": "TormatoTransformedBody",
    },
}

PROBES = """
float sdf(vec3 p) { return parts(deform(p)).x; }
vec3 sdfN(vec3 p) {
  const vec2 k = vec2(1.0, -1.0);
  const float h = 0.0012;
  return normalize(k.xyy*sdf(p + k.xyy*h) + k.yyx*sdf(p + k.yyx*h) + k.yxy*sdf(p + k.yxy*h) + k.xxx*sdf(p + k.xxx*h));
}
vec3 onSurface(vec3 p) {
  for (int i = 0; i < 3; i++) p -= sdf(p)*sdfN(p);
  return p;
}
float near(float d) { return 1.0 - smoothstep(0.004, 0.030, d); }
vec4 probe(vec3 p) {
#if PROBE == 0
  return pack24(sdf(p), 0.5);
#elif PROBE >= 10 && PROBE <= 12
  vec3 o = onSurface(p) - p;
  return pack24(PROBE == 10 ? o.x : (PROBE == 11 ? o.y : o.z), 0.05);
#elif PROBE == 2 || PROBE == 3 || PROBE == 20 || PROBE == 21
  // 20 and 21: the same at points near the surface (a game mesh's texels), snapped onto it first.
#if PROBE >= 20
  p = onSurface(p);
#endif
  vec3 dp = deform(p);
  vec3 glow;
  vec3 a;
  // As the page shades it: the teeth their own colour, everything else the skin's (the eyes seen from
  // straight in front, the page's default view ray).
  if (parts(dp).y > 2.5) {
    vec2 g = mouthCoord(dp);
    a = TEETHC*mix(0.55, 1.0, smoothstep(mouthBack(g.x) + 0.02, mouthBack(g.x) + 0.09, dp.z));
    glow = vec3(0.0);
  } else {
    a = skinAlbedo(dp, glow);
  }
#if PROBE == 2 || PROBE == 20
  return vec4(sqrt(clamp(a, 0.0, 1.0)), 1.0);
#else
  return vec4(sqrt(clamp(glow*0.5, 0.0, 1.0)), 1.0);
#endif
#else
  // Parts, for the rig: r wings, g horns, b tail (transformed only), a unused.
  vec3 q = deform(p);
  float h = near(min(hornDist(q, -1.0).x, hornDist(q, 1.0).x));
#if XF == 1
  float w = near(min(wing(q, -1.0).x, wing(q, 1.0).x));
  return vec4(w, h, smoothstep(0.0, 0.08, tailT(q.z))*(1.0 - w), 0.0);
#else
  return vec4(0.0, h, 0.0, 0.0);
#endif
#endif
}
"""


def unpack24_f32(data, range_):
    """sample_concept.unpack24 in float32 (exact for its 24-bit integers), halving the peak memory on a big grid."""
    n = data[..., 0].astype(np.float32)*65536.0
    n += data[..., 1].astype(np.float32)*256.0
    n += data[..., 2]
    n *= 2.0*range_/16777215.0
    n -= range_
    return n


def check_page():
    """The page is what gets sampled, so it must be built from the current template."""
    if PAGE.stat().st_mtime < TEMPLATE.stat().st_mtime:
        raise SystemExit("The concept page is older than its template: run "
                         "python tools/slugs/build_tormato_concept.py --no-render first")


def probe(form, which):
    check_page()
    return FORMS[form]["defines"] | {"PROBE": which}, PROBES


def sample_mesh(form):
    """Surface-nets mesh of the form's distance field, vertices snapped onto it. Concept coordinates."""
    t = time.time()
    defines, glsl = probe(form, 0)
    step = FORMS[form]["step"]
    xs, ys, zs, data = sc.sample_grid(PAGE, defines, glsl, FORMS[form]["bounds"], step)
    vals = unpack24_f32(data, 0.5)
    del data
    # Nothing may touch the box's sides, or the mesh would be cut open there.
    edge = min(vals[0].min(), vals[-1].min(), vals[:, 0].min(), vals[:, -1].min(), vals[:, :, 0].min(), vals[:, :, -1].min())
    assert edge > 0, f"{form} reaches the edge of its sampling box"
    verts, faces = surface_nets(xs, ys, zs, vals)
    del vals
    print(form, "surface nets", len(verts), "verts", len(faces), "quads", round(time.time() - t, 1), "s")
    off = np.stack([sc.unpack24(sc.sample_points(PAGE, *probe(form, 10 + a), verts), 0.05) for a in range(3)], 1)
    # A snap longer than a grid step has diverged (thin wing edges); leave those vertices where they are.
    bad = np.linalg.norm(off, axis=1) > step
    off[bad] = 0.0
    print(form, "snap offsets: mean", round(float(np.abs(off).mean()), 5), "diverged", int(bad.sum()))
    return verts + off, faces


def sample_attributes(form, verts):
    out = {}
    for name, which in (("colour", 2), ("glow", 3)):
        defines, glsl = probe(form, which)
        v = sc.sample_points(PAGE, defines, glsl, verts)[:, :3].astype(float)/255.0
        out[name] = v*v*(2.0 if name == "glow" else 1.0)
    defines, glsl = probe(form, 4)
    v = sc.sample_points(PAGE, defines, glsl, verts).astype(float)/255.0
    out["parts"] = v[:, :3]
    return out


def build(form):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    name = FORMS[form]["name"]
    verts, faces = sample_mesh(form)
    attrs = sample_attributes(form, verts)
    obj = ba.make_object(name, verts, faces, attrs)
    obj.data.materials.append(ba.review_material(name + "Review"))
    SOURCE.mkdir(parents=True, exist_ok=True)
    out = BUILD/form
    out.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.engine = "CYCLES"
    obj.rotation_euler.z = 3.14159265   # the review renders expect the face toward +Y, as the game export does
    bpy.context.view_layer.update()
    renders = er.renders(out)
    obj.rotation_euler.z = 0.0
    blend = SOURCE/f"tormato-{form}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    report = {"form": form, "page": str(PAGE.relative_to(ROOT)), "defines": FORMS[form]["defines"], "step": FORMS[form]["step"],
              "blend": str(blend.relative_to(ROOT)), "renders": renders, "tool": bpy.app.version_string,
              "objects": {obj.name: {"vertices": len(obj.data.vertices), "faces": len(obj.data.polygons),
                                     "boundsBlender": [co.min(0).round(3).tolist(), co.max(0).round(3).tolist()]}}}
    (out/"report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FORMS)
    for form in argv:
        build(form)


if __name__ == "__main__":
    main()
