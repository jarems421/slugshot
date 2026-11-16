"""Upload one original solid grayscale wall emission mask with the private client.

No geometry, colour/normal texture, account setting or experience is changed.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image
from upload_lobby_assets import ROOT, PRIVATE, load_client, upload


def main():
    path = ROOT / "build/lobby/wall-fill-mask.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (64, 64), (255, 255, 255)).save(path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    cache_path = PRIVATE / "wall-fill-mask.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    if cache.get("sha256") != digest:
        client = load_client()
        key = client.api_key()
        owner = json.loads((ROOT / "private-assets/floppy/roblox_assets.json").read_text())["owner"]
        asset = upload(client, key, owner, path, "Image", "Slugshot wall emission mask", "image/png")
        cache_path.write_text(json.dumps({"id": asset, "sha256": digest}, indent=2))
    print("PASS: original wall emission mask cached privately")


if __name__ == "__main__":
    main()
