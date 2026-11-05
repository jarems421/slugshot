"""Holds the Luau motion kit and its browser twin to the same numbers, and the numbers to what the kit promises."""
import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LUAU = ROOT / "experiments/creatures/shared/MotionKit.luau"
TWIN = ROOT / "tools/slugs/motion-preview/motion-kit.js"
SPEC = ROOT / "experiments/creatures/tests/server/MotionKit.spec.server.luau"


class MotionKit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        out = subprocess.run(["node", str(ROOT / "tools/slugs/golden_motion_kit.mjs")], capture_output=True, text=True, check=True)
        cls.golden = json.loads(out.stdout)

    def test_same_motion_at_any_frame_rate(self):
        self.assertAlmostEqual(self.golden["squash60"]["x"], self.golden["squash30"]["x"], places=6)

    def test_low_damping_overshoots_and_high_damping_barely_does(self):
        self.assertGreater(self.golden["squash60"]["peak"], 1.3)
        self.assertLess(self.golden["flip60"]["peak"], 1.01)

    def test_chain_trails(self):
        lead, tip = self.golden["chain"]
        self.assertGreater(lead, tip)

    def test_hop_stages(self):
        self.assertEqual([h[0] for h in self.golden["hop"]], ["rest", "windup", "hold", "air", "air", "land", "land", "rest"])

    def test_luau_spec_expects_these_numbers(self):
        spec = SPEC.read_text(encoding="utf-8")
        block = spec[spec.index("local GOLDEN"):spec.index("-- End of golden numbers")]
        found = {name: list(map(float, re.findall(r"-?[\d.]+", value))) for name, value in re.findall(r"^	(\w+) = (.+?),?$", block, re.M)}
        g = self.golden
        expected = {
            "squashX": [g["squash60"]["x"]], "squashPeak": [g["squash60"]["peak"]], "flipPeak": [g["flip60"]["peak"]],
            "chain": g["chain"], "kick": [g["kick"]], "ease": [g["ease"]], "soft": [g["soft"]], "arc": [g["arc"]],
            "pulse": [g["pulse"]], "window": [g["window"]], "ballistic": [g["ballistic"]],
            "hopPress": [h[1] for h in g["hop"]], "hopLift": [h[2] for h in g["hop"]],
        }
        self.assertEqual(found, expected)

    def test_tunes_match(self):
        luau = LUAU.read_text(encoding="utf-8")
        twin = TWIN.read_text(encoding="utf-8")
        self.assertEqual(
            re.findall(r"(\w+) = table\.freeze\(\{ freq = ([\d.]+), damp = ([\d.]+) \}\)", luau),
            re.findall(r"(\w+): \{ freq: ([\d.]+), damp: ([\d.]+) \}", twin),
        )
        self.assertEqual(
            re.findall(r"(\w+) = table\.freeze\(MotionKit\.fromStiffness\(([\d.]+), ([\d.]+)\)\)", luau),
            re.findall(r"(\w+): fromStiffness\(([\d.]+), ([\d.]+)\)", twin),
        )


if __name__ == "__main__":
    unittest.main()
