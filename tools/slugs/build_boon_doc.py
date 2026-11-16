"""Build Boon Doc's two final forms in Blender from his concept page (docs/slugs/catalog/evidence/boon-doc/).

Owner, 2026-11-14: both forms final; "Okay, build it in Blender. But not in Studio yet". As for Aquabeek (ADR 0033),
the page's own shader is evaluated through headless Chrome (sample_concept.py) rather than ported by hand: its
distance field on a grid, meshed with surface nets; each vertex snapped onto the surface; its colour and glow; and
which part it belongs to (wings, limbs, spines or antennae), for the rig later. The halo floats free, so it is its
own object. The page's time uniform is left at 0, where every sway and breath is at rest and only the base form's
forward lean remains, so this is the rest pose.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_boon_doc.py [-- base transformed]`

Writes assets/source/slugs/models/boon-doc/boon-doc-{base,transformed}.blend and ignored build/slugs/boon-doc/source/:
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

PAGE = ROOT/"docs/slugs/catalog/evidence/boon-doc/boon-doc.html"
TEMPLATE = ROOT/"tools/slugs/boon_doc_concept/template.html"
SOURCE = ROOT/"assets/source/slugs/models/boon-doc"
BUILD = ROOT/"build/slugs/boon-doc/source"
STEP = 0.008
PICKS = {"PLAIN": 0, "BODYV": 3, "EYEV": 2, "MOUTHV": 0, "BELLYV": 7}   # the page's picks; both forms use them
FORMS = {
    "base": {
        "defines": {"XF": 0} | PICKS,
        "bounds": ((-1.00, 1.00), (-0.04, 2.48), (-1.02, 0.86)),
        "halo": ((-0.50, 0.50), (2.24, 2.78), (-0.58, 0.40)),
        "name": "BoonDocBody",
    },
    "transformed": {
        "defines": {"XF": 1} | PICKS,
        "bounds": ((-1.40, 1.40), (0.30, 2.52), (-1.50, 1.36)),
        "halo": ((-0.50, 0.50), (2.18, 2.72), (0.12, 1.08)),
        "name": "BoonDocTransformedBody",
    },
}

PROBES = """
float sdf(vec3 p) {
#if HALO == 1
  return halo(deform(p)).x;
#else
  return skin(deform(p));
#endif
}
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
  vec3 n = sdfN(p);
  vec3 dp = deform(p);
  vec3 glow;
#if HALO == 1
  // As the page shades the halo: gold, brightest along the middle of the band.
  float hv = halo(dp).y;
  vec3 a = mix(GOLDC*0.85, vec3(1.0, 0.92, 0.70), exp(-pow((hv - 0.5)/0.22, 2.0))*0.6);
  glow = GOLDC*(0.55 + 0.35*exp(-pow((hv - 0.5)/0.20, 2.0)));
#else
  vec3 a = skinAlbedo(dp, n, glow);
#endif
#if PROBE == 2 || PROBE == 20
  return vec4(sqrt(clamp(a, 0.0, 1.0)), 1.0);
#else
  return vec4(sqrt(clamp(glow*0.5, 0.0, 1.0)), 1.0);
#endif
#else
  // Parts, for the rig: r wings, g arms, b legs, a spines (transformed) or antennae (base).
  vec3 q = deform(p);
  float w = near(min(angelWing(q, -1.0).x, angelWing(q, 1.0).x));
#if XF == 1
  return vec4(w, near(arms(q).x), near(legs(q)), near(spines(q).x));
#else
  return vec4(w, 0.0, 0.0, near(min(antennaDist(q, -1.0).x, antennaDist(q, 1.0).x)));
