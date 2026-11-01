"""Draw the lobby scale plan from experiments/lobby/scale/shared/layout.json, the same numbers the block-out uses.

Writes build/lobby-scale/plan.html: a labelled top-down plan and a side section through the PvP axis.
"""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[2]
L = json.loads((ROOT / "experiments/lobby/scale/shared/layout.json").read_text(encoding="utf-8"))
OUT = ROOT / "build/lobby-scale/plan.html"
SIZE = 660


def polar(angle, radius):
    rad = math.radians(angle)
    return radius * math.sin(rad), -radius * math.cos(rad)


def rgb(values):
    return f"rgb({values[0]},{values[1]},{values[2]})"


def pts(points):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def sector(a1, a2, r1, r2, fill, extra=""):
    steps = max(2, int(abs(a2 - a1) / 3))
    angles = [a1 + (a2 - a1) * i / steps for i in range(steps + 1)]
    outline = [polar(a, r2) for a in angles] + [polar(a, r1) for a in reversed(angles)]
    return f'<polygon points="{pts(outline)}" fill="{fill}" {extra}/>'


def circle(center, radius, fill, extra=""):
    return f'<circle cx="{center[0]:.1f}" cy="{center[1]:.1f}" r="{radius:.1f}" fill="{fill}" {extra}/>'


def text(position, words, cls="label", dy=0):
    return f'<text x="{position[0]:.1f}" y="{position[1] + dy:.1f}" class="{cls}">{words}</text>'


