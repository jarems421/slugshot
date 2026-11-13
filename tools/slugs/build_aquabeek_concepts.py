"""Build the three Aquabeek concept prototypes from one signed-distance template.

Writes each page to docs/slugs/catalog/evidence/aquabeek/<letter>/, renders its
turntable with render_concept.py, and writes a self-contained copy with the frames
embedded to build/slugs/aquabeek/ for publishing as an artifact.

    python tools/slugs/build_aquabeek_concepts.py               # pages, renders, artifacts
    python tools/slugs/build_aquabeek_concepts.py --only a --frames 0,3,6,12 --size 360
    python tools/slugs/build_aquabeek_concepts.py --no-render   # pages and artifacts only
"""
from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "tools/slugs/aquabeek_concept/template.html"
PAGES = ROOT / "docs/slugs/catalog/evidence/aquabeek"
BUILD = ROOT / "build/slugs/aquabeek"


def notes(rows: list[tuple[str, str]]) -> str:
    return "".join(f"<div><dt>{k}</dt><dd>{v}</dd></div>" for k, v in rows)


# Three faces to compare, shared by every prototype. Each has almond eyes set into the face,
# lids that carry the expression, a coloured iris and a smile set into the face with solid teeth.
FACES = [
    ("Sly", [
        ("Eyes", "Almond eyes with heavy, level lids and a sea-green iris looking straight at you. Sure of itself."),
        ("Mouth", "A closed smirk of solid teeth, lifted on one side, with ink creases hooking up at the corners."),
        ("Marking", "Three gill-slit marks on each cheek."),
    ]),
    ("Bright", [
        ("Eyes", "Open almond eyes, lightly lidded, with glowing aqua irises. Alert and eager."),
        ("Mouth", "A wide, even grin showing a band of top teeth over a dark mouth, creased at both corners."),
        ("Marking", "A small glowing water drop on the forehead, between the eyes."),
    ]),
    ("Mischief", [
        ("Eyes", "One lid raised and one dropped, with warm amber irises that stand out against the blue. Up to something."),
        ("Mouth", "A lopsided open grin with a row of small pointed teeth, friendly rather than fangs."),
        ("Marking", "Dark teal freckles across the nose."),
    ]),
]


def face_notes(faces=None) -> str:
    faces = faces or [(f"f{i}", f"Face {i + 1} · {name}", rows) for i, (name, rows) in enumerate(FACES)]
    out = []
    for i, (key, name, rows) in enumerate(faces):
        hidden = "" if i == 0 else " hidden"
        out.append(f'<dl data-face-note="{key}"{hidden}><div><dt>Option</dt><dd>{name}</dd></div>{notes(rows)}</dl>')
    return "\n      ".join(out)


