"""Build isolated settings schema/store regressions; tests never enter playable projects."""
import json
from pathlib import Path
import subprocess

from build_combat_range import generate
from verify_movement import definitions

ROOT = Path(__file__).resolve().parents[1]


def main():
    generate()
    tests = ["tools/studio/" + name for name in (
        "settings-store-check.server.luau", "settings-test-store.luau", "settings-client-check.client.luau"
    )]
    for command in (["stylua", "--check", *tests], ["selene", *tests]):
        subprocess.run(command, cwd=ROOT, check=True)
    project = json.loads((ROOT / "combat-range.private.project.json").read_text())
    project["name"] = "SlugshotSettingsCheck"
    project["tree"]["ServerScriptService"]["SettingsStoreCheck"] = {
        "$path": "tools/studio/settings-store-check.server.luau"
    }
    persistence = project["tree"]["ServerScriptService"]["SettingsPersistence"]
    persistence["ProductionSettingsStore"] = persistence["SettingsStore"]
    persistence["SettingsStore"] = {"$path": "tools/studio/settings-test-store.luau"}
    project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["SettingsClientCheck"] = {
        "$path": "tools/studio/settings-client-check.client.luau"
    }
    path = ROOT / "build/settings-check.project.json"
    # Rojo resolves paths relative to the generated project, one directory below root.
    def paths(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path":
                    node[key] = "../" + value
                else:
                    paths(value)
    paths(project)
    path.write_text(json.dumps(project, indent=2))
    subprocess.run(["rojo", "build", str(path), "--output", "build/SlugshotSettingsCheck.rbxlx"], cwd=ROOT, check=True)
    subprocess.run(["rojo", "sourcemap", "--absolute", str(path), "--output", "build/settings-check.sourcemap.json"], cwd=ROOT, check=True)
    subprocess.run(["luau-lsp", "analyze", f"--definitions=@roblox={definitions().relative_to(ROOT).as_posix()}",
                    "--sourcemap=build/settings-check.sourcemap.json", *tests], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
