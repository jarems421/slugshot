"""Create the labelled SVG plan directly from the authored layout, without art deps."""
import html
import json
from pathlib import Path
from layout import CONFIG, ROOT, layout


def main():
    data = layout()
    width, height, scale = 1200, 1050, min(800/data["config"]["width"],800/data["config"]["depth"])
    chunks = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
              '<rect width="1200" height="1050" fill="#141c28"/>',
              '<style>text{font-family:Arial,sans-serif;fill:#e3e6ed;font-size:17px}.small{font-size:14px}.title{font-size:28px;font-weight:bold}</style>',
              '<text x="44" y="42" class="title">ROCKLOCK / COLLAPSED CAVERN</text>',
              '<text x="44" y="70">Rocklock greybox Â· metres not used: all dimensions are Roblox studs Â· north at top</text>']
    def point(x, z): return 480+x*scale, 505+z*scale
    def label(x, z, text, cls="small"):
        px, py = point(x*data["config"]["width"]/100,z*data["config"]["depth"]/90)
        chunks.append(f'<text x="{px}" y="{py}" text-anchor="middle" class="{cls}">{html.escape(text)}</text>')
    for spec in data["boxes"]:
        x,y,z=spec["position"];w,h,d=spec["size"]
        if spec["role"] == "Boundary": continue
        px,py=point(x-w/2,z-d/2)
        color = "#6c6170" if spec["role"] in {"Cover","Pillar"} else "#42576d" if spec["role"] in {"Stair","Crown","Shelf","WallRun","Bridge"} else "#303b49"
        if spec["role"] == "Spawn": color="#bf9b62"
        chunks.append(f'<rect x="{px:.2f}" y="{py:.2f}" width="{w*scale:.2f}" height="{d*scale:.2f}" fill="{color}" stroke="#7f8b9e" stroke-width="0.7"/>')
    for name,color in [("West","#7ed8e4"),("Centre","#efca88"),("East","#bc9ce8"),("Underpass","#9ce3b2")]:
        points=" ".join(f"{point(p[0],p[2])[0]},{point(p[0],p[2])[1]}" for p in data["config"]["routes"][name])
        chunks.append(f'<polyline points="{points}" stroke="{color}" stroke-width="4" fill="none" stroke-dasharray="9 6"/>')
    label(0,-37,"NORTH SPAWN")
    label(0,39,"SOUTH SPAWN")
    label(-36,0,"WEST +10")
    label(36,0,"EAST +10")
    label(0,0,"ARCH / -4 TUNNEL")
    label(0,7,"KEYSTONE ABOVE +41")
    label(0,-24,"COVER +7")
    label(0,25,"COVER +7")
    for index,text in enumerate([
        f'{data["config"]["width"]} Ã— {data["config"]["depth"]} playable footprint', f'{data["config"]["spawn_separation"]:.1f} between spawn markers', f'Ceiling approx. +{data["config"]["ceiling"]}', "West: continuous run face", "East: broad stone bridge",
        "Both flanks: gentle ramps", "Open floor / two main heights", "Underpass: -4 floor / +8 roof", "Dashed lines: route connections", "No live combat or destruction", "Interaction markers are disabled", "Primary floor stays connected"]):
        chunks.append(f'<text x="930" y="{140+index*34}" class="small">{html.escape(text)}</text>')
    chunks.extend(['<text x="44" y="960">Config: experiments/movement/rocklock/config.json Â· geometry: tools/rocklock/layout.py</text>',
                   '<text x="44" y="990" class="small">Top-down schematic hides the roof and irregular wall silhouettes. Validate actual traversal and camera in Studio.</text>', '</svg>'])
    dest=ROOT / "docs/diagrams/rocklock-layout.svg"
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text("\n".join(chunks)+"\n",encoding="utf-8")
    print(dest.relative_to(ROOT))


if __name__ == "__main__": main()
