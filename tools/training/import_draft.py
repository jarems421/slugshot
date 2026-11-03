"""Privately import the reviewed authored draft for the owner's Studio inspection.

Existing island/wall/debris assets are reused. No marketplace listing or experience
publication. IDs and credentials stay in ignored private storage; content hashes
avoid duplicate imports. Uses the project's previously reviewed Open Cloud client.
"""
import hashlib
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/lobby'))
from upload_lobby_assets import load_client,upload


def main():
    out=ROOT/'private-assets/training';out.mkdir(parents=True,exist_ok=True)
    cache_path=out/'draft-imports.json'
    cache=json.loads(cache_path.read_text()) if cache_path.exists() else {}
    client=load_client();key=client.api_key()
    owner=json.loads((ROOT/'private-assets/floppy/roblox_assets.json').read_text())['owner']
    for name,file,kind,mime in [('model','training-authored.glb','Model','model/gltf-binary'),('paint','training-stone.png','Image','image/png')]:
        path=ROOT/'build/training'/file;digest=hashlib.sha256(path.read_bytes()).hexdigest()
        assert path.stat().st_size<20_000_000,'Split the draft before import: Assets API 20 MB cap'
        if cache.get(name,{}).get('sha256')==digest:continue
        asset=upload(client,key,owner,path,kind,'Slugshot training review '+name,mime)
        cache[name]={'id':asset,'sha256':digest};cache_path.write_text(json.dumps(cache,indent=2))
        print('Private Studio draft imported:',name,flush=True)
    (out/'TrainingDraft.luau').write_text('--!strict\n-- Private training review IDs; never commit.\nreturn { model = '+str(cache['model']['id'])+' }\n',encoding='utf-8')
    doc=ET.Element('roblox',version='4');folder=ET.SubElement(doc,'Item',{'class':'Folder','referent':'TrainingMaterials'})
    ET.SubElement(ET.SubElement(folder,'Properties'),'string',name='Name').text='TrainingMaterials'
    item=ET.SubElement(folder,'Item',{'class':'SurfaceAppearance','referent':'StonePaint'});props=ET.SubElement(item,'Properties')
    ET.SubElement(props,'string',name='Name').text='StonePaint';content=ET.SubElement(props,'Content',name='ColorMap');ET.SubElement(content,'url').text='rbxassetid://'+str(cache['paint']['id'])
    ET.ElementTree(doc).write(out/'materials.rbxmx',encoding='utf-8',xml_declaration=True)
    print('PASS: private inspection draft ready; no experience published')


if __name__=='__main__':main()
