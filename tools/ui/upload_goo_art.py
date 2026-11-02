"""Upload the health bar's goo textures privately through Open Cloud.

Identical images reuse their earlier upload. The IDs go to ignored private-assets/ui only, and the API key is read by
the existing private upload client, never printed.
"""
import hashlib
import importlib.util
import json
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
         "crystal": "fx-crystal", "crystalSmall": "fx-crystal-small", "ledge": "fx-ledge"}



def main():
    sys.argv = ["upload_open_cloud.py", str(ART / "goo-front.png")]
    spec = importlib.util.spec_from_file_location("private_upload", FLOPPY / "upload_open_cloud.py")
    client = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(client)
    key = client.api_key()
    owner = json.loads((FLOPPY / "roblox_assets.json").read_text())["owner"]
    PRIVATE.mkdir(parents=True, exist_ok=True)
    cache_path = PRIVATE / "goo-assets.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    for name, filename in NAMES.items():
        data = (ART / f"{filename}.png").read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if cache.get(name, {}).get("sha256") == digest:
            continue
        request = {"assetType": "Image", "displayName": f"Slugshot UI {filename}",
                   "description": "Original Slugshot health bar texture",
                   "creationContext": {"creator": {"userId": str(owner)}}}
        boundary = uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
                f'Content-Type: application/json\r\n\r\n{json.dumps(request)}\r\n'
                f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{filename}.png"\r\n'
                'Content-Type: image/png\r\n\r\n').encode() + data + f'\r\n--{boundary}--\r\n'.encode()
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
    lines = ["--!strict", "-- Private image IDs for the health bar; never commit.", "return {"]
    lines += [f"\t{name} = {cache[name]['id']}," for name in NAMES]
    lines += ["}", ""]
    (PRIVATE / "GooArt.luau").write_text("\n".join(lines), encoding="utf-8")
    for name in NAMES:
        reply = client.call("GET", f"https://apis.roblox.com/assets/v1/assets/{cache[name]['id']}?readMask=moderationResult", key)
        print(name, reply.get("moderationResult", {}).get("moderationState"))


if __name__ == "__main__":
    main()
