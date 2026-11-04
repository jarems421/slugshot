"""Ink outline around a transparent render's silhouette, thick enough to survive being drawn small."""
import sys
from PIL import Image, ImageFilter

src, dst, width = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert('RGBA')
grown = im.getchannel('A').point(lambda v: 255 if v > 90 else 0)
# Many small grows are far faster than one wide filter, and round the corners the same way.
for _ in range(width // 2):
    grown = grown.filter(ImageFilter.MaxFilter(5))
grown = grown.filter(ImageFilter.GaussianBlur(0.8))
ink = Image.new('RGBA', im.size, (11, 12, 16, 255))
ink.putalpha(grown)
ink.alpha_composite(im)
ink.save(dst)
print('outlined', dst)
