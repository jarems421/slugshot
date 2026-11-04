"""Cut a finished menu background into the tiles Backdrop.luau lays out: Roblox shrinks any image to 1024 px, so a
sharp full-screen picture has to arrive in pieces. Each tile reaches PAD past its share, so no seam opens between them.

python tile.py <finished 3000x1687 image> <name>   ->  assets/source/ui/goo/back-<name>-1..6.jpg"""
import sys
from pathlib import Path
from PIL import Image

# SHARED with experiments/combat/client/Backdrop.luau.
COLS, ROWS = 3, 2
WIDTH, HEIGHT, PAD = 3000, 1687, 12
OUT = Path(__file__).resolve().parents[3] / 'assets/source/ui/goo'


def main(source, name):
    image = Image.open(source).convert('RGB')
    assert image.size == (WIDTH, HEIGHT), image.size
    index = 0
    for row in range(ROWS):
        for col in range(COLS):
            index += 1
            box = (max(0, round(col * WIDTH / COLS - PAD)), max(0, round(row * HEIGHT / ROWS - PAD)),
                   min(WIDTH, round((col + 1) * WIDTH / COLS + PAD)), min(HEIGHT, round((row + 1) * HEIGHT / ROWS + PAD)))
            tile = image.crop(box)
            assert max(tile.size) <= 1024, tile.size
            tile.save(OUT / f'back-{name}-{index}.jpg', quality=92)
    print(name, index, 'tiles')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