PROTOS = {
    "a": {
        "index": 0,
        "name": "Aquabeek A · Crestfin",
        "lede": "The closest to the original and to Inferno's build: his upright body, lean and swept ear-antennae, retold as a cheerful water slug.",
        "base": [
            ("Body", "Inferno's body plan: upright, a slight forward lean, no arms or feet, pooling onto the floor, and a short tail that ends in a small flat fluke."),
            ("Fin-ears", "Inferno's swept-back ear-antennae rebuilt as webbed fins, with soft scallops between the rays and glowing aqua tips."),
            ("Back", "One continuous dorsal fin from the tail up over the crown, scalloped between darker rays and paling at the edge. It replaces Inferno's blade spines."),
            ("Eyes", "Big round eyes with large dark pupils glancing up, two highlights and relaxed teal lids just covering the top. Shallow lenses set into soft sockets, not bug eyes."),
            ("Mouth", "A wide, open, happy smile with two small rounded teeth at the top and a tongue."),
            ("Colour", "Ocean-blue front, teal back and crown meeting along a soft wave line, three teal droplet freckles on each cheek."),
            ("Belly", "A pale sky-blue panel whose top edge rolls like a wave, with a lighter crest along it."),
            ("Familiar from the original", "Blue and teal two-tone, a pale belly, two fins on the head, big round eyes and a happy open grin."),
            ("Its own", "Inferno's silhouette and swept fins instead of upright notched fins, a dorsal fin, a wave-edged belly instead of a straight panel, and no buck-tooth gap."),
        ],
        "comet": [
            ("Shape", "A marlin-dragon on Inferno's flying body: a long bill, swept pectoral fins with rays and a foam edge, a tall scalloped sail down the back and a crescent tail fin."),
            ("Its DNA", "The same fin-ears, round eyes (now with a low, determined lid), grin and two-tone colouring."),
            ("Wake", "A spiralling ribbon of water streams back from the tail, where Inferno has fire."),
        ],
    },
    "b": {
        "index": 1,
        "name": "Aquabeek B · Gillbeak",
        "lede": "Redrawn from the owner's reference, then rebuilt on Inferno's body: a soft, leaning water slug with a teal hood, swept fins and a sculpted face.",
        "forms": [("f3", "Base form"), ("comet", "Transformed")],
        "base": [
            ("Body", "Inferno's body plan: a soft body leaning slightly forward, pooling onto the floor in uneven lobes. No arms or feet. A short tail, shortened again, ends in a small flat fluke."),
            ("Hood", "A teal hood over the crown and down the sides of the head, dipping to a point between the eyes. It blends into the blue face instead of ending in a hard seam."),
            ("Fins", "A short, broad fin at each top corner and three small fins down each side of the head, all sweeping back, teal paling to glassy tips."),
            ("Back", "A low webbed dorsal fin down the back, on a teal stripe that runs from the hood into the tail."),
            ("Eyes", "Sculpted like Floppy's rather than painted on: tall almond openings tilted up at the outer corner under a light rolled lid, a bold black liner ending in a sharp wing and five curved lashes. A living iris: deep sea at the top to glowing aqua at the bottom, fine light and dark fibres, a lighter jagged ring round a soft round pupil that slowly breathes, light gathering low in the iris, and a big highlight overlapping the pupil."),
            ("Eyeshadow", "Blended, with no edge: deep violet at the lash line fading up into teal shimmer, reaching higher toward the outer corner like a smoky wing."),
            ("Face", "A soft muzzle under the eyes gives the face planes, with a wide socket around each eye."),
            ("Mouth", "A soft, sweet smile, centred and narrower than the eyes: lips tinted blue-violet, a cupid's bow on the upper lip and a fuller, glossy lower lip, slightly parted over a band of top teeth, with both corners turned up into small dimples, the right a touch higher."),
            ("Markings", "A small glowing water drop under the point of the hood. A pale belly starting low on the front, its top a gentle three-crest wave, blended into the blue the same way all round with a foam line just inside its edge. On the belly, a bold glowing drop outlined in deep teal, falling into two deep-teal ripple rings with two small splash droplets."),
            ("Surface", "Glossy, with a faint glassy glow at the edges."),
        ],
        "comet": [
            ("Shape", "Unchanged for now: a long eel-dragon that swims in an S, with a short flat bill, a ribbon fin along its back and belly, and a paddle tail."),
            ("Next", "Once the base form is agreed, the transformation gets redrawn to match it."),
        ],
    },
    "c": {
        "index": 2,
        "name": "Aquabeek C · Breaker",
        "lede": "The boldest, Inferno's rival: taller and sleeker, leaning in, with a crest that curls forward like a breaking wave and a manta-like transformation.",
        "base": [
            ("Body", "Inferno's body plan, slimmer, taller in the head and leaning further forward, ready to go. No arms or feet, a short tail with a small fluke."),
            ("Wave crest", "One blade rising off the crown and curling forward like a breaking wave, paling to glowing foam at the curl. Two short swept fin-ears sit below it."),
            ("Back", "A low dorsal fin down the back, and a thin line of foam where the teal back meets the blue front."),
            ("Eyes", "Round eyes with a glowing aqua iris around a small pupil, and a lid dipping toward the nose: focused, a predator among slugs, still cute."),
            ("Mouth", "A wide, confident grin with two small fangs near the corners, and no tongue."),
            ("Colour", "Cobalt front, bright teal back, a pale cyan belly."),
            ("Belly", "A pale belly that narrows to a point toward the chest, like a wave's trough."),
            ("Familiar from the original", "The blue and teal colouring, pale belly, a fin on the head, big eyes and a toothy grin."),
            ("Its own", "A single breaking-wave crest, glowing irises, a narrow belly and a cockier attitude."),
        ],
        "comet": [
            ("Shape", "A manta-swordfish: broad, slowly flapping wings with foam edges, a long thin bill, a tall swept sail and a whip tail."),
            ("Its DNA", "The same fin-ears, glowing-iris eyes under a low lid, grin and colouring."),
            ("Wake", "A spiralling ribbon of water streams back from the tail."),
        ],
    },
}


