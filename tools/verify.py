"""Run the same foundation checks locally and in CI. Python 3.11+, stdlib only."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys
import tomllib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    print("+ " + " ".join(args), flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


def nodes(path):
    return ET.parse(path).getroot()


def item_at(tree, *names):
    parent = tree
    for name in names:
        matches = [x for x in parent.findall("Item")
                   if x.findtext("Properties/string[@name='Name']") == name]
        assert len(matches) == 1, f"Expected exactly one instance at {names}: {name}"
        parent = matches[0]
    return parent


def verify_builds():
    normal = nodes(ROOT / "build/Slugshot.rbxlx")
    test = nodes(ROOT / "build/SlugshotTests.rbxlx")
    for tree in (normal, test):
        for path, kind, source in [
            (("ReplicatedStorage", "Shared", "Foundation"), "ModuleScript", "src/shared/Foundation.luau"),
            (("ServerScriptService", "Server"), "Script", "src/server/init.server.luau"),
            (("StarterPlayer", "StarterPlayerScripts", "Client"), "LocalScript", "src/client/init.client.luau"),
        ]:
            item = item_at(tree, *path)
            assert item.attrib["class"] == kind, (path, kind)
            assert item.findtext("Properties/*[@name='Source']") == (ROOT / source).read_text(encoding="utf-8"), path
    normal_scripts = [x for x in normal.iter("Item") if x.attrib.get("class") in {"Script", "LocalScript", "ModuleScript"}]
    assert len(normal_scripts) == 3, "Normal build must contain only the three setup scripts"
    spec = item_at(test, "ServerScriptService", "FoundationTests", "Foundation.spec")
    assert spec.attrib["class"] == "Script"
    assert spec.findtext("Properties/*[@name='Source']") == (ROOT / "tests/studio/Foundation.spec.server.luau").read_text(encoding="utf-8")
    skills = list((ROOT / ".agents/skills").glob("*/SKILL.md"))
    assert skills, "Missing project skills"
    assert {p.parent.name for p in skills} == {p.parent.name for p in (ROOT / ".claude/skills").glob("*/SKILL.md")}, "Skill sets differ"
    for skill in skills:
        # Our metadata uses only two plain scalar fields, not general YAML.
        header = skill.read_text(encoding="utf-8").split("---", 2)
        assert len(header) == 3 and not header[0], skill
        fields = dict(line.split(": ", 1) for line in header[1].strip().splitlines())
        assert set(fields) == {"name", "description"}, skill
        assert fields["name"] == skill.parent.name and re.fullmatch(r"[a-z0-9-]{1,64}", fields["name"]), skill
        assert fields["description"].strip() and ": " not in fields["description"], skill
        assert skill.read_bytes() == (ROOT / ".claude/skills" / skill.parent.name / "SKILL.md").read_bytes(), skill
    print("PASS: instance placement, script classes, source fidelity, test isolation and skill parity")


def main():
    for tool in ("rojo", "stylua", "selene", "luau-lsp"):
        if not shutil.which(tool):
            raise RuntimeError(f"Missing {tool}. See docs/development.md before installing anything.")
        run(tool, "--version")
    # Parse manifests early so malformed configuration fails before a build.
    for path in ROOT.glob("*.project.json"):
        json.loads(path.read_text(encoding="utf-8"))
    for name in ("rokit.toml", "stylua.toml", "selene.toml"):
        tomllib.loads((ROOT / name).read_text(encoding="utf-8"))
    run("stylua", "--check", "src", "tests/studio")
    run("selene", "src", "tests/studio")
    # Engine globals require Studio or full engine type definitions. Check the
    # engine-independent shared module here without pretending to check those.
    run("luau-lsp", "analyze", "--platform=standard", "src/shared/Foundation.luau")
    (ROOT / "build").mkdir(exist_ok=True)
    run("rojo", "build", "default.project.json", "--output", "build/Slugshot.rbxlx")
    run("rojo", "build", "test.project.json", "--output", "build/SlugshotTests.rbxlx")
    run("rojo", "sourcemap", "default.project.json", "--output", "build/sourcemap.json")
    verify_builds()
    print("PASS: automated foundation checks. Studio execution remains a separate check.")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, RuntimeError, subprocess.CalledProcessError, OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
