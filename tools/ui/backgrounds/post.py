"""Haze by distance and a soft vignette over a background render. post_bg.py in.png out.jpg [haze]"""
import sys
import numpy as np
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
amount = float(sys.argv[3]) if len(sys.argv) > 3 else 0.55
img = np.asarray(Image.open(src).convert('RGB')).astype(float) / 255
depth = np.asarray(Image.open(src.replace('.png', '-depth.png')).convert('L').resize((img.shape[1], img.shape[0]))).astype(float) / 255
depth = np.where(depth <= 0.04045, depth / 12.92, ((depth + 0.055) / 1.055) ** 2.4)  # saved through the sRGB curve
haze = np.array([22, 24, 50]) / 255
f = (np.clip(depth, 0, 1) ** 1.3 * amount)[..., None]
out = img * (1 - f) + haze * f
h, w = depth.shape
ys, xs = np.mgrid[0:h, 0:w]
r = np.hypot((xs / w - 0.5) * 1.6, (ys / h - 0.55) * 1.9)
out *= (1 - 0.45 * np.clip(r - 0.35, 0, 1) ** 1.5)[..., None]
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype('uint8')).save(dst, quality=88)
