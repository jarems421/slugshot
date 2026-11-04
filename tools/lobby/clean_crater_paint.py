"""Clear the lava paint that the volcano's bake smeared onto the rock round the crater (owner, 2026-11-03: a glitch on
the rock at the top where lava is painted on it). Lava-orange texels of the rock maps above RIM become the rock around
them and stop glowing, fading in over FEATHER so no line shows. The downhill creases below are left as painted.

    python tools/lobby/clean_crater_paint.py <hub-volcano export folder> <out folder>
Writes <group>-color.png and <group>-emit.png for each rock group into the out folder."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

GROUPS = ("VolcanoFront", "VolcanoBack")
RIM, FEATHER = 25.0, 2.0  # modelled height (Blender Z) where the crater's rock starts, and the fade below it


def clean(export: Path, out: Path, group: str):
    textures = export/"textures"
    colour = np.asarray(Image.open(textures/f"{group}-color.png").convert("RGB")).astype(np.float32)
    glow = np.asarray(Image.open(textures/f"{group}-emit.png").convert("L")).astype(np.float32)
    height = np.load(textures/f"{group}-pos.npy")[..., 2]
    # Lava paint is strongly red over blue; the rock is a cool grey-blue.
    lava = (colour[..., 0] > 120) & (colour[..., 0] > colour[..., 2] + 50)
    lava = ndimage.binary_dilation(lava, iterations=2)  # its soft fringe too
    weight = np.clip((height - (RIM - FEATHER))/FEATHER, 0, 1)*lava
    # The rock it should be: the average of nearby rock texels, widened until every painted texel has some.
    # Not the black padding between the atlas's islands, or its ink lines.
    rock = (~lava & (colour.mean(-1) > 45)).astype(np.float32)
    fill = colour.copy()
    done = ~lava
    for radius in (4, 8, 16, 32):
        count = ndimage.uniform_filter(rock, 2*radius + 1)
        total = np.stack([ndimage.uniform_filter(colour[..., c]*rock, 2*radius + 1) for c in range(3)], -1)
        need = ~done & (count > 1e-3)
        fill[need] = (total/np.maximum(count, 1e-3)[..., None])[need]
        done |= need
    colour = colour*(1 - weight[..., None]) + fill*weight[..., None]
    glow = glow*(1 - weight)
    Image.fromarray(colour.clip(0, 255).astype(np.uint8)).save(out/f"{group}-color.png")
    Image.fromarray(glow.clip(0, 255).astype(np.uint8)).save(out/f"{group}-emit.png")
    print(group, "cleaned texels", int((weight > 0).sum()))


if __name__ == "__main__":
    export, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for name in GROUPS:
        clean(export, out, name)
