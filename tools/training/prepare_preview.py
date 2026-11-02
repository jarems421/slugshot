"""Prepare the local asset review. Vendored scripts are pinned to upstream SHA-256.

python tools/training/prepare_preview.py
python -m http.server 8879 --bind 127.0.0.1 --directory build/training
Open http://127.0.0.1:8879/. No cloud hosting or asset publication.
"""
import hashlib
import json
import shutil
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/training'
manifest=json.loads((ROOT/'assets/source/environments/training/preview-vendor.json').read_text())
for dest,spec in manifest.items():
    path=OUT/'vendor'/dest
    raw=path.read_bytes() if path.exists() else b''
    # GLTFLoader's single relative helper import is rebased locally after verification.
    canonical=raw.replace(b'./utils/BufferGeometryUtils.js',b'../utils/BufferGeometryUtils.js') if dest=='GLTFLoader.js' else raw
    if hashlib.sha256(canonical).hexdigest()!=spec['sha256']:
        canonical=urllib.request.urlopen(spec['source'],timeout=30).read()
    assert hashlib.sha256(canonical).hexdigest()==spec['sha256'],f'Unexpected upstream content: {dest}'
    path.parent.mkdir(parents=True,exist_ok=True)
    if dest=='GLTFLoader.js':canonical=canonical.replace(b'../utils/BufferGeometryUtils.js',b'./utils/BufferGeometryUtils.js')
    path.write_bytes(canonical)
for source,dest in [('preview.html','index.html'),('preview.js','preview.js')]:
    shutil.copyfile(ROOT/'tools/training'/source,OUT/dest)
print('PASS: local preview and pinned MIT-licensed three.js r158 prepared')
print('Serve build/training on 127.0.0.1:8879 to inspect the asset')