def top_down():
    s = []
    shore, rock, bridges = L["shore"], L["spawnRock"], L["bridges"]
    wall, inner = shore["wallRadius"], shore["innerRadius"]
    s.append(circle((0, 0), wall + 6, "var(--wall)"))
    for zone in L["zones"]:
        s.append(sector(zone["from"], zone["to"], inner, wall, rgb(zone["color"])))
    growth = L["overgrowth"]
    s.append(sector(growth["from"], growth["to"], growth["innerRadius"], growth["outerRadius"], rgb(growth["color"])))
    ravine = L["ravine"]
    s.append(sector(ravine["from"], ravine["to"], ravine["innerRadius"], ravine["outerRadius"], rgb([214, 96, 34])))
    ledge = ravine["ledge"]
    s.append(sector(ravine["from"], ravine["to"], ravine["innerRadius"], ravine["innerRadius"] + ledge["width"], rgb(L["route"]["color"])))
    # The spiral route, shaded by height, drawn under the peaks it joins.
    route = L["route"]
    points = route["points"]
    tunnel = route["tunnel"]
    r2 = wall
    r1 = wall - route["width"]
    s.append(sector(points[0]["angle"], points[-1]["angle"], r1, r2, rgb(route["color"])))
    s.append(sector(tunnel["from"], tunnel["to"], r1, r2, "var(--tunnel)"))
    for peak, label in ((L["volcano"], "rimRadius"), (L["mountain"], "topRadius")):
        center = polar(peak["angle"], peak["radius"])
        s.append(circle(center, peak["baseRadius"], rgb(peak["color"])))
        s.append(circle(center, peak[label], "none", 'stroke="var(--ink)" stroke-width="1.5" stroke-dasharray="4 3"'))
    volcano = L["volcano"]
    s.append(circle(polar(volcano["angle"], volcano["radius"]), volcano["craterRadius"], rgb([240, 110, 40])))
    pond = L["pond"]
    pond_center = polar(pond["angle"], pond["radius"])
    mountain_center = polar(L["mountain"]["angle"], L["mountain"]["radius"])
    s.append(
        f'<line x1="{mountain_center[0]:.1f}" y1="{mountain_center[1]:.1f}" x2="{pond_center[0]:.1f}" y2="{pond_center[1]:.1f}" '
        f'stroke="rgb(70,190,200)" stroke-width="{L["waterfall"]["width"]}"/>'
    )
    s.append(circle(pond_center, pond["diameter"] / 2, "rgb(70,190,200)"))
    # Sinkhole, bridges and the rock.
    s.append(circle((0, 0), inner, "var(--pit)", 'stroke="var(--lip)" stroke-width="2.5"'))
    s.append(circle((0, 0), L["skyWell"]["openingRadius"], "none", 'stroke="var(--ink)" stroke-width="1" stroke-dasharray="2 4"'))
    for angle in bridges["angles"]:
        a, b = polar(angle, rock["radius"]), polar(angle, inner)
        s.append(
            f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" '
            f'stroke="rgb(150,108,66)" stroke-width="{bridges["width"]}"/>'
        )
    s.append(circle((0, 0), rock["radius"], "rgb(142,146,162)"))
    # Buildings and gates, drawn square to the centre.
    shop = L["gunShop"]
    c = polar(shop["angle"], shop["radius"])
    s.append(
        f'<rect x="{c[0] - shop["depth"] / 2:.1f}" y="{c[1] - shop["width"] / 2:.1f}" width="{shop["depth"]}" height="{shop["width"]}" '
        f'fill="{rgb(shop["color"])}" stroke="var(--ink)" stroke-width="1.5"/>'
    )
    for portal in L["portals"]:
        p = polar(portal["angle"], portal["radius"])
        half = portal["width"] / 2 + 4
        s.append(
            f'<rect x="{p[0] - half:.1f}" y="{p[1] - 2:.1f}" width="{half * 2:.1f}" height="4" fill="{rgb(portal["color"])}" '
            f'transform="rotate({portal["angle"]} {p[0]:.1f} {p[1]:.1f})"/>'
        )
    entrance = L["entrance"]
    p = polar(entrance["angle"], entrance["radius"])
    half = entrance["width"] / 2
    s.append(f'<rect x="{p[0] - half:.1f}" y="{p[1] - 3:.1f}" width="{half * 2}" height="6" fill="var(--ink)"/>')
    board = polar(L["bountyBoard"]["angle"], L["bountyBoard"]["radius"])
    s.append(circle(board, 3, "rgb(150,108,66)", 'stroke="var(--ink)"'))
    # Walk distance from spawn to PvP.
    s.append('<line x1="0" y1="-26" x2="0" y2="-150" stroke="var(--ink)" stroke-width="1.2" stroke-dasharray="6 4"/>')
    # Labels.
    s.append(text(polar(0, 164), "PvP", "label strong", dy=-6))
    s.append(text(polar(-22, 150), "Training", "label", dy=-12))
    s.append(text(polar(22, 150), "Veylume", "label", dy=-12))
    s.append(text(polar(-14, 128), "Bounty", "small"))
    s.append(text((6, -108), "155 studs, 10 s walk", "small on start"))
    s.append(text((0, 4), "Spawn", "small dark"))
    s.append(text(polar(0, 192), "Volcano", "label on"))
    s.append(text(polar(70, 262), "Waterfall", "label on", dy=-8))
    s.append(text(polar(70, 262), "mountain", "label on", dy=7))
    s.append(text(pond_center, "Slug pond", "label on", dy=4))
    s.append(text(polar(-42.5, 245), "Lava ravine", "label on"))
    s.append(text(c, "Gun shop", "small dark", dy=4))
    s.append(text(polar(37, 240), "Overgrowth", "small on"))
    s.append(text(polar(180, 250), "Entrance", "label on"))
    s.append(text(polar(215, 262), "Caverns", "small on"))
    s.append(text(polar(-112, 268), "Spiral route", "small on"))
    s.append(text((52, 44), "Maelstrom", "small on"))
    s.append(text((52, 57), "170 across", "small on"))
    s.append('<g transform="translate(-300,322)"><rect width="100" height="4" fill="var(--ink)"/>'
             '<text x="50" y="-5" class="small">100 studs</text></g>')
    return f'<svg viewBox="-315 -315 630 650" role="img" aria-label="Top-down plan of the lobby" class="plan">{"".join(s)}</svg>'


