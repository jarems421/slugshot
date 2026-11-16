"""The HUD canister slugs' idle as looping flipbooks (owner, 2026-11-15: "idle breathing chilling animations, idle facial
expressions"; the canister had to stay as sharp as the stills, tools/ui/build_canister_slugs.py, which ruled out a live
3D view).

Each slug's idle (experiments/combat/client/SlugIdle.luau, a LOOP-second loop) is captured in a running client of the
game place, in the world renderer: 44 copies of the slug in an 11 by 4 grid, each posed at its own frame time, framed
exactly as a canister frames it (field of view 24's direction, the same floor gap and fill), filmed from far away with
a long lens so every copy is seen alike, lit by the sun from the stills' key-light direction (point lights would spill
onto the neighbours), warm-white, with raised ambient. Every copy must render alike, or the loop flickers between batches
("the lighting continuously changes ... like clips", owner, 2026-11-16): the atmosphere off (its glare darkened the right
of the screen by 8%), environment lighting and shadows off, the camera's Focus on the slugs (left at the player, Roblox
drew some copies at a lower detail level, which read as a shadow on Inferno), the game's colour grade kept, blur and bloom
off, screen GUIs hidden, and nothing else animating the copies on its own clock (FloppyFace and FloppyIdle follow the
model's IdlePhase). Each batch is captured on an unlit black backdrop and again on white; transparency comes from the
difference, as for the stills. Batches of 44: b0/w0 frames 0-43, b1/w1 44-87, and so on.

Rows fill the window's height exactly; columns are the glass's shape, centred. Each frame is shrunk to twice the
glass (92 by 124, as the stills): 176 frames (about 29 a second; 12 read as choppy), packed 88 to a 1024 sheet, 11 to a
row, read left to right, top to bottom. TONE as for the stills.

Writes assets/source/ui/goo/canister-{slug}-idle-{1,2}.png (twice the glass) and canister-{slug}-idle-small.png (the
glass's design size, for screens where the glass is near it); upload with tools/ui/upload_goo_art.py.

`python tools/ui/build_canister_flipbooks.py [slug ...]` (captures in build/ui/canister-captures/flip/{slug}/)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT/"build/ui/canister-captures/flip"
OUT = ROOT/"assets/source/ui/goo"
GLASS = (46, 62)
FRAME = (92, 124)
ROWS, COLS, BATCHES = 4, 11, 4
FRAMES = 176
SHEET = 1024
PER_ROW = SHEET//FRAME[0]  # 11
PER_SHEET = PER_ROW*(SHEET//FRAME[1])  # 88
CLEAN, EDGE = 0.04, 3
SMALL_HOLE = 120  # capture pixels
CAL_BLUR = 3  # capture pixels
# Pixel-exact frames for the glass at its design size (owner, 2026-11-16: the slugs "look too low resolution and not
# crisp enough", without making the HUD bigger): shrunk here with a good filter and sharpened, so Roblox draws them
# one to one instead of shrinking the 2x frames on the fly. 176 of them, 22 to a row, fill one 1024 sheet.
SMALL = GLASS
SMALL_PER_ROW = 22
# A thin dark ink outline round the silhouette, as the style guide asks for creatures; Floppy has his own.
INK = np.array([0.06, 0.05, 0.10])
OUTLINED = {"inferno", "rammstone", "aquabeek", "tormato", "boondoc"}
# Saturation and brightness, as for the stills; Floppy's brought back to his still's (owner, 2026-11-16: his green "way
# too bright"; the loops' stronger light had lifted it from 0.73 to 0.84).
TONE = {"rammstone": (0.84, 0.92), "floppy": (0.94, 0.865)}


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64)/255


def shrink(channel, size):
    return np.asarray(Image.fromarray(channel.astype(np.float32), "F").resize(size, Image.LANCZOS))


def fill_small_holes(mask):
    """Closes small holes only (Floppy's eye rings turn between the black and white captures and would read as
    holes); a real opening like Boon Doc's halo stays open."""
    holes = ndimage.binary_fill_holes(mask) & ~mask
    labels, count = ndimage.label(holes)
    if count:
        sizes = ndimage.sum(holes, labels, range(1, count + 1))
        small = np.isin(labels, np.nonzero(sizes < SMALL_HOLE)[0] + 1)
        mask = mask | small
    return mask


def cells(black, white):
    """Each cell's premultiplied colour and alpha, row by row."""
    h, w, _ = black.shape
    dark = black[:12, :12].reshape(-1, 3).mean(0)
    light = white[:12, :12].reshape(-1, 3).mean(0)
    alpha = np.clip(1 - ((white - black)/(light - dark)).mean(axis=2), 0, 1)
    alpha = np.where(alpha < CLEAN, 0, np.where(alpha > 1 - CLEAN, 1, alpha))
    row_h = h/ROWS
    col_w = row_h*GLASS[0]/GLASS[1]
    left = (w - col_w*COLS)/2
    # Every cell is sampled at its exact place on a grid of one fixed size, rather than cut at rounded pixels: the
    # rounding moved the slug by fractions of a pixel from one cell to the next, which read as jitter bigger than the
    # motion itself (owner, 2026-11-16: "really poor stocky transitions").
    ch, cw = int(row_h), int(col_w)
    gy, gx = np.mgrid[0:ch, 0:cw].astype(np.float64)
    out = []
    for r in range(ROWS):
        for c in range(COLS):
            ys = r*row_h + (gy + 0.5)*row_h/ch - 0.5
            xs = left + c*col_w + (gx + 0.5)*col_w/cw - 0.5

            def sample(channel):
                return ndimage.map_coordinates(channel, [ys, xs], order=3, mode="nearest")
            a = np.clip(sample(alpha), 0, 1)
            solid = ndimage.binary_erosion(fill_small_holes(a > 0.5), iterations=EDGE)
            a = np.where(solid, 1, a)
            colour = np.clip(np.stack([sample(black[..., k]) for k in range(3)], -1) - (1 - a[..., None])*dark, 0, 1)
            out.append((colour, a))
    return out


