"""Build Aquabeek's two final forms in Blender from her concept page (docs/slugs/catalog/evidence/aquabeek/b/).

Owner, 2026-11-14: "this is the design ... finalize this as a design, and then build out Aquabeek and ... get into
Roblox". Rather than porting the concept's shader to NumPy by hand, the page's own shader is evaluated through
headless Chrome (sample_concept.py): its distance field on a grid, meshed with surface nets; each vertex snapped
onto the surface; its colour and glow; and, on the transformed form, which blade it belongs to and how far along,
for the game rig. The sways are switched off (MOTION 0), so this is the rest pose.

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_aquabeek.py [-- base transformed]`

Writes assets/source/slugs/models/aquabeek/aquabeek-{base,transformed}.blend and ignored build/slugs/aquabeek/source/:
renders and report.json. Nothing is uploaded. Concept coordinates are y-up with the face toward +z; Blender gets
(x, -z, y).
"""
import json
import sys
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import export_floppy_roblox as ef
import export_rammstone_roblox as er
import sample_concept as sc
from build_floppy import surface_nets, to_blender
from common import ROOT

PAGE = ROOT/"docs/slugs/catalog/evidence/aquabeek/b/aquabeek-b.html"
TEMPLATE = ROOT/"tools/slugs/aquabeek_concept/template.html"
SOURCE = ROOT/"assets/source/slugs/models/aquabeek"
BUILD = ROOT/"build/slugs/aquabeek/source"
STEP = 0.008
MIN_ISLAND = 400  # faces; smaller loose pieces are sampling crumbs at blade tips
FORMS = {
    "base": {
        "defines": {"PROTO": 1, "FORM": 0, "FISH": 0, "FACE": 3, "MOTION": "0.0"},
        "rest": "p.z -= LEAN*smoothstep(0.3, 1.9, p.y);",   # her lean is part of the pose; the breathing is not
        "bounds": ((-1.05, 1.05), (-0.06, 2.30), (-1.00, 0.80)),
        "name": "AquabeekBody",
    },
    "transformed": {
        "defines": {"PROTO": 1, "FORM": 0, "FISH": 1, "FACE": 3, "FISHV": 4, "FMOUTH": 1, "MOTION": "0.0"},
        "rest": "",
        "bounds": ((-1.10, 1.10), (0.76, 2.50), (-2.66, 1.04)),
        "name": "AquabeekTransformedBody",
    },
}

PROBES = """
vec3 rest(vec3 p) { %(rest)s return p; }
float sdf(vec3 p) { return skin(rest(p)); }
vec3 sdfN(vec3 p) {
  const vec2 k = vec2(1.0, -1.0);
  const float h = 0.0012;
  return normalize(k.xyy*sdf(p + k.xyy*h) + k.yyx*sdf(p + k.yyx*h) + k.yxy*sdf(p + k.yxy*h) + k.xxx*sdf(p + k.xxx*h));
}
vec3 onSurface(vec3 p) {
  for (int i = 0; i < 3; i++) p -= sdf(p)*sdfN(p);
  return p;
}
vec4 probe(vec3 p) {
#if PROBE == 0
  return pack24(sdf(p), 0.5);
#elif PROBE >= 10 && PROBE <= 12
  // One axis of the snap onto the surface, at full precision (8 bits left rings in the shading).
  vec3 o = onSurface(p) - p;
  return pack24(PROBE == 10 ? o.x : (PROBE == 11 ? o.y : o.z), 0.05);
#elif PROBE == 2 || PROBE == 3 || PROBE == 20 || PROBE == 21
  // 20 and 21: the same at points near the surface (a game mesh's texels), snapped onto it first.
#if PROBE >= 20
  p = onSurface(p);
#endif
  vec3 n = sdfN(p);
  vec3 glow;
  vec3 a = skinAlbedo(rest(p), n, glow);
#if PROBE == 2 || PROBE == 20
  return vec4(sqrt(clamp(a, 0.0, 1.0)), 1.0);
#else
  return vec4(sqrt(clamp(glow*0.5, 0.0, 1.0)), 1.0);
#endif
#else
#if FISH == 1
  vec3 q = rest(p);
  vec3 w = wingFin(q, q.x < 0.0 ? -1.0 : 1.0);
  return vec4(1.0 - smoothstep(0.004, 0.030, w.x), clamp(w.y, 0.0, 1.0), w.z/2.0, 1.0);
#else
  return vec4(0.0);
#endif
#endif
}
"""


def check_page():
    """The page is what gets sampled, so it must be built from the current template."""
    if PAGE.stat().st_mtime < TEMPLATE.stat().st_mtime:
        raise SystemExit("The concept page is older than its template: run "
                         "python tools/slugs/build_aquabeek_concepts.py --only b first")