#endif
#endif
}
"""


def check_page():
    """The page is what gets sampled, so it must be built from the current template."""
    if PAGE.stat().st_mtime < TEMPLATE.stat().st_mtime:
        raise SystemExit("The concept page is older than its template: run "
                         "python tools/slugs/build_boon_doc_concept.py --no-render first")


def probe(form, which, halo=0):
    check_page()
    return FORMS[form]["defines"] | {"PROBE": which, "HALO": halo}, PROBES


def sample_mesh(form, halo=0):
    """Surface-nets mesh of the form's distance field, vertices snapped onto it. Concept coordinates."""
    t = time.time()
    bounds = FORMS[form]["halo" if halo else "bounds"]
    defines, glsl = probe(form, 0, halo)
    xs, ys, zs, data = sc.sample_grid(PAGE, defines, glsl, bounds, STEP)
    vals = sc.unpack24(data, 0.5).astype(np.float32)
    del data
    # Nothing may touch the box's sides, or the mesh would be cut open there.
    edge = min(vals[0].min(), vals[-1].min(), vals[:, 0].min(), vals[:, -1].min(), vals[:, :, 0].min(), vals[:, :, -1].min())
    assert edge > 0, f"{form} {'halo' if halo else 'body'} reaches the edge of its sampling box"
    verts, faces = surface_nets(xs, ys, zs, vals)
    del vals
    print(form, "halo" if halo else "body", "surface nets", len(verts), "verts", len(faces), "quads", round(time.time() - t, 1), "s")
    off = np.stack([sc.unpack24(sc.sample_points(PAGE, *probe(form, 10 + a, halo), verts), 0.05) for a in range(3)], 1)
    # A snap longer than a grid step has diverged (thin feather edges); leave those vertices where they are.
    bad = np.linalg.norm(off, axis=1) > STEP
    off[bad] = 0.0
    print(form, "snap offsets: mean", round(float(np.abs(off).mean()), 5), "diverged", int(bad.sum()))
    return verts + off, faces


def sample_attributes(form, verts, halo=0):
    out = {}
    for name, which in (("colour", 2), ("glow", 3)):
        defines, glsl = probe(form, which, halo)
        v = sc.sample_points(PAGE, defines, glsl, verts)[:, :3].astype(float)/255.0
        out[name] = v*v*(2.0 if name == "glow" else 1.0)
    if not halo:
        defines, glsl = probe(form, 4)
        v = sc.sample_points(PAGE, defines, glsl, verts).astype(float)/255.0
        out["parts"] = v[:, :3]
        out["parts2"] = np.repeat(v[:, 3:4], 3, 1)
    return out


def build(form):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    name = FORMS[form]["name"]
    objs = []
    for halo, obj_name in ((0, name), (1, name.replace("Body", "Halo"))):
        verts, faces = sample_mesh(form, halo)
        attrs = sample_attributes(form, verts, halo)
        obj = ba.make_object(obj_name, verts, faces, attrs)
        obj.data.materials.append(ba.review_material(obj_name + "Review"))
        objs.append(obj)
    SOURCE.mkdir(parents=True, exist_ok=True)
    out = BUILD/form
    out.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.engine = "CYCLES"
    for obj in objs:
        obj.rotation_euler.z = 3.14159265   # the review renders expect the face toward +Y, as the game export does
    bpy.context.view_layer.update()
    renders = er.renders(out)
    for obj in objs:
        obj.rotation_euler.z = 0.0
    blend = SOURCE/f"boon-doc-{form}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    report = {"form": form, "page": str(PAGE.relative_to(ROOT)), "defines": FORMS[form]["defines"], "step": STEP,
              "blend": str(blend.relative_to(ROOT)), "renders": renders, "tool": bpy.app.version_string, "objects": {}}
    for obj in objs:
        co = np.empty(len(obj.data.vertices)*3)
        obj.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        report["objects"][obj.name] = {"vertices": len(obj.data.vertices), "faces": len(obj.data.polygons),
                                       "boundsBlender": [co.min(0).round(3).tolist(), co.max(0).round(3).tolist()]}
    (out/"report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FORMS)
    for form in argv:
        build(form)


if __name__ == "__main__":
    main()
