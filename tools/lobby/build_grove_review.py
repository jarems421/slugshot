"""Build the single canonical lobby review from current private asset references."""
import hashlib
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
from build_hub import main as build_hub

ROOT=Path(__file__).resolve().parents[2]

def main():
    build_hub()
    project=json.loads((ROOT/"lobby-hub.private.project.json").read_text(encoding="utf-8"))
    def absolute(node):
        if isinstance(node,dict):
            for key,value in node.items():
                if key=="$path":node[key]=str(ROOT/value)
                else:absolute(value)
    absolute(project)
    project["name"]="SlugshotGroveReview"
    for name,file in [("ReviewSpawn","grove-review-spawn.server.luau"),("SoleReview","grove-sole-review.server.luau")]:
        project["tree"]["ServerScriptService"][name]={"$path":str(ROOT/"tools/studio"/file)}
    out=ROOT/"build/grove"
    out.mkdir(parents=True,exist_ok=True)
    path=out/"review.project.json"
    path.write_text(json.dumps(project,indent=2),encoding="utf-8")
    place=ROOT/"build/SlugshotGroveReview.rbxlx"
    subprocess.run(["rojo","build",str(path),"--output",str(place)],cwd=ROOT,check=True)
    doc=ET.parse(place)
    hashes={}
    expected_sources=[
        ("FloppyAsset",ROOT/"private-assets/floppy/FloppyAsset.luau"),
        ("InfernoAsset",ROOT/"private-assets/inferno/InfernoAsset.luau"),
        ("HubArt",ROOT/"experiments/lobby/hub/server/HubArt.server.luau"),
        ("HubMotion",ROOT/"experiments/lobby/hub/client/HubMotion.client.luau"),
    ]
    for name,source_path in expected_sources:
        expected=source_path.read_text(encoding="utf-8")
        sources=[item.findtext('Properties/*[@name="Source"]') for item in doc.iter("Item") if item.findtext('Properties/string[@name="Name"]')==name]
        assert sources and all(s and s.replace("\r\n","\n")==expected.replace("\r\n","\n") for s in sources),f"stale {name} in review place"
        hashes[name]=hashlib.sha256(expected.encode()).hexdigest()
    (out/"review-manifest.json").write_text(json.dumps({"assetConfigHashes":{k:v for k,v in hashes.items() if k.endswith("Asset")},"sourceHashes":hashes,"compiledReferencesCurrent":True,"place":place.name},indent=2),encoding="utf-8")
    print("PASS: review embeds current private references and lobby effect sources")

if __name__=="__main__":main()