def probe(form, which):
    check_page()
    spec = FORMS[form]
    return spec["defines"] | {"PROBE": which}, PROBES % {"rest": spec["rest"]}


def sample_mesh(form):
    """Surface-nets mesh of the form's distance field, vertices snapped onto it. Concept coordinates."""
    t = time.time()
    defines, glsl = probe(form, 0)
    xs, ys, zs, data = sc.sample_grid(PAGE, defines, glsl, FORMS[form]["bounds"], STEP)
    vals = sc.unpack24(data, 0.5).astype(np.float32)
    del data
    verts, faces = surface_nets(xs, ys, zs, vals)
    del vals
    print(form, "surface nets", len(verts), "verts", len(faces), "quads", round(time.time() - t, 1), "s")
    off = np.stack([sc.unpack24(sc.sample_points(PAGE, *probe(form, 10 + a), verts), 0.05) for a in range(3)], 1)
    # A snap longer than a grid step has diverged (thin fin edges); leave those vertices where they are.
    bad = np.linalg.norm(off, axis=1) > STEP
    off[bad] = 0.0
    print(form, "snap offsets: mean", round(float(np.abs(off).mean()), 5), "diverged", int(bad.sum()))
    return verts + off, faces


def sample_attributes(form, verts):
    out = {}
    for name, which in (("colour", 2), ("glow", 3)):
        defines, glsl = probe(form, which)
        v = sc.sample_points(PAGE, defines, glsl, verts)[:, :3].astype(float)/255.0
        out[name] = v*v*(2.0 if name == "glow" else 1.0)
    if form == "transformed":
        defines, glsl = probe(form, 4)
        v = sc.sample_points(PAGE, defines, glsl, verts).astype(float)/255.0
        out["blade"] = v[:, :3]   # on a blade (0..1), how far along it, which blade /2
    return out


def make_object(name, verts, faces, attrs):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in to_blender(verts)], [], [tuple(f) for f in faces])
    mesh.validate()
    assert len(mesh.vertices) == len(verts), "validate changed the vertices"
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    # Drop loose crumbs and keep the vertex order in step with the attributes.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    seen, small = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        if len(island) < MIN_ISLAND:
            small += island
    keep = np.ones(len(bm.verts), bool)
    if small:
        bmesh.ops.delete(bm, geom=small, context="FACES_ONLY")
        loose = [v for v in bm.verts if not v.link_faces]
        for v in loose:
            keep[v.index] = False
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    # Surface nets leave the winding inconsistent, which shows as dark seams under smooth shading.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for key, value in attrs.items():
        value = value[keep]
        attr = mesh.color_attributes.new(key, "FLOAT_COLOR", "POINT")
        rgba = np.concatenate([value, np.ones((len(value), 1))], 1).astype(np.float32)
        attr.data.foreach_set("color", rgba.ravel())
    mesh.shade_smooth()
    print(name, "islands removed:", len(small), "faces")
    return obj


def review_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    col = nodes.new("ShaderNodeVertexColor")
    col.layer_name = "colour"
    glow = nodes.new("ShaderNodeVertexColor")
    glow.layer_name = "glow"
    links.new(col.outputs["Color"], shader.inputs["Base Color"])
    links.new(glow.outputs["Color"], shader.inputs["Emission Color"])
    shader.inputs["Emission Strength"].default_value = 1.0
    shader.inputs["Roughness"].default_value = 0.35
    return mat


def build(form):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    verts, faces = sample_mesh(form)
    attrs = sample_attributes(form, verts)
    obj = make_object(FORMS[form]["name"], verts, faces, attrs)
    obj.data.materials.append(review_material(FORMS[form]["name"] + "Review"))
    SOURCE.mkdir(parents=True, exist_ok=True)
    out = BUILD/form
    out.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.engine = "CYCLES"
    obj.rotation_euler.z = 3.14159265   # the review renders expect the face toward +Y, as the game export does
    bpy.context.view_layer.update()
    renders = er.renders(out)
    obj.rotation_euler.z = 0.0
    blend = SOURCE/f"aquabeek-{form}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    co = np.empty(len(obj.data.vertices)*3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    report = {"form": form, "page": str(PAGE.relative_to(ROOT)), "defines": FORMS[form]["defines"], "step": STEP,
              "vertices": len(obj.data.vertices), "faces": len(obj.data.polygons),
              "boundsBlender": [co.min(0).round(3).tolist(), co.max(0).round(3).tolist()],
              "blend": str(blend.relative_to(ROOT)), "renders": renders, "tool": bpy.app.version_string}
    (out/"report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(FORMS)
    for form in argv:
        build(form)


if __name__ == "__main__":
    main()
