"""Pack turntable frames from tools/lobby/render_character_look.py into 6-column JPEG sheets for the review pages.

    python tools/lobby/sheet_frames.py <frames dir> <out dir> <name> [<name> ...]
"""

import sys
from pathlib import Path

from PIL import Image

COLS, FRAMES = 6, 36


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for name in sys.argv[3:]:
        frames = [Image.open(src/f"{name}-{i:02d}.png").convert("RGB") for i in range(FRAMES)]
        w, h = frames[0].size
        sheet = Image.new("RGB", (w*COLS, h*((FRAMES + COLS - 1)//COLS)))
        for i, f in enumerate(frames):
            sheet.paste(f, ((i % COLS)*w, (i//COLS)*h))
        path = out/f"{name}.jpg"
        sheet.save(path, quality=86, optimize=True)
        print(f"{path.name}: {path.stat().st_size//1024} KB")


if __name__ == "__main__":
    main()
