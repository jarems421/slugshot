"""Build the Tormato concept page from its signed-distance template.

The page shows the base form with eye options to compare. Each option is rendered on its own
(front, three-quarter, side, back, a face close-up and a belly close-up); Live 3D on the page draws
any combination. Writes the page to docs/slugs/catalog/evidence/tormato/, renders with
render_concept.py, and writes a self-contained copy with the frames embedded to build/slugs/tormato/
for publishing as an artifact.

    python tools/slugs/build_tormato_concept.py                                  # page, renders, artifact
    python tools/slugs/build_tormato_concept.py --forms e1 --frames 0,3 --out <dir>   # a draft
    python tools/slugs/build_tormato_concept.py --no-render                      # page and artifact only
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
TEMPLATE = ROOT / "tools/slugs/tormato_concept/template.html"
PAGE = ROOT / "docs/slugs/catalog/evidence/tormato/tormato.html"
BUILD = ROOT / "build/slugs/tormato"

NAME = "Tormato"
LEDE = (
    "Base form final (owner, 2026-11-15). Transformed form, round 4: your dragon wings, ram horns curled "
    "up over his head like Rammstone's, no arms or legs, and a striped red tail with a small grey tip."
)
BASE = [
    ("Head and body", "Boon Doc's approved body plan, upright with a slight lean, the crown a little taller like the reference's dome. The pooled base's folds twist as they rise, like a skirt mid-spin. He sways in a slow circle, as if the wind keeps turning him (Live 3D)."),
    ("Eyes", "Eye of the storm in the almond shape, with a positive canthal tilt: the outer corners sit higher than the inner. The top arch peaks toward the inner corner and the bottom dips lowest toward the outer; the inner end is blunt and round, closed by the fine lower line. Each eye sits a little below the skin and rises in a rounded glassy cap under a rolled upper lid; the storm sinks in like a funnel, sliding against the rim as he turns."),
    ("Horns", "Short, thick pale-yellow horns laid straight back by the wind, the tips lifting and dipped in storm grey; set a little further forward on the head and about a fifth shorter."),
    ("Twister bands", "Deep crimson bands of wind spiral up round him, tight near the base and opening toward the shoulders, with a slow wave so they flow. Each is one long brush stroke per turn, fine at both ends, thinning to a point wherever it meets the belly or the face. Where they open out toward the shoulders, a finer line runs between each pair, so his upper back is never bare. They wheel slowly round him in Live 3D."),
    ("Forehead", "A tornado mark in the bands' crimson: one solid funnel, wide and rounded at the top and narrowing straight down to a point just above his eyes, with thin curved gaps across it, slanted a touch so it reads as spinning."),
    ("Mouth", "The lopsided open grin, high on the face and calm, with a row of top teeth and two round, pointed fangs rising from behind the lower lip, clear below the top teeth from the front, the side or three-quarters."),
    ("Colour", "Vermilion, redder than Inferno's orange, deepening down the back and warming over the muzzle; a butter-yellow belly with a warm line round its edge and faint ripples of air across it; storm grey for the wind."),
]
COMET = [
    ("Idea", "After your reference: a red dragon with curled horns and dragon wings. His own face and colours make him Tormato, and the grey-fraying wings keep him clear of Inferno."),
    ("Head and face", "His base face (Eye of the storm eyes, the grin with two fangs, the tornado mark) with the horns grown into thick ram horns curled like Rammstone's: each rises up and back, then curls round above and behind his head and forward again, the point pushed forward, so the curl sits up out of his face. Ridged, with storm-grey tips."),
    ("Body", "A dragon's torso with no arms or legs: the back of his head flows into a thick neck and a deep chest dropping below the head, a narrower waist, then haunches."),
    ("Wings (your pick)", "Dragon wings: an arm bone out to the wrist, three finger bones splaying to the trailing edge, scalloped membrane between them. Vermilion deepening toward the edge, which frays into storm grey; the bones darker. The flap travels out along the span, so they bend rather than hinge (Live 3D)."),
    ("Tail", "A long red tail tapering smoothly from his haunches to a point, curving up a little, striped with the crimson twister bands that wind along his body, and tipped with a small storm-grey tip like the slugs' antenna tips."),
    ("Belly", "Butter yellow underneath, from under the chin back along the body, narrowing down the tail."),
]
# The current picks; none left to choose.
BASESEL: dict = {}
# Option rows: (shader key letter, label, [(value, name, note), ...]).
OPTIONS: list = []


def key(sel: dict[str, int]) -> str:
    return "".join(f"{g}{sel.get(g, BASESEL[g])}" for g in BASESEL) or "base"


def all_forms() -> list[str]:
    # The picks, then each option on its own, then the transformed form.
    forms = [key({})]
    for g, _, opts in OPTIONS:
        forms += [key({g: v}) for v, _, _ in opts if v != BASESEL[g]]
    return forms + (["comet"] if COMET else [])


def default_frames() -> str:
    return "0,3,6,12" if OPTIONS else ",".join(str(i) for i in range(24))


def notes(rows: list[tuple[str, str]]) -> str:
    return "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in rows)


def option_rows() -> str:
    rows = []
    if COMET:
        rows.append('<div class="controls" role="group" aria-label="Form"><button data-form="base" aria-pressed="true">Base form</button><button data-form="comet" aria-pressed="false">Transformed</button></div>')
    for g, label, opts in OPTIONS:
        buttons = "".join(
            f'<button data-opt="{g}" data-val="{v}" aria-pressed="{str(v == BASESEL[g]).lower()}">{n}</button>' for v, n, _ in opts
        )
        rows.append(f'<div class="optrow" role="group" aria-label="{label}"><span class="glabel">{label}</span>{buttons}</div>')
    return "\n      ".join(rows)


def option_notes() -> str:
    out = []
    for g, label, opts in OPTIONS:
        for v, n, text in opts:
            hidden = "" if v == BASESEL[g] else " hidden"
            out.append(f'<dl data-opt-note="{g}{v}"{hidden}><div><dt>{label} · {n}</dt><dd>{text}</dd></div></dl>')
    return "\n      ".join(out)


def write_page() -> Path:
    html = TEMPLATE.read_text(encoding="utf-8")
    for k, value in {
        "{{TITLE}}": NAME,
        "{{NAME}}": NAME,
        "{{LEDE}}": LEDE,
        "{{NOTES_BASE}}": notes(BASE),
        "{{NOTES_COMET}}": notes(COMET),
        "{{FORM_BUTTONS}}": option_rows(),
        "{{FORM_NOTES}}": option_notes(),
        "{{BASESEL}}": json.dumps(BASESEL),
        "{{VIEWS}}": "[" + default_frames() + "]",
    }.items():
        html = html.replace(k, value)
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
    out = BUILD / "tormato.html"
    out.write_text(html, encoding="utf-8")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=480)
    parser.add_argument("--frames", default="", help="turntable indices out of 24 (default: all 24 with no options, else 0,3,6,12); close-ups are always added")
    parser.add_argument("--forms", default="", help="comma-separated option keys such as e1; default is every option")
    parser.add_argument("--out", type=Path, help="render somewhere other than the page's frames/ folder (drafts)")
    parser.add_argument("--no-render", action="store_true")
    args = parser.parse_args()
    write_page()
    if not args.no_render:
        if not args.out and not args.forms:
            # A full render replaces the page's frames, so stale options never linger.
            shutil.rmtree(PAGE.parent / "frames", ignore_errors=True)
        if render(args.size, args.frames or default_frames(), args.forms or ",".join(all_forms()), args.out):
            return 1
    if not args.out:
        print(write_artifact())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
