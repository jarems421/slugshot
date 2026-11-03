"""Build the real lobby with its isolated native resident-motion review."""
import json
from pathlib import Path
import subprocess
from build_hub import main as build_hub

ROOT = Path(__file__).resolve().parents[2]


def main():
    build_hub()
    project = json.loads((ROOT / "lobby-hub.private.project.json").read_text(encoding="utf-8"))

    def absolute(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path":
                    node[key] = str(ROOT / value)
                else:
                    absolute(value)

    absolute(project)
    project["name"] = "SlugshotGroveMotionCheck"
    project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["GroveCheck"] = {
        "$path": str(ROOT / "tools/studio/grove-motion-check.client.luau")
    }
    out = ROOT / "build/grove"
    out.mkdir(parents=True, exist_ok=True)
    path = out / "check.project.json"
    path.write_text(json.dumps(project, indent=2), encoding="utf-8")
    subprocess.run(["rojo", "build", str(path), "--output", "build/SlugshotGroveMotionCheck.rbxlx"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
