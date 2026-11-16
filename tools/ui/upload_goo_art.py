"""Upload original UI artwork privately through Open Cloud.

Identical images reuse their earlier upload. The IDs go to ignored private-assets/ui only, and the API key is read by
the existing private upload client, never printed.
"""
import hashlib
import importlib.util
import json
import re
from pathlib import Path
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/source/ui/goo"
FLOPPY = ROOT / "private-assets/floppy"
PRIVATE = ROOT / "private-assets/ui"
NAMES = {"barFront": "bar-front", "barBack": "bar-back", "barShine": "bar-shine", "barFrame": "bar-frame",
         "bandFront": "band-front", "bandBack": "band-back", "bandShine": "band-shine", "edge": "goo-edge",
         "dripBook": "goo-drip-book", "bead": "goo-bead", "glow": "fx-glow", "spark": "fx-spark",
         "iconControls": "icon-controls", "iconMouseButton": "icon-mouse-button", "iconCrosshair": "icon-crosshair",
         "crystal": "fx-crystal", "crystalSmall": "fx-crystal-small", "ledge": "fx-ledge",
         "slugFloppy": "slug-floppy", "slugInferno": "slug-inferno", "iconInventory": "icon-inventory",
         # The slugs in the HUD canisters (tools/ui/build_canister_slugs.py).
         "canisterFloppy": "canister-floppy", "canisterInferno": "canister-inferno",
         "canisterRammstone": "canister-rammstone", "canisterAquabeek": "canister-aquabeek",
         # Their idle flipbooks, two sheets each (tools/ui/build_canister_flipbooks.py).
         **{f"canisterIdle{slug}{n}": f"canister-{slug.lower()}-idle-{n}"
            for slug in ("Floppy", "Inferno", "Rammstone", "Aquabeek", "Tormato", "BoonDoc") for n in (1, 2)},
         **{f"canisterIdle{slug}Small": f"canister-{slug.lower()}-idle-small"
            for slug in ("Floppy", "Inferno", "Rammstone", "Aquabeek", "Tormato", "BoonDoc")}}
# The menu backgrounds, six tiles each (tools/ui/backgrounds/tile.py).
for _back, _file in (("Controls", "controls"), ("Gameplay", "gameplay"), ("Crosshair", "crosshair"), ("PvP", "pvp")):
    for _index in range(1, 7):
        NAMES[f"back{_back}{_index}"] = f"back-{_file}-{_index}"



def main():
    requested = sys.argv[1:]
    selected = [name for name in NAMES if not requested or name in requested]
    if requested and set(requested) - NAMES.keys():
        raise ValueError("Unknown UI art name")
    sys.argv = ["upload_open_cloud.py", str(ART / "goo-front.png")]
    spec = importlib.util.spec_from_file_location("private_upload", FLOPPY / "upload_open_cloud.py")
    client = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(client)
    key = client.api_key()
    owner = json.loads((FLOPPY / "roblox_assets.json").read_text())["owner"]
    PRIVATE.mkdir(parents=True, exist_ok=True)
    cache_path = PRIVATE / "goo-assets.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    # Private mappings can exist without a full upload cache (for example in a
    # new checkout). A partial upload must preserve all existing image bindings.
    module_path = PRIVATE / "GooArt.luau"
    existing = module_path.read_text(encoding="utf-8") if module_path.exists() else ""
    references = {name: int(value) for name, value in
                  re.findall(r"(?m)^\s*(\w+)\s*=\s*(\d+)\s*,?", existing)}
    for name in selected:
        filename = NAMES[name]
        # The menu backgrounds are pictures, so JPEG; everything else is PNG.
        path = next(ART / f"{filename}{ext}" for ext in (".png", ".jpg") if (ART / f"{filename}{ext}").exists())
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if cache.get(name, {}).get("sha256") == digest:
            continue
        request = {"assetType": "Image", "displayName": f"Slugshot UI {filename}",
                   "description": "Original Slugshot UI artwork",
                   "creationContext": {"creator": {"userId": str(owner)}}}
        boundary = uuid.uuid4().hex
        body = ((f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
                 f'Content-Type: application/json\r\n\r\n{json.dumps(request)}\r\n'
                 f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
                 f'Content-Type: image/{"jpeg" if path.suffix == ".jpg" else "png"}\r\n\r\n').encode()
                + data + f'\r\n--{boundary}--\r\n'.encode())
        operation = client.call("POST", "https://apis.roblox.com/assets/v1/assets", key,
                                body, "multipart/form-data; boundary=" + boundary)
        operation_id = operation.get("operationId") or operation.get("path", "").split("/")[-1]
        for _ in range(60):
            if operation.get("done"):
                break
            time.sleep(2)
            operation = client.call("GET", "https://apis.roblox.com/assets/v1/operations/" + operation_id, key)
        if not operation.get("done") or operation.get("error"):
            raise RuntimeError("Image upload did not complete: " + name)
        cache[name] = {"id": int(operation["response"]["assetId"]), "sha256": digest}
        cache_path.write_text(json.dumps(cache, indent=2) + "\n", encoding="utf-8")
        print("Uploaded", name, flush=True)
    references.update({name: cache[name]["id"] for name in selected})
    lines = ["--!strict", "-- Private UI image IDs; never commit.", "return {"]
    lines += [f"\t{name} = {asset_id}," for name, asset_id in references.items()]
    lines += ["}", ""]
    (PRIVATE / "GooArt.luau").write_text("\n".join(lines), encoding="utf-8")
    for name in selected:
        reply = client.call("GET", f"https://apis.roblox.com/assets/v1/assets/{cache[name]['id']}?readMask=moderationResult", key)
        print(name, reply.get("moderationResult", {}).get("moderationState"))


if __name__ == "__main__":
    main()
