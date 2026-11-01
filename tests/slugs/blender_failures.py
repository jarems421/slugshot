"""Run under Blender after generation. Corruption stays in memory; never saves."""
import copy
import math
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/slugs"))
from common import SOURCE, load_species
from blender_pipeline import generate, source_matches, validate_scene


def expect_failure(label, message, mutate):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "build/slugs/placeholder/source/protoform.blend"))
    species = load_species(SOURCE / "species/placeholder.json")
    form = species["forms"]["protoform"]
    mutate(species, form)
    try:
        validate_scene(species, form)
    except ValueError as error:
        assert message in str(error), (label, str(error))
        print("PASS negative Blender check:", label)
    else:
        raise AssertionError("Validator accepted corrupted asset: " + label)


expect_failure("missing bone", "Missing/extra bones", lambda s, f: setattr(bpy.data.objects["CreatureRig"].data.bones["head"], "name", "wrong_head"))
expect_failure("wrong orientation", "Unapplied scale/orientation", lambda s, f: setattr(bpy.data.objects["CreatureRig"], "rotation_euler", (0, 0, 1)))
expect_failure("unapplied scale", "Unapplied scale/orientation", lambda s, f: setattr(bpy.data.objects["CreatureRig"], "scale", (2, 2, 2)))
expect_failure("incorrect attachment", "Incorrect attachment position", lambda s, f: setattr(bpy.data.objects["left-eye"].data.vertices[0], "co", (100, 100, 100)))
expect_failure("triangle budget", "Excessive polygon count", lambda s, f: s["budgets"].update(trianglesPerMesh=1))
expect_failure("missing action", "Missing/empty animation action", lambda s, f: setattr(bpy.data.actions["Idle"], "name", "MissingIdle"))


def remove_weight(species, form):
    mesh = bpy.data.objects["Body_PLACEHOLDER"]
    for group in mesh.vertex_groups:
        group.remove([0])


expect_failure("unweighted vertex", "Invalid skin weights", remove_weight)


def wrong_roll(species, form):
    armature = bpy.data.objects["CreatureRig"]
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    armature.data.edit_bones["head"].roll = math.pi
    bpy.ops.object.mode_set(mode="OBJECT")


expect_failure("reversed bone roll", "Incorrect bone roll", wrong_roll)

bpy.ops.wm.open_mainfile(filepath=str(ROOT / "build/slugs/placeholder/source/protoform.blend"))
changed = load_species(SOURCE / "species/placeholder.json")
changed["palette"]["body"] = [0.8, 0.1, 0.1]
try:
    source_matches(changed, changed["forms"]["protoform"])
except ValueError as error:
    assert "Stale Blender source" in str(error), str(error)
    print("PASS negative Blender check: stale source configuration")
else:
    raise AssertionError("Stale source accepted after palette change")
# A real second configuration: one eye, no horn, new proportions and bands.
# Validate and generate in a disposable build child; no public species/design added.
variant = load_species(SOURCE / "species/placeholder.json")
form = variant["forms"]["protoform"]
form["features"] = [copy.deepcopy(form["features"][0])]
form["features"][0]["socket"] = "face_center"
form["size"] = [2.0, 3.5, 1.5]
form["headScale"] = 1.2
variant["pattern"] = "bands"
generate(variant, ROOT / "build/slugs/variant-check")
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "build/slugs/variant-check/source/protoform.blend"))
assert "test-horn" not in bpy.context.scene.objects and "right-eye" not in bpy.context.scene.objects
assert len({p.material_index for p in bpy.data.objects["Body_PLACEHOLDER"].data.polygons}) == 2, "Band materials were not assigned"
print("PASS: Blender generation of single-eye, horn-free, proportion/pattern variant")
