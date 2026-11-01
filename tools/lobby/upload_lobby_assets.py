"""Upload built lobby assets privately to the owner's Roblox account (owner-approved, 2026-11-01).

For each asset key: uploads <key>.glb as a Model and every colour/normal/emission map as an Image through
Open Cloud, reusing the reviewed Floppy client (API key from ROBLOX_API_KEY, never printed). Unchanged
files are skipped by content hash. Writes, all under ignored private-assets/lobby/:
  LobbyAssets.luau   model ids and per-group ink/emission settings for the look-test place
  materials.rbxmx    SurfaceAppearance templates (map setters are plugin-only, so the place clones these)
  uploads.json       hash cache

    python tools/lobby/upload_lobby_assets.py crystals-1 rock-wall-1 ...
"""

import hashlib
import importlib.util
import json
import sys
import time
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT/"private-assets/lobby"
EXPORT = ROOT/"build/lobby/export"


def load_client():
    spec = importlib.util.spec_from_file_location("private_upload", ROOT/"private-assets/floppy/upload_open_cloud.py")
    client = importlib.util.module_from_spec(spec)
    saved = sys.argv
    sys.argv = ["upload_open_cloud.py", "unused"]
    spec.loader.exec_module(client)
    sys.argv = saved
    return client


def upload(client, key, owner, path: Path, asset_type, display, content_type):
    request = {"assetType": asset_type, "displayName": display[:50],
               "description": "Slugshot lobby look test (private)",
               "creationContext": {"creator": {"userId": str(owner)}}}
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
            f'Content-Type: application/json\r\n\r\n{json.dumps(request)}\r\n'
            f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
            f'Content-Type: {content_type}\r\n\r\n').encode() + path.read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    op = client.call("POST", "https://apis.roblox.com/assets/v1/assets", key, body, "multipart/form-data; boundary=" + boundary)
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(90):
        if op.get("done"):
            break
        time.sleep(2)
        op = client.call("GET", "https://apis.roblox.com/assets/v1/operations/" + op_id, key)
    if not op.get("done") or op.get("error"):
        raise RuntimeError(f"Upload did not complete: {path.name}: {op.get('error')}")
    return int(op["response"]["assetId"])


def effect_points(k):
    """Where the look test puts lights and sparkles, in concept coordinates (studs, Y up).

    Crystals and glowing caps are grouped into cells; each cell becomes one point with its size and glow
    colour. The giant mushroom also gets its spore area: under the cap, across most of its radius.
    """
    meshes = ROOT/"build/lobby/meshes"/k
    data = {f.stem: np.load(f) for f in meshes.glob("*.npz")}
    allv = np.concatenate([d["verts"] for d in data.values()])
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    out = {"height": round(float(hi[1] - lo[1]), 3), "center": ((lo + hi)/2).tolist(), "points": []}
    for name, kind, cell in (("Crystal", "crystal", 2.0), ("GlowCap", "cap", 3.0), ("Gem", "gem", 6.0)):
        if name not in data:
            continue
        v, e = data[name]["verts"], data[name]["emit"]
        keys = np.floor(v/cell).astype(np.int64)
        _, inv = np.unique(keys, axis=0, return_inverse=True)
        for i in range(inv.max() + 1):
            sel = inv.ravel() == i
            if sel.sum() < 40:
                continue
            c = v[sel].mean(axis=0)
            col = e[sel].mean(axis=0)
            col = col/max(float(col.max()), 1e-3)
            out["points"].append({"kind": kind, "p": c.tolist(), "s": float(np.linalg.norm(v[sel] - c, axis=1).max()),
                                  "color": col.tolist()})
    if "Cap" in data and k.startswith("mushroom"):
        v = data["Cap"]["verts"]
        c = v.mean(axis=0)
        r = float(np.percentile(np.hypot(v[:, 0] - c[0], v[:, 2] - c[2]), 90))
        e = data["Cap"]["emit"]
        glow = e[e.max(axis=1) > 0.2].mean(axis=0)
        out["spores"] = {"p": [float(c[0]), float(np.percentile(v[:, 1], 15)), float(c[2])], "r": r*0.85,
                         "color": (glow/max(float(glow.max()), 1e-3)).tolist()}
    return out


def make_fx_textures(folder: Path):
    """A soft glowing spore dot and a four-point star twinkle (white, alpha-shaped; tinted in Roblox)."""
    from PIL import Image
    folder.mkdir(parents=True, exist_ok=True)
    n = 128
    y, x = np.mgrid[-1:1:n*1j, -1:1:n*1j]
    r = np.hypot(x, y)
    spore = np.clip(np.exp(-(r/0.32)**2) + 0.35*np.exp(-(r/0.75)**2), 0, 1)
    star = np.maximum(np.exp(-(np.abs(x)/0.05)**1.2 - (y/0.85)**2*4), np.exp(-(np.abs(y)/0.05)**1.2 - (x/0.85)**2*4))
    star = np.clip(np.maximum(star, np.exp(-(r/0.16)**2)) + 0.25*np.exp(-(r/0.5)**2), 0, 1)
    for name, a in (("spore", spore), ("twinkle", star)):
        rgba = np.zeros((n, n, 4), dtype="u1")
        rgba[..., :3] = 255
        rgba[..., 3] = (a*255).astype("u1")
        Image.fromarray(rgba, "RGBA").save(folder/f"{name}.png")


