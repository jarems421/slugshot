"""Refine the existing private blaster with compact proportions and angular tips.

Run in Blender 4.5 with -- --input <private roblox_meshes.json> --output <build dir>.
The input is the owner's existing mesh data, never a bundled reference/download.
Output meshes retain material names; mesh-specs.json contains bounds, not asset IDs.
The additional 12% overall size reduction is applied by the runtime Tool.
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
import bmesh
import math
from mathutils import Vector
import numpy as np

GRIP_TOP = 0.03
GRIP_LENGTH_SCALE = 0.70
BARREL_START = -0.80
BARREL_LENGTH_SCALE = 0.96
# A longer run at the same tip height makes the downward cut shallower,
# without extending the point below the existing prong or closing the gap.
TIP_BEVEL_LENGTH = 0.24
TIP_EDGE_HEIGHT = 0.012

# Keep the orange identity, with a darker coated housing and clearer metal/grip
# separation. The spiral vanes emit; their recessed backplate keeps them legible.
FINISH = {
    "Orange": ("A9572C", "Metal", 0.02, 0.43, 0.0),
    "BodyGrey": ("363F48", "Metal", 0.04, 0.40, 1.0),
    "DarkGrey": ("252D34", "Metal", 0.02, 0.48, 1.0),
    "Steel": ("A2ABB1", "Metal", 0.12, 0.30, 1.0),
    "Black": ("20252A", "SmoothPlastic", 0.0, 0.65, 0.0),
    "GripNavy": ("252C31", "SmoothPlastic", 0.0, 0.80, 0.0),
    "GripBand": ("677078", "Metal", 0.04, 0.44, 1.0),
    "White": ("BAC0BC", "Metal", 0.02, 0.48, 0.0),
    "ChargerBlack": ("343D43", "Metal", 0.03, 0.42, 1.0),
    "ChargerVane": ("EBF0ED", "Neon", 0.0, 0.40, 0.0),
    "CyanGlow": ("A5CDD0", "Neon", 0.0, 0.40, 0.0),
}


def solid_barrel_tips(obj, points, tip_end):
    """Extend the existing housing cross-section into solid, unvented panels."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=5e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    plane = Vector((0, 1.20, 0))-obj.location
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                          plane_co=plane, plane_no=Vector((0, 1, 0)), dist=1e-7,
                          clear_outer=True, clear_inner=False)
    seam_vertices = [v for v in bm.verts if abs(v.co.y-plane.y) < 2e-6]
    bmesh.ops.remove_doubles(bm, verts=seam_vertices, dist=5e-4)
    seam = [e for e in bm.edges if e.is_boundary
            and all(abs(v.co.y-plane.y) < 2e-6 for v in e.verts)]
    assert seam, "Missing barrel cross-section"
    result = bmesh.ops.extrude_edge_only(bm, edges=seam)
    for vertex in result["geom"]:
        if isinstance(vertex, bmesh.types.BMVert):
            vertex.co.y = -tip_end-obj.location.y
    end = [e for e in bm.edges if e.is_boundary
           and all(abs(v.co.y+tip_end+obj.location.y) < 2e-6 for v in e.verts)]
    bmesh.ops.holes_fill(bm, edges=end, sides=0)
    assert not [e for e in bm.edges if e.is_boundary
                and all(abs(v.co.y+tip_end+obj.location.y) < 2e-6 for v in e.verts)], "Open solid panel"
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    current = np.array([(obj.location + v.co)[:] for v in obj.data.vertices])
    current = current[:, [0, 2, 1]] * np.array([1, 1, -1])
    bevel_barrel_tips(obj, current, tip_end)


