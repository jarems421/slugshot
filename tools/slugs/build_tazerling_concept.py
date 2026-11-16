"""Build the Tazerling base-form concept page from its signed-distance template.

The page compares options for the chosen direction (form keys dNeM: direction N, Storm cell eye M);
each is rendered as its own turntable. Directions 0 (round 14), 2 and 3 stay in the template as history.
Writes the page to docs/slugs/catalog/evidence/tazerling/, renders the turntables with
render_concept.py, and writes a self-contained copy with the frames embedded to
build/slugs/tazerling/ for publishing as an artifact.

    python tools/slugs/build_tazerling_concept.py                          # page, renders, artifact
    python tools/slugs/build_tazerling_concept.py --forms d1e0 --frames 0,2 --out <dir>   # a draft
    python tools/slugs/build_tazerling_concept.py --no-render              # page and artifact only
"""
from __future__ import annotations

import argparse
import base64
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "tools/slugs/tazerling_concept/template.html"
PAGE = ROOT / "docs/slugs/catalog/evidence/tazerling/tazerling.html"
BUILD = ROOT / "build/slugs/tazerling"

NAME = "Tazerling"
LEDE = (
    "Storm cell, the chosen direction: deep royal blue, round 14's feelers, subtle lids over glowing slit eyes, "
    "and a clean body. The base form is final; the transformed form is a first concept."
)
PICK_LABEL = "Form"
# (form key, button, note). The form key is dNeMbK for the base form: direction N, Storm cell eye M
# (1, the lid; the brow d1e0 is history), body lightning K (2, clean, is final; 0 crisp, 1 blended
# and 3 rare are history). xN is direction N's transformed form.
DIRECTIONS = [
    ("d1e1b2", "Base", "<b>Final.</b> Storm cell with a clean body: no lightning on the body; the electricity lives in the eyes, the sparks, the feeler tips and the belly seams."),
    ("x1", "Transformed", "<b>Concept 4.</b> Rammstone's transformed silhouette without the armour, with the reference's electric parts: the head flatter and wider than the base's, roaring wide; a broad chest and one even taper back to a point, no legs. Two big arms growing straight out of the body (no separate shoulder balls), both reaching forward so the hands sit either side of the head; each hand three thick jagged electric fingers with flame-like barbs. The mohawk: three big flames of lightning swept back off the top of the head, the side ones splaying out. The back half electrified: its outline breaks into jagged lightning flames sweeping back, it glows toward the point, which bursts into spikes, and bolts strike and sparks leap off it (Live 3D). Thin yellow lines along the tops of the arms. Lightning trails come later in game."),
]
NOTES = [
    ("Colour", "A deep royal blue a shade under round 14's, darkening down the back, with a storm-grey belly."),
    ("Antennae", "Round 14's feelers: short and soft in the body's blue, bending and whipping as he moves, tips glowing electric yellow with small sparks crawling up them (Live 3D)."),
    ("Eyes", "Under low, subtle lids, each eye glows strongly: deep amber at the rim through electric yellow to a white-hot centre along the middle, breathing gently, with a soft bloom of light round it. Three arcs of lightning strike across it, each on its own clock, snapping on, stuttering, fading and re-striking in a new shape, and the centre flares when one hits (Live 3D). A bold ink line on the top edge."),
    ("Sparks", "Now and then an arc leaps from an eye's outer corner and crawls back over the head toward the temple, hugging the skin, forking once and crackling into a new shape many times a second while it lives, then fades. Each eye's sparks keep their own clock (Live 3D)."),
    ("Mouth and belly", "The open lopsided grin, now a little higher on the face, and the four belly plates split by glowing lightning seams with the climbing pulse."),
    ("Body plan", "The round-14 head on Inferno's body: upright, a slight forward lean, pooling onto the floor, a short plain tail."),
]
DEFAULT_DIR = "d1e1b2"


def notes(rows: list[tuple[str, str]]) -> str:
    return "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in rows)


def buttons() -> str:
    return "\n          ".join(
        f'<button data-dir="{key}" aria-pressed="{str(key == DEFAULT_DIR).lower()}">{name}</button>' for key, name, _ in DIRECTIONS
    )


def option_notes() -> str:
    out = []
    for key, name, text in DIRECTIONS:
        hidden = "" if key == DEFAULT_DIR else " hidden"
        out.append(f'<dl data-dir-note="{key}"{hidden}><div><dt>{name}</dt><dd>{text}</dd></div></dl>')
    return "\n      ".join(out)


def all_forms() -> list[str]:
    return [key for key, _, _ in DIRECTIONS]


def write_page() -> Path:
    html = TEMPLATE.read_text(encoding="utf-8")
    for key, value in {
        "{{TITLE}}": NAME,
        "{{NAME}}": NAME,
        "{{LEDE}}": LEDE,
        "{{NOTES}}": notes(NOTES),
        "{{DIR_BUTTONS}}": buttons(),
        "{{PICK_LABEL}}": PICK_LABEL,
        "{{OPTION_NOTES}}": option_notes(),
    }.items():
        html = html.replace(key, value)
    PAGE.parent.mkdir(parents=True, exist_ok=True)
    PAGE.write_text(html, encoding="utf-8")
    return PAGE


def render(size: int, frames: str, forms: str, out: Path | None) -> int:
    cmd = [sys.executable, str(ROOT / "tools/slugs/render_concept.py"), str(PAGE), "--size", str(size), "--timeout", "3000", "--forms", forms]
    if frames:
        cmd += ["--frames", frames]
    if out:
        cmd += ["--out", str(out)]
    return subprocess.run(cmd, cwd=ROOT).returncode


def write_artifact() -> Path:
    frames = {}
    for jpg in sorted((PAGE.parent / "frames").glob("*.jpg")):
        frames[jpg.stem] = "data:image/jpeg;base64," + base64.b64encode(jpg.read_bytes()).decode("ascii")
    html = PAGE.read_text(encoding="utf-8")
    html = html.replace('<script id="vs"', f"<script>window.__FRAMES__ = {json.dumps(frames)};</script>\n" + '<script id="vs"', 1)
    BUILD.mkdir(parents=True, exist_ok=True)
    out = BUILD / "tazerling.html"
    out.write_text(html, encoding="utf-8")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=480)
    parser.add_argument("--frames", default="")
    parser.add_argument("--forms", default="", help="comma-separated dNeM form keys; default is every option on the page")
    parser.add_argument("--out", type=Path, help="render somewhere other than the page's frames/ folder (drafts)")
    parser.add_argument("--no-render", action="store_true")
    args = parser.parse_args()
    write_page()
    if not args.no_render:
        if not args.out and not args.forms:
            # A full render replaces the page's frames, so stale directions never linger.
            shutil.rmtree(PAGE.parent / "frames", ignore_errors=True)
        if render(args.size, args.frames, args.forms or ",".join(all_forms()), args.out):
            return 1
    if not args.out:
        print(write_artifact())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