def main():
    keys = sys.argv[1:]
    PRIVATE.mkdir(parents=True, exist_ok=True)
    client = load_client()
    key = client.api_key()
    owner = json.loads((ROOT/"private-assets/floppy/roblox_assets.json").read_text())["owner"]
    cache_path = PRIVATE/"uploads.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}

    def cached(tag, path, asset_type, content_type):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if cache.get(tag, {}).get("sha256") == digest:
            return cache[tag]["id"]
        asset_id = upload(client, key, owner, path, asset_type, "Slugshot " + tag, content_type)
        cache[tag] = {"id": asset_id, "sha256": digest}
        cache_path.write_text(json.dumps(cache, indent=1))
        print(f"uploaded {tag}: {asset_type}", flush=True)
        return asset_id

    manifest = json.loads((PRIVATE/"manifest.json").read_text()) if (PRIVATE/"manifest.json").exists() else {}
    for k in keys:
        report = json.loads((EXPORT/k/"build.json").read_text())
        entry = {"model": cached(f"{k} model", EXPORT/k/f"{k}.glb", "Model", "model/gltf-binary"), "groups": {}}
        for g in report["groups"]:
            maps = {}
            for kind in ("color", "normal", "emit"):
                if kind in g:
                    maps[kind] = cached(f"{k} {g['name']} {kind}", EXPORT/k/g[kind], "Image", "image/png")
            entry["groups"][g["name"]] = {"maps": maps, "ink": g.get("inkShell"), "emissive": g.get("emissiveStrength", 0)}
        entry.update(effect_points(k))
        manifest[k] = entry
    (PRIVATE/"manifest.json").write_text(json.dumps(manifest, indent=1))
    fx_dir = ROOT/"build/lobby/fx"
    make_fx_textures(fx_dir)
    fx = {name: cached(f"fx {name}", fx_dir/f"{name}.png", "Image", "image/png") for name in ("spore", "twinkle")}

    def v3(p):
        return f"Vector3.new({p[0]:.3f}, {p[1]:.3f}, {p[2]:.3f})"

    lines = ["--!strict", "-- Private lobby look-test asset ids; never commit. Generated by tools/lobby/upload_lobby_assets.py.",
             "return {", f"\tfx = {{ spore = {fx['spore']}, twinkle = {fx['twinkle']} }},", "\tassets = {"]
    for k, e in manifest.items():
        lines.append(f'\t\t["{k}"] = {{ model = {e["model"]}, height = {e["height"]}, center = {v3(e["center"])},')
        lines.append("\t\t\tgroups = {")
        for name, g in e["groups"].items():
            ink = f'"{g["ink"]}"' if g["ink"] else "nil"
            lines.append(f'\t\t\t\t{name} = {{ ink = {ink}, emissive = {g["emissive"]} }},')
        lines.append("\t\t\t},")
        lines.append("\t\t\tpoints = {")
        for pt in e["points"]:
            c = pt["color"]
            lines.append(f'\t\t\t\t{{ kind = "{pt["kind"]}", p = {v3(pt["p"])}, s = {pt["s"]:.2f}, '
                         f'c = Color3.new({c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f}) }},')
        lines.append("\t\t\t},")
        if e.get("spores"):
            sp = e["spores"]
            sc = sp["color"]
            lines.append(f'\t\t\tspores = {{ p = {v3(sp["p"])}, r = {sp["r"]:.2f}, '
                         f'c = Color3.new({sc[0]:.3f}, {sc[1]:.3f}, {sc[2]:.3f}) }},')
        lines.append("\t\t},")
    lines += ["\t},", "}", ""]
    (PRIVATE/"LobbyAssets.luau").write_text("\n".join(lines), encoding="utf-8")

    doc = ET.Element("roblox", version="4")
    folder = ET.SubElement(doc, "Item", {"class": "Folder", "referent": "LobbyMaterials"})
    ET.SubElement(ET.SubElement(folder, "Properties"), "string", name="Name").text = "LobbyMaterials"
    for k, e in manifest.items():
        for name, g in e["groups"].items():
            item = ET.SubElement(folder, "Item", {"class": "SurfaceAppearance", "referent": f"{k}_{name}"})
            props = ET.SubElement(item, "Properties")
            ET.SubElement(props, "string", name="Name").text = f"{k}/{name}"
            for kind, prop in (("color", "ColorMap"), ("normal", "NormalMap")):
                if kind in g["maps"]:
                    content = ET.SubElement(props, "Content", name=prop)
                    ET.SubElement(content, "url").text = f"rbxassetid://{g['maps'][kind]}"
            if "emit" in g["maps"]:
                content = ET.SubElement(props, "Content", name="EmissiveMaskContent")
                ET.SubElement(content, "uri").text = f"rbxassetid://{g['maps']['emit']}"
    ET.ElementTree(doc).write(PRIVATE/"materials.rbxmx", encoding="utf-8", xml_declaration=True)
    print("PASS: lobby assets uploaded privately;", ", ".join(keys))


if __name__ == "__main__":
    main()
