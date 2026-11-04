"""Upload Inferno's two forms and their image maps as private assets on the owner's account (owner-requested test).

Reads build/slugs/inferno/{base,dragon}. The Roblox API key comes from the existing private client and is never
printed. Identical files reuse earlier uploads. Ids and material templates stay in ignored private-assets/inferno.
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
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT/"private-assets/inferno"
CLIENT = ROOT/"private-assets/floppy/upload_open_cloud.py"
BUILD = ROOT/"build/slugs/inferno"
# Emissive mask value on plain skin; InfernoAppearance divides its visibility floor by this, as Floppy's does.
EMISSIVE_FLOOR = 0.05
FORMS = {"base": ("InfernoBody", "inferno-base"), "dragon": ("InfernoDragonBody", "inferno-dragon")}


def flame_sprite(path):
    """The glow round the tail flame: its outline grown soft and running back past the point. Runs down the image, as a Beam maps it."""
    width, height = 512, 256
    v, u = np.mgrid[1.0:-1.0:height*1j, 0.0:1.0:width*1j]

    def ramp(a, b, x):
        t = np.clip((x - a)/(b - a), 0.0, 1.0)
        return t*t*(3.0 - 2.0*t)
    # In concept units: the image covers 2.2 along the flame and 1.1 across. The flame itself starts 0.45 up the tail and is 1.9 long.
    at = np.clip((-0.35 + 2.2*u + 0.45)/1.9, 0.0, 1.0)
    half = (0.51*(at + 0.03)**0.42*(1.0 - at)**0.95*1.35 + 0.06*(1.0 - ramp(0.6, 0.84, u)))/0.55
    half = half*(1.0 + 0.10*np.sin(u*19.0 + np.sign(v)*1.2) + 0.06*np.sin(u*37.0))
    across = np.abs(v)/np.maximum(half, 1e-3)
    alpha = 0.9*(1.0 - ramp(0.35, 1.0, across))*ramp(0.0, 0.15, u)
    inner, outer, point = np.array([255.0, 135.0, 30.0]), np.array([225.0, 50.0, 12.0]), np.array([180.0, 28.0, 8.0])
    rgb = inner + (outer - inner)*ramp(0.2, 0.85, across)[..., None]
    rgb = rgb + (point - rgb)*ramp(0.6, 0.95, u)[..., None]
    pixels = np.dstack([rgb, alpha*255.0]).round().astype(np.uint8)
    Image.fromarray(np.rot90(pixels, -1), "RGBA").save(path)


# Glowing templates for the fire effects (tools/slugs/upload_fire_effects.py): name, colour, glow mask, see-through tips.
FIRE_MATERIALS = {"InfernoWingFire": ("comicWingFireImage", "comicWingFireGlow", True),
                  "InfernoExplosion": ("comicExplosionImage", "comicExplosionGlow", False)}


def add_fire_materials(folder, ids):
    """SurfaceAppearance templates for the fire effects, from whichever of their ids are known."""
    for name, (colour, glow, see_through) in FIRE_MATERIALS.items():
        if colour not in ids or glow not in ids:
            continue
        item = ET.SubElement(folder, "Item", {"class": "SurfaceAppearance", "referent": name})
        properties = ET.SubElement(item, "Properties")
        ET.SubElement(properties, "string", name="Name").text = name
        ET.SubElement(ET.SubElement(properties, "Content", name="ColorMap"), "url").text = f"rbxassetid://{ids[colour]}"
        ET.SubElement(ET.SubElement(properties, "Content", name="EmissiveMaskContent"), "uri").text = f"rbxassetid://{ids[glow]}"
        if see_through:
            ET.SubElement(properties, "token", name="AlphaMode").text = "1"  # Transparency


def private_uploader():
    """An upload(name, path, asset_type, content_type) function that returns the asset id and skips identical files."""
    PRIVATE.mkdir(parents=True, exist_ok=True)
    sys.argv = ["upload_open_cloud.py", str(BUILD/"base/model.glb")]
    spec = importlib.util.spec_from_file_location("private_upload", CLIENT)
    client = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(client)
    key = client.api_key()
    owner = client.USER_ID
    cache_path = PRIVATE/"assets.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}

    def upload(name, path, asset_type, content_type):
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if cache.get(name, {}).get("sha256") == digest:
            return cache[name]["id"]
        request = {"assetType": asset_type, "displayName": "Inferno " + name, "description": "Slugshot private test asset",
                   "creationContext": {"creator": {"userId": str(owner)}}}
        boundary = uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
                f'Content-Type: application/json\r\n\r\n{json.dumps(request)}\r\n'
                f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
                f'Content-Type: {content_type}\r\n\r\n').encode() + data + f'\r\n--{boundary}--\r\n'.encode()
        operation = client.call("POST", "https://apis.roblox.com/assets/v1/assets", key, body,
                                "multipart/form-data; boundary=" + boundary)
        operation_id = operation.get("operationId") or operation.get("path", "").split("/")[-1]
        for _ in range(90):
            if operation.get("done"):
                break
            time.sleep(2)
            operation = client.call("GET", "https://apis.roblox.com/assets/v1/operations/" + operation_id, key)
        if not operation.get("done") or operation.get("error"):
            raise RuntimeError("Upload did not complete: " + name)
        cache[name] = {"id": int(operation["response"]["assetId"]), "sha256": digest}
        cache_path.write_text(json.dumps(cache, indent=2) + "\n", encoding="utf-8")
        print("Uploaded:", name, flush=True)
        return cache[name]["id"]
    return upload


def main():
    upload = private_uploader()
    cache_path = PRIVATE/"assets.json"
    cache = json.loads(cache_path.read_text())
    sprite = PRIVATE/"flame-sprite.png"
    flame_sprite(sprite)
    flame = upload("flameSprite", sprite, "Image", "image/png")
    floor = round(EMISSIVE_FLOOR*255)
    document = ET.Element("roblox", version="4")
    folder = ET.SubElement(document, "Item", {"class": "Folder", "referent": "materials"})
    ET.SubElement(ET.SubElement(folder, "Properties"), "string", name="Name").text = "InfernoMaterials"
    lines = ["--!strict", "-- Private model ids, image ids and face rig numbers; never commit.", "return {", f"\tflame = {flame},"]
    # Made by upload_fire_effects.py; kept when the rest of this file is rewritten.
    lines += [f"\t{name} = {cache[name]['id']}," for name in cache if name.startswith("comic")]
    for form, (mesh, stem) in FORMS.items():
        textures = BUILD/form/"textures"
        with Image.open(textures/(stem + "-glow.png")) as glow:
            glow.convert("L").point(lambda v: max(v, floor)).save(textures/(stem + "-emissive.png"))
        with Image.open(textures/(stem + "-roughness.png")) as rough:
            rough.getchannel("G").save(textures/(stem + "-roughness-gray.png"))
        ids = {prop: upload(f"{form}-{suffix}", textures/f"{stem}-{suffix}.png", "Image", "image/png")
               for prop, suffix in (("ColorMap", "color"), ("NormalMap", "normal"), ("RoughnessMap", "roughness-gray"),
                                    ("EmissiveMaskContent", "emissive"))}
        model = upload(form + "-model", BUILD/form/"model.glb", "Model", "model/gltf-binary")
        item = ET.SubElement(folder, "Item", {"class": "SurfaceAppearance", "referent": mesh})
        properties = ET.SubElement(item, "Properties")
        ET.SubElement(properties, "string", name="Name").text = mesh
        for prop, value in ids.items():
            content = ET.SubElement(properties, "Content", name=prop)
            ET.SubElement(content, "uri" if prop == "EmissiveMaskContent" else "url").text = f"rbxassetid://{value}"
        prefix = "Inferno" if form == "base" else "InfernoDragon"
        with Image.open(textures/f"{stem}-eyes-glow.png") as glow:
            glow.convert("L").save(textures/f"{stem}-eyes-emissive.png")
        with Image.open(textures/f"{stem}-mouth-glow.png") as glow:
            glow.convert("L").save(textures/f"{stem}-mouth-emissive.png")
        parts = {prefix + "Eyes": {"ColorMap": upload(f"{form}-eyes", textures/f"{stem}-eyes-color.png", "Image", "image/png"),
                                   "EmissiveMaskContent": upload(f"{form}-eyes-glow", textures/f"{stem}-eyes-emissive.png", "Image", "image/png")},
                 prefix + "Mouth": {"ColorMap": upload(f"{form}-mouth", textures/f"{stem}-mouth.png", "Image", "image/png"),
                                    "EmissiveMaskContent": upload(f"{form}-mouth-glow", textures/f"{stem}-mouth-emissive.png", "Image", "image/png")}}
        for part, maps in parts.items():
            item = ET.SubElement(folder, "Item", {"class": "SurfaceAppearance", "referent": part})
            properties = ET.SubElement(item, "Properties")
            ET.SubElement(properties, "string", name="Name").text = part
            for prop, value in maps.items():
                content = ET.SubElement(properties, "Content", name=prop)
                ET.SubElement(content, "uri" if prop == "EmissiveMaskContent" else "url").text = f"rbxassetid://{value}"
        rig = json.loads((BUILD/form/"export-report.json").read_text())["faceRig"]
        lines.append(f"\t{form} = {{")
        lines.append(f"\t\tmodel = {model},")
        lines.append(f"\t\teyeAxis = Vector3.new({', '.join(str(v) for v in rig['eyeAxis'])}),")
        lines.append("		mouth = {")
        for bone, delta in rig["mouth"].items():
            lines.append(f"			{bone} = Vector3.new({', '.join(str(v) for v in delta)}),")
        lines.append("		},")
        lines.append("\t},")
    lines += ["}", ""]
    (PRIVATE/"InfernoAsset.luau").write_text("\n".join(lines), encoding="utf-8")
    add_fire_materials(folder, {name: item["id"] for name, item in cache.items()})
    ET.ElementTree(document).write(PRIVATE/"materials.rbxmx", encoding="utf-8", xml_declaration=True)
    print("PASS: Inferno assets and material templates written privately")


if __name__ == "__main__":
    main()
