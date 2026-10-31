"""Failure cases that protect real species authoring and export boundaries."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/slugs"))
from common import ROOT, SOURCE, load_species, rig_spec, validate_species, within


class SpeciesContracts(unittest.TestCase):
    def setUp(self):
        self.data = load_species(SOURCE / "species/placeholder.json")

    def rejected(self, message):
        with self.assertRaisesRegex(ValueError, message):
            validate_species(self.data)

    def test_missing_transformed_model(self):
        del self.data["forms"]["transformed"]
        self.rejected("transformed asset missing")

    def test_non_transforming_species_needs_no_transformed_form(self):
        self.data["transformation"]["enabled"] = False
        del self.data["forms"]["transformed"]
        validate_species(self.data)

    def test_missing_idle_slot(self):
        del self.data["forms"]["protoform"]["animations"]["idle"]
        self.rejected("Missing required animation slots")

    def test_mismatched_animation_rig(self):
        self.data["forms"]["protoform"]["animations"]["idle"]["rig"] = "expanded-test-v1"
        self.rejected("Incompatible animation rig")

    def test_bad_attachment(self):
        self.data["forms"]["protoform"]["features"][0]["socket"] = "missing"
        self.rejected("Missing attachment point")

    def test_duplicate_feature(self):
        form = self.data["forms"]["protoform"]
        form["features"].append(copy.deepcopy(form["features"][0]))
        self.rejected("Duplicate/invalid feature")

    def test_single_eye_and_feature_removal(self):
        form = self.data["forms"]["protoform"]
        form["features"] = form["features"][:1]
        form["features"][0]["socket"] = "face_center"
        form["size"] = [2.1, 3.6, 1.5]
        form["headScale"] = 1.2
        validate_species(self.data)

    def test_invalid_scale(self):
        self.data["forms"]["protoform"]["size"][0] = -1
        self.rejected("Invalid model scale")

    def test_nan_scale(self):
        self.data["forms"]["protoform"]["size"][0] = float("nan")
        self.rejected("Invalid model scale")

    def test_bad_budget(self):
        self.data["budgets"]["trianglesPerMesh"] = 20001
        self.rejected("Invalid budget")

    def test_missing_authored_source(self):
        form = self.data["forms"]["protoform"]
        form["generator"] = "authored"
        form["source"] = "assets/source/slugs/models/placeholder/missing.blend"
        self.rejected("Missing Blender source")

    def test_cross_species_source_dependency(self):
        form = self.data["forms"]["protoform"]
        form["generator"] = "authored"
        form["source"] = "assets/source/slugs/models/other/model.blend"
        self.rejected("Path must stay inside")

    def test_no_uploaded_ids_in_public_config(self):
        self.data["forms"]["protoform"]["animations"]["idle"]["assetId"] = "example"
        self.rejected("ignored private storage")

    def test_path_traversal(self):
        with self.assertRaisesRegex(ValueError, "Path must stay inside"):
            within(ROOT / "build/../outside", ROOT / "build/slugs")

    def test_invalid_rig_id(self):
        with self.assertRaisesRegex(ValueError, "Invalid rig id"):
            rig_spec("../../other")

    def test_missing_rig(self):
        with self.assertRaisesRegex(ValueError, "Missing rig specification"):
            rig_spec("unknown-rig")

    def test_malformed_structure(self):
        del self.data["forms"]["protoform"]["size"]
        self.rejected("missing field")

    def test_real_species_cannot_use_art_placeholder_generator(self):
        self.data["placeholder"] = False
        self.rejected("Unsupported generator/rig")

    def test_material_reference(self):
        self.data["forms"]["protoform"]["features"][0]["material"] = "absent"
        self.rejected("Missing feature material")

    def test_invalid_transformation_order(self):
        self.data["transformation"]["transitionFraction"] = 0.9
        self.data["transformation"]["revealFraction"] = 0.5
        self.rejected("ordering")

    def test_first_slug_is_authored_and_has_no_transformed_form(self):
        design = load_species(SOURCE / "species/flopper-inspired.json")
        self.assertFalse(design["placeholder"])
        self.assertFalse(design["transformation"]["enabled"])
        self.assertNotIn("transformed", design["forms"])
        self.assertTrue((ROOT / design["forms"]["protoform"]["source"]).is_file())

    def test_first_slug_has_requested_motion_slots(self):
        design = load_species(SOURCE / "species/flopper-inspired.json")
        form = design["forms"]["protoform"]
        self.assertTrue({"idle", "blink", "hop", "launch", "impact"} <= set(form["animations"]))
        bones = {bone["name"] for bone in rig_spec(form["rig"])["bones"]}
        self.assertTrue({"eye_left", "eye_right", "feelers_left", "feelers_right"} <= bones)


if __name__ == "__main__":
    unittest.main()
