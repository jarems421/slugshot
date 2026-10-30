"""Verify the isolated movement experiment without changing the foundation build."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
# Roblox API types for luau-lsp, from the luau-lsp release pinned in rokit.toml (MIT).
# Data only (never executed); cached in ignored .tools/ and checked by hash.
DEFINITIONS = ROOT / ".tools/luau/globalTypes.None.d.luau"
DEFINITIONS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.None.d.luau"
DEFINITIONS_SHA256 = "9ad75109b8dc9197f6d1726208bfa0b12de47c3a43672a4fa43227f0cec609ee"


def run(*args):
    print("+ " + " ".join(args), flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


def definitions():
    if DEFINITIONS.exists() and hashlib.sha256(DEFINITIONS.read_bytes()).hexdigest() == DEFINITIONS_SHA256:
        return DEFINITIONS
    print("+ download " + DEFINITIONS_URL, flush=True)
    with urllib.request.urlopen(DEFINITIONS_URL, timeout=60) as response:
        data = response.read()
    digest = hashlib.sha256(data).hexdigest()
    assert digest == DEFINITIONS_SHA256, f"Roblox type definitions changed upstream ({digest})"
    DEFINITIONS.parent.mkdir(parents=True, exist_ok=True)
    DEFINITIONS.write_bytes(data)
    return DEFINITIONS


def main():
    run(sys.executable, "tools/verify.py")
    run("stylua", "--check", "experiments/movement")
    run("selene", "experiments/movement")
    # Strict type check of every movement script (clients, server, shared, tests) against
    # the Roblox API, with instance paths from a sourcemap of the test project.
    run("rojo", "sourcemap", "movement.test.project.json", "--output", "build/movement.sourcemap.json")
    run("luau-lsp", "analyze", f"--definitions=@roblox={definitions().relative_to(ROOT).as_posix()}",
        "--sourcemap=build/movement.sourcemap.json", "experiments/movement")
    for name, output in [("movement.project.json", "SlugshotMovementLab"), ("movement.test.project.json", "SlugshotMovementTests")]:
        project = json.loads((ROOT / name).read_text(encoding="utf-8"))
        assert "private-assets" not in json.dumps(project), "Restricted assets must not be mapped"
        run("rojo", "build", name, "--output", f"build/{output}.rbxlx")
        tree = ET.parse(ROOT / f"build/{output}.rbxlx")
        scripts = [i for i in tree.iter("Item") if i.attrib.get("class") in {"Script", "LocalScript", "ModuleScript"}]
        names = [i.findtext("Properties/string[@name='Name']") for i in scripts]
        assert "MovementSandbox" in names and "Presentation" in names and "MotionMath" in names
        assert "Clips" in names and "OriginalClips" in names
        assert "MovementPrivateClips" not in names, "Private clip data must stay out of public builds"
        for spec in ("Math.spec", "Clips.spec"):
            assert (spec in names) == (name == "movement.test.project.json"), "Test scripts leaked into playable sandbox"
        assert not any(i.attrib.get("class") in {"KeyframeSequence", "Animation"} for i in tree.iter("Item")), "Public build must remain independent of restricted clips and IDs"
    private = json.loads((ROOT / "movement.private.project.json").read_text(encoding="utf-8"))
    assert json.dumps(private).count("private-assets") == 1, "Only the generated clip module may be mapped privately"
    print("PASS: foundation unchanged; movement builds, Luau checks and private-asset/test isolation")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, subprocess.CalledProcessError, OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
