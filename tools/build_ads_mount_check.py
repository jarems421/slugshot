"""Build an isolated ADS review/range while preserving current concurrent UI sources."""
import argparse
import json
import re
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--ui-root",type=Path,default=ROOT)
    parser.add_argument("--review",action="store_true")
    args=parser.parse_args()
    ui=args.ui_root.resolve();out=ROOT/"build/ads-mount";out.mkdir(parents=True,exist_ok=True)
    project=json.loads((ui/"combat-range.private.project.json").read_text())
    def absolute(node):
        if isinstance(node,dict):
            for key,value in node.items():
                if key=="$path":node[key]=str(ui/value)
                else:absolute(value)
    absolute(project)
    client=out/"client";client.mkdir(exist_ok=True)
    for path in (ui/"experiments/combat/client").glob("*.luau"):
        shutil.copyfile(path,client/path.name)
    for name in ["AdsSight.luau","Viewmodel.luau"]:
        shutil.copyfile(ROOT/"experiments/combat/client"/name,client/name)
    tree=project["tree"]
    scripts=tree["StarterPlayer"]["StarterPlayerScripts"]
    scripts["Combat"]={"$path":str(client)}
    movement=out/"movement";movement.mkdir(exist_ok=True)
    for path in (ui/"experiments/movement/client").glob("*.luau"):
        shutil.copyfile(path,movement/path.name)
    shutil.copyfile(ROOT/"experiments/movement/client/init.client.luau",movement/"init.client.luau")
    # Carry this ADS framing value while retaining concurrent charge settings/bindings.
    own_tuning=(ROOT/"experiments/movement/client/Tuning.luau").read_text()
    down=re.search(r"adsGunDown = ([\d.]+)",own_tuning).group(1)
    tuning=movement/"Tuning.luau"
    tuning.write_text(re.sub(r"adsGunDown = [\d.]+", "adsGunDown = "+down,tuning.read_text()))
    scripts["MovementSandbox"]={"$path":str(movement)}
    tree["ReplicatedStorage"]["MovementExperiment"]={"$path":str(ROOT/"experiments/movement/shared")}
    tree["ServerScriptService"]["FloppyIntegration"]["FloppyBlaster"]={"$path":str(ROOT/"experiments/creatures/floppy/server/FloppyBlaster.server.luau")}
    if args.review:
        driver=out/"AdsMountCheck.client.luau"
        shutil.copyfile(ROOT/"tools/studio/ads-mount-check.luau",driver)
        scripts["AdsMountCheck"]={"$path":str(driver)}
    project["name"]="SlugshotAdsMountCheck" if args.review else "SlugshotAdsMountRange"
    target=out/"range.private.project.json";target.write_text(json.dumps(project,indent=2))
    output=ROOT/"build"/(project["name"]+".rbxlx")
    subprocess.run(["rojo","build",str(target),"--output",str(output)],cwd=ROOT,check=True)
    if args.review:
        model=ET.parse(output)
        assert any(i.get("class")=="LocalScript" and i.findtext("Properties/string[@name='Name']")=="AdsMountCheck" for i in model.iter("Item"))

if __name__=="__main__":main()
