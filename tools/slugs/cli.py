"""Public creature pipeline CLI. No downloads, addons, uploads or pip packages."""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from common import ROOT, SOURCE, compile_runtime, load_species, within


def blender_executable():
    configured = os.environ.get("BLENDER") or shutil.which("blender")
    candidates = [Path(configured)] if configured else sorted((ROOT / ".tools").glob("blender-*/blender.exe")) + sorted((ROOT / ".tools").glob("blender-*/blender"))
    if not candidates or not candidates[0].is_file():
        raise ValueError("Existing Blender required. Set BLENDER to its executable; this tool never installs software.")
    return str(candidates[0].resolve())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("compile", "validate-config", "generate", "export", "render", "validate", "all"))
    parser.add_argument("--species", default="placeholder", help="Species filename under assets/source/slugs/species")
    parser.add_argument("--frames", type=int, default=24, help="Frames per preview (8-120)")
    args = parser.parse_args()
    # Validate before constructing any output path or invoking Blender.
    from common import identifier, require
    require(identifier(args.species), "Invalid species id")
    require(8 <= args.frames <= 120, "Preview frames must be 8-120")
    config = SOURCE / "species" / f"{args.species}.json"
    load_species(config)
    if args.command == "compile":
        compile_runtime(ROOT / "experiments/creatures/shared/Definitions.luau")
        subprocess.run(["stylua", "experiments/creatures/shared/Definitions.luau"], cwd=ROOT, check=True)
    elif args.command != "validate-config":
        output = within(ROOT / "build/slugs" / args.species, ROOT / "build/slugs")
        subprocess.run([blender_executable(), "--background", "--factory-startup", "--disable-autoexec", "--python-exit-code", "1", "--python", str(ROOT / "tools/slugs/blender_pipeline.py"), "--", args.command, "--config", str(config), "--output", str(output), "--frames", str(args.frames)], cwd=ROOT, check=True)
    print(f"PASS: {args.command} ({args.species})")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
