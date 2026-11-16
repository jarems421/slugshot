"""Draw an original flat satchel icon from vector paths, using the owner's reference for the shape.

Colours follow the HUD rather than the reference (owner, 2026-11-14: "I don't want it to be like a brown colour"):
slate-blue leather, pale trim, a dark strap, and a buckle in the health goo's green.

No source pixels are copied. The SVG is the editable master; PNG is rendered at
four times delivery size with Matplotlib's existing Agg backend and downsampled.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

import matplotlib
matplotlib.use("Agg")
from matplotlib.figure import Figure
from matplotlib.backends.backend_agg import FigureCanvasAgg
from matplotlib.patches import PathPatch
from matplotlib.path import Path as DrawPath
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/source/ui/goo"

# M/L/Q/C/Z paths in a 100-unit square. Filled shapes stay readable at HUD size.
SHAPES = [
    ("#2a313c", "M 17 30 Q 11 51 5 72 Q 0 87 14 91 Q 50 98 86 91 Q 100 87 95 72 Q 89 51 83 30 Z"),
    ("#5b6a7d", "M 19 30 Q 14 52 8 74 Q 3 85 16 88 Q 50 94 84 88 Q 97 85 92 74 Q 86 52 81 30 Z"),
    ("#4d5b6d", "M 50 40 Q 24 49 8 74 Q 3 85 16 88 Q 50 94 84 88 Q 97 85 92 74 Q 86 52 81 30 Z"),
    ("#e6ecef", "M 9 14 Q 50 6 91 14 L 91 31 Q 91 39 84 42 L 50 55 L 16 42 Q 9 39 9 31 Z"),
    ("#76879c", "M 13 13 Q 50 7 87 13 L 87 30 Q 87 36 81 39 L 50 50 L 19 39 Q 13 36 13 30 Z"),
    ("#66778c", "M 13 13 Q 50 7 87 13 L 87 20 Q 50 14 13 24 Z"),
    ("#2c333f", "M 40 23 Q 50 16 60 23 L 60 77 Q 50 85 40 77 Z"),
    ("#3a4352", "M 42 25 Q 50 20 58 25 L 58 75 Q 50 81 42 75 Z"),
    ("#b9d97a", "M 34 38 L 66 38 L 66 61 L 50 68 L 34 61 Z M 39 43 L 39 58 L 50 63 L 61 58 L 61 43 Z"),
    ("#e6f5c4", "M 34 38 L 39 43 L 61 43 L 66 38 Z M 34 61 L 50 68 L 50 63 L 39 58 Z"),
    ("#a5c766", "M 46 56 Q 46 54 50 54 Q 54 54 54 56 L 54 72 L 46 72 Z"),
    ("#7f9c4c", "M 46 72 L 50 69 L 54 72 Z"),
]


def path_data(data):
    tokens = data.split()
    vertices, codes = [], []
    count = {"M": 1, "L": 1, "Q": 2, "C": 3}
    kind = {"M": DrawPath.MOVETO, "L": DrawPath.LINETO,
            "Q": DrawPath.CURVE3, "C": DrawPath.CURVE4}
    i = 0
    while i < len(tokens):
        op = tokens[i]
        i += 1
        if op == "Z":
            vertices.append(vertices[0])
            codes.append(DrawPath.CLOSEPOLY)
            continue
        for _ in range(count[op]):
            vertices.append((float(tokens[i]), float(tokens[i + 1])))
            codes.append(kind[op])
            i += 2
    return DrawPath(vertices, codes)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    svg = ET.Element("svg", xmlns="http://www.w3.org/2000/svg", viewBox="0 0 100 100")
    for color, data in SHAPES:
        ET.SubElement(svg, "path", fill=color, d=data, **{"fill-rule": "evenodd"})
    ET.ElementTree(svg).write(OUT / "icon-inventory.svg", encoding="utf-8", xml_declaration=True)
    figure = Figure(figsize=(4, 4), dpi=256, facecolor=(0, 0, 0, 0))
    canvas = FigureCanvasAgg(figure)
    axis = figure.add_axes((0, 0, 1, 1))
    axis.set(xlim=(0, 100), ylim=(100, 0), aspect="equal")
    axis.axis("off")
    for color, data in SHAPES:
        axis.add_patch(PathPatch(path_data(data), facecolor=color, edgecolor="none"))
    canvas.draw()
    image = Image.frombuffer("RGBA", canvas.get_width_height(), canvas.buffer_rgba(), "raw", "RGBA", 0, 1)
    image.resize((256, 256), Image.Resampling.LANCZOS).save(OUT / "icon-inventory.png")
    print("Built original inventory satchel SVG and transparent PNG")


if __name__ == "__main__":
    main()
