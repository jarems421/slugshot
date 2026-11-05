"""Build a three-way motion comparison for one study as a single HTML file. Changes no game source.

python tools/slugs/build_motion_preview.py inferno-transform [--cdn]
--cdn loads Three.js r159 from jsDelivr instead of embedding it, for a page published as an Artifact.
"""
import argparse
import base64
import hashlib
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/slugs/motion-preview"
OUT = ROOT / "build/slugs/motion-preview"
LIBRARY = {
    "three.module.js": "5898fd8f4ec3688073967ad95967338a415790d6bbf31d4841bc56389ed7374a",
    "GLTFLoader.js": "e82db2e3dbddcf606e451a63e84b57f04f60738ef9c4c2c243f95ef7e6409899",
    "BufferGeometryUtils.js": "9be041e96308775d00e2695cc607645b9a9b64fd7c0e759dd8f7c00a8d92becb",
    "LICENSE.txt": "852e0e8699169bf9f6fdc6bda3e682d078dcbc738b5d33e74df594721bff271d",
}
MODELS = {
    "inferno-base": "inferno/base/model.glb",
    "inferno-dragon": "inferno/dragon/model.glb",
    "floppy": "floppy/roblox/model.glb",
}


def searched_roots(*parts):
    """This worktree first, then the worktree that normally holds ignored creature builds. SLUGSHOT_ASSET_ROOT overrides."""
    roots = [ROOT, ROOT.parent / "slugshot-slug-pipeline"]
    if os.environ.get("SLUGSHOT_ASSET_ROOT"):
        roots.insert(0, Path(os.environ["SLUGSHOT_ASSET_ROOT"]))
    return [root.joinpath(*parts) for root in roots]


def find(*parts):
    for path in searched_roots(*parts):
        if path.exists():
            return path
    raise SystemExit(f"Missing {'/'.join(parts)}; looked in: " + ", ".join(map(str, searched_roots(*parts))))


def model_path(name):
    return find("build/slugs", MODELS[name])


def three_files():
    folder = find(".tools/three-r159")
    files = {}
    for name, digest in LIBRARY.items():
        data = (folder / name).read_bytes()
        assert hashlib.sha256(data).hexdigest() == digest, f"changed Three r159: {name}"
        files[name] = data.decode("utf-8")
    return files


def data_url(code):
    return "data:text/javascript;base64," + base64.b64encode(code.encode("utf-8")).decode()


def import_map(cdn, files):
    if cdn:
        base = "https://cdn.jsdelivr.net/npm/three@0.159.0"
        imports = {"three": f"{base}/build/three.module.js", "three/addons/": f"{base}/examples/jsm/"}
    else:
        loader = files["GLTFLoader.js"].replace("'../utils/BufferGeometryUtils.js'", "'three/addons/utils/BufferGeometryUtils.js'")
        imports = {
            "three": data_url(files["three.module.js"]),
            "three/addons/loaders/GLTFLoader.js": data_url(loader),
            "three/addons/utils/BufferGeometryUtils.js": data_url(files["BufferGeometryUtils.js"]),
        }
    return json.dumps({"imports": imports})


def module_body(path):
    """A file's code without its export keywords, plus the names it exported."""
    text = path.read_text(encoding="utf-8")
    names = re.findall(r"^export (?:const|function) (\w+)", text, re.M)
    return re.sub(r"^export (const|function)", r"\1", text, flags=re.M), names


def build(study_id, cdn):
    study_path = SOURCE / "studies" / f"{study_id}.js"
    if not study_path.is_file():
        known = ", ".join(sorted(p.stem for p in (SOURCE / "studies").glob("*.js")))
        raise SystemExit(f"No study {study_id}. Known: {known}")
    study = study_path.read_text(encoding="utf-8").replace("export default", "const study =", 1)
    # Named in `model:` fields, so a study embeds only the models it uses.
    used = sorted(set(re.findall(r"model: '([\w-]+)'", study)))
    models = {name: base64.b64encode(model_path(name).read_bytes()).decode() for name in used}
    kit, names = module_body(SOURCE / "motion-kit.js")
    viewer = (SOURCE / "viewer.js").read_text(encoding="utf-8")
    imports = "".join(re.findall(r"^import .*\n", viewer, re.M))
    viewer = re.sub(r"^import .*\n", "", viewer, flags=re.M)
    files = three_files()
    script = "\n".join([
        imports,
        "const kit = (() => {", kit, f"return {{ {', '.join(names)} }};", "})();",
        "const MODELS = " + json.dumps(models) + ";",
        study,
        viewer,
    ])
    page = (SOURCE / "page.html").read_text(encoding="utf-8")
    page = page.replace("<title>Slug motion study</title>", f"<title>{re.search(r'title: .(.+?).,', study).group(1)}</title>")
    licence = "" if cdn else "<!-- Three.js r159\n" + files["LICENSE.txt"] + "\n-->\n"
    html = "\n".join([
        ("" if cdn else '<!doctype html>\n<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'),
        licence + page,
        '<script type="importmap">' + import_map(cdn, files) + "</script>",
        '<script type="module">' + script.replace("</script", "<\\/script") + "</script>",
    ])
    target = OUT / study_id
    target.mkdir(parents=True, exist_ok=True)
    name = f"{study_id}{'-artifact' if cdn else ''}.html"
    (target / name).write_text(html, encoding="utf-8")
    provenance = {
        "purpose": "Local motion comparison; no game source changed",
        "models": {n: hashlib.sha256(model_path(n).read_bytes()).hexdigest() for n in used},
        "three": LIBRARY,
    }
    (target / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    return target / name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("study")
    parser.add_argument("--cdn", action="store_true")
    args = parser.parse_args()
    print(build(args.study, args.cdn))


if __name__ == "__main__":
    main()
