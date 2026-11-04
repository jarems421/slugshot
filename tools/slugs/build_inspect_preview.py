"""Build the local Inferno inspect comparison without changing any Roblox runtime source."""
from pathlib import Path
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/slugs/inferno/inspect-preview"
CACHE = ROOT / ".tools/three-r159"
LIBRARY = {
    "three.module.js": "5898fd8f4ec3688073967ad95967338a415790d6bbf31d4841bc56389ed7374a",
    "GLTFLoader.js": "e82db2e3dbddcf606e451a63e84b57f04f60738ef9c4c2c243f95ef7e6409899",
    "BufferGeometryUtils.js": "9be041e96308775d00e2695cc607645b9a9b64fd7c0e759dd8f7c00a8d92becb",
    "LICENSE.txt": "852e0e8699169bf9f6fdc6bda3e682d078dcbc738b5d33e74df594721bff271d",
}


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"purpose": "Local concept comparison; no Studio implementation", "files": {}}
    sources = {
        "inferno.glb": ROOT / "build/slugs/inferno/base/model.glb",
        "blaster.glb": ROOT / "build/slugs/floppy/blaster-long-bevel/model.glb",
    }
    for name, source in sources.items():
        shutil.copyfile(source, OUT / name)
        manifest["files"][name] = hashlib.sha256(source.read_bytes()).hexdigest()
    # Export only authored material colours; asset/account IDs never enter the browser preview.
    mapping = (ROOT / "private-assets/floppy/BlasterMesh.luau").read_text(encoding="utf-8-sig")
    palette = dict(re.findall(r'name\s*=\s*"([^"]+)".*?color\s*=\s*"([^"]+)"', mapping, re.S))
    (OUT / "palette.json").write_text(json.dumps(palette, indent=2) + "\n", encoding="utf-8")
    vendor = OUT / "vendor"
    (vendor / "utils").mkdir(parents=True, exist_ok=True)
    (vendor / "loaders").mkdir(exist_ok=True)
    for name, digest in LIBRARY.items():
        source = CACHE / name
        assert hashlib.sha256(source.read_bytes()).hexdigest() == digest, f"changed Three r159: {name}"
        target = vendor / ("loaders" if name == "GLTFLoader.js" else "utils" if name == "BufferGeometryUtils.js" else "") / name
        shutil.copyfile(source, target)
        manifest["files"][str(target.relative_to(OUT))] = digest
    for source in (ROOT / "tools/slugs/inspect-preview").iterdir():
        if source.is_file():
            shutil.copyfile(source, OUT / source.name)
    # A single offline file is the user-facing artifact: no server, network, account or Studio needed.
    def js(value):
        return json.dumps(value).replace("</", "<\\/")

    import base64
    runtime = (OUT / "preview.js").read_text(encoding="utf-8")
    runtime = runtime.replace("const palette = await (await fetch('./palette.json')).json();", "const palette = " + json.dumps(palette) + ";")
    for name in ("inferno", "blaster"):
        uri = "data:model/gltf-binary;base64," + base64.b64encode((OUT / f"{name}.glb").read_bytes()).decode()
        runtime = runtime.replace(f"'./{name}.glb'", js(uri))
    bootstrap = "\n".join([
        "const moduleURL = code => URL.createObjectURL(new Blob([code], {type:'text/javascript'}));",
        "const threeURL = moduleURL(" + js((CACHE / "three.module.js").read_text()) + ");",
        "const utilsURL = moduleURL(" + js((CACHE / "BufferGeometryUtils.js").read_text()) + ".replace(\"from 'three'\", \"from '\"+threeURL+\"'\"));",
        "const loaderURL = moduleURL(" + js((CACHE / "GLTFLoader.js").read_text()) + ".replace(\"from 'three'\", \"from '\"+threeURL+\"'\").replace(\"'../utils/BufferGeometryUtils.js'\", JSON.stringify(utilsURL)));",
        "const flowURL = moduleURL(" + js((OUT / "flow.js").read_text()) + ".replace(\"from 'three'\", \"from '\"+threeURL+\"'\"));",
        "const app = " + js(runtime) + ".replace(\"from 'three'\", \"from '\"+threeURL+\"'\").replace(\"'./vendor/loaders/GLTFLoader.js'\", JSON.stringify(loaderURL)).replace(\"'./flow.js'\", JSON.stringify(flowURL));",
        "await import(moduleURL(app));",
    ])
    page = (OUT / "index.html").read_text(encoding="utf-8")
    page = page.replace('<head>', '<head>\n<!-- Three.js r159\n' + (CACHE / "LICENSE.txt").read_text() + '\n-->')
    page = page.replace('<link rel="stylesheet" href="style.css">', '<style>' + (OUT / "style.css").read_text() + '</style>')
    page = re.sub(r'<script type="importmap">.*?</script>', '', page)
    page = page.replace('<script type="module" src="preview.js"></script>', '<script type="module">' + bootstrap + '</script>')
    (OUT / "Inferno-inspect-studies.html").write_text(page, encoding="utf-8")
    (OUT / "Inferno-inspect-studies-v3.html").write_text(page, encoding="utf-8")
    (OUT / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(OUT)


if __name__ == "__main__":
    build()
