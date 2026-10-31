"""Creature contracts, safe paths and deterministic Roblox data. Stdlib only."""
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/slugs"
SLOTS = {
    "protoform": {"idle", "blink", "breathing", "happy", "angry", "surprised", "hop", "launch", "spin", "prepare"},
    "transformed": {"reveal", "movement", "attackStartup", "attack", "impact", "recovery"},
}
GENERATORS = {"protoform-placeholder": "protoform-v1", "expanded-placeholder": "expanded-test-v1"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def within(path, parent):
    path = Path(path).resolve()
    require(path.is_relative_to(parent.resolve()), f"Path must stay inside {parent}: {path}")
    return path


def identifier(value):
    return isinstance(value, str) and re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", value)


def number(value, low, high):
    return type(value) in (int, float) and math.isfinite(value) and low <= value <= high


def vector(value, low=-100, high=100):
    return isinstance(value, list) and len(value) == 3 and all(number(v, low, high) for v in value)


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rig_spec(rig_id):
    require(identifier(rig_id), f"Invalid rig id: {rig_id}")
    path = SOURCE / "rigs" / f"{rig_id}.json"
    require(path.is_file(), f"Missing rig specification: {path}")
    rig = read(path)
    require(rig["id"] == rig_id, f"Rig id mismatch: {path}")
    seen = set()
    for bone in rig["bones"]:
        name = bone["name"]
        require(identifier(name) and name not in seen, f"Duplicate/invalid bone: {name}")
        require(bone["parent"] in seen if seen else bone["parent"] is None and name == "root", f"Invalid parent/order for bone {name}")
        require(vector(bone["position"], -2, 2), f"Invalid rest position: {name}")
        seen.add(name)
    require(seen, f"Empty skeleton: {rig_id}")
    for socket, spec in rig["sockets"].items():
        require(identifier(socket) and spec["bone"] in seen and vector(spec["position"], -2, 2), f"Invalid socket: {socket}")
    return rig


def load_species(path):
    data = read(path)
    validate_species(data)
    return data


def validate_species(data):
    try:
        return _validate_species(data)
    except (KeyError, TypeError, IndexError, AttributeError) as error:
        raise ValueError(f"Invalid species structure or missing field: {error}") from error


def _validate_species(data):
    require(data.get("version") == 1, "Species version must be 1")
    require(identifier(data.get("id")), "Invalid species id")
    require(isinstance(data.get("placeholder"), bool), "placeholder must be boolean")
    require(bool(data.get("provenance")), "Missing provenance/permission statement")
    require(data.get("pattern") in {"solid", "bands"}, "Unknown pattern (supported: solid, bands)")
    palette = data["palette"]
    require(all(k in palette for k in ("body", "feature", "eye")), "Missing required palette material")
    require(all(identifier(k) and vector(v, 0, 1) for k, v in palette.items()), "Invalid palette colors")
    forms = data["forms"]
    require("protoform" in forms and set(forms) <= set(SLOTS), "Forms require protoform and optional transformed")
    profile = data["transformation"]
    require(isinstance(profile["enabled"], bool), "Transformation enabled must be boolean")
    require(not profile["enabled"] or "transformed" in forms, "Transformation enabled but transformed asset missing")
    require(number(profile["duration"], 0.01, 10), "Invalid transformation duration")
    require(number(profile["spinTurnsPerSecond"], -30, 30), "Invalid rotation speed")
    require(number(profile["transitionFraction"], 0.1, 0.9) and number(profile["revealFraction"], 0.1, 1) and profile["transitionFraction"] < profile["revealFraction"], "Invalid transition/reveal ordering")
    require(vector(profile["effectColor"], 0, 1) and identifier(profile["effect"]), "Invalid effect reference/color")
    budgets = data["budgets"]
    for key, limit in (("trianglesPerMesh", 20000), ("totalTriangles", 100000), ("maxBones", 128), ("maxInfluences", 4)):
        require(type(budgets[key]) is int and 1 <= budgets[key] <= limit, f"Invalid budget: {key}")
    for form_name, form in forms.items():
        rig = rig_spec(form["rig"])
        require(len(rig["bones"]) <= budgets["maxBones"], f"Bone budget exceeded: {form_name}")
        require(vector(form["size"], 0.1, 50), f"Invalid model scale: {form_name}")
        require(number(form["headScale"], 0.5, 2) and number(form["eyeSpacing"], 0, 2), f"Invalid proportions: {form_name}")
        if form["source"] is None:
            require(data["placeholder"] and GENERATORS.get(form["generator"]) == form["rig"], f"Unsupported generator/rig or missing authored source: {form_name}")
        else:
            require(form["generator"] == "authored", "Source models must use generator=authored")
            path = within(ROOT / form["source"], SOURCE / "models" / data["id"])
            require(path.suffix == ".blend" and path.is_file(), f"Missing Blender source file: {path}")
        seen = set()
        for feature in form["features"]:
            require(identifier(feature["id"]) and feature["id"] not in seen, f"Duplicate/invalid feature: {feature['id']}")
            seen.add(feature["id"])
            require(feature["kind"] in {"eye", "horn", "antenna", "fin", "ear"}, f"Unknown anatomy kind: {feature['kind']}")
            require(feature["socket"] in rig["sockets"], f"Missing attachment point: {feature['socket']}")
            require(vector(feature["offset"], -5, 5) and vector(feature["scale"], 0.01, 10), "Invalid feature scale/offset")
            require(feature["material"] in palette, f"Missing feature material: {feature['material']}")
        required = {"idle"} if form_name == "protoform" else ({"reveal", "attack"} if profile["enabled"] else set())
        require(required <= set(form["animations"]), f"Missing required animation slots: {sorted(required - set(form['animations']))}")
        for slot, animation in form["animations"].items():
            require(slot in SLOTS[form_name], f"Unknown animation slot: {slot}")
            require(animation["rig"] == form["rig"], f"Incompatible animation rig: {form_name}.{slot}")
            require(isinstance(animation["action"], str) and re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]{0,63}", animation["action"]), f"Invalid animation action: {slot}")
            require(isinstance(animation["loop"], bool), f"Invalid loop flag: {slot}")
            require("assetId" not in animation, "Reusable uploaded IDs belong in ignored private storage")
    return data


def feature_position(feature, form, rig):
    pos = list(rig["sockets"][feature["socket"]]["position"])
    if feature["kind"] == "eye":
        pos[0] *= form["eyeSpacing"]
    return [pos[i] * form["size"][i] + feature["offset"][i] for i in range(3)]


def luau(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "{" + ", ".join(luau(v) for v in value) + "}"
    return "{\n" + ",\n".join(f"[{json.dumps(k)}] = {luau(v)}" for k, v in sorted(value.items())) + "\n}"


def compiled_data():
    species = {}
    rigs = {}
    for path in sorted((SOURCE / "species").glob("*.json")):
        data = load_species(path)
        require(path.stem == data["id"] and data["id"] not in species, "Species filename/id must match and be unique")
        species[data["id"]] = data
        for form in data["forms"].values():
            rigs[form["rig"]] = rig_spec(form["rig"])
    return species, rigs


def compile_runtime(output):
    species, rigs = compiled_data()
    content = "--!strict\n-- Generated by tools/slugs/cli.py compile; edit the source JSON.\nlocal Types = require(script.Parent.Types)\nreturn { species = " + luau(species) + " :: {[string]: Types.Species}, rigs = " + luau(rigs) + " :: {[string]: Types.Rig} }\n"
    Path(output).write_text(content, encoding="utf-8")
