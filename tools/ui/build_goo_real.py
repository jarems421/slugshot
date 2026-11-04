"""The realistic goo the owner chose (2026-11-03): the same tiling strips and flipbook as build_goo_art.py (so Goo.luau
samples them unchanged), but with a thin ink edge, a bright meniscus, light fading with depth, cloudiness and a few
bubbles. Run after build_goo_art.py; it overwrites the goo it made in assets/source/ui/goo."""
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_goo_art as G  # noqa: E402

OUT = G.OUT
smooth = G.smoothstep


def periodic_noise(xs, ys, period, seed, scale_y):
    """Soft clouds that tile across the strip's period."""
    rng = np.random.default_rng(seed)
    total = np.zeros_like(xs)
    for cycles, amp in ((2, 0.5), (3, 0.35), (5, 0.25), (9, 0.14)):
        for _ in range(2):
            phase, fy, py = rng.uniform(0, 2 * np.pi), rng.uniform(0.6, 1.4) / scale_y, rng.uniform(0, 2 * np.pi)
            total += amp * np.sin(2 * np.pi * cycles * xs / period + phase + np.sin(ys * fy + py) * 1.3)
    return total / 1.6


def bubbles(xs, ys, period, inside, seed, count, depth_min, radius):
    """Small bubbles held in the goo, tiling across the period: a lighter body, a darker rim and a glint."""
    rng = np.random.default_rng(seed)
    body, glint = np.zeros_like(xs), np.zeros_like(xs)
    for _ in range(count):
        bx, r = rng.uniform(0, period), rng.uniform(radius * 0.45, radius)
        depth = rng.uniform(depth_min, depth_min + 7)
        dx = (xs - bx + period / 2) % period - period / 2
        dy = inside - depth
        d = np.hypot(dx, dy)
        body += np.clip(1 - d / r, 0, 1) ** 0.6 * 0.5 - smooth(r * 0.75, r, d) * smooth(r * 1.25, r, d) * 0.35
        glint += np.exp(-(((dx + r * 0.35) / (r * 0.28)) ** 2) - (((dy - r * 0.35) / (r * 0.28)) ** 2))
    return body, np.clip(glint, 0, 1)


def surface(name, spec, parts, hanging, ink, near, deep, reach, seed=1, bubble_count=6):
    d = spec["density"]
    w, h = int((spec["period"] + spec["margin"]) * d), int(spec["rows"] * d)
    xs, ys = np.meshgrid((np.arange(w) + 0.5) / d, (np.arange(h) + 0.5) / d)
    edge = spec["edge"] + G.wave(xs, spec["period"], parts)
    slope = np.gradient(edge, axis=1) * d
    inside = (edge - ys if hanging else ys - edge) / np.sqrt(1 + slope * slope)
    soft = 0.55 / d * 1.4
    # Light comes in through the surface and fades with depth, but the far side glows a little where it scatters back.
    value = near + (deep - near) * smooth(0, reach, inside) ** 0.8
    value += 0.1 * np.exp(-np.maximum(inside, 0) / 0.9)  # the meniscus catching the light
    value += 0.05 * periodic_noise(xs, ys, spec["period"], seed, reach)
    body, glint = bubbles(xs, ys, spec["period"], inside, seed + 7, bubble_count, reach * 0.35, 2.4)
    value = np.clip(value + body * 0.16 * smooth(1.5, 3.5, inside), 0, 1)
    face = smooth(-soft, soft, inside)
    alpha = smooth(-soft, soft, inside + ink)
    rgb = value[..., None] * face[..., None] + G.INK * (1 - face[..., None])
    G.write(name, rgb, alpha)
    return glint * face * 0.85  # the bubbles' glints go in the shine, which is sampled with the front


def shine(name, spec, parts, hanging, start, end, extra=0):
    """A sharp wet highlight just under the surface, and a broad faint reflection deeper in."""
    d = spec["density"]
    w, h = int((spec["period"] + spec["margin"]) * d), int(spec["rows"] * d)
    xs, ys = np.meshgrid((np.arange(w) + 0.5) / d, (np.arange(h) + 0.5) / d)
    edge = spec["edge"] + G.wave(xs, spec["period"], parts)
    inside = edge - ys if hanging else ys - edge
    sharp = smooth(start * 0.7, start * 0.7 + 0.35, inside) * (1 - smooth(start * 0.7 + 0.6, start * 0.7 + 1.1, inside))
    theta = 2 * np.pi * xs / spec["period"]
    breaks = 0.5 + 0.5 * np.sin(5 * theta + 1.1) * np.sin(3 * theta + 0.3)
    broad = smooth(end, end + 1.5, inside) * (1 - smooth(end + 2.5, end + 6, inside)) * 0.16
    alpha = sharp * (0.35 + 0.6 * smooth(0.25, 0.7, breaks)) + broad * (0.5 + 0.5 * breaks)
    return G.write(name, np.ones_like(inside), np.clip(alpha + extra, 0, 1))


def drip_frame(f, xs, ys):
    """The flipbook's drop, with a thin edge and a bright, wetter bead."""
    rgb, alpha = ORIGINAL_DRIP(f, xs, ys)
    value = rgb.mean(axis=2)
    dark = value < 0.3  # the old thick outline: thin it by fading its outer half
    alpha = np.where(dark, alpha * 0.55, alpha)
    lit = np.where(dark, value, np.clip(0.7 + (value - 0.84) * 1.6, 0, 1))
    return np.where(dark[..., None], rgb, lit[..., None] * np.ones(3)), alpha


ORIGINAL_DRIP = G.drip_frame
G.drip_frame = drip_frame

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    glints = surface("bar-front", G.BAR, G.BAR_WAVE, False, 0.45, 1.0, 0.62, 9, seed=3, bubble_count=7)
    surface("bar-back", G.BAR, G.BAR_BACK_WAVE, False, 0, 0.9, 0.7, 6, seed=5, bubble_count=0)
    shine("bar-shine", G.BAR, G.BAR_WAVE, False, 1.0, 4.5, glints)
    glints = surface("band-front", G.BAND, G.BAND_WAVE, True, 0.7, 1.0, 0.55, 16, seed=11, bubble_count=10)
    surface("band-back", G.BAND, G.BAND_BACK_WAVE, True, 0.7, 0.9, 0.7, 10, seed=13, bubble_count=0)
    shine("band-shine", G.BAND, G.BAND_WAVE, True, 2.0, 7.0, glints)
    G.drip_book()
    print(sorted(p.name for p in OUT.glob('*.png')))
