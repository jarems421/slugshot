"""Build the local movement playtest places (outputs stay in ignored build/).

- SlugshotMovementLabPrivate.rbxlx: the current lab with privately retargeted clips.
- SlugshotMovementLab-v1.rbxlx / -v2.rbxlx: earlier labs, rebuilt from their exact commits, for A/B play.

    python tools/build_movement_playtest.py [--retarget]

--retarget regenerates private-assets/generated/MovementClips.luau from
private-assets/mixamo/*.fbx using portable Blender in .tools/ (or BLENDER env var).
"""
import argparse
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSIONS = {
    "v1": "e2b5688",  # "Add isolated movement lab..." - the reviewed v1 sandbox.
    "v2": "0b06985",  # "Refine movement lab with original clips..." - clips, rolls, flips.
}
CLIPS = ROOT / "private-assets/generated/MovementClips.luau"


def run(*args, **kwargs):
    print("+ " + " ".join(str(a) for a in args), flush=True)
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True, **kwargs)


def blender():
    if os.environ.get("BLENDER"):
        return Path(os.environ["BLENDER"])
    found = sorted((ROOT / ".tools").glob("blender-*/blender.exe")) + sorted((ROOT / ".tools").glob("blender-*/blender"))
    if not found:
        raise SystemExit("Blender not found: unpack a portable release into .tools/ or set BLENDER")
    return found[-1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--retarget", action="store_true")
    args = parser.parse_args()
    if args.retarget:
        manifest = json.loads((ROOT / "tools/mixamo_manifest.json").read_text(encoding="utf-8"))
        files = {spec["file"] for spec in manifest["clips"].values()}
        present = {path.name for path in (ROOT / "private-assets/mixamo").glob("*.fbx")}
        missing = sorted(files - present)
        if missing:
            print("Missing from private-assets/mixamo: " + ", ".join(missing))
        if not files & present:
            raise SystemExit("FAIL: no Mixamo FBX files to retarget; see docs/movement-assets.md")
        run(
            blender(), "--background", "--factory-startup", "--python-exit-code", "1",
            "--python", "tools/mixamo_to_r15.py", "--",
            "--input", "private-assets/mixamo", "--manifest", "tools/mixamo_manifest.json",
            "--output", CLIPS, "--report", "private-assets/generated/retarget-report.json",
        )
    if CLIPS.exists():
        run("rojo", "build", "movement.private.project.json", "--output", "build/SlugshotMovementLabPrivate.rbxlx")
    else:
        print(f"SKIP private lab: {CLIPS.relative_to(ROOT)} not generated (run with --retarget)")
    for version, commit in VERSIONS.items():
        source = ROOT / f"build/movement-{version}"
        shutil.rmtree(source, ignore_errors=True)
        archive = subprocess.run(
            ["git", "archive", commit, "movement.project.json", "src", "experiments/movement"],
            cwd=ROOT, check=True, capture_output=True,
        ).stdout
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(source, filter="data")
        run("rojo", "build", source / "movement.project.json", "--output", f"build/SlugshotMovementLab-{version}.rbxlx")
    print("PASS: playtest places in build/ (ignored). Never commit or publish the private lab.")


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
