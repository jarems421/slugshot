"""Write the private BlasterMesh mapping for the Slugshot-look blaster (never committed; private-assets is ignored).

Keeps every existing part's Roblox finish from the current mapping, adds the ink shells as near-black Neon (lamps
never grey them and they never bloom, as in the look pack), and points at the newly uploaded model. The previous
mapping is backed up beside it.

    python tools/lobby/blaster_mapping.py <mesh-specs.json> <roblox_assets.json> <BlasterMesh.luau> [<more mapping copies>]
"""

import json
import re
import shutil
import sys
from pathlib import Path

INK = "0E0E12"  # LookPack.INK


def finishes(luau: str):
    out = {}
    for m in re.finditer(r'name = "(\w+)",\s*color = "(\w+)",\s*material = "(\w+)",\s*reflectance = ([\d.]+)', luau):
        out[m.group(1)] = (m.group(2), m.group(3), float(m.group(4)))
    return out


def main():
    specs = json.loads(Path(sys.argv[1]).read_text())
    model = json.loads(Path(sys.argv[2]).read_text())["model"]
    targets = [Path(p) for p in sys.argv[3:]]
    old = finishes(targets[0].read_text(encoding="utf-8"))
    rotation = re.search(r"rotation = (CFrame[^\n]*),", targets[0].read_text(encoding="utf-8"))
    lines = ["--!strict", "-- Private Slugshot-look blaster mapping (bladed-ridge tips, ink shells); never commit.", "return {",
             f"\tmodel = {model},"]
    if rotation:
        lines.append(f"\trotation = {rotation.group(1)},")
    lines.append("\tmeshes = {")
    for sp in specs:
        name = sp["name"]
        color, material, refl = (INK, "Neon", 0.0) if name.endswith("_Ink") else old[name]
        c, s = sp["centre"], sp["size"]
        lines += ["\t\t{", f'\t\t\tname = "{name}",', f'\t\t\tcolor = "{color}",', f'\t\t\tmaterial = "{material}",',
                  f"\t\t\treflectance = {refl},", f"\t\t\tcentre = Vector3.new({c[0]:.6f}, {c[1]:.6f}, {c[2]:.6f}),",
                  f"\t\t\tsize = Vector3.new({s[0]:.6f}, {s[1]:.6f}, {s[2]:.6f}),", "\t\t},"]
    lines += ["\t},", "}", ""]
    for t in targets:
        backup = t.with_name("BlasterMesh.before-slugshot-look.luau")
        if not backup.exists():
            shutil.copy2(t, backup)
        t.write_text("\n".join(lines), encoding="utf-8")
        print("wrote", t)


if __name__ == "__main__":
    main()
