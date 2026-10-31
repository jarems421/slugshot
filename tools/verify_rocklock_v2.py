"""Offline verification for Rocklock v2 (does not run Roblox).

python tools/verify_rocklock_v2.py [--skip-movement]
Checks: Luau strict types/lint/format for the v2 scripts; layout routes reachable from both
spawns with every destructible intact AND with every destructible destroyed; each route
within the real movement controller's limits; destruction data and damage rules; rock skins
never above walkable tops or past wall-run faces; place contents, controller fidelity,
private-asset isolation and v1/foundation independence.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/rocklock_v2"))
import layout as L  # noqa: E402
from build import ADAPTER, SPAWN  # noqa: E402

GRAVITY = 196.2
failures = []


def check(ok, message):
    print(("PASS  " if ok else "FAIL  ") + message)
    if not ok:
        failures.append(message)


def run(*args):
    print("+ " + " ".join(args), flush=True)
    return subprocess.run(args, cwd=ROOT).returncode == 0


def config_number(text, pattern):
    match = re.search(pattern, text, re.S)
    if not match:
        raise ValueError(f"Movement config value not found: {pattern}")
    return float(match.group(1))


def movement_limits():
    text = (ROOT / "experiments/movement/shared/Config.luau").read_text(encoding="utf-8")
    athletic = text[text.index("Athletic = {"):]
    jump = config_number(athletic, r"JumpPower = ([\d.]+)")
    run_speed = config_number(athletic, r"RunSpeed = ([\d.]+)")
    sprint = config_number(athletic, r"SprintSpeed = ([\d.]+)")
    double = config_number(text, r"DoubleJump = ([\d.]+)")
    mantle = config_number(text, r"MinHeight = 0\.7.*?MaxHeight = ([\d.]+)")
    wall = text[text.index("WallRun = {"):]
    climb = config_number(wall, r"Climb = ([\d.]+)")
    climb_time = config_number(wall, r"ClimbTime = ([\d.]+)")
    height = jump * jump / (2 * GRAVITY)
    air = 2 * jump / GRAVITY
    return {"jump_height": height, "double_height": height + double * double / (2 * GRAVITY),
            "mantle": mantle, "run_jump": run_speed * air, "sprint_jump": sprint * air,
            "climb_reach": climb * climb_time + mantle, "climb": climb}


def reachable(edges, start):
    graph = {}
    for e in edges:
        graph.setdefault(e["a"], set()).add(e["b"])
        if e["kind"] != "drop":
            graph.setdefault(e["b"], set()).add(e["a"])
    seen, todo = {start}, [start]
    while todo:
        n = todo.pop()
        for m in graph.get(n, ()):
            if m not in seen:
                seen.add(m)
                todo.append(m)
    return seen


def verify_layout():
    limits = movement_limits()
    print("Movement limits (from Config): " + ", ".join(f"{k} {v:.1f}" for k, v in limits.items()))
    check(180 <= L.WIDTH <= 240 and 150 <= L.DEPTH <= 200, f"footprint {L.WIDTH:.0f} x {L.DEPTH:.0f} studs (owner 2026-10-31: 140 x 112 felt tiny; scaled 1.5x)")
    check(L.MIDDLE - L.LOWER in range(8, 13) and L.HIGH - L.LOWER in range(18, 23), "three tiers: lower 0, middle 10, high 20")
    ids = {d["id"] for d in L.DESTRUCTIBLES} | {t["id"] for t in L.TERRAIN}
    nodes = set(L.NODES)
    check(all(e["a"] in nodes and e["b"] in nodes for e in L.EDGES), "every route edge joins known nodes")
    check(all(set(e["requires"] + e["opens"]) <= ids for e in L.EDGES), "route edges reference real destructibles")
    for state, edges in (("intact", [e for e in L.EDGES if not e["opens"]]),
                         ("all destructibles destroyed", [e for e in L.EDGES if not e["requires"]])):
        for spawn in ("Spawn_N", "Spawn_S"):
            seen = reachable(edges, spawn)
            check(seen == nodes, f"{state}: every region reachable from {spawn} ({len(seen)}/{len(nodes)})")
    for spawn in ("Spawn_N", "Spawn_S"):
        exits = {e["b"] for e in L.EDGES if e["a"] == spawn and not e["requires"]}
        check(len(exits) >= 3, f"{spawn} has {len(exits)} independent exits (needs 3)")
    for e in L.EDGES:
        label = f"{e['a']} -> {e['b']} ({e['kind']})"
        if e["kind"] == "ramp":
            check(e.get("slope", 0) <= 42, f"{label} slope {e.get('slope', 0):.1f} <= 42")
        elif e["kind"] == "jump":
            limit = limits["sprint_jump"] if e.get("skill") else limits["run_jump"]
            check(e["gap"] <= limit, f"{label} gap {e['gap']} <= {'sprint' if e.get('skill') else 'run'} jump {limit:.1f}")
        elif e["kind"] == "jumpmantle":
            reach = limits["jump_height"] + limits["mantle"]
            check(e["rise"] <= reach, f"{label} rise {e['rise']} <= jump+mantle {reach:.1f}")
        elif e["kind"] == "climb":
            check(e["rise"] <= limits["climb_reach"], f"{label} rise {e['rise']} <= climb reach {limits['climb_reach']:.1f}")
        elif e["kind"] == "wallrun":
            check(e.get("climb", 0) <= limits["climb"] + 1e-6, f"{label} uses the real wall-run climb speed")
    for s in L.STATIC:
        if s["kind"] == "ramp":
            check(s["slope"] <= 42, f"ramp {s['name']} slope {s['slope']:.1f} <= 42")
    categories = {"Full", "Partial", "Landmark", "Essential"}
    for d in L.DESTRUCTIBLES:
        stages = [c["stage"] for c in d["chunks"]]
        ok = (d["category"] in categories and d["health"] > 0 and d["stages"] >= max(stages)
              and all(0 <= s <= d["stages"] for s in stages) and all(c["rubble"] in ("Small", "Large") for c in d["chunks"])
              and (d["hazard"] is not None) == (d["kind"] == "Hanging") and d["category"] != "Essential")
        check(ok, f"destructible {d['id']} ({d['category']}, {d['health']} HP, {d['stages']} stages) data valid")
    for d in L.DESTRUCTIBLES:
        if d["hazard"]:
            x, _, z = d["chunks"][0]["pos"]
            far = all(math.hypot(x - s["position"][0], z - s["position"][2]) > d["hazard"]["radius"] + 12 for s in L.SPAWNS)
            check(far, f"{d['id']} cannot fall onto a spawn")
    for d in L.DESTRUCTIBLES:
        for c in d["chunks"]:
            x, y, z = c["pos"]
            inside = abs(x) < 12 and y >= L.MIDDLE - 0.1 and abs(z) > 44
            check(not inside, f"{d['id']}.{c['name']} is outside the spawn alcoves") if inside else None
    config = (ROOT / "experiments/rocklock-v2/shared/DestructionConfig.luau").read_text(encoding="utf-8")
    multipliers = [float(v) for v in re.findall(r"(?:Blunt|Penetrating|Tunnelling|Explosive|Elemental) = ([\d.]+)",
                                                  config[config.index("Materials"):config.index("MinMultiplier")])]
    minimum = config_number(config, r"MinMultiplier = ([\d.]+)")
    check(minimum > 0 and all(m > 0 for m in multipliers), f"no attack does zero structural damage (min multiplier {minimum}, {len(multipliers)} entries > 0)")


def verify_geometry():
    stats = json.loads((ROOT / "build/rocklock-v2/stats.json").read_text())
    geology = json.loads((ROOT / "build/rocklock-v2/geology.json").read_text())
    sha = lambda p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
    check(geology["layout_sha256"] == sha("tools/rocklock_v2/layout.py"), "rock skins generated from the current layout")
    check(geology["generator_sha256"] == sha("tools/rocklock_v2/geology_blender.py"), "rock skins generated by the current generator")
    check(stats["total_parts"] <= 9000, f"part budget {stats['total_parts']} <= 9000")
    tops = {s["name"]: s for s in L.STATIC if s["skin"]}
    above, past = 0, 0
    for mesh in geology["meshes"]:
        base = mesh["name"].rsplit("_", 1)[0]
        s = tops.get(base)
        if not s:
            continue
        top = s["pos"][1] + s["size"][1] / 2
        face_x = s["pos"][0] + s["size"][0] / 2
        for tri in mesh["triangles"]:
            for v in tri:
                above += v[1] > top + 0.02
                past += "east" in s["run_faces"] and v[0] > face_x + 0.1
    check(above == 0, f"rock skins never rise above walkable tops ({above} vertices)")
    check(past == 0, f"rock skins never protrude past wall-run faces ({past} vertices)")


def verify_places():
    sources = {p: (ROOT / p).read_text(encoding="utf-8") for p in (
        "experiments/movement/shared/Config.luau", "experiments/movement/client/Presentation.luau",
        "experiments/movement/client/Traversal.luau", "experiments/movement/shared/OriginalClips.luau",
        "experiments/movement/client/init.client.luau", "experiments/rocklock-v2/server/Destruction.luau")}
    original = (ROOT / "experiments/movement/server/init.server.luau").read_text(encoding="utf-8")
    for file, private in (("SlugshotRocklockV2.rbxlx", False), ("SlugshotRocklockV2Private.rbxlx", True)):
        path = ROOT / "build" / file
        if private and not path.exists():
            print("SKIP  private place not built")
            continue
        tree = ET.parse(path)
        scripts = [(i.get("class"), i.findtext("Properties/string[@name='Name']"), i.findtext("Properties/*[@name='Source']"))
                   for i in tree.iter("Item") if i.get("class") in {"Script", "LocalScript", "ModuleScript"}]
        names = {n for _, n, _ in scripts}
        bodies = [b for _, _, b in scripts]
        check(all(src in bodies for src in sources.values()), f"{file}: movement and destruction sources are byte-identical to the repo")
        check(original.replace(SPAWN, ADAPTER) in bodies, f"{file}: movement server differs only by the spawn adapter")
        check({"Destruction", "SelfTest", "DestructionConfig", "RocklockV2"} <= names, f"{file}: destruction scripts present")
        check(("MovementPrivateClips" in names) == private and ("RocklockBlasterMesh" in names) == private,
              f"{file}: private clips/blaster mesh {'present' if private else 'absent'}")
        check(not any(".spec" in (n or "") for n in names), f"{file}: no test specs in the playable place")
        check(not any(i.get("class") in {"MeshPart", "Animation", "KeyframeSequence"} for i in tree.iter("Item")),
              f"{file}: no uploaded meshes or animation assets embedded")
    for project in ("default.project.json", "movement.project.json", "movement.private.project.json",
                    "rocklock.project.json", "rocklock.private.project.json"):
        text = (ROOT / project).read_text(encoding="utf-8")
        check("rocklock-v2" not in text and "rocklock_v2" not in text, f"{project} is independent of v2")
    check("build/rocklock/generated/map.rbxmx" in (ROOT / "rocklock.project.json").read_text(encoding="utf-8"),
          "Rocklock v1 place still builds its own map (baseline preserved)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-movement", action="store_true")
    args = parser.parse_args()
    if not args.skip_movement:
        check(run(sys.executable, "tools/verify_movement.py"), "movement and foundation verification")
    check(run("rojo", "sourcemap", "rocklock-v2.project.json", "--output", "build/rocklock-v2/sourcemap.json"), "v2 sourcemap")
    check(run("luau-lsp", "analyze", "--definitions=@roblox=.tools/luau/globalTypes.None.d.luau",
              "--sourcemap=build/rocklock-v2/sourcemap.json", "experiments/rocklock-v2", "experiments/movement/rocklock"),
          "v2 Luau strict type check")
    check(run("selene", "experiments/rocklock-v2"), "v2 lint")
    check(run("stylua", "--check", "experiments/rocklock-v2"), "v2 formatting")
    verify_layout()
    verify_geometry()
    verify_places()
    print(f"\n{'FAIL' if failures else 'PASS'}: Rocklock v2 offline verification ({len(failures)} failures)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