def side_section():
    # A straight cut from the Entrance wall to the wall behind the volcano; depth is cut off at -120.
    wall = L["shore"]["wallRadius"]
    ceiling = L["cavern"]["ceilingY"]
    well = L["skyWell"]["openingRadius"]
    inner = L["shore"]["innerRadius"]
    rock = L["spawnRock"]
    volcano = L["volcano"]
    bridges = L["bridges"]
    s = []

    def z(y):
        return -y

    s.append(f'<rect x="{-wall}" y="{z(ceiling)}" width="{wall - well}" height="10" fill="var(--wall)"/>')
    s.append(f'<rect x="{well}" y="{z(ceiling)}" width="{wall - well}" height="10" fill="var(--wall)"/>')
    s.append(f'<rect x="{-L["skyWell"]["columnRadius"]}" y="{z(ceiling)}" width="{L["skyWell"]["columnRadius"] * 2}" height="{ceiling}" fill="var(--light)"/>')
    s.append(f'<rect x="{-wall - 6}" y="{z(ceiling)}" width="6" height="{ceiling + 120}" fill="var(--wall)"/>')
    s.append(f'<rect x="{wall}" y="{z(ceiling)}" width="6" height="{ceiling + 120}" fill="var(--wall)"/>')
    for x1, x2 in ((-wall, -inner), (inner, wall)):
        s.append(f'<rect x="{x1}" y="0" width="{x2 - x1}" height="120" fill="var(--wall)"/>')
    s.append(f'<rect x="{-inner}" y="{-L["maelstrom"]["waterY"]}" width="{inner * 2}" height="3" fill="rgb(70,190,200)"/>')
    c = volcano["radius"]
    s.append(f'<polygon points="{c - volcano["baseRadius"]},0 {c - volcano["rimRadius"]},{z(volcano["height"])} {c - volcano["craterRadius"]},{z(volcano["height"])} {c - volcano["craterFloorRadius"]},{z(volcano["craterFloorY"])} {c + volcano["craterFloorRadius"]},{z(volcano["craterFloorY"])} {c + volcano["craterRadius"]},{z(volcano["height"])} {c + volcano["rimRadius"]},{z(volcano["height"])} {wall},0" fill="{rgb(volcano["color"])}"/>')
    portal = next(p for p in L["portals"] if p["name"] == "PvP")
    s.append(f'<rect x="{portal["radius"] - 2}" y="{z(portal["height"] + portal["rise"])}" width="4" height="{portal["height"]}" fill="{rgb(portal["color"])}"/>')
    s.append(f'<polygon points="{-rock["radius"]},0 {rock["radius"]},0 0,{rock["undersideDepth"]}" fill="rgb(142,146,162)"/>')
    for sign in (1, -1):
        mid = sign * (rock["radius"] + inner) / 2
        s.append(f'<path d="M{sign * rock["radius"]} 0 Q{mid} {bridges["sag"] * 2} {sign * inner} 0" fill="none" stroke="rgb(150,108,66)" stroke-width="3"/>')
    entrance = L["entrance"]
    s.append(f'<rect x="{-entrance["radius"] - 4}" y="{z(entrance["height"] + entrance["post"])}" width="8" height="{entrance["height"] + entrance["post"]}" fill="var(--ink)"/>')
    s.append(text((0, z(ceiling) - 8), "Sky Well, 250 up", "small"))
    s.append(text((0, 58), "Maelstrom water", "small on"))
    s.append(text((0, 104), "falls on to -500, then respawn", "small on"))
    s.append(text((c, z(volcano["height"]) - 8), "Volcano rim, 135", "small"))
    s.append(text((portal["radius"] - 10, z(portal["height"]) - 12), "PvP", "small"))
    s.append(text((-(rock["radius"] + inner) / 2, -14), "Bridge", "small"))
    s.append(text((-entrance["radius"] + 14, z(entrance["height"]) - 14), "Entrance", "small"))
    return f'<svg viewBox="-315 -270 630 395" role="img" aria-label="Side section from the Entrance to the volcano" class="section">{"".join(s)}</svg>'


def seconds(distance, speed):
    return f"{distance / speed:.1f} s"


