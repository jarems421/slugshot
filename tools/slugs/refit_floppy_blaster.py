"""Shorten the existing private blaster grip without changing its upper housing.

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
import numpy as np

GRIP_TOP = 0.03
GRIP_LENGTH_SCALE = 0.82


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    data = json.loads(args.input.read_text(encoding="utf-8"))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    specs = []
    for item in data["meshes"]:
        points = np.array(item["vertices"]).reshape(-1, 3) + np.array(item["centre"])
        below = points[:, 1] < GRIP_TOP
        points[below, 1] = GRIP_TOP + (points[below, 1] - GRIP_TOP) * GRIP_LENGTH_SCALE
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
        normals /= np.linalg.norm(normals, axis=1)[:, None]
        normals = normals[:, [0, 2, 1]] * np.array([1, -1, 1])
        mesh.normals_split_custom_set_from_vertices(normals.tolist())
        obj = bpy.data.objects.new(item["name"], mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = (centre[0], -centre[2], centre[1])
        material = bpy.data.materials.new(item["name"])
        material.diffuse_color = (*[int(item["color"][i:i+2], 16) / 255 for i in (0, 2, 4)], 1)
        mesh.materials.append(material)
        specs.append({key: item[key] for key in ("name", "color", "material", "reflectance")}
                     | {"centre": centre.tolist(), "size": (upper - lower).tolist()})
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "mesh-specs.json").write_text(json.dumps(specs, indent=2) + "\n", encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output / "grip-shortened.blend"))
    bpy.ops.export_scene.gltf(filepath=str(args.output / "model.glb"), export_format="GLB",
                              export_yup=True, export_normals=True, export_materials="NONE")
    print("PASS: grip length scale", GRIP_LENGTH_SCALE, "meshes", len(specs))


if __name__ == "__main__":
    main()
