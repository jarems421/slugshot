"""The slugs standing in the HUD's canisters, as sharp pictures (owner, 2026-11-15: the slugs in the canisters "look very
like low resolution and low quality", and later that the slugs in the lobby, about as small, look "pretty high quality").
A ViewportFrame draws with flat lighting and no smoothing, so a slug about 40 px tall came out jagged; the world renderer
the lobby uses lights, shades and smooths. The canister slugs stand still, so a picture of each, taken in the world,
serves.

Each is captured in a running client of the game place (Studio, through the MCP): the slug's icon model
(SlugVisuals.iconModel) far above the map, framed exactly as SlugIcon frames it (field of view 24, the same camera
direction and floor gap) so the whole window height is the canister's glass; a key and a fill point light and raised
ambient for the capture only; bloom and depth of field off; every screen GUI hidden. Behind it, an unlit backdrop
(a SurfaceGui with LightInfluence 0), captured once black and once white. Where the two differ the slug is see-through:
alpha = 1 - (white - black) / (white backdrop - black backdrop), measured from the corners, since the game's colour
grading turns pure white grey. Anything enclosed by a slug's outline is solid: Floppy's eye rings turn between the two
captures, which would otherwise read as holes.

Sizes (owner: Rammstone's is "a good size"; Floppy looked smaller than the rest; matching heights made Rammstone, whose
height is mostly horns, the smallest): Rammstone, Inferno and Aquabeek at the canister's fill of 0.6, Floppy at 0.68.

The capture lights lift every slug's colour about 15% over the viewport's; on Rammstone's strong red that read as
"way more vibrant" (owner, 2026-11-15), so TONE brings a slug's saturation and brightness back by hand.

The result is twice the canister glass (46 by 62), lightly sharpened; at four times, Roblox's own shrinking on screen
broke fine detail into noise.

Writes assets/source/ui/goo/canister-{slug}.png; upload with tools/ui/upload_goo_art.py.

`python tools/ui/build_canister_slugs.py [captures folder]` (default build/ui/canister-captures/world, holding
{slug}-black.jpg and {slug}-white.jpg)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"assets/source/ui/goo"
SLUGS = ("floppy", "inferno", "rammstone", "aquabeek")
GLASS = (46, 62)
SIZE = (92, 124)  # twice the canister glass
CLEAN = 0.04  # alpha this close to 0 or 1 is capture noise (the captures are JPEG)
EDGE = 3  # pixels inside the outline where the measured alpha is kept
# Saturation and brightness multipliers. Rammstone's saturation is matched to his viewport capture (0.555 / 0.665).
TONE = {"rammstone": (0.84, 0.92)}


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64)/255


def backdrop(image):
    """The backdrop's colour, from the four corners."""
    h, w, _ = image.shape
    corners = [image[:20, :20], image[:20, w - 20:], image[h - 20:, :20], image[h - 20:, w - 20:]]
    return np.mean([c.reshape(-1, 3).mean(axis=0) for c in corners], axis=0)


def shrink(channel):
    return np.asarray(Image.fromarray(channel.astype(np.float32), "F").resize(SIZE, Image.LANCZOS))


def picture(captures, slug):
    black = load(captures/f"{slug}-black.jpg")
    white = load(captures/f"{slug}-white.jpg")
    dark, light = backdrop(black), backdrop(white)
    alpha = np.clip(1 - ((white - black)/(light - dark)).mean(axis=2), 0, 1)
    alpha = np.where(alpha < CLEAN, 0, np.where(alpha > 1 - CLEAN, 1, alpha))
    solid = ndimage.binary_erosion(ndimage.binary_fill_holes(alpha > 0.5), iterations=EDGE)
    alpha = np.where(solid, 1, alpha)
    # The window's whole height is the glass; its width follows from the glass's shape.
    h, w = alpha.shape
    width = round(h*GLASS[0]/GLASS[1])
    left = (w - width)//2
    alpha = alpha[:, left:left + width]
    colour = np.clip(black[:, left:left + width] - (1 - alpha[..., None])*dark, 0, 1)  # premultiplied
    small = np.clip(np.dstack([shrink(colour[..., i]) for i in range(3)] + [shrink(alpha)]), 0, 1)
    # A light sharpen, still premultiplied, so the edges get no dark fringe.
    small = np.stack([np.asarray(Image.fromarray((small[..., i]*255).round().astype(np.uint8))
                                 .filter(ImageFilter.UnsharpMask(radius=0.8, percent=50, threshold=0)))/255
                      for i in range(4)], axis=2)
    small[..., :3] = np.minimum(small[..., :3], small[..., 3:4])
    a = small[..., 3:4]
    rgb = np.where(a > 0, np.clip(small[..., :3]/np.maximum(a, 1e-6), 0, 1), 0)
    if slug in TONE:
        saturation, brightness = TONE[slug]
        hsv = np.asarray(Image.fromarray((rgb*255).round().astype(np.uint8)).convert("HSV")).astype(np.float64)
        hsv[..., 1] *= saturation
        hsv[..., 2] *= brightness
        rgb = np.asarray(Image.fromarray(np.clip(hsv, 0, 255).round().astype(np.uint8), "HSV").convert("RGB"))/255
    path = OUT/f"canister-{slug}.png"
    Image.fromarray((np.dstack([rgb, a])*255).round().astype(np.uint8), "RGBA").save(path)
    return path


def main():
    captures = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT/"build/ui/canister-captures/world"
    for slug in SLUGS:
        print("built", picture(captures, slug).relative_to(ROOT))


if __name__ == "__main__":
    main()