def frame(colour, alpha, slug):
    small = np.clip(np.dstack([shrink(colour[..., i], FRAME) for i in range(3)] + [shrink(alpha, FRAME)]), 0, 1)
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
    return np.dstack([rgb, a])


def premultiply(f):
    return np.dstack([f[..., :3]*f[..., 3:], f[..., 3:]])


def unpremultiply(pm):
    a = pm[..., 3:]
    return np.dstack([np.where(a > 0, np.clip(pm[..., :3]/np.maximum(a, 1e-6), 0, 1), 0), a])


def outline(f, reach):
    a = f[..., 3]
    ring = np.clip(ndimage.grey_dilation(a, size=(reach, reach)) - a, 0, 1)*0.85
    new = a + ring*(1 - a)
    rgb = (f[..., :3]*a[..., None] + INK*(ring*(1 - a))[..., None])/np.maximum(new, 1e-6)[..., None]
    return np.dstack([np.clip(rgb, 0, 1), new])


def small_frame(f):
    pm = premultiply(f)
    pm = np.stack([shrink(pm[..., i], SMALL) for i in range(4)], -1)
    pm = np.stack([np.asarray(Image.fromarray((np.clip(pm[..., i], 0, 1)*255).round().astype(np.uint8))
                              .filter(ImageFilter.UnsharpMask(radius=0.6, percent=90, threshold=0)))/255
                   for i in range(4)], -1)
    pm[..., :3] = np.minimum(pm[..., :3], pm[..., 3:4])
    return unpremultiply(pm)


def build(slug):
    folder = CAPTURES/slug
    raw = []
    for b in range(BATCHES):
        if not (folder/f"b{b}.jpg").exists():
            break
        raw += cells(load(folder/f"b{b}.jpg"), load(folder/f"w{b}.jpg"))
    raw = raw[:FRAMES]
    assert len(raw) == FRAMES, (slug, len(raw))
    # The copies are lit and seen alike (see above), and cells are sampled exactly, so each frame is used as it is: an
    # earlier correction averaged each grid position over the four poses it held and baked part of the motion in.
    # The renderer shades each grid position differently, whatever the copy's angle or the colour grade: brighter in the
    # middle of the screen, and Floppy's gloss covering 22% of him at the left edge and 35% near the middle. Played in
    # order, the loop crosses the grid every 11 frames, which read as the lighting "flickering" (owner, 2026-11-16). So a
    # calibration capture (calb/calw: every copy in the same pose) measures each position against the mean of all, and
    # that difference, lightly smoothed so the slug's small movements don't matter, is divided out of every frame.
    per = ROWS*COLS
    cal = cells(load(folder/"calb.jpg"), load(folder/"calw.jpg"))
    stack = np.array([colour for colour, _ in cal])  # premultiplied
    mask = np.array([a for _, a in cal])
    reference = stack.mean(axis=0)
    gains = []
    for k in range(per):
        here = np.stack([ndimage.gaussian_filter(stack[k, ..., c], CAL_BLUR) for c in range(3)], -1)
        mean = np.stack([ndimage.gaussian_filter(reference[..., c], CAL_BLUR) for c in range(3)], -1)
        gain = np.where(here > 0.02, mean/np.maximum(here, 1e-4), 1)
        gains.append(np.clip(gain, 0.7, 1.4))
    frames = [frame(np.clip(colour*gains[i % per], 0, 1), alpha, slug) for i, (colour, alpha) in enumerate(raw)]
    small = [small_frame(f) for f in frames]
    if slug in OUTLINED:
        small = [outline(f, 3) for f in small]
        frames = [outline(f, 5) for f in frames]
    sheet = np.zeros((SHEET, SHEET, 4))
    for i, f in enumerate(small):
        x, y = (i % SMALL_PER_ROW)*SMALL[0], (i//SMALL_PER_ROW)*SMALL[1]
        sheet[y:y + SMALL[1], x:x + SMALL[0]] = f
    path = OUT/f"canister-{slug}-idle-small.png"
    Image.fromarray((sheet*255).round().astype(np.uint8), "RGBA").save(path)
    print("built", path.relative_to(ROOT))
    for n in range(FRAMES//PER_SHEET):
        sheet = np.zeros((SHEET, SHEET, 4))
        for i, f in enumerate(frames[n*PER_SHEET:(n + 1)*PER_SHEET]):
            x, y = (i % PER_ROW)*FRAME[0], (i//PER_ROW)*FRAME[1]
            sheet[y:y + FRAME[1], x:x + FRAME[0]] = f
        path = OUT/f"canister-{slug}-idle-{n + 1}.png"
        Image.fromarray((sheet*255).round().astype(np.uint8), "RGBA").save(path)
        print("built", path.relative_to(ROOT))


if __name__ == "__main__":
    for name in sys.argv[1:] or ["floppy", "inferno", "rammstone", "aquabeek", "tormato", "boondoc"]:
        build(name)
