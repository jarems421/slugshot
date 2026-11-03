"""Prepare minimal private cloud-settings acceptance place; does not publish or enable APIs."""
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
def source(path):
    return {"$path":str(ROOT/path)}
def main():
    tree={"$className":"DataModel",
      "Workspace":{"$className":"Workspace","Floor":{"$className":"Part","$properties":{"Anchored":True,"Size":[64,1,64],"Position":[0,-1,0]}},"Spawn":{"$className":"SpawnLocation","$properties":{"Anchored":True,"Position":[0,1,0],"Neutral":True}}},
      "ReplicatedStorage":{"$className":"ReplicatedStorage","Combat":{"$className":"Folder","SettingsSchema":source("experiments/combat/shared/SettingsSchema.luau")},"MovementExperiment":{"$className":"Folder","Config":source("experiments/movement/shared/Config.luau"),"KeybindDefinitions":source("experiments/movement/shared/KeybindDefinitions.luau")}},
      "ServerScriptService":{"$className":"ServerScriptService","SettingsPersistence":{"$className":"Folder","SettingsPersistence":source("experiments/combat/server/SettingsPersistence.server.luau"),"SettingsStore":source("experiments/combat/server/SettingsStore.luau")}},
      "StarterPlayer":{"$className":"StarterPlayer","StarterPlayerScripts":{"$className":"StarterPlayerScripts","MovementSandbox":{"$className":"Folder","Keybinds":source("experiments/movement/client/Keybinds.luau")},"SettingsSync":source("experiments/combat/client/SettingsSync.luau"),"CloudReview":source("tools/studio/settings-cloud-check.client.luau")}}}
    path=ROOT/"build/settings-cloud-check.project.json"
    path.write_text(json.dumps({"name":"SlugshotSettingsCloudCheck","tree":tree},indent=2),encoding="utf-8")
    subprocess.run(["rojo","build",str(path),"--output","build/SlugshotSettingsCloudCheck.rbxlx"],cwd=ROOT,check=True)
    document=ET.parse(ROOT/"build/SlugshotSettingsCloudCheck.rbxlx").getroot()
    instances={}
    for item in document.iter("Item"):
        name=item.findtext('Properties/string[@name="Name"]')
        instances.setdefault(name,[]).append(item)
    folder=next(item for item in instances["SettingsPersistence"] if item.get("class")=="Folder")
    children={item.findtext('Properties/string[@name="Name"]'):item.get("class") for item in folder.findall("Item")}
    assert children.get("SettingsPersistence")=="Script" and children.get("SettingsStore")=="ModuleScript",children
    assert any(item.get("class")=="Folder" for item in instances["MovementSandbox"])
    subprocess.run(["rojo","sourcemap","--absolute",str(path),"--output","build/settings-cloud-check.sourcemap.json"],cwd=ROOT,check=True)
if __name__=="__main__":main()
