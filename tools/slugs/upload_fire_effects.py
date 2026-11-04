"""Upload Inferno's 3D fire effects privately to the owner's account (owner-requested test asset).

Build them first in Blender with tools/slugs/build_wing_fire.py (wing fire) and the same script with --explosion. Ids go
into ignored private-assets/inferno/InfernoAsset.luau, and glowing SurfaceAppearance templates into its materials.rbxmx.
"""
import importlib.util
import re

import numpy as np
from PIL import Image
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRIVATE = ROOT/"private-assets/inferno"
BUILD = ROOT/"build/slugs/inferno"
FILES = {
    "comicWingFireModel": ("wing-fire/model.glb", "Model", "model/gltf-binary"),
    "comicWingFireImage": ("wing-fire/textures/wing-fire-color.png", "Image", "image/png"),
    "comicWingFireGlow": ("wing-fire/textures/wing-fire-glow.png", "Image", "image/png"),
    "comicExplosionModel": ("explosion/model.glb", "Model", "model/gltf-binary"),
    "comicExplosionImage": ("explosion/textures/explosion-color.png", "Image", "image/png"),
    "comicExplosionGlow": ("explosion/textures/explosion-glow.png", "Image", "image/png"),
    "comicEmber": ("embers/ember.png", "Image", "image/png"),
}


def draw_ember(path):
    """One comic ember: a round hot head and a tail thinning to a point, pale in the middle and orange at the edge,
    in hard bands with no ink line. The tail runs up the image, which particles turn to trail behind the ember."""
    width, height, scale = 64, 128, 4
    y, x = np.mgrid[0.0:1.0:height*scale*1j, -0.5:0.5:width*scale*1j]
    head = 0.8  # the head's centre, down the image
    radius = 0.21
    along = np.clip((head - y)/(head - 0.04), 0.0, 1.0)
    half = np.where(y >= head, np.sqrt(np.maximum(radius**2 - (y - head)**2*0.25, 0.0)), radius*(1.0 - along)**1.4)
    inside = np.abs(x) < half
    depth = 1.0 - np.abs(x)/np.maximum(half, 1e-4)
    rgb = np.zeros(x.shape + (3,))
    for start, colour in ((0.0, (255, 120, 30)), (0.35, (255, 200, 70)), (0.7, (255, 248, 210))):
        rgb[depth >= start] = np.array(colour)/255.0
    alpha = inside*1.0
    pixels = np.dstack([rgb*alpha[..., None], alpha])
    pixels = pixels.reshape(height, scale, width, scale, 4).mean(axis=(1, 3))
    cover = np.maximum(pixels[..., 3:], 1e-4)
    out = np.dstack([pixels[..., :3]/cover, pixels[..., 3:]])
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(out, 0, 1)*255).round().astype(np.uint8), "RGBA").save(path)


def main():
    spec = importlib.util.spec_from_file_location("upload_inferno", ROOT/"tools/slugs/upload_inferno.py")
    inferno = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(inferno)
    draw_ember(BUILD/"embers/ember.png")
    uploader = inferno.private_uploader()
    ids = {name: uploader(name, BUILD/path, kind, content) for name, (path, kind, content) in FILES.items()}
    module = PRIVATE/"InfernoAsset.luau"
    text = re.sub(r"\tcomic\w+ = \d+,\n", "", module.read_text(encoding="utf-8"))
    lines = "".join(f"\t{name} = {asset},\n" for name, asset in ids.items())
    module.write_text(text.replace("return {\n", "return {\n" + lines, 1), encoding="utf-8")
    materials = PRIVATE/"materials.rbxmx"
    tree = ET.parse(materials)
    folder = tree.getroot().find("Item")
    for item in list(folder):
        if item.get("referent") in inferno.FIRE_MATERIALS:
            folder.remove(item)
    inferno.add_fire_materials(folder, ids)
    tree.write(materials, encoding="utf-8", xml_declaration=True)
    print("PASS: fire effects uploaded and material templates written privately")


if __name__ == "__main__":
    main()
