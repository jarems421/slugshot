"""Build the Boon Doc concept page from its signed-distance template.

The page compares design options for the base form: body markings, eyes, mouths and bellies. Each
option is rendered on its own against the current design (front, three-quarter, side, back and a
face close-up); Live 3D on the page draws any combination. Writes the page to
docs/slugs/catalog/evidence/boon-doc/, renders with render_concept.py, and writes a self-contained
copy with the frames embedded to build/slugs/boon-doc/ for publishing as an artifact.

    python tools/slugs/build_boon_doc_concept.py                                       # page, renders, artifact
    python tools/slugs/build_boon_doc_concept.py --forms b0e3m0y0 --frames 0,3 --out <dir>   # a draft
    python tools/slugs/build_boon_doc_concept.py --no-render                           # page and artifact only
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
TEMPLATE = ROOT / "tools/slugs/boon_doc_concept/template.html"
PAGE = ROOT / "docs/slugs/catalog/evidence/boon-doc/boon-doc.html"
BUILD = ROOT / "build/slugs/boon-doc"

NAME = "Boon Doc"
LEDE = (
    "Final design, both forms approved by the owner (2026-11-14). Base: the healing slug as a little healing angel, "
    "with angel wings, the Healing mint eye, the reference smile and a belly glowing from within. "
    "Transformed: a fat, warty flying toad with a halo, glowing bulbs down his spine and angel wings he hasn't earned."
)
BASE = [
    ("Head and body", "A crossover of Inferno's and Aquabeek's: every mass halfway between theirs, a broad, fairly flat-topped head wider than a thick neck, on a soft muzzle. Upright with a slight lean, no arms or feet; the pooled base spreads in soft folds like the hem of a robe."),
    ("Eye (picked)", "Healing mint: pure light with no pupil, a white-gold heart and pale gold turning to soft healing mint toward a teal rim, faint rays turning slowly, a small gleam."),
    ("Mouth (picked)", "The owner's drawn reference, bigger and taller: a nearly straight upper line lifting at the corners, a shallow curved lower line, one solid white shape (no tooth lines), a bold outline, a flick at his right corner and a short line under the lip."),
    ("Wings (picked)", "Angel wings after the owner's reference: low on the upper back near the spine, a modest size, set apart so they show past his sides from the front, each leaning off the skin and joined to the body only by a slim ivory stem at its root: a top edge arching up and out, hanging down into long feathers. Sculpted rows of small overlapping covert feathers along the top, long flight feathers below that fan out and curve as they go down, their rounded tips scalloping the bottom edge; each wing bends softly, the lower feathers curling back, with a slow ripple flowing down them (Live 3D). The belly's and eye's warm ivory inner light, glowing softly, warming to gold toward the bottom, with warm creases; swaying a little (Live 3D)."),
    ("Belly (picked)", "Ivory with a fine gold edge, glowing warm from within and warming to luminous white gold toward the base."),
    ("Gilded lid", "The rolled upper lid over the eye is gold, thickest at the top and tapering to points at the corners, with a fine ink line."),
    ("Halo", "A gold band with a little thickness, floating just above his head, tilted toward you, glowing and bobbing gently (Live 3D)."),
    ("Antennae", "Soft, of middling length, set toward the edges of the head and flopping back, the tips glowing gold."),
    ("Colour", "Soft celadon deepening to teal down the back; gold and ivory are the divine light."),
    ("Healing light", "Small four-point stars of gold light drift up round him (Live 3D)."),
]
# The transformed form, approved as final by the owner on 2026-11-14.
COMET = [
    ("Idea", "The show's transformed form, from the owner's two stills, made a little ugly on purpose (the owner: \"it could be a little joke\"): a fat, warty, flat-headed toad that is mostly head, with a halo and angel wings it hasn't earned."),
    ("Head and cap", "Broad, flat-topped and one smooth surface; the dark teal cap is painted over the top, its front edge dipping over the eye. The Healing mint eye beneath, the halo floating above the forehead, clear of the spines."),
    ("Grin", "The reference smile, wider: one solid white shape with a bold outline."),
    ("Body", "Fat and saggy: a heavy gut and a double chin, low warts all over the top, sides and face, kept clear of the eye and mouth. Celadon, deepening to teal over the top, the ivory underside following the body's curve and blending slowly up through pale mint into the green, with no edge line, an inner light glowing from the middle of the belly."),
    ("Spine", "A row of seven spikes down the middle from the forehead over the head and down the back, largest over the head, each tipped with a round bulb glowing ivory gold and lighting the air round it; they sway in turn (Live 3D)."),
    ("Arms", "Thick and pudgy, held forward but relaxed and carrying their weight: the upper arm drops to a bent elbow, the forearm reaches forward and the hand hangs from the wrist, four stubby fingers drooping and curling, round pads paling to glowing ivory: healing hands."),
    ("Legs", "Short, fat toad legs dangling under the heavy body, as if the wings are only just holding him up: fat thighs, knees bent a little outward, limp three-toed feet pointing down and back, swaying a little (Live 3D)."),
    ("Wings", "His angel wings lying along his upper back, raised a little off it in a shallow V, the flight feathers fanned open and parting at their tips like a spread wing, beating slowly (Live 3D)."),
]
# The owner's picks (2026-11-14): angel wings (b3), Healing mint eye (e2), reference smile (m0),
# inner and rising light belly together (y7). Every row is picked, so the page shows one design.
BASESEL = {"b": 3, "e": 2, "m": 0, "y": 7}
# Option rows: (shader key letter, label, [(value, name, note), ...]); the first is the row's default.
# Earlier options are history (see the record); their shader code is kept where still in use.
OPTIONS: list = []


def key(sel: dict[str, int]) -> str:
    return "".join(f"{g}{sel.get(g, BASESEL[g])}" for g in "bemy")


def all_forms() -> list[str]:
    # The picks with each row's default, then each option on its own.
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
        "{{NOTES_COMET}}": notes(COMET or []),
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
    out = BUILD / "boon-doc.html"
    out.write_text(html, encoding="utf-8")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=480)
    parser.add_argument("--frames", default="", help="turntable indices out of 24 (default: all 24 with no options, else 0,3,6,12); a close-up is always added")
    parser.add_argument("--forms", default="", help="comma-separated option keys such as b0e3m0y0; default is every option")
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
