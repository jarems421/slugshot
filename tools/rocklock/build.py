"""Reproducible, upload-free Rocklock place build; stdlib plus existing Blender/Rojo.

python tools/rocklock/build.py --render [--private]
python tools/rocklock/build.py --reuse-geometry [--private]

Source controller files are never edited. Only its original lab spawn expression
is replaced in an ignored generated copy, before authority initialization.
"""
import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/rocklock"
SOURCE = ROOT / "experiments/movement"
CONFIG = SOURCE / "rocklock/config.json"
SPAWN = 'character:PivotTo(CFrame.new((player.UserId % 3) * 6 - 6, 5, 30))'
ADAPTER = 'character:PivotTo(require(script.RocklockSpawns).frameFor(player))'


def run(*args):
    print("+ " + " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True)


def blender():
    explicit = os.environ.get("BLENDER")
    if explicit:
        return Path(explicit)
    paths = sorted((ROOT / ".tools").glob("blender-*/blender.exe")) + sorted((ROOT / ".tools").glob("blender-*/blender"))
    if not paths:
        raise RuntimeError("Existing Blender required: set BLENDER; no software is installed by this script")
    return paths[-1]


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def mul(a, n): return tuple(x * n for x in a)
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return mul(a, 1 / math.sqrt(dot(a, a)))


def triangle_wedges(a, b, c):
    # Split at the altitude to the longest edge. Each half is one native WedgePart.
    ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
    if dot(ab, ab) > max(dot(ac, ac), dot(bc, bc)):
        a, c = c, a
    elif dot(ac, ac) > max(dot(ab, ab), dot(bc, bc)):
        a, b = b, a
    ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
    normal = cross(ac, ab)
    if dot(normal, normal) < 1e-10:
        return []
    right, back = unit(normal), unit(bc)
    up = unit(cross(back, right))
    height = abs(dot(ab, up))
    result = []
    for p, r, z in [(b, right, back), (c, mul(right, -1), mul(back, -1))]:
        length = abs(dot(sub(p, a), back))
        if height > 0.01 and length > 0.01:
            result.append((mul(add(a, p), 0.5), [0.035, height, length], (r, up, z)))
    return result


def property_(props, kind, name, value):
    element = ET.SubElement(props, kind, name=name)
    if kind in {"Vector3", "Color3"}:
        for key, number in zip(("X", "Y", "Z") if kind == "Vector3" else ("R", "G", "B"), value):
            ET.SubElement(element, key).text = f"{number:.7g}"
    elif kind == "CoordinateFrame":
        position, (right, up, back) = value
        for key, number in zip(("X", "Y", "Z"), position):
            ET.SubElement(element, key).text = f"{number:.7g}"
        for row in range(3):
            for col, vector in enumerate((right, up, back)):
                ET.SubElement(element, f"R{row}{col}").text = f"{vector[row]:.9g}"
    else:
        element.text = str(value).lower() if isinstance(value, bool) else str(value)


def attributes(props, values):
    """Roblox AttributesSerialize v0; strings and booleans only."""
    data = struct.pack("<I", len(values))
    for name, value in values.items():
        name_bytes = name.encode()
        data += struct.pack("<I", len(name_bytes)) + name_bytes
        if isinstance(value, bool):
            data += b"\x03" + bytes([value])
        else:
            encoded = str(value).encode()
            data += b"\x02" + struct.pack("<I", len(encoded)) + encoded
    property_(props, "BinaryString", "AttributesSerialize", base64.b64encode(data).decode())


def instance(parent, kind, name):
    item = ET.SubElement(parent, "Item", {"class": kind})
    props = ET.SubElement(item, "Properties")
    property_(props, "string", "Name", name)
    return item, props


def rotation(yaw=0, pitch=0):
    y, p = math.radians(yaw), math.radians(pitch)
    return ((math.cos(y), 0, -math.sin(y)),
            (math.sin(y)*math.sin(p), math.cos(p), math.cos(y)*math.sin(p)),
            (math.sin(y)*math.cos(p), -math.sin(p), math.cos(y)*math.cos(p)))


def part(parent, name, position, size, color, collides, basis=None, kind="Part", transparency=0, attrs=None):
    item, props = instance(parent, kind, name)
    for prop, value in [("Anchored", True), ("CanCollide", collides), ("CanQuery", collides),
                        ("CanTouch", False), ("CastShadow", transparency == 0)]:
        property_(props, "bool", prop, value)
    property_(props, "Vector3", "size", size)
    property_(props, "CoordinateFrame", "CFrame", (position, basis or rotation()))
    property_(props, "Color3", "Color", [v / 255 for v in color])
    property_(props, "float", "Transparency", transparency)
    property_(props, "token", "Material", 800)  # Built-in Slate; no uploaded texture.
    property_(props, "token", "TopSurface", 0)
    property_(props, "token", "BottomSurface", 0)
    if attrs:
        attributes(props, attrs)
    return item


def crystal_point(v, placement):
    x, y, z = [n * placement["scale"] for n in v]
    orientation = placement["orientation"]
    # Local Y points out of the surface; rotations retain local cluster shape.
    transformed = {"west": (y, x, z), "east": (-y, x, -z),
                   "north": (x, z, y), "south": (-x, z, -y),
                   "ceiling": (x, -y, -z)}[orientation]
    return add(placement["position"], transformed)


def model(data, crystals):
    document = ET.Element("roblox", version="4")
    map_, props = instance(document, "Model", "Rocklock")
    attributes(props, {"MapVersion": str(data["config"]["version"]), "Seed": str(data["config"]["seed"]),
                       "ConfigSHA256": data["config_sha256"], "Prototype": True})
    collision, _ = instance(map_, "Folder", "Collision")
    groups = {}
    for spec in data["boxes"]:
        role = spec["role"]
        if role not in groups:
            groups[role], group_props = instance(collision, "Folder", role)
            if role == "Boundary":
                attributes(group_props, {"NoParkour": True})
        # A skinned block is only an authoring aid: the visible stone skin is
        # the collision surface, so an invisible box cannot bridge its dips.
        part(groups[role], spec["name"], spec["position"], spec["size"], spec["color"],
             role != "Spawn" and not spec.get("stone_skin"), rotation(spec["yaw"], spec["pitch"]),
             transparency=1 if spec.get("stone_skin") else 0,
             kind=spec.get("kind","Part"))
    art, _ = instance(map_, "Folder", "RockSilhouettes")
    rock_parts = 0
    solid_rock_parts = 0
    for spec in data["rocks"]:
        folder, folder_props = instance(art, "Model", spec["name"])
        solid = True
        if spec["group"] in {"Shell", "Roof"} or spec.get("collision", "").startswith(("SideBoundary", "EndBoundary", "CornerBoundary")):
            attributes(folder_props, {"NoParkour": True})
        for i, indices in enumerate(spec["triangles"]):
            vertices = [spec["vertices"][index] for index in indices]
            # Tiny consistent facet differences read in flat Studio lighting too.
            gain = 0.82 + (i % 7) * 0.045
            color = [min(255, round(v * gain)) for v in spec["color"]]
            for j, (pos, size, basis) in enumerate(triangle_wedges(*vertices)):
                part(folder, f"Facet{i}_{j}", pos, size, color, solid, basis, "WedgePart")
                rock_parts += 1
                solid_rock_parts += int(solid)
    spawns, _ = instance(map_, "Folder", "Spawns")
    for spec in data["config"]["spawns"]:
        direction = sub(spec["look_at"], spec["position"])
        yaw = math.degrees(math.atan2(-direction[0], -direction[2]))
        part(spawns, spec["name"], spec["position"], [1, 1, 1], [255, 255, 255],
             False, rotation(yaw), transparency=1, attrs={"Spawn": spec["name"]})
    markers, _ = instance(map_, "Folder", "InteractionMarkers")
    for spec in data["config"]["interactions"]:
        part(markers, spec["id"], spec["position"], spec["size"], [255, 180, 80], False,
             transparency=1, attrs={"InteractionId": spec["id"], "Kind": spec["kind"],
                                    "Target": spec["target"], "PreserveRoutes": spec["preserve"],
                                    "Enabled": False, "ServerAuthoritative": True, "ResetEachRound": True})
    crystal_folder, _ = instance(map_, "Folder", "CrystalFormations")
    variants = {v["name"]: v for v in crystals["variants"]}
    crystal_parts = 0
    for placement in crystals["placements"]:
        variant = variants[placement["variant"]]
        formation, formation_props = instance(crystal_folder, "Model", placement["name"])
        attributes(formation_props, {"Variant": variant["name"]})
        light_added = False
        for shard_index, shard in enumerate(variant["shards"]):
            for i, indices in enumerate(shard["triangles"]):
                vertices = [crystal_point(shard["vertices"][index], placement) for index in indices]
                gain = [0.62, 0.78, 0.9, 1.0, 1.13][(i // 3 + shard_index) % 5]
                color = [min(255, round(c * gain)) for c in variant["color"]]
                for j, (pos, size, basis) in enumerate(triangle_wedges(*vertices)):
                    facet = part(formation, f"Shard{shard_index}_Facet{i}_{j}", pos, size, color, False, basis, "WedgePart")
                    props = facet.find("Properties")
                    props.find("token[@name='Material']").text = "288"  # Neon, shaded per facet.
                    props.find("bool[@name='CastShadow']").text = "false"
                    crystal_parts += 1
                    if not light_added:
                        _, light_props = instance(facet, "PointLight", "CrystalLight")
                        property_(light_props, "Color3", "Color", [min(1, (c / 255) * 0.65 + 0.35) for c in variant["color"]])
                        property_(light_props, "float", "Brightness", 1.15 if placement["scale"] > 0.6 else 0.8)
                        property_(light_props, "float", "Range", 55 if placement["scale"] > 0.6 else 28)
                        property_(light_props, "bool", "Shadows", False)
                        light_added = True
        assert light_added, placement["name"]
    count = len(data["boxes"]) + rock_parts + crystal_parts + len(data["config"]["spawns"]) + len(data["config"]["interactions"])
    assert count <= data["config"]["native_part_budget"], f"Native part budget exceeded: {count}"
    return document, dict(parts=count, decorative_wedges=rock_parts, solid_rock_wedges=solid_rock_parts,
                          collision_parts=sum(s["role"] != "Spawn" and not s.get("stone_skin") for s in data["boxes"]),
                          rocks=len(data["rocks"]), triangles=sum(len(s["triangles"]) for s in data["rocks"]),
                          crystal_variants=len(variants), crystal_formations=len(crystals["placements"]), crystal_wedges=crystal_parts)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--private", action="store_true", help="Also build the ignored private-clip owner place")
    parser.add_argument("--reuse-geometry", action="store_true", help="Use cached Blender output only if inputs match")
    parser.add_argument("--output-suffix", default="", help="Optional output suffix such as -v3 to preserve another open place")
    args = parser.parse_args()
    if args.output_suffix and (not args.output_suffix.startswith("-") or not args.output_suffix[1:].replace("-", "").isalnum()):
        raise ValueError("Output suffix must start with '-' and contain only letters, numbers and hyphens")
    generated = OUT / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    if args.reuse_geometry:
        if args.render:
            raise ValueError("--render requires Blender; omit --reuse-geometry")
    else:
        command = [blender(), "--background", "--factory-startup", "--python-exit-code", "1",
                   "--python", ROOT / "tools/rocklock/blender_scene.py", "--", "--output", OUT]
        if args.render:
            command.append("--render")
        run(*command)
    data = json.loads((OUT / "geometry.json").read_text(encoding="utf-8"))
    for key, path in [("config_sha256", CONFIG), ("generator_sha256", ROOT / "tools/rocklock/blender_scene.py"),
                      ("layout_sha256", ROOT / "tools/rocklock/layout.py")]:
        assert data[key] == hashlib.sha256(path.read_bytes()).hexdigest(), f"Stale Blender geometry: {path}; regenerate"
    crystals = json.loads((OUT / "crystals/geometry.json").read_text(encoding="utf-8"))
    assert crystals["generator_sha256"] == hashlib.sha256((ROOT / "tools/rocklock/crystals_blender.py").read_bytes()).hexdigest(), "Stale crystal geometry; regenerate in Blender"
    tree, stats = model(data, crystals)
    ET.ElementTree(tree).write(generated / "map.rbxmx", encoding="utf-8", xml_declaration=True)
    server = (SOURCE / "server/init.server.luau").read_text(encoding="utf-8")
    assert server.count(SPAWN) == 1, "Upstream spawn changed: review the map adapter before building"
    server_dir = generated / "server"
    server_dir.mkdir(exist_ok=True)
    (server_dir / "init.server.luau").write_text(server.replace(SPAWN, ADAPTER), encoding="utf-8")
    for project, name in [("rocklock.project.json", "SlugshotRocklock"),
                          *(([("rocklock.private.project.json", "SlugshotRocklockPrivate")]) if args.private else [])]:
        if "private" in project and not (ROOT / "private-assets/generated/MovementClips.luau").is_file():
            raise RuntimeError("Private clips missing; build public Rocklock or follow existing movement private workflow")
        if "private" in project and not (ROOT / "private-assets/generated/blaster/BlasterMesh.luau").is_file():
            raise RuntimeError("Private blaster mesh missing; run private-assets/generated/blaster/make_module.py")
        run("rojo", "build", project, "--output", "build/" + name + args.output_suffix + ".rbxlx")
    stats.update(config_sha256=data["config_sha256"], blender=data["tool"], fbx_roundtrip=data["fbx_roundtrip"],
                 movement_server_sha256=hashlib.sha256(server.encode()).hexdigest(),
                 movement_adapter="Only initial spawn expression; all movement behaviour is unchanged",
                 private_built=args.private)
    (OUT / "build-report.json").write_text(json.dumps(stats, indent=2) + "\n", encoding="utf-8")
    (OUT / "layout.json").write_text(json.dumps({k:v for k,v in data.items() if k in {"config", "boxes"}}, indent=2), encoding="utf-8")
    # Editable original art and the reviewed export follow the repository convention.
    source_dir = ROOT / "assets/source/environment/rocklock-cavern"
    export_dir = ROOT / "assets/exports/environment/rocklock-cavern"
    source_dir.mkdir(parents=True, exist_ok=True)
    export_dir.mkdir(parents=True, exist_ok=True)
    for path, dest in ([] if args.reuse_geometry else [(OUT / "rocklock.blend", source_dir / "rocklock.blend"),
                       (OUT / "rocklock-rocks.fbx", export_dir / "rocklock-rocks.fbx")]):
        if not dest.exists() or path.read_bytes() != dest.read_bytes():
            shutil.copyfile(path, dest)
    if args.reuse_geometry:
        print("PASS: Rocklock built: " + json.dumps(stats))
        return
    asset_report = dict(creator="Original Slugshot procedural geometry", third_party_art=False,
                        tool=data["tool"], seed=data["config"]["seed"], config_sha256=data["config_sha256"],
                        fbx_roundtrip=data["fbx_roundtrip"], uploaded=False,
                        source_sha256=hashlib.sha256((source_dir / "rocklock.blend").read_bytes()).hexdigest(),
                        export_sha256=hashlib.sha256((export_dir / "rocklock-rocks.fbx").read_bytes()).hexdigest())
    (export_dir / "export.json").write_text(json.dumps(asset_report, indent=2) + "\n", encoding="utf-8")
    print("PASS: Rocklock built: " + json.dumps(stats))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, AssertionError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
