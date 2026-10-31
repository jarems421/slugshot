"""One deterministic layout for the Blender scene and the Roblox collision model.

Positions and dimensions are in studs, Roblox X/right, Y/up, Z/south.
No third-party models, textures or source data are used.
"""
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "experiments/movement/rocklock/config.json"


def layout(config=None):
    c = config or json.loads(CONFIG.read_text(encoding="utf-8"))
    palette = c["palette"]
    boxes, rocks = [], []
    rng = random.Random(c["seed"])
    # Author at 100x90; scale the complete layout, including metadata, in X/Z.
    sx, sz = c["width"] / 100, c["depth"] / 90

    def box(name, pos, size, role="Ground", color="stone", yaw=0, pitch=0):
        item = dict(name=name, position=pos, size=size, role=role,
                    color=palette[color], yaw=yaw, pitch=pitch)
        boxes.append(item)
        return item

    def rock(name, pos, size, group="Shell", color="wall", tilt=0):
        rocks.append(dict(name=name, position=pos, size=size, group=group,
                          color=palette[color], seed=rng.randrange(2**30), tilt=tilt))

    # Four solid floor pieces leave a real sunken underpass, with no hidden floor.
    box("FloorWest", [-29, -2, 0], [44, 4, 92], color="floor")
    box("FloorEast", [29, -2, 0], [44, 4, 92], color="floor")
    for sign, name in [(-1, "North"), (1, "South")]:
        box(name + "Floor", [0, -2, sign * 32], [14, 4, 28], color="floor")
        # Ramp surface descends from y=0 at z=18 to -4 at z=8.
        angle = -sign * math.degrees(math.atan2(4, 10))
        box(name + "TunnelRamp", [0, -2.5, sign * 13],
            [14, 1, math.hypot(10, 4) + 0.4], "Tunnel", "floor", pitch=angle)
        box(name + "Baffle", [0, 3.5, sign * 24], [14, 7, 5], "Cover", "stone")
        # One broad formation protects each spawn; both sides stay wide open.
        box(name + "SpawnPad", [0, 0.025, sign * 37], [8, 0.05, 6], "Spawn",
            "west" if sign == -1 else "east")
        rock(name + "BaffleCap", [0, 7.8, sign * 24], [14, 2, 5], "Cover", "stone")

    box("UnderpassFloor", [0, -5, 0], [14, 2, 17], "Tunnel", "floor")
    box("UnderpassRoof", [0, 10, 0], [14, 4, 18], "Tunnel", "shelf")
    for side in [-1, 1]:
        box(f"UnderpassSide{side}", [side * 8.5, 4, 0], [3, 16, 20], "Tunnel")

    # Side routes: broad shelves and four gentle rock ramps, never mandatory jumps.
    shelf = c["shelf_height"]
    route_width = c["route_width"]
    for side, name in [(-1, "West"), (1, "East")]:
        x = side * 36
        if side == -1:
            box("WestShelf", [x, shelf / 2, 0], [route_width, shelf, 40], "Shelf", "shelf")
        else:
            for end in [-1, 1]:
                box(f"EastShelf{end}", [x, shelf / 2, end * 14], [route_width, shelf, 12], "Shelf", "shelf")
            box("EastStoneBridge", [x, shelf - 1.5, 0], [12, 3, 16.2], "Bridge", "shelf")
            # Solid foundations make the bridge read as an eroded natural stone arch.
            for end in [-1, 1]:
                rock(f"EastBridgeFoot{end}", [x, 4, end * 8], [15, 8, 7], "Route", "stone")
                box(f"EastBridgeSupport{end}", [x, 4, end * 9], [14, 8, 5], "Pillar")
        for end in [-1, 1]:
            ramp = box(f"{name}Approach{end}", [x, shelf/2, end*29.5],
                       [route_width, shelf, 19.1], "Ramp", "shelf", yaw=0 if end == -1 else 180)
            ramp["kind"] = "WedgePart"
        # The wall face is continuous, vertical and exactly at x=43.5.
        box(name + "RunFace", [side * 46, 21, 0], [5, 42, 44], "WallRun", "wall")
        for end in [-1, 1]:
            rock(f"{name}CliffButtress{end}", [side * 48, 14, end * 19],
                 [6, 30, 12], "Route", "wall")

    # Fractured central arch, rooted into the tunnel walls and topped by a broken crown.
    for side in [-1, 1]:
        box(f"ArchPier{side}", [side * 11, 14, 0], [6, 28, 9], "Pillar")
        rock(f"ArchPillar{side}", [side * 11, 16, 0], [8, 34, 11], "Landmark", "stone")
        rock(f"ArchHaunch{side}", [side * 7, 31, 0], [12, 11, 11], "Landmark", "stone", tilt=side * 27)
        rock(f"BrokenTooth{side}", [side * 3.7, 35, side * 1.5], [4, 6, 7], "Landmark", "fracture", tilt=side * 30)
    rock("SuspendedKeystone", [0, 41, 0], [9, 7, 9], "Collapse", "fracture", tilt=18)
    rock("CeilingFracture", [0, 63, 0], [12, 38, 13], "Collapse", "ceiling", tilt=8)

    # A high, fully enclosed faceted chamber. Backing walls are visible boundary rock,
    # not invisible barriers. Corners are bevelled rather than square arena corners.
    for side in [-1, 1]:
        box(f"SideBoundary{side}", [side * 54, c["ceiling"]/2, 0], [12, c["ceiling"]+8, 76], "Boundary", "wall")
        box(f"EndBoundary{side}", [0, c["ceiling"]/2, side * 49], [88, c["ceiling"]+8, 12], "Boundary", "wall")
        for end in [-1, 1]:
            box(f"CornerBoundary{side}_{end}", [side * 49, c["ceiling"]/2, end * 44],
                [12, c["ceiling"]+8, 22], "Boundary", "wall", yaw=-side * end * 45)
    for i in range(16):
        a = 2 * math.pi * i / 16
        x = 56 * math.copysign(math.sqrt(abs(math.cos(a))), math.cos(a))
        z = 51 * math.copysign(math.sqrt(abs(math.sin(a))), math.sin(a))
        rock(f"CavernColumn{i:02}", [x * 1.045, c["ceiling"]*.46 + rng.uniform(-2, 2), z * 1.045],
             [rng.uniform(19, 27), rng.uniform(c["ceiling"]*.92, c["ceiling"]*1.1), rng.uniform(22, 30)], "Shell", "wall",
             tilt=rng.uniform(-8, 8))
        if i % 4 != 0 and i not in {1, 9}:
            rock(f"UpperStratum{i:02}", [x * 0.93, c["ceiling"]*.76, z * 0.93],
                 [24, rng.uniform(14, 23), 22], "Shell", "ceiling", tilt=rng.uniform(-12, 12))
    box("CavernRoofBacking", [0, c["ceiling"] + 3, 0], [132, 6, 122], "Boundary", "ceiling")
    for i, (x, z) in enumerate([(-35, -28), (0, -36), (35, -28), (-37, 18), (0, 35), (36, 22)]):
        rock(f"CeilingSlab{i}", [x, c["ceiling"] - 4 + rng.uniform(-2, 2), z],
             [62, 15, 54], "Roof", "ceiling", tilt=rng.uniform(-8, 8))
    # Hanging rock formations make a layered skyline without filling combat lanes.
    for i, (x, z, height, width) in enumerate([
        (-42,-32,18,5),(-30,-38,13,4),(-15,-35,17,5),(7,-38,12,4),(28,-33,19,6),(42,-26,14,4),
        (-42,1,14,4),(-32,29,18,5),(-13,37,12,4),(13,35,16,5),(30,30,13,4),(42,5,17,5)]):
        height *= 1.9
        rock(f"Stalactite{i:02}", [x, c["ceiling"]-height/2-2, z], [width,height,width*0.85], "Stalactite", "ceiling", tilt=rng.uniform(-4,4))
        rocks[-1]["profile"] = "stalactite"

    # Seeded stone skins keep the broad, reliable collision planes while replacing
    # exposed cuboids with chamfered, layered silhouettes. The relief is <=0.35 studs.
    for item in boxes:
        if (item["role"] in {"Boundary", "Cover", "Shelf", "Crown", "Pillar", "Mantle", "WallRun"}
                or item["name"].startswith("UnderpassSide") or item["name"] == "UnderpassRoof") and item["name"] != "CavernRoofBacking":
            skin = dict(name=item["name"] + "Stone", position=item["position"][:], size=item["size"][:],
                        group="StoneSkin", color=item["color"], seed=rng.randrange(2**30), tilt=0,
                        profile="stratum", yaw=item["yaw"], collision=item["name"])
            rocks.append(skin)
            item["stone_skin"] = skin["name"]

    # Scaling is shared by art, collision, route coordinates and spawn markers.
    for item in boxes + rocks:
        if item.get("pitch"):
            pitch = math.radians(item["pitch"])
            item["size"][2] *= math.hypot(math.cos(pitch)*sz, math.sin(pitch)) / sz
            item["pitch"] = math.degrees(math.atan(math.tan(pitch)/sz))
        item["position"] = [round(item["position"][0] * sx, 5), item["position"][1], round(item["position"][2] * sz, 5)]
        item["size"] = [round(item["size"][0] * sx, 5), item["size"][1], round(item["size"][2] * sz, 5)]
    metadata = json.loads(json.dumps(c))
    metadata["spawn_separation"] = abs(c["spawns"][1]["position"][2]-c["spawns"][0]["position"][2])*sz
    for spawn in metadata["spawns"]:
        for key in ("position", "look_at"):
            spawn[key][0] *= sx
            spawn[key][2] *= sz
    for route in metadata["routes"].values():
        for point in route:
            point[0] *= sx
            point[2] *= sz
    for marker in metadata["interactions"]:
        marker["position"][0] *= sx
        marker["position"][2] *= sz
        marker["size"][0] *= sx
        marker["size"][2] *= sz
    return dict(config=metadata, boxes=boxes, rocks=rocks)


if __name__ == "__main__":
    print(json.dumps(layout(), indent=2))