def bevel_barrel_tips(obj, points, tip_end):
    """Cut downward muzzle planes, retaining the inner rails and firing gap."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    front_vertices = [v for v in bm.verts if -(v.co.y + obj.location.y) < tip_end + TIP_BEVEL_LENGTH + 0.01]
    bmesh.ops.remove_doubles(bm, verts=front_vertices, dist=1e-7)
    for upper_prong in (True, False):
        tip_points = points[(points[:, 2] < tip_end + TIP_BEVEL_LENGTH)
                            & ((points[:, 1] > 0.30) if upper_prong else (points[:, 1] < 0.30))]
        assert len(tip_points), "Missing barrel tip"
        low, high = float(tip_points[:, 1].min()), float(tip_points[:, 1].max())
        height = low + TIP_EDGE_HEIGHT
        slope = (high - height) / TIP_BEVEL_LENGTH
        # Plane in Blender (X,-Z,Y); discard the material above its downward cut.
        plane = Vector((0, -tip_end, height)) - obj.location
        normal = Vector((0, slope, 1)).normalized()
        faces = [f for f in bm.faces if ((f.calc_center_median().z + obj.location.z > 0.30) == upper_prong)]
        edges = {e for f in faces for e in f.edges}
        vertices = {v for f in faces for v in f.verts}
        bmesh.ops.bisect_plane(bm, geom=list(vertices) + list(edges) + faces,
                                        plane_co=plane, plane_no=normal, dist=1e-7,
                                        clear_outer=True, clear_inner=False)
        # Hard-normal seams duplicate vertices in the source. Weld the new
        # planar cut perimeter before capping so the tips remain solid.
        on_plane = [v for v in bm.verts
                    if abs(normal.dot(v.co - plane)) < 2e-6
                    and ((v.co.z + obj.location.z > 0.30) == upper_prong)]
        bmesh.ops.remove_doubles(bm, verts=on_plane, dist=5e-4)
        cut = [e for e in bm.edges if e.is_boundary
               and all(abs(normal.dot(v.co - plane)) < 2e-6 for v in e.verts)]
        if cut:
            bmesh.ops.holes_fill(bm, edges=cut, sides=0)
        assert not [e for e in bm.edges if e.is_boundary
                    and all(abs(normal.dot(v.co - plane)) < 2e-6 for v in e.verts)], "Open muzzle cap"
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(38))
    obj.select_set(False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    data = json.loads(args.input.read_text(encoding="utf-8"))
    original_end = min(m["centre"][2] + min(m["vertices"][2::3]) for m in data["meshes"])
    tip_end = BARREL_START + (original_end - BARREL_START) * BARREL_LENGTH_SCALE
    bpy.ops.wm.read_factory_settings(use_empty=True)
    specs = []
    for item in data["meshes"]:
        points = np.array(item["vertices"]).reshape(-1, 3) + np.array(item["centre"])
        below = points[:, 1] < GRIP_TOP
        points[below, 1] = GRIP_TOP + (points[below, 1] - GRIP_TOP) * GRIP_LENGTH_SCALE
        forward = points[:, 2] < BARREL_START
        points[forward, 2] = BARREL_START + (points[forward, 2] - BARREL_START) * BARREL_LENGTH_SCALE
        lower, upper = points.min(axis=0), points.max(axis=0)
        centre = (lower + upper) / 2
        relative = points - centre
        # Gun (X,Y,Z) -> Blender (X,-Z,Y).
        vertices = relative[:, [0, 2, 1]] * np.array([1, -1, 1])
        mesh = bpy.data.meshes.new(item["name"])
        mesh.from_pydata(vertices.tolist(), [], np.array(item["triangles"]).reshape(-1, 3).tolist())
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
        normals = np.array(item["normals"]).reshape(-1, 3)
        normals[below, 1] /= GRIP_LENGTH_SCALE
        normals[forward, 2] /= BARREL_LENGTH_SCALE
        normals /= np.linalg.norm(normals, axis=1)[:, None]
        normals = normals[:, [0, 2, 1]] * np.array([1, -1, 1])
        mesh.normals_split_custom_set_from_vertices(normals.tolist())
        obj = bpy.data.objects.new(item["name"], mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = (centre[0], -centre[2], centre[1])
        if item["name"] == "Orange":
            solid_barrel_tips(obj, points, tip_end)
            # Recompute exported dimensions from the cut geometry, retaining
            # exact correspondence between mesh coordinates and runtime bounds.
            local = np.array([v.co[:] for v in obj.data.vertices])
            points = local[:, [0, 2, 1]] * np.array([1, 1, -1]) + centre
            lower, upper = points.min(axis=0), points.max(axis=0)
            new_centre = (lower + upper) / 2
            shift = centre - new_centre
            for vertex in obj.data.vertices:
                vertex.co += Vector((shift[0], -shift[2], shift[1]))
            centre = new_centre
            obj.location = (centre[0], -centre[2], centre[1])
            obj.data.update()
        if item["name"] in {"BodyGrey", "DarkGrey", "Orange", "White", "GripNavy", "GripBand"}:
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            if obj.data.has_custom_normals:
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
            obj.data.shade_smooth()
            obj.data.set_sharp_from_angle(angle=math.radians(12))
            weighted = obj.modifiers.new("CrispPanelNormals", "WEIGHTED_NORMAL")
            weighted.keep_sharp = True
            weighted.mode = "FACE_AREA"
            bpy.ops.object.modifier_apply(modifier=weighted.name)
            mesh = obj.data
            obj.select_set(False)

        color, engine_material, reflectance, roughness, metallic = FINISH.get(
            item["name"], (item["color"], item["material"], item["reflectance"], 0.4, 0.0))
        material = bpy.data.materials.new(item["name"])
        material.use_nodes = True
        rgb = [int(color[i:i+2], 16) / 255 for i in (0, 2, 4)]
        linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
        material.diffuse_color = (*linear, 1)
        shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = (*linear, 1)
        shader.inputs["Roughness"].default_value = roughness
        shader.inputs["Metallic"].default_value = metallic
        if engine_material == "Neon":
            shader.inputs["Emission Color"].default_value = (*linear, 1)
            shader.inputs["Emission Strength"].default_value = 1.5
        mesh.materials.append(material)
        specs.append({"name": item["name"], "color": color, "material": engine_material,
                      "reflectance": reflectance, "centre": centre.tolist(), "size": (upper - lower).tolist()})
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "mesh-specs.json").write_text(json.dumps(specs, indent=2) + "\n", encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output / "grip-shortened.blend"))
    bpy.ops.export_scene.gltf(filepath=str(args.output / "model.glb"), export_format="GLB",
                              export_yup=True, export_normals=True, export_materials="NONE")
    print("PASS: grip scale", GRIP_LENGTH_SCALE, "barrel scale", BARREL_LENGTH_SCALE, "meshes", len(specs))


if __name__ == "__main__":
    main()