def rows():
    walk = L["walkSpeeds"]
    distance = L["portals"][1]["radius"] - 2
    run = walk["run"]
    entries = [
        ("Spawn to PvP gate", f"{distance} studs: {seconds(distance, walk['default'])} walking, {seconds(distance, run)} running, {seconds(distance, walk['sprint'])} sprinting"),
        ("Spawn rock", f"{L['spawnRock']['radius'] * 2} across, for 20 to 25 players"),
        ("Bridges", f"4 wooden, {L['shore']['innerRadius'] - L['spawnRock']['radius']} long, {L['bridges']['width']} wide, {L['bridges']['sag']} droop"),
        ("Maelstrom", f"{L['shore']['innerRadius'] * 2} across. No barriers, a low hop-over lip, fall to {L['fall']['respawnY']} and respawn"),
        ("Cavern", f"{L['shore']['wallRadius'] * 2} across, ceiling {L['cavern']['ceilingY']} up"),
        ("Portals", "Curved arc about 50 apart, PvP raised 4 and largest"),
        ("Volcano and mountain", f"{L['volcano']['height']} high, reached from the spiral route"),
        ("Spiral route", f"{L['route']['width']} wide, about {math.radians(250) * 293:.0f} long ({math.radians(250) * 293 / run:.0f} s running), rising from 0 to {L['route']['points'][-1]['y']}"),
        ("Slug pond", f"{L['pond']['diameter']} across, wadeable, slugs all around it"),
        ("Gun shop", f"Walk-in building, {L['gunShop']['width']} by {L['gunShop']['depth']}"),
    ]
    return "".join(f"<tr><th scope=\"row\">{k}</th><td>{v}</td></tr>" for k, v in entries)


PAGE = """<title>Lobby Scale Map</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
/* Layout: a surveyor's sheet, plan first, then section, then the numbers. */
:root {{ --bg:#eceae4; --fg:#20232b; --muted:#5b5f6b; --rule:#c6c4bb; --ink:#20232b;
  --wall:#4a4e5e; --pit:#2c3a50; --lip:#8f93a3; --tunnel:#6d6f78; --light:rgba(150,160,120,.28);
  --on:#f4f3ee; --display:"Barlow Condensed",system-ui,sans-serif; --body:"Barlow",system-ui,sans-serif; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg:#16181e; --fg:#e8e7e1; --muted:#a2a5b0; --rule:#343742;
  --ink:#e8e7e1; --wall:#3c404e; --pit:#101826; --light:rgba(235,240,210,.16); color-scheme:dark; }} }}
:root[data-theme="dark"] {{ --bg:#16181e; --fg:#e8e7e1; --muted:#a2a5b0; --rule:#343742;
  --ink:#e8e7e1; --wall:#3c404e; --pit:#101826; --light:rgba(235,240,210,.16); color-scheme:dark; }}
body {{ background:var(--bg); color:var(--fg); font:16px/1.5 var(--body); }}
main {{ max-width:{size}px; margin:0 auto; padding-block:28px 48px; padding-left:max(16px,env(safe-area-inset-left,0px)); padding-right:max(16px,env(safe-area-inset-right,0px)); display:grid; gap:28px; }}
h1 {{ font:600 2.2rem/1.1 var(--display); margin:0 0 6px; text-wrap:balance; }}
h2 {{ font:600 1.35rem/1.2 var(--display); margin:0 0 8px; }}
p {{ margin:0; color:var(--muted); max-width:65ch; }}
svg {{ display:block; width:100%; height:auto; }}
text {{ text-anchor:middle; font-family:var(--body); fill:var(--fg); }}
.label {{ font-size:12.5px; font-weight:600; }} .strong {{ font-size:15px; font-weight:700; }} .small {{ font-size:10.5px; font-weight:500; }}
.on {{ fill:var(--on); }} .dark {{ fill:#17191f; }} .start {{ text-anchor:start; }}
table {{ width:100%; border-collapse:collapse; font-variant-numeric:tabular-nums; }}
th,td {{ text-align:left; vertical-align:top; padding:8px 0; border-top:1px solid var(--rule); }}
th {{ font-weight:600; width:34%; padding-right:12px; }}
</style>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600&family=Barlow:wght@400;500;600;700&display=swap">
<main>
<header><h1>Lobby Scale Map</h1><p>V1 for judging distance and layout only. All sizes are in studs, seen from above with PvP at the top.</p></header>
<section>{plan}</section>
<section><h2>Side view, Entrance to volcano</h2>{section}</section>
<section><h2>Key sizes</h2><table>{rows}</table></section>
</main>
"""


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(PAGE.format(size=SIZE + 60, plan=top_down(), section=side_section(), rows=rows()), encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
