"""Build a private shooting range; --review adds disposable native evidence fixtures."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET
from build_combat_range import generate
ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--review', action='store_true')
    args = parser.parse_args()
    generate()
    out = ROOT / 'build/shooting-feel'
    out.mkdir(parents=True, exist_ok=True)
    project = json.loads((ROOT / 'combat-range.private.project.json').read_text())
    def absolute(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == '$path':
                    node[key] = str(ROOT / value)
                else:
                    absolute(value)
    absolute(project)
    if args.review:
        for filename, service, name in [
            ('shooting-feel-check.client.luau', project['tree']['StarterPlayer']['StarterPlayerScripts'], 'ShootingFeelCheck'),
            ('shooting-feel-fixture.server.luau', project['tree']['ServerScriptService'], 'ShootingFeelFixture')
        ]:
            target = out / filename
            shutil.copyfile(ROOT / 'tools/studio' / filename, target)
            service[name] = {'$path': str(target)}
    project['name'] = 'SlugshotShootingFeelCheck' if args.review else 'SlugshotShootingFeelRange'
    target = out / 'range.private.project.json'
    target.write_text(json.dumps(project, indent=2))
    output = ROOT / 'build' / (project['name'] + '.rbxlx')
    subprocess.run(['rojo', 'build', str(target), '--output', str(output)], cwd=ROOT, check=True)
    model = ET.parse(output)
    names = {i.findtext("Properties/string[@name='Name']"): i.get('class') for i in model.iter('Item')}
    if args.review:
        assert names['ShootingFeelCheck'] == 'LocalScript'
        assert names['ShootingFeelFixture'] == 'Script'
    else:
        assert 'ShootingFeelCheck' not in names and 'ShootingFeelFixture' not in names

if __name__ == '__main__':
    main()
