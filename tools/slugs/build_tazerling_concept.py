"""Build the Tazerling base-form concept page from its signed-distance template.

The page compares antenna and mouth options: every pairing is rendered as its own turntable.
Writes the page to docs/slugs/catalog/evidence/tazerling/, renders the turntables with
render_concept.py, and writes a self-contained copy with the frames embedded to
build/slugs/tazerling/ for publishing as an artifact.

    python tools/slugs/build_tazerling_concept.py                          # page, renders, artifact
    python tools/slugs/build_tazerling_concept.py --forms a0m2 --frames 0,2 --out <dir>   # a draft
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
    "The electric slug on Inferno's body, with glowing lightning eyes and a sculpted grin. "
    "Short, soft feelers that crackle with electricity."
)
ANTENNAE = [
    ("4", "Feelers", "Short, soft feelers in Tazerling's own blue, slim all the way with rounded ends rather than horn points. They bend and whip along their length as he moves (Live 3D). The tips themselves glow electric yellow, white-hot at the very end, and small yellow sparks crawl up each feeler toward the tip, leaping off the skin and back."),
]
MOUTHS = [
    ("2", "Grin", "The open lopsided grin, about 18% wider and deeper than before, sculpted like Aquabeek's: rolled lips, dimples, a row of top teeth with a fang toward each corner, and a tongue."),
]
NOTES = [
    ("Eyes", "Set into the head like Aquabeek's, never bulging, with no lid, set wide apart: sharp, angled almonds whose outer corners sweep up to a point, the top edge a straight line sloping toward the nose. No pupils: each eye burns electric blue, brightest in the middle, with a pale cyan core and faint crackling veins. A glowing gold line runs along the top edge, blue light spills onto the skin, and every couple of seconds a clean spark shoots from an outer corner and fades (Live 3D shows them firing)."),
    ("Body", "Inferno's body plan: upright, a slight forward lean, no arms or feet, pooling onto the floor in uneven lobes, and a short, stubby tail with a sharp yellow spike standing up from its very end, white-hot at the point."),
    ("Head", "A broad head shaped like Aquabeek's: a wide dome with a rounded crown on a slimmer neck, and a slim muzzle tucked under the eyes so nothing bulges out as cheeks."),
    ("Back", "Three sharp lightning bolts bulging out of the skin down the spine, biggest at the back of the head: electric yellow, white-hot along their raised middle, with a thin ink edge, on a midnight-indigo back."),
        ("Belly", "Pale ice blue, following the body's curve, stopping well below the mouth and widening into the base, with zigzag lightning edges, a warm hint of yellow down the middle, and stacked pale-yellow chevrons pointing down it like a charge meter."),
    ("Familiar from the original", "The royal-blue body and pale belly, yellow lightning on the head and a toothy grin."),
    ("Its own", "Inferno's body with a round head, glowing lightning eyes, crackling feelers, raised lightning bolts down the back, a chevron charge-meter belly, a spiked tail, and no buck-tooth gap or arms."),
]
DEFAULT_ANT, DEFAULT_MOUTH = "4", "2"


def notes(rows: list[tuple[str, str]]) -> str:
    return "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in rows)


def buttons(kind: str, options, default: str) -> str:
    return "\n          ".join(
        f'<button data-{kind}="{key}" aria-pressed="{str(key == default).lower()}">{name}</button>' for key, name, _ in options
    )


def option_notes() -> str:
    out = []
    for kind, label, options, default in (("ant", "Antennae", ANTENNAE, DEFAULT_ANT), ("mouth", "Mouth", MOUTHS, DEFAULT_MOUTH)):
        for key, name, text in options:
            hidden = "" if key == default else " hidden"
            out.append(f'<dl data-{kind}-note="{key}"{hidden}><div><dt>{label} · {name}</dt><dd>{text}</dd></div></dl>')
    return "\n      ".join(out)


def all_forms() -> list[str]:
    return [f"a{a}m{m}" for a, _, _ in ANTENNAE for m, _, _ in MOUTHS]


def write_page() -> Path:
    html = TEMPLATE.read_text(encoding="utf-8")
    for key, value in {
        "{{TITLE}}": NAME,
        "{{NAME}}": NAME,
        "{{LEDE}}": LEDE,
        "{{NOTES}}": notes(NOTES),
        "{{ANT_BUTTONS}}": buttons("ant", ANTENNAE, DEFAULT_ANT),
        "{{MOUTH_BUTTONS}}": buttons("mouth", MOUTHS, DEFAULT_MOUTH),
        "{{OPTION_NOTES}}": option_notes(),
        "{{MOUTH_HIDDEN}}": " hidden" if len(MOUTHS) < 2 else "",
        "{{ANT_HIDDEN}}": " hidden" if len(ANTENNAE) < 2 else "",
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
    parser.add_argument("--forms", default="", help="comma-separated aXmY pairings; default is every pairing")
    parser.add_argument("--out", type=Path, help="render somewhere other than the page's frames/ folder (drafts)")
    parser.add_argument("--no-render", action="store_true")
    args = parser.parse_args()
    write_page()
    if not args.no_render:
        if not args.out and not args.forms:
            # A full render replaces the page's frames, so stale pairings never linger.
            shutil.rmtree(PAGE.parent / "frames", ignore_errors=True)
        if render(args.size, args.frames, args.forms or ",".join(all_forms()), args.out):
            return 1
    if not args.out:
        print(write_artifact())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
