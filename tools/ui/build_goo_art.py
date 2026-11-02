"""Paint the PvP UI's textures: the goo, the menu's effects and its cavern scenery.

Roblox snaps UI to whole pixels, so slow motion steps visibly (owner, 2026-11-02: "0.5 frames a second"). The goo is
therefore sampled through ImageRectOffset, which is not snapped: thin columns read a wavy surface at any fraction of a
pixel, and drips play from a rendered flipbook in which a drop really necks, pinches off and falls. Numbers shared with
experiments/combat/client/Goo.luau are marked SHARED. Everything is white so the game can tint it; ink stays dark.

python tools/ui/build_goo_art.py [--preview out.png]
"""
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/source/ui/goo"
INK = np.array([11, 12, 16]) / 255

# SHARED with Goo.luau.
BAR = dict(period=256, density=3.75, rows=32, top=8, window=16, edge=11, margin=8)
BAND = dict(period=480, density=2.0, rows=46, top=8, window=30, edge=26, margin=16)
BAND_WAVE = ((3, 2.8, 0.4), (5, 1.9, 1.9), (8, 1.1, 4.1))  # cycles per period, design px, phase
BAND_BACK_WAVE = ((2, 3.2, 2.6), (7, 1.7, 0.7), (4, 1.4, 5.3))
BAR_WAVE = ((2, 1.0, 0.4), (3, 0.7, 1.9), (5, 0.35, 4.1))
BAR_BACK_WAVE = ((3, 1.3, 2.6), (2, 0.8, 0.7), (7, 0.3, 5.3))
CELL_W, CELL_H, CELL_SCALE, CELL_COLS, FRAMES, DETACH = 16, 52, 3, 21, 126, 78
ATTACH_ROW = 10  # the row of a flipbook cell that sits on the goo's edge
DETACH_Y, DETACH_R = 23.5, 3.0


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def write(name, value, alpha):
    """value is H x W (grey) or H x W x 3."""
    rgb = value if value.ndim == 3 else np.dstack([value] * 3)
    rgba = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    image = Image.fromarray((rgba * 255 + 0.5).astype("uint8"), "RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / f"{name}.png")
    return image


def assert_soft(image, name):
    """A glow must reach nothing before its image's edge, or it shows as a straight line (owner, 2026-11-02)."""
    alpha = np.asarray(image.getchannel("A"))
    edges = max(alpha[0].max(), alpha[-1].max(), alpha[:, 0].max(), alpha[:, -1].max())
    assert edges <= 1, f"{name} is cut off at its edge: alpha {edges}"


def wave(x, period, parts):
    theta = 2 * np.pi * x / period
    return sum(amp * np.sin(cycles * theta + phase) for cycles, amp, phase in parts)


def surface(name, spec, parts, hanging, ink, near, deep, reach):
    """A tiling liquid surface. near and deep are its shade at the edge and well inside."""
    d = spec["density"]
    w, h = int((spec["period"] + spec["margin"]) * d), int(spec["rows"] * d)
    xs, ys = np.meshgrid((np.arange(w) + 0.5) / d, (np.arange(h) + 0.5) / d)
    edge = spec["edge"] + wave(xs, spec["period"], parts)
    slope = np.gradient(edge, axis=1) * d
    inside = (edge - ys if hanging else ys - edge) / np.sqrt(1 + slope * slope)
    soft = 0.55 / d * 1.4
    value = near + (deep - near) * smoothstep(0, reach, inside)
    if ink:
        face = smoothstep(-soft, soft, inside)
        alpha = smoothstep(-soft, soft, inside + ink)
        rgb = value[..., None] * np.ones(3) * face[..., None] + INK * (1 - face[..., None])
    else:
        alpha = smoothstep(-soft, soft, inside)
        rgb = value[..., None] * np.ones(3)
    return write(name, rgb, alpha)


def shine(name, spec, parts, hanging, start, end):
    d = spec["density"]
    w, h = int((spec["period"] + spec["margin"]) * d), int(spec["rows"] * d)
    xs, ys = np.meshgrid((np.arange(w) + 0.5) / d, (np.arange(h) + 0.5) / d)
    edge = spec["edge"] + wave(xs, spec["period"], parts)
    inside = edge - ys if hanging else ys - edge
    band = smoothstep(start, start + 0.7, inside) * (1 - smoothstep(end - 0.7, end, inside))
    theta = 2 * np.pi * xs / spec["period"]
    breaks = 0.5 + 0.5 * np.sin(5 * theta + 1.1) * np.sin(3 * theta + 0.3)
    return write(name, np.ones_like(band), band * smoothstep(0.3, 0.62, breaks) * 0.72)


def edge_mask():
    """Masks the liquid's rounded end, in the bar's empty colour."""
    w, h = 48, 64
    xs, ys = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    bulge = w * (0.12 + 0.76 * np.sin(np.pi * np.clip(ys / h, 0, 1)) ** 0.55)
    return write("goo-edge", np.ones_like(xs), smoothstep(-1.2, 1.2, xs - bulge))


def rounded(xs, ys, x0, y0, x1, y1, r):
    qx = np.abs(xs - (x0 + x1) / 2) - (x1 - x0) / 2 + r
    qy = np.abs(ys - (y0 + y1) / 2) - (y1 - y0) / 2 + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def bar_frame():
    """The bar's ink outline, a 9-slice: rounded outside and in. Liquid underneath stays inside its corners."""
    w, h = 160, 88
    xs, ys = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    outer = rounded(xs, ys, 0, 0, w, h, 40)
    inner = rounded(xs, ys, 12, 12, w - 12, h - 12, 28)
    alpha = smoothstep(1.2, -1.2, outer) * smoothstep(-1.2, 1.2, inner)
    return write("bar-frame", INK * np.ones((h, w, 3)), alpha)


def drip_frame(f, xs, ys):
    """One frame of a drop's life, in design px: x from the centre, y down from the goo's edge."""
    t = f / FRAMES
    detach = DETACH / FRAMES
    a = smoothstep(0, 0.3, t)
    stretch = np.clip((t - 0.3) / (detach - 0.3), 0, 1)
    if t < detach:
        bead_y = 2.6 + (6.5 - 2.6) * a + (DETACH_Y - 6.5) * stretch ** 2
        radius = 2.8 + (3.6 - 2.8) * a + (DETACH_R - 3.6) * stretch
        neck = 1.9 + (1.7 - 1.9) * a + (0.42 - 1.7) * stretch
        tail_y, tail_r = bead_y, neck
    else:
        # The drop has gone. What is left snaps back up, then wobbles and settles.
        s = (t - detach) / (1 - detach)
        recoil = np.exp(-s * 9)
        wobble = 0.55 * np.exp(-s * 5) * np.sin(s * 26)
        bead_y = 2.6 + (DETACH_Y - 2.5 - 2.6) * recoil + wobble
        radius = 2.8 + (0.5 - 2.8) * recoil
        neck = 1.9 + (0.42 - 1.9) * smoothstep(0.12, 0, s)
        tail_y, tail_r = bead_y, neck
    x = np.abs(xs)
    flare = neck + 2.6 * np.exp(-np.maximum(ys, 0) / 1.0)
    funnel = np.maximum(x - flare, ys - bead_y)  # only the flare where it leaves the goo; the bead rounds it off
    # A tapered neck: thin near the bead, widening up to the goo.
    along = np.clip(ys / max(tail_y, 0.01), 0, 1)
    neck_d = np.where(ys <= tail_y, x - (tail_r + (neck * 1.25 - tail_r) * (1 - along)), np.hypot(x, ys - tail_y) - tail_r)
    body = smin(funnel, neck_d, 1.2)
    bead = np.hypot(x, (ys - bead_y) / (1.0 + 0.12 * stretch)) - radius
    d = smin(body, bead, 1.3 + 1.2 * (1 - stretch))
    soft = 0.5
    inkless = smoothstep(-0.6, 0.4, ys)  # no outline above the edge, where it lies over the goo
    face = smoothstep(soft, -soft, d)
    outline = smoothstep(soft, -soft, d - 1.0) * inkless
    fade = smoothstep(-5.5, -1.5, ys)  # melts into the goo above
    alpha = np.maximum(face * fade, outline)
    value = 0.84 + 0.16 * smoothstep(0, 1.6, -d)
    if t < detach:
        glint = np.exp(-(((xs + radius * 0.34) / (radius * 0.26)) ** 2) - (((ys - bead_y + radius * 0.3) / (radius * 0.34)) ** 2))
        value = np.clip(value + glint * 0.5, 0, 1.0)
    rgb = value[..., None] * np.ones(3) * face[..., None] + INK * (1 - face[..., None])
    return rgb, alpha


def drip_book():
    w, h = CELL_W * CELL_SCALE, CELL_H * CELL_SCALE
    rows = int(np.ceil(FRAMES / CELL_COLS))
    sheet = np.zeros((rows * h, CELL_COLS * w, 4))
    xs, ys = np.meshgrid((np.arange(w) + 0.5) / CELL_SCALE - CELL_W / 2, (np.arange(h) + 0.5) / CELL_SCALE - ATTACH_ROW)
    for f in range(FRAMES):
        rgb, alpha = drip_frame(f, xs, ys)
        col, row = f % CELL_COLS, f // CELL_COLS
        sheet[row * h : (row + 1) * h, col * w : (col + 1) * w, :3] = rgb
        sheet[row * h : (row + 1) * h, col * w : (col + 1) * w, 3] = alpha
    image = Image.fromarray((np.clip(sheet, 0, 1) * 255 + 0.5).astype("uint8"), "RGBA")
    image.save(OUT / "goo-drip-book.png")
    assert image.width <= 1024 and image.height <= 1024
    return image


def bead():
    d = 32
    xs, ys = np.meshgrid(np.arange(d) + 0.5, np.arange(d) + 0.5)
    distance = d / 2 - 1 - np.hypot(xs - d / 2, ys - d / 2)
    outer = smoothstep(-1.2, 1.2, distance)
    inner = smoothstep(3.0, 5.4, distance)
    value = (0.86 + 0.14 * smoothstep(0, 6, distance))
    glint = np.exp(-(((xs - d * 0.38) / (d * 0.13)) ** 2) - (((ys - d * 0.36) / (d * 0.15)) ** 2))
    value = np.clip(value + glint * 0.5, 0, 1)
    rgb = value[..., None] * np.ones(3) * inner[..., None] + INK * (1 - inner[..., None])
    return write("goo-bead", rgb, outer)


def menu_art():
    size = 128
    xs, ys = np.meshgrid(np.linspace(-1, 1, size), np.linspace(-1, 1, size))
    r = np.hypot(xs, ys)
    assert_soft(write("fx-glow", np.ones_like(r), np.clip(1 - r, 0, 1) ** 2), "fx-glow")
    # A twinkle: a thin four-point star with a soft heart.
    star = np.abs(xs) ** 0.42 + np.abs(ys) ** 0.42
    twinkle = (1 - smoothstep(0.62, 1.0, star)) + 0.5 * np.clip(1 - r * 2.6, 0, 1) ** 2
    assert_soft(write("fx-spark", np.ones_like(r), twinkle), "fx-spark")

    def icon(name, draw):
        mask = Image.new("L", (384, 384), 0)
        draw(ImageDraw.Draw(mask))
        mask = mask.resize((96, 96), Image.LANCZOS)
        white = Image.new("RGBA", (96, 96), (255, 255, 255, 255))
        white.putalpha(mask)
        white.save(OUT / f"{name}.png")

    def mouse(d):
        d.rounded_rectangle((116, 40, 268, 344), 76, outline=255, width=30)
        d.line((192, 40, 192, 150), fill=255, width=26)
        d.line((116, 150, 268, 150), fill=255, width=26)

    def mouse_button(d):
        d.rounded_rectangle((116, 40, 268, 344), 76, fill=255)
        d.rectangle((192, 0, 384, 384), fill=0)
        d.rectangle((0, 150, 384, 384), fill=0)

    def crosshair(d):
        d.ellipse((76, 76, 308, 308), outline=255, width=28)
        d.ellipse((168, 168, 216, 216), fill=255)
        for line in ((192, 12, 192, 110), (192, 274, 192, 372), (12, 192, 110, 192), (274, 192, 372, 192)):
            d.line(line, fill=255, width=28)

    icon("icon-controls", mouse)
    icon("icon-mouse-button", mouse_button)
    icon("icon-crosshair", crosshair)


def crystal(path, shards):
    """An inked crystal cluster in greys, so the game can tint it. Each shard: base x, half-width, tip x, tip y."""
    size = 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    ink = (11, 12, 16, 255)
    for x, half, tip_x, tip_y, light in shards:
        left, right = (x - half, size), (x + half, size)
        tip = (tip_x, tip_y)
        shoulder_l = (x - half * 0.86 + (tip_x - x) * 0.62, tip_y + (size - tip_y) * 0.2)
        shoulder_r = (x + half * 0.86 + (tip_x - x) * 0.62, tip_y + (size - tip_y) * 0.2)
        ridge = (x + (tip_x - x) * 0.3 - half * 0.1, size)
        d.polygon([left, shoulder_l, tip, shoulder_r, right], fill=ink)
        inset = 16
        d.polygon([(left[0] + inset, size), (shoulder_l[0] + inset, shoulder_l[1] + inset), (tip[0], tip[1] + inset * 2),
                   ridge], fill=(light, light, light, 255))
        dark = int(light * 0.66)
        d.polygon([(right[0] - inset, size), (shoulder_r[0] - inset, shoulder_r[1] + inset), (tip[0], tip[1] + inset * 2),
                   ridge], fill=(dark, dark, dark, 255))
        d.line([tip, ridge], fill=ink, width=7)
        glint = (x + (tip_x - x) * 0.72 - half * 0.34, tip_y + (size - tip_y) * 0.2)
        d.line([glint, (glint[0] - (tip_x - x) * 0.2 - half * 0.1, glint[1] + (size - tip_y) * 0.28)],
               fill=(255, 255, 255, 255), width=int(half * 0.13))
    image.resize((384, 384), Image.LANCZOS).save(path)


def scenery():
    """Cavern pieces for the menu (owner, 2026-11-02: above all it must still feel like Slugterra). All original."""
    crystal(OUT / "fx-crystal.png", [
        (250, 72, 200, 470, 205), (760, 80, 830, 380, 205), (640, 88, 690, 190, 220),
        (380, 96, 340, 250, 225), (510, 130, 510, 40, 255), (830, 56, 890, 640, 190), (150, 62, 110, 660, 190),
    ])
    crystal(OUT / "fx-crystal-small.png", [
        (300, 110, 230, 500, 205), (720, 110, 790, 470, 205), (510, 170, 520, 150, 255),
    ])
    w, h = 1280, 384
    ledge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ledge)
    d.polygon([(10, h), (40, 170), (170, 70), (390, 96), (560, 32), (800, 60), (1010, 44), (1210, 150), (1270, h)],
              fill=(11, 12, 16, 255))
    d.polygon([(40, h), (66, 184), (180, 98), (392, 124), (562, 60), (800, 88), (1000, 72), (1188, 170), (1240, h)],
              fill=(64, 66, 108, 255))
    d.polygon([(66, 184), (180, 98), (392, 124), (562, 60), (800, 88), (1000, 72), (1188, 170), (980, 196), (640, 170),
               (330, 214)], fill=(98, 100, 150, 255))
    for line in ([(392, 124), (420, 240), (370, 340)], [(800, 88), (760, 210), (830, 330)],
                 [(1000, 72), (1060, 200), (1030, 300)], [(180, 98), (210, 230)]):
        d.line(line, fill=(11, 12, 16, 255), width=14, joint="curve")
    ledge.resize((320, 96), Image.LANCZOS).save(OUT / "fx-ledge.png")


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    menu_art()
    scenery()
    edge_mask()
    bar_frame()
    bead()
    art = {
        "bar-front": surface("bar-front", BAR, BAR_WAVE, False, 0.9, 1.0, 0.88, 7),
        "bar-back": surface("bar-back", BAR, BAR_BACK_WAVE, False, 0, 1.0, 1.0, 1),
        "bar-shine": shine("bar-shine", BAR, BAR_WAVE, False, 1.0, 2.6),
        "band-front": surface("band-front", BAND, BAND_WAVE, True, 1.5, 1.0, 0.8, 12),
        "band-back": surface("band-back", BAND, BAND_BACK_WAVE, True, 1.5, 1.0, 1.0, 1),
        "band-shine": shine("band-shine", BAND, BAND_WAVE, True, 2.0, 4.2),
        "drip": drip_book(),
    }
    return art


