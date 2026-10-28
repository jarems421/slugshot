"""Verify the isolated movement experiment without changing the foundation build."""
from pathlib import Path
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    print("+ " + " ".join(args), flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    run(sys.executable, "tools/verify.py")
    run("stylua", "--check", "experiments/movement")
    run("selene", "experiments/movement")
    run("luau-lsp", "analyze", "--platform=standard", "experiments/movement/shared/MotionMath.luau")
    for name, output in [("movement.project.json", "SlugshotMovementLab"), ("movement.test.project.json", "SlugshotMovementTests")]:
        project = json.loads((ROOT / name).read_text(encoding="utf-8"))
        assert "private-assets" not in json.dumps(project), "Restricted assets must not be mapped"
        run("rojo", "build", name, "--output", f"build/{output}.rbxlx")
        tree = ET.parse(ROOT / f"build/{output}.rbxlx")
        scripts = [i for i in tree.iter("Item") if i.attrib.get("class") in {"Script", "LocalScript", "ModuleScript"}]
        names = [i.findtext("Properties/string[@name='Name']") for i in scripts]
        assert "MovementSandbox" in names and "Presentation" in names and "MotionMath" in names
        assert ("Math.spec" in names) == (name == "movement.test.project.json"), "Test scripts leaked into playable sandbox"
        assert not any(i.attrib.get("class") in {"KeyframeSequence", "Animation"} for i in tree.iter("Item")), "Public build must remain independent of restricted clips and IDs"
    print("PASS: foundation unchanged; movement builds, Luau checks and private-asset/test isolation")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, subprocess.CalledProcessError, OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
