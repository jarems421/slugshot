"""Verify creature contracts, strict Luau and isolation; optionally exercise Blender."""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/slugs"))
from common import compile_runtime
from cli import blender_executable
from verify_movement import definitions


def run(*args):
    print("+ " + " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--blender", action="store_true", help="Generate, export, render, reimport and test corrupted assets headlessly")
    args = parser.parse_args()
    run(sys.executable, "tools/verify.py")
    run(sys.executable, "-m", "unittest", "discover", "-s", "tests/slugs", "-p", "test_*.py", "-v")
    with tempfile.TemporaryDirectory(prefix="slug-data-") as directory:
        path = Path(directory) / "Definitions.luau"
        compile_runtime(path)
        run("stylua", path)
        if path.read_bytes() != (ROOT / "experiments/creatures/shared/Definitions.luau").read_bytes():
            raise ValueError("Stale Roblox definitions: run python tools/slugs/cli.py compile")
    run("stylua", "--check", "experiments/creatures")
    run("selene", "experiments/creatures")
    run("rojo", "sourcemap", "creatures.test.project.json", "--output", "build/creatures.sourcemap.json")
    run("luau-lsp", "analyze", f"--definitions=@roblox={definitions().relative_to(ROOT).as_posix()}", "--sourcemap=build/creatures.sourcemap.json", "experiments/creatures")
    for project, name, is_test in (("creatures.project.json", "SlugshotCreaturePreview", False), ("creatures.test.project.json", "SlugshotCreatureTests", True)):
        output = f"build/{name}.rbxlx"
        run("rojo", "build", project, "--output", output)
        tree = ET.parse(ROOT / output)
        names = [i.findtext("Properties/string[@name='Name']") for i in tree.iter("Item") if i.attrib.get("class") in {"Script", "ModuleScript", "LocalScript"}]
        assert ("Timeline.spec" in names) == is_test, "Creature tests leaked into preview build"
        assert ("CreatureVisualTests" in names) == is_test, "Client fixture tests leaked into preview build"
        assert {"Visual", "Playback", "NativeFixture", "Timeline", "Definitions"} <= set(names), "Missing creature modules"
        assert not {"MovementSandbox", "MovementExperiment", "Foundation", "MovementPrivateClips"} & set(names), "Unrelated systems leaked into creature lab"
        for i in tree.iter("Item"):
            text = i.findtext("Properties/*[@name='Source']") or ""
            assert "rbxassetid://" not in text or i.findtext("Properties/string[@name='Name']") == "Playback", "Public IDs leaked into lab"
    if args.blender:
        for config in sorted((ROOT / "assets/source/slugs/species").glob("*.json")):
            run(sys.executable, "tools/slugs/cli.py", "all", "--species", config.stem)
        run(blender_executable(), "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1", "--python", ROOT / "tests/slugs/blender_failures.py")
        run(blender_executable(), "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1", "--python", ROOT / "tests/slugs/flopper_motion.py")
    print("PASS: creature contracts, generated-data parity, Luau, foundation and lab/test isolation. Studio execution is separate.")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
