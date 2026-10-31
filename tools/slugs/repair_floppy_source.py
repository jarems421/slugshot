"""Create a technically repaired variant, preserving the approved Floppy baseline.

Run headlessly in Blender 4.5. Does not overwrite floppy.blend or its textures.
"""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_floppy_roblox import ROOT, repair_surface

source = ROOT / "assets/source/slugs/models/floppy/floppy.blend"
target = source.with_name("floppy-repaired.blend")
bpy.ops.wm.open_mainfile(filepath=str(source))
body = bpy.data.objects["FloppyBody"]
repair_surface(body)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(target), compress=True)
print("PASS: repaired source variant; approved baseline preserved")
