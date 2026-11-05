from pathlib import Path
import base64,hashlib,json,re,shutil

HERE=Path(__file__).resolve().parent
CACHE=Path('C:/Users/runni/slugshot-slug-pipeline/.tools/three-r159')
MODELS=Path('C:/Users/runni/slugshot-slug-pipeline/build/slugs/inferno')
EXPECTED={'three.module.js':'5898fd8f4ec3688073967ad95967338a415790d6bbf31d4841bc56389ed7374a','GLTFLoader.js':'e82db2e3dbddcf606e451a63e84b57f04f60738ef9c4c2c243f95ef7e6409899','BufferGeometryUtils.js':'9be041e96308775d00e2695cc607645b9a9b64fd7c0e759dd8f7c00a8d92becb','LICENSE.txt':'852e0e8699169bf9f6fdc6bda3e682d078dcbc738b5d33e74df594721bff271d'}
for name,digest in EXPECTED.items():
    assert hashlib.sha256((CACHE/name).read_bytes()).hexdigest()==digest,name
for form in ['base','dragon']:
    shutil.copyfile(MODELS/form/'model.glb',HERE/f'inferno-{form}.glb')
def js(value):return json.dumps(value).replace('</','<\\/')
runtime=(HERE/'preview.js').read_text(encoding='utf-8')
for form in ['base','dragon']:
    uri='data:model/gltf-binary;base64,'+base64.b64encode((HERE/f'inferno-{form}.glb').read_bytes()).decode()
    runtime=runtime.replace(f"'./inferno-{form}.glb'",js(uri))
bootstrap='\n'.join([
    "const moduleURL = code => URL.createObjectURL(new Blob([code], {type:'text/javascript'}));",
    'const threeURL = moduleURL('+js((CACHE/'three.module.js').read_text(encoding='utf-8'))+');',
    'const utilsURL = moduleURL('+js((CACHE/'BufferGeometryUtils.js').read_text(encoding='utf-8'))+".replace(\"from 'three'\", \"from '\"+threeURL+\"'\"));",
    'const loaderURL = moduleURL('+js((CACHE/'GLTFLoader.js').read_text(encoding='utf-8'))+".replace(\"from 'three'\", \"from '\"+threeURL+\"'\").replace(\"'../utils/BufferGeometryUtils.js'\", JSON.stringify(utilsURL)));",
    'const waterURL = moduleURL('+js((HERE/'water-identity.js').read_text(encoding='utf-8'))+".replace(\"from 'three'\", \"from '\"+threeURL+\"'\"));",
    'const app = '+js(runtime)+".replace(\"from 'three'\", \"from '\"+threeURL+\"'\").replace(\"'./vendor/loaders/GLTFLoader.js'\", JSON.stringify(loaderURL)).replace(\"'./water-identity.js'\",JSON.stringify(waterURL));",
    'try { await import(moduleURL(app)); } catch(error) { document.querySelector("#error").hidden=false;document.querySelector("#error").textContent="Preview could not start: "+error.message;throw error; }'
])
page=(HERE/'index.html').read_text(encoding='utf-8').replace('<head>','<head>\n<!-- Three.js r159\n'+(CACHE/'LICENSE.txt').read_text(encoding='utf-8')+'\n-->')
page=page.replace('<link rel="stylesheet" href="style.css">','<style>'+(HERE/'style.css').read_text(encoding='utf-8')+'</style>')
page=page.replace('<script type="module" src="preview.js"></script>','<script type="module">'+bootstrap+'</script>')
out=HERE/'Slugshot-ability-lab.html';out.write_text(page,encoding='utf-8');print(str(out));print(out.stat().st_size)

(HERE/'Inferno-five-abilities.html').write_text(page,encoding='utf-8')
