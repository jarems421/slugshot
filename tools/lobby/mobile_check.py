"""See roughly what a lobby change looks like and costs on mobile, without a phone.

Runs the hub in Studio at phone and iPad screen sizes and low graphics levels, then writes to build/lobby/mobile-check:
  report.txt          costs at each view, what's over budget, and what jumped since the last run
  sheet-<look>.jpg    every view for that device look; shots/ holds them full size

It estimates. Looks and relative costs should be close, but it can't give a real frame rate: only a real device can. The budgets
are starting guesses until a real phone and iPad run calibrates them (planned for when the lobby is finished).

    python tools/lobby/mobile_check.py

Game scripts can't set the graphics level, so a small plugin does, on a signal only this check sends. It is installed for the run
and removed afterwards. Studio takes focus briefly to start Play, but only the check's own window is sent anything.
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"build/lobby/mobile-check"
PLACE = ROOT/"build/SlugshotLobbyMobileCheck.rbxlx"
PLUGIN_NAME = "SlugshotMobileCheck.rbxmx"
PLUGIN_SOURCE = """-- Lets the lobby's mobile check set the graphics level, which game scripts aren't allowed to do. It only acts on the check's own
-- attribute, so it does nothing in any other place, and the check installs it only for its own run.
local rendering = settings().Rendering
workspace:GetAttributeChangedSignal("MobileCheckQuality"):Connect(function()
	local level = workspace:GetAttribute("MobileCheckQuality")
	if typeof(level) == "number" then
		rendering.QualityLevel = (Enum.QualityLevel :: any)[string.format("Level%02d", level)]
	end
end)
"""
# Starting guesses, not measurements: see the note above.
BUDGET = {"tris": 200_000, "draws": 150, "tex": 100}
JUMP = 1.10
# Studio's panels sit this far from the window's corner, around the game's view.
VIEW_X, VIEW_Y = 11, 214
LINE = re.compile(r"HUBCHECK view (\S+) (\S+) (\d+) (\d+) tris=(-?\d+) draws=(-?\d+) tex=(\d+) mesh=(\d+)")


def install_plugin():
    folder = Path(os.environ["LOCALAPPDATA"])/"Roblox/Plugins"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder/PLUGIN_NAME
    path.write_text(f'<roblox version="4"><Item class="Script"><Properties><string name="Name">SlugshotMobileCheck</string>'
                    f'<token name="RunContext">0</token><ProtectedString name="Source"><![CDATA[{PLUGIN_SOURCE}]]></ProtectedString>'
                    f"</Properties></Item></roblox>\n", encoding="utf-8")
    return path


def run_studio(shots):
    runner = Path(__file__).with_name("mobile_check_run.ps1")
    result = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(runner), "-Place", str(PLACE),
                             "-OutDir", str(shots), "-Timeout", "300"], capture_output=True, text=True, errors="replace")
    if result.returncode:
        raise SystemExit(f"Studio run failed:\n{result.stderr[-1500:]}")
    return result.stdout


def parse(output):
    rows = []
    for line in output.splitlines():
        found = LINE.search(line)
        if found:
            look, view, width, height, tris, draws, tex, mesh = found.groups()
            rows.append({"look": look, "view": view, "width": int(width), "height": int(height), "tris": int(tris),
                         "draws": int(draws), "tex": int(tex), "mesh": int(mesh)})
    return rows


def crop_shots(rows, shots):
    for row in rows:
        path = shots/f"{row['look']}_{row['view']}.png"
        if path.exists():
            image = Image.open(path).convert("RGB")
            image.crop((VIEW_X, VIEW_Y, VIEW_X + row["width"], VIEW_Y + row["height"])).save(path)


def contact_sheets(rows, shots):
    for look in dict.fromkeys(row["look"] for row in rows):
        chosen = [row for row in rows if row["look"] == look]
        columns, width = 4, 480
        height = round(width*chosen[0]["height"]/chosen[0]["width"])
        sheet = Image.new("RGB", (columns*width, (height + 22)*((len(chosen) + columns - 1)//columns)), (12, 12, 18))
        draw = ImageDraw.Draw(sheet)
        for index, row in enumerate(chosen):
            x, y = index % columns*width, index//columns*(height + 22)
            draw.text((x + 4, y + 5), f"{look} {row['view']}: {row['tris']//1000}k tris, {row['draws']} draws", fill=(235, 235, 245))
            path = shots/f"{look}_{row['view']}.png"
            if path.exists():
                sheet.paste(Image.open(path).resize((width, height), Image.LANCZOS), (x, y + 22))
        sheet.save(OUT/f"sheet-{look}.jpg", quality=88)


def report(rows, previous):
    known = {(row["look"], row["view"]): row for row in previous}
    lines = ["Mobile check. An estimate: looks and relative costs, not real frame rates. Budgets are starting guesses.", ""]
    problems = []
    for look in dict.fromkeys(row["look"] for row in rows):
        chosen = [row for row in rows if row["look"] == look]
        # Textures only build up as a run goes on, so one figure per look says as much as a column would.
        peak = max(row["tex"] for row in chosen)
        lines.append(f"{look}: {chosen[0]['width']}x{chosen[0]['height']}, textures up to {peak} MB, meshes {max(r['mesh'] for r in chosen)} MB")
        lines += [f"  {row['view']:8s} {row['tris']/1000:5.0f}k tris  {row['draws']:4d} draws" for row in chosen]
        lines.append("")
        if peak > BUDGET["tex"]:
            problems.append(f"over budget: {look} textures {peak} MB (limit {BUDGET['tex']})")
        for key in ("tris", "draws"):
            over = [row for row in chosen if row[key] > BUDGET[key]]
            if over:
                worst = max(over, key=lambda row: row[key])
                problems.append(f"over budget: {look} {key} in {len(over)} of {len(chosen)} views, worst {worst['view']} {worst[key]} (limit {BUDGET[key]})")
            for row in chosen:
                old = known.get((look, row["view"]))
                if old and old[key] > 0 and row[key] > old[key]*JUMP:
                    problems.append(f"jumped: {look} {row['view']} {key} {old[key]} to {row[key]}")
    if not previous:
        lines.append("First run, so nothing to compare with yet.")
    lines += problems or ["Nothing over budget or jumped."]
    return "\n".join(lines) + "\n"


def main():
    subprocess.run([sys.executable, str(Path(__file__).with_name("build_hub.py")), "--mobile"], check=True, stdout=subprocess.DEVNULL)
    latest = OUT/"latest.json"
    previous = json.loads(latest.read_text()) if latest.exists() else []
    shots = OUT/"shots"
    shutil.rmtree(shots, ignore_errors=True)
    shots.mkdir(parents=True)
    plugin = install_plugin()
    try:
        output = run_studio(shots)
    finally:
        plugin.unlink(missing_ok=True)
    rows = parse(output)
    if not rows:
        raise SystemExit("The check ran but reported nothing:\n" + output[-1500:])
    crop_shots(rows, shots)
    contact_sheets(rows, shots)
    text = report(rows, previous)
    (OUT/"report.txt").write_text(text, encoding="utf-8")
    latest.write_text(json.dumps(rows, indent=1))
    print(text)
    print(f"Sheets and report in {OUT}")


if __name__ == "__main__":
    main()