def forms(spec: dict) -> list[tuple[str, str]]:
    return spec.get("forms", [(f"f{i}", f"Face {i + 1} · {name}") for i, (name, _) in enumerate(FACES)] + [("comet", "Transformed")])


def write_page(letter: str) -> Path:
    spec = PROTOS[letter]
    html = TEMPLATE.read_text(encoding="utf-8")
    for key, value in {
        "{{TITLE}}": spec["name"].replace(" · ", " "),
        "{{NAME}}": spec["name"],
        "{{LETTER}}": letter.upper(),
        "{{LEDE}}": spec["lede"],
        "{{PROTO}}": str(spec["index"]),
        "{{NOTES_BASE}}": notes(spec["base"]),
        "{{FACE_NOTES}}": face_notes(spec.get("faces")) if len(forms(spec)) > 2 else "",
        "{{FORM_BUTTONS}}": "\n        ".join(
            f'<button data-form="{key}" aria-pressed="{str(n == 0).lower()}">{label}</button>' for n, (key, label) in enumerate(forms(spec))
        ),
        "{{NOTES_COMET}}": notes(spec["comet"]),
    }.items():
        html = html.replace(key, value)
    out = PAGES / letter / f"aquabeek-{letter}.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    return out


def render(page: Path, size: int, frames: str, form_keys: str) -> int:
    cmd = [sys.executable, str(ROOT / "tools/slugs/render_concept.py"), str(page), "--size", str(size), "--timeout", "1500", "--forms", form_keys]
    if frames:
        cmd += ["--frames", frames]
    return subprocess.run(cmd, cwd=ROOT).returncode


def write_artifact(letter: str, page: Path) -> Path:
    frames = {}
    for jpg in sorted((page.parent / "frames").glob("*.jpg")):
        frames[jpg.stem] = "data:image/jpeg;base64," + base64.b64encode(jpg.read_bytes()).decode("ascii")
    html = page.read_text(encoding="utf-8")
    embed = f"<script>window.__FRAMES__ = {json.dumps(frames)};</script>\n"
    html = html.replace('<script id="vs"', embed + '<script id="vs"', 1)
    BUILD.mkdir(parents=True, exist_ok=True)
    out = BUILD / f"aquabeek-{letter}.html"
    out.write_text(html, encoding="utf-8")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", default="abc")
    parser.add_argument("--size", type=int, default=560)
    parser.add_argument("--frames", default="")
    parser.add_argument("--no-render", action="store_true")
    args = parser.parse_args()
    pages = {letter: write_page(letter) for letter in args.only}
    if not args.no_render:
        with ThreadPoolExecutor(len(pages)) as pool:
            codes = list(pool.map(lambda lp: render(lp[1], args.size, args.frames, ",".join(k for k, _ in forms(PROTOS[lp[0]]))), pages.items()))
        if any(codes):
            return 1
    for letter, page in pages.items():
        print(write_artifact(letter, page))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