def tint(image, colour):
    data = np.asarray(image).astype(float) / 255
    data[..., :3] *= np.array(colour)
    return Image.fromarray((data * 255 + 0.5).astype("uint8"), "RGBA")


def preview(art, path):
    """The goo as the game composes it, sampled the same way: a column at a time with a height field."""
    teal, sage = (84 / 255, 228 / 255, 214 / 255), (185 / 255, 217 / 255, 122 / 255)
    canvas = Image.new("RGBA", (1000, 640), (28, 28, 60, 255))
    ImageDraw.Draw(canvas).rectangle((0, 0, 1000, 44), fill=(24, 23, 52, 255))

    def sample(tex, spec, col, width, height, scroll, heights, dst, colour):
        d = spec["density"]
        for i in range(int(width / col)):
            x = (scroll + i * col) % spec["period"]
            y = spec["top"] - heights(i * col)
            box = (x * d, y * d, (x + col) * d, (y + height) * d)
            part = tint(tex, colour).transform((col, height), Image.EXTENT, box, Image.BILINEAR)
            canvas.alpha_composite(part, (dst[0] + i * col, dst[1]))

    swell = lambda s: (lambda x: 2.4 * np.sin(x / 90 + s) + 1.2 * np.sin(x / 37 + s * 1.7))
    back_colour = tuple(c * 0.7 for c in teal)
    sample(art["band-back"], BAND, 16, 1000, 30, 40, swell(1.0), (0, 30), back_colour)
    sample(art["band-front"], BAND, 8, 1000, 30, 200, swell(0.2), (0, 30), teal)
    sample(art["band-shine"], BAND, 8, 1000, 30, 200, swell(0.2), (0, 30), (1, 1, 1))
    ImageDraw.Draw(canvas).rectangle((0, 0, 1000, 32), fill=(24, 23, 52, 255))
    ImageDraw.Draw(canvas).rectangle((0, 30, 1000, 32), fill=(11, 12, 16, 255))
    book = tint(art["drip"], teal)
    w, h = CELL_W * CELL_SCALE, CELL_H * CELL_SCALE
    for n, f in enumerate((4, 22, 40, 58, 70, 77, 79, 84, 95, 120)):
        cell = book.crop(((f % CELL_COLS) * w, (f // CELL_COLS) * h, (f % CELL_COLS + 1) * w, (f // CELL_COLS + 1) * h))
        cell = cell.resize((CELL_W, CELL_H), Image.LANCZOS)
        edge_x = 60 + n * 90
        canvas.alpha_composite(cell, (edge_x - CELL_W // 2, 30 + 18 - ATTACH_ROW))
    # Big flipbook strip.
    for n, f in enumerate((0, 14, 28, 42, 56, 66, 74, 77, 79, 82, 88, 100, 118)):
        cell = book.crop(((f % CELL_COLS) * w, (f // CELL_COLS) * h, (f % CELL_COLS + 1) * w, (f // CELL_COLS + 1) * h))
        canvas.alpha_composite(cell, (10 + n * 74, 110))

    def bar(y, share, s):
        width = 290
        base = Image.new("RGBA", (width + 6, 22), (0, 0, 0, 0))
        ImageDraw.Draw(base).rectangle((3, 3, width + 2, 18), fill=(20, 23, 28, 255))
        canvas.alpha_composite(base, (20, y))
        heights = lambda x: 1.6 * np.sin(x / 40 + s) + (x / width - 0.5) * 5 * np.sin(s)
        sample(art["bar-back"], BAR, 8, width, 16, 30, lambda x: -heights(x) * 0.6, (23, y + 3), tuple(c * 0.72 for c in sage))
        sample(art["bar-front"], BAR, 4, width, 16, 90, heights, (23, y + 3), sage)
        sample(art["bar-shine"], BAR, 4, width, 16, 90, heights, (23, y + 3), (1, 1, 1))
        end = int(23 + share * width)
        if share < 1:
            mask = Image.open(OUT / "goo-edge.png").resize((12, 16), Image.LANCZOS)
            canvas.alpha_composite(tint(mask, (20 / 255, 23 / 255, 28 / 255)), (end - 8, y + 3))
            ImageDraw.Draw(canvas).rectangle((end + 4, y + 3, 23 + width - 1, y + 18), fill=(20, 23, 28, 255))
        frame = Image.open(OUT / "bar-frame.png")
        left = frame.crop((0, 0, 40, 88)).resize((10, 22), Image.LANCZOS)
        mid = frame.crop((60, 0, 100, 88)).resize((width + 6 - 20, 22), Image.LANCZOS)
        right = frame.crop((120, 0, 160, 88)).resize((10, 22), Image.LANCZOS)
        canvas.alpha_composite(left, (20, y))
        canvas.alpha_composite(mid, (30, y))
        canvas.alpha_composite(right, (20 + width + 6 - 10, y))
        for at, f in ((0.1, 30), (0.3, 62), (0.52, 76), (0.74, 96)):
            if at < share:
                cell = book if False else tint(art["drip"], tuple(c * 0.9 for c in sage))
                piece = cell.crop(((f % CELL_COLS) * w, (f // CELL_COLS) * h, (f % CELL_COLS + 1) * w, (f // CELL_COLS + 1) * h))
                piece = piece.resize((CELL_W, CELL_H), Image.LANCZOS)
                canvas.alpha_composite(piece, (int(23 + at * width) - CELL_W // 2, y + 22 - ATTACH_ROW))

    bar(330, 1.0, 0.4)
    bar(410, 0.72, 1.5)
    bar(490, 0.46, 3.1)
    canvas.crop((0, 320, 340, 560)).resize((680, 480), Image.LANCZOS).save(str(path).replace(".png", "-bar.png"))
    canvas.save(path)


if __name__ == "__main__":
    built = build()
    if "--preview" in sys.argv:
        preview(built, sys.argv[sys.argv.index("--preview") + 1])
    print("art written", sorted(p.name for p in OUT.glob("*.png")))
