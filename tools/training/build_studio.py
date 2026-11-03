"""Build an isolated local Studio review from private draft imports and existing art."""
import argparse
import json
import os
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/training/studio'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    server=OUT/'server';server.mkdir(parents=True,exist_ok=True)
    code=(ROOT/'experiments/movement/server/init.server.luau').read_text(encoding='utf-8')
    old='character:PivotTo(CFrame.new((player.UserId % 3) * 6 - 6, 5, 30))'
    assert code.count(old)==1
    code=code.replace(old,'character:PivotTo(CFrame.new((player.UserId % 3) * 6 - 6, 5.5, 76))')
    code=code.replace('if root.Position.Y < -40 and not state.spawning then','if root.Position.Y < -105 and not state.spawning then')
    (server/'init.server.luau').write_text(code,encoding='utf-8')
    project=json.loads((ROOT/'movement.project.json').read_text());project['name']='SlugshotTrainingReview';project['servePort']=34889
    tree=project['tree']
    tree['Workspace']={'$className':'Workspace','$properties':{'FallenPartsDestroyHeight':-240}}
    tree['Lighting']={'$className':'Lighting','$properties':{'Technology':'ShadowMap'}}
    rep=tree['ReplicatedStorage'];rep['LookPack']={'$path':'experiments/lobby/shared/LookPack.luau'}
    rep['TrainingOutline']={'$path':'experiments/lobby/scale/shared/rim_shape.json'}
    rep['MovementPrivateClips']={'$path':'private-assets/generated/MovementClips.luau'}
    services=tree['ServerScriptService'];services['MovementSandbox']={'$path':str(server),'Arena':{'$path':'experiments/training/server/Arena.luau'}}
    services['Training']={'$path':'experiments/training/server'}
    tree['StarterPlayer']['StarterPlayerScripts']['Training']={'$path':'experiments/training/client'}
    storage={'$className':'ServerStorage','TrainingLayout':{'$path':'build/training/studio-layout.json'}}
    for name,file in {'HubAssets':'HubAssets.luau','HubMaterials':'hub_materials.rbxmx','LobbyAssets':'LobbyAssets.luau','LobbyMaterials':'materials.rbxmx'}.items():
        path=ROOT/'private-assets/lobby'/file
        if not path.exists():path=ROOT/'build/training-assets'/file
        assert path.exists(),file
        storage[name]={'$path':str(path)}
    storage['TrainingDraft']={'$path':'private-assets/training/TrainingDraft.luau'}
    storage['TrainingMaterials']={'$path':'private-assets/training/materials.rbxmx'}
    tree['ServerStorage']=storage
    if args.check:
        project['name']='SlugshotTrainingReviewCheck'
        services['TrainingCheck']={'$path':'experiments/training/check/Check.server.luau'}
        tree['StarterPlayer']['StarterPlayerScripts']['TrainingTour']={'$path':'experiments/training/check/Tour.client.luau'}
    def absolute(node):
        for key,value in node.items():
            if key=='$path':node[key]=str((ROOT/value).resolve())
            elif isinstance(value,dict) and not key.startswith('$'):absolute(value)
    absolute(tree);path=OUT/('check.project.json' if args.check else 'review.project.json');path.write_text(json.dumps(project,indent=2))
    subprocess.run(['rojo','build',str(path),'--output',str(ROOT/'build'/f'{project["name"]}.rbxlx')],cwd=ROOT,check=True)
    subprocess.run(['rojo','sourcemap',str(path),'--output',str(OUT/'sourcemap.json')],cwd=ROOT,check=True)
    # Rojo paths are relative to the generated project; luau-lsp resolves from
    # the workspace. Rebase the analysis map rather than weakening require types.
    mapping=json.loads((OUT/'sourcemap.json').read_text())
    def rebase(node):
        if 'filePaths' in node:node['filePaths']=[os.path.relpath((OUT/p).resolve(),ROOT).replace('\\','/') for p in node['filePaths']]
        for child in node.get('children',[]):rebase(child)
    rebase(mapping);(OUT/'sourcemap.json').write_text(json.dumps(mapping))


if __name__=='__main__':main()
