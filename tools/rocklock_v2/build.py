"""Reproducible, upload-free Rocklock v2 place build (stdlib plus the existing Blender and Rojo).

python tools/rocklock_v2/build.py [--geometry] [--private]
--geometry regenerates the Blender rock skins (otherwise reused while layout and generator
hashes match). Writes build/rocklock-v2/generated/map.rbxmx, a spawn-adapted copy of the
movement server, stats.json, preview.json and build/SlugshotRocklockV2[Private].rbxlx.
The movement controller source is never edited; v1 (tools/rocklock) is untouched.
"""
import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "build/rocklock-v2"
sys.path.insert(0, str(HERE))
import layout as L  # noqa: E402

SPAWN = 'character:PivotTo(CFrame.new((player.UserId % 3) * 6 - 6, 5, 30))'
ADAPTER = 'character:PivotTo(require(script.RocklockSpawns).frameFor(player))'
PART_BUDGET = 9000


def run(*args):
    print("+ " + " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def blender():
    paths = sorted((ROOT / ".tools").glob("blender-*/blender.exe")) + sorted((ROOT / ".tools").glob("blender-*/blender"))
    if not paths:
        raise RuntimeError("Existing Blender required under .tools; nothing is installed by this script")
    return paths[-1]


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def mul(a, n): return tuple(x * n for x in a)
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return mul(a, 1 / math.sqrt(dot(a, a)))


def euler(yaw=0.0, pitch=0.0, roll=0.0):
    """Basis (right, up, back) for R = Ry(yaw) * Rx(pitch) * Rz(roll), degrees."""
    y, p, r = (math.radians(v) for v in (yaw, pitch, roll))
    def ry(v): return (v[0]*math.cos(y) + v[2]*math.sin(y), v[1], -v[0]*math.sin(y) + v[2]*math.cos(y))
    def rx(v): return (v[0], v[1]*math.cos(p) - v[2]*math.sin(p), v[1]*math.sin(p) + v[2]*math.cos(p))
    def rz(v): return (v[0]*math.cos(r) - v[1]*math.sin(r), v[0]*math.sin(r) + v[1]*math.cos(r), v[2])
    return tuple(ry(rx(rz(axis))) for axis in ((1, 0, 0), (0, 1, 0), (0, 0, 1)))


def triangle_wedges(a, b, c):
    # Split at the altitude to the longest edge; each half is one native WedgePart.
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
            result.append((mul(add(a, p), 0.5), [0.05, height, length], (r, up, z)))
    return result


def prop(props, kind, name, value):
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
    """Roblox AttributesSerialize: strings and booleans (numbers are written as strings)."""
    data = struct.pack("<I", len(values))
    for name, value in values.items():
        name_bytes = name.encode()
        data += struct.pack("<I", len(name_bytes)) + name_bytes
        if isinstance(value, bool):
            data += b"\x03" + bytes([value])
        else:
            encoded = str(value).encode()
            data += b"\x02" + struct.pack("<I", len(encoded)) + encoded
    prop(props, "BinaryString", "AttributesSerialize", base64.b64encode(data).decode())


def instance(parent, kind, name):
    item = ET.SubElement(parent, "Item", {"class": kind})
    props = ET.SubElement(item, "Properties")
    prop(props, "string", "Name", name)
    return item, props


def part(parent, name, position, size, color, collides, basis=None, kind="Part", transparency=0.0,
         attrs=None, query=None, shadow=None, material=800):
    item, props = instance(parent, kind, name)
    for key, value in [("Anchored", True), ("CanCollide", collides), ("CanQuery", collides if query is None else query),
                       ("CanTouch", False), ("CastShadow", (transparency == 0) if shadow is None else shadow)]:
        prop(props, "bool", key, value)
    prop(props, "Vector3", "size", size)
    prop(props, "CoordinateFrame", "CFrame", (position, basis or euler()))
    prop(props, "Color3", "Color", [v / 255 for v in color])
    prop(props, "float", "Transparency", transparency)
    prop(props, "token", "Material", material)  # 800 = built-in Slate
    prop(props, "token", "TopSurface", 0)
    prop(props, "token", "BottomSurface", 0)
    if attrs:
        attributes(props, attrs)
    return item


def tint(color, name, amount=6):
    h = int(hashlib.md5(name.encode()).hexdigest()[:6], 16)
    d = (h % (2 * amount + 1)) - amount
    return tuple(max(0, min(255, c + d)) for c in color)


def ramp_frame(item):
    a, b, t = item["start"], item["end"], item["thickness"]
    back = unit(sub(b, a))
    right = unit(cross((0, 1, 0), back))
    up = cross(back, right)
    centre = sub(mul(add(a, b), 0.5), mul(up, t / 2))
    return centre, (right, up, back)


def build_map(geology):
    document = ET.Element("roblox", version="4")
    map_, props = instance(document, "Model", "Rocklock")
    attributes(props, {"MapVersion": L.VERSION, "Seed": str(L.SEED), "Layout": "Rocklock v2"})
    counts = {"collision": 0, "visible_static": 0, "skin_wedges": 0, "chunks": 0}

    collision, _ = instance(map_, "Folder", "Collision")
    for item in L.STATIC:
        color = tint(L.PALETTE[item["color"]], item["name"])
        if item["kind"] == "ramp":
            centre, basis = ramp_frame(item)
        else:
            centre, basis = item["pos"], euler(item.get("yaw", 0.0))
        attrs = {"Essential": True, "Kind": item["kind"]}
        if item["run_faces"]:
            attrs["WallRunFace"] = ",".join(item["run_faces"])
        visible = item["visible"]
        part(collision, item["name"], centre, item["size"], color, True, basis,
             transparency=0 if visible else 1, attrs=attrs, shadow=visible or item["kind"] == "roof")
        counts["collision"] += 1
        counts["visible_static"] += 1 if visible else 0

    geology_folder, _ = instance(map_, "Folder", "Geology")
    for mesh in geology["meshes"]:
        model, _ = instance(geology_folder, "Model", mesh["name"])
        color = tint(tuple(mesh["color"]), mesh["name"], 5)
        for i, tri in enumerate(mesh["triangles"]):
            for j, (position, size, basis) in enumerate(triangle_wedges(*[tuple(v) for v in tri])):
                part(model, f"F{i}_{j}", position, size, color, False, basis, kind="WedgePart", query=False)
                counts["skin_wedges"] += 1

    destructibles, _ = instance(map_, "Folder", "Destructibles")
    for d in L.DESTRUCTIBLES:
        model, mprops = instance(destructibles, "Model", d["id"])
        attrs = {"Id": d["id"], "Category": d["category"], "Kind": d["kind"], "Material": d["material"],
                 "Health": str(d["health"]), "Stages": str(d["stages"])}
        if d["hazard"]:
            attrs.update({"HazardRadius": str(d["hazard"]["radius"]), "HazardDamage": str(d["hazard"]["damage"]),
                          "HazardWarning": str(d["hazard"]["warning"])})
        attributes(mprops, attrs)
        for c in d["chunks"]:
            color = tint(tuple(c["color"] or L.PALETTE["breakable"]), d["id"] + c["name"], 7)
            part(model, c["name"], c["pos"], c["size"], color, True, euler(c["yaw"], c["pitch"], c["roll"]),
                 kind="WedgePart" if c["shape"] == "Wedge" else "Part",
                 attrs={"Stage": str(c["stage"]), "Rubble": c["rubble"]})
            counts["chunks"] += 1

    zones, _ = instance(map_, "Folder", "TerrainZones")
    for z in L.TERRAIN:
        centre = mul(add(z["min"], z["max"]), 0.5)
        size = sub(z["max"], z["min"])
        part(zones, z["id"], centre, size, (122, 98, 74), False, transparency=1, query=False,
             attrs={"Id": z["id"], "Kind": z["kind"]})

    spawns, _ = instance(map_, "Folder", "Spawns")
    for s in L.SPAWNS:
        back = unit(sub(s["position"], s["look_at"]))
        right = unit(cross((0, 1, 0), back))
        up = cross(back, right)
        part(spawns, s["name"], s["position"], (6, 1, 6), (90, 140, 200), False, (right, up, back),
             transparency=1, query=False)

    lights, _ = instance(map_, "Folder", "Lights")
    ceiling = next(d for d in L.DECOR if d["type"] == "ceiling")
    for i, (x, z, r) in enumerate(ceiling["holes"]):
        for tag, y, rng, brightness in (("Shaft", 48.0, 44, 1.1), ("Bounce", 6.0, 30, 0.55)):
            holder = part(lights, f"{tag}{i}", (x, y, z), (1, 1, 1), (255, 236, 205), False, transparency=1, query=False)
            light, lprops = instance(holder, "PointLight", "Light")
            prop(lprops, "Color3", "Color", (1.0, 0.9, 0.76))
            prop(lprops, "float", "Brightness", brightness)
            prop(lprops, "float", "Range", rng)
            prop(lprops, "bool", "Shadows", False)

    return document, counts


def preview_rubble():
    """Approximate post-destruction rubble for the before/after renders (the game computes
    real landings at run time with raycasts)."""
    floor = {}
    boxes = [s for s in L.STATIC if s["kind"] != "ramp" and s["kind"] not in ("roof", "boundary", "bedrock")]
    def top_at(x, z, below):
        best = -10.0
        for s in boxes:
            (cx, cy, cz), (sx, sy, sz) = s["pos"], s["size"]
            top = cy + sy / 2
            if abs(x - cx) <= sx / 2 and abs(z - cz) <= sz / 2 and top <= below and top > best:
                best = top
        return best
    rubble = []
    for d in L.DESTRUCTIBLES:
        centre = mul(tuple(sum(c["pos"][i] for c in d["chunks"]) / len(d["chunks"]) for i in range(3)), 1)
        for c in d["chunks"]:
            if c["rubble"] != "Large" and d["kind"] != "Hanging":
                continue
            x, y, z = c["pos"]
            if d["kind"] != "Hanging":
                away = (x - centre[0], z - centre[2])
                n = math.hypot(*away) or 1.0
                push = 1.5 + math.sqrt(sum(v * v for v in c["size"])) * 0.25
                x, z = x + away[0] / n * push, z + away[1] / n * push
            bottom = top_at(x, z, y - c["size"][1] / 2 + 0.1)
            if d["kind"] == "Hanging":
                drop = min(cc["pos"][1] - cc["size"][1] / 2 for cc in d["chunks"]) - bottom
                rubble.append({"pos": (x, y - drop, z), "size": c["size"], "yaw": c["yaw"] + 25})
            else:
                rubble.append({"pos": (x, bottom + c["size"][1] / 2, z), "size": c["size"], "yaw": c["yaw"] + 30})
    return rubble


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--geometry", action="store_true", help="Regenerate Blender rock skins")
    parser.add_argument("--private", action="store_true", help="Also build the ignored private place")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    geo_path = OUT / "geology.json"
    fresh = geo_path.exists() and (lambda g: g["layout_sha256"] == sha(HERE / "layout.py")
                                   and g["generator_sha256"] == sha(HERE / "geology_blender.py"))(
        json.loads(geo_path.read_text()))
    if args.geometry or not fresh:
        run(blender(), "-b", "--factory-startup", "-P", HERE / "geology_blender.py", "--", HERE, geo_path)
    geology = json.loads(geo_path.read_text())
    document, counts = build_map(geology)
    generated = OUT / "generated"
    (generated / "server").mkdir(parents=True, exist_ok=True)
    ET.ElementTree(document).write(generated / "map.rbxmx", encoding="utf-8", xml_declaration=False)
    server = (ROOT / "experiments/movement/server/init.server.luau").read_text(encoding="utf-8")
    assert server.count(SPAWN) == 1, "Upstream spawn changed: review the map adapter before building"
    (generated / "server/init.server.luau").write_text(server.replace(SPAWN, ADAPTER), encoding="utf-8")
    total = counts["collision"] + counts["skin_wedges"] + counts["chunks"]
    assert total <= PART_BUDGET, f"Part budget exceeded: {total} > {PART_BUDGET}"
    stats = dict(counts, total_parts=total, version=L.VERSION, layout_sha256=sha(HERE / "layout.py"),
                 geology_sha256=sha(geo_path), movement_server_sha256=hashlib.sha256(server.encode()).hexdigest(),
                 structures=len(L.DESTRUCTIBLES), terrain_zones=len(L.TERRAIN), private_built=False)
    (OUT / "preview.json").write_text(json.dumps({"rubble": preview_rubble()}, indent=1))
    targets = [("rocklock-v2.project.json", "SlugshotRocklockV2")]
    if args.private:
        for needed in ("private-assets/generated/MovementClips.luau", "private-assets/generated/blaster/BlasterMesh.luau"):
            if not (ROOT / needed).is_file():
                raise RuntimeError(f"Private input missing: {needed}; build the public place instead")
        targets.append(("rocklock-v2.private.project.json", "SlugshotRocklockV2Private"))
        stats["private_built"] = True
    for project, name in targets:
        run("rojo", "build", project, "--output", f"build/{name}.rbxlx")
    (OUT / "stats.json").write_text(json.dumps(stats, indent=1))
    print("PASS: Rocklock v2 built:", json.dumps(stats))


if __name__ == "__main__":
    main()
