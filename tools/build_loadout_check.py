"""Disposable native loadout/inspect check with Floppy copies in slots 1, 2 and 5.

The playable range keeps the real single-Floppy loadout; fixtures never grant species.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from build_combat_range import generate

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inspect-review", action="store_true")
    args = parser.parse_args()
    generate()
    out = ROOT / 'build/loadout-check'
    out.mkdir(parents=True, exist_ok=True)
    shared = out / 'shared'
    shutil.copytree(ROOT / 'experiments/combat/shared', shared, dirs_exist_ok=True)
    module = shared / 'init.luau'
    module.write_text(module.read_text().replace('Combat.Loadout = { "Floppy", "Inferno" }',
        'Combat.Loadout = { [1] = "Floppy", [2] = "Floppy", [5] = "Floppy" }'))
    project = json.loads((ROOT / 'combat-range.private.project.json').read_text())

    def absolute(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == '$path':
                    node[key] = str(ROOT / value)
                else:
                    absolute(value)

    absolute(project)
    project['name'] = 'SlugshotLoadoutCheck'
    project['tree']['ReplicatedStorage']['Combat']['$path'] = str(shared)
    project['tree']['StarterPlayer']['StarterPlayerScripts']['LoadoutCheck'] = {
        '$path': str(ROOT / 'tools/studio' / ('inspect-review.client.luau' if args.inspect_review else 'loadout-check.client.luau'))}
    project['tree']['ServerScriptService']['LoadoutReloadFixture'] = {
        '$path': str(ROOT / 'tools/studio/loadout-reload.server.luau')}
    target = out / 'check.private.project.json'
    target.write_text(json.dumps(project, indent=2))
    subprocess.run(['rojo', 'build', str(target), '--output', 'build/SlugshotLoadoutCheck.rbxlx'],
                   cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
