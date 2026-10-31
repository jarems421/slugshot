"""Rocklock v2: the single source of truth for the cavern's geometry, routes and destruction.

Pure data and stdlib. Consumed by geology_blender.py (rock skins), build.py (Roblox place),
diagram.py (route/interaction maps), render.py (previews) and tools/verify_rocklock_v2.py.

Roblox axes: x across (west -, east +), y up, z along (north spawn -, south spawn +).
Footprint 210 x 168 studs (owner, 2026-10-31: 140 x 112 felt tiny and packed; scaled 1.5x with
movement-tuned gaps and heights kept fixed). Tiers: lower 0 (sunken collapse and gully -6), middle 10, high 20-21.
Gameplay collision is mirror-symmetric north/south so both spawns are equal; west and east
differ on purpose (west: wall-run cliff and Eyrie; east: shelves, natural bridge and Spire).
"""
import math

VERSION = "2.1.0"
SEED = 1712
K = 1.5  # horizontal scale over the first draft; heights and jump gaps do not scale
WIDTH, DEPTH = 210.0, 168.0
X0, X1, Z0, Z1 = -105.0, 105.0, -84.0, 84.0
CEILING_CELL = 42.0
LOWER, MIDDLE, HIGH = 0.0, 10.0, 20.0
PIT, GULLY = -6.0, -6.0
CEILING = 64.0

PALETTE = {
    "lower": (118, 104, 92), "middle": (128, 114, 100), "high": (140, 126, 110),
    "ramp": (124, 110, 97), "cliff": (98, 90, 84), "column": (132, 118, 104),
    "mass": (110, 100, 91), "boundary": (88, 82, 77), "ceiling": (84, 78, 74),
    # Breakable rock reads lighter and warmer than essential rock, so players can learn it.
    "breakable": (170, 148, 120), "shell": (158, 138, 114), "hanging": (150, 132, 112),
    "rubble": (152, 132, 108), "seal": (176, 154, 124),
}

STATIC = []          # collision (and visible floors); see box()
DESTRUCTIBLES = []   # structures of chunks, see structure()
TERRAIN = []         # runtime Terrain zones (excavatable earth)
DECOR = []           # skin-only formations (stalactites, ceiling, strata)
NODES = {}           # route graph nodes: name -> (x, y, z)
EDGES = []           # route graph edges
SPAWNS = [
    {"name": "North", "position": (0.0, MIDDLE + 3.15, -75.0), "look_at": (0.0, MIDDLE + 3.15, 0.0)},
    {"name": "South", "position": (0.0, MIDDLE + 3.15, 75.0), "look_at": (0.0, MIDDLE + 3.15, 0.0)},
]


def mirror_z(p):
    return (p[0], p[1], -p[2])


def box(name, x0, x1, y0, y1, z0, z1, kind="mass", color="mass", visible=False, skin=True,
        yaw=0.0, run_faces=(), mirror=False, essential=True):
    """Axis-aligned (optionally yawed) collision box from bounds. Visible boxes are native
    floor parts; invisible ones get a Blender rock skin. mirror adds the z-mirrored twin."""
    def add(suffix, zz0, zz1):
        STATIC.append({
            "name": name + suffix, "kind": kind, "color": color, "visible": visible,
            "skin": skin and not visible, "yaw": yaw, "run_faces": list(run_faces),
            "essential": essential,
            "pos": ((x0 + x1) / 2, (y0 + y1) / 2, (zz0 + zz1) / 2),
            "size": (x1 - x0, y1 - y0, zz1 - zz0),
        })
    if mirror:
        add("_N", z0, z1)
        add("_S", -z1, -z0)
    else:
        add("", z0, z1)


def ramp(name, start, end, width, thickness=2.0, color="ramp", mirror=False):
    """A sloped walkable slab from start (x, top y, z) to end; collision follows the slope."""
    def add(suffix, a, b):
        dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        horizontal = math.hypot(dx, dz)
        STATIC.append({
            "name": name + suffix, "kind": "ramp", "color": color, "visible": True, "skin": False,
            "essential": True, "run_faces": [],
            "yaw": math.degrees(math.atan2(-dx, -dz)), "pitch": math.degrees(math.atan2(dy, horizontal)),
            "pos": ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - thickness / 2, (a[2] + b[2]) / 2),
            "size": (width, thickness, math.hypot(horizontal, dy)),
            "slope": math.degrees(math.atan2(abs(dy), horizontal)),
            "start": a, "end": b, "thickness": thickness,
        })
    if mirror:
        add("_N", start, end)
        add("_S", mirror_z(start), mirror_z(end))
    else:
        add("", start, end)


def chunk(name, pos, size, stage, rubble="Large", shape="Block", yaw=0.0, pitch=0.0, roll=0.0, color=None):
    return {"name": name, "pos": pos, "size": size, "stage": stage, "rubble": rubble,
            "shape": shape, "yaw": yaw, "pitch": pitch, "roll": roll, "color": color}


def structure(sid, category, kind, material, health, stages, chunks, mirror=False, hazard=None, note=""):
    """category: Full | Partial | Landmark | Essential. Chunks with stage 0 never break."""
    def add(suffix, flip):
        cs = []
        for c in chunks:
            c2 = dict(c)
            if flip:
                c2["pos"] = mirror_z(c["pos"])
                c2["yaw"] = -c["yaw"]
                c2["pitch"] = -c["pitch"]
            cs.append(c2)
        DESTRUCTIBLES.append({"id": sid + suffix, "category": category, "kind": kind,
                              "material": material, "health": health, "stages": stages,
                              "chunks": cs, "hazard": hazard, "note": note})
    if mirror:
        add("_N", False)
        add("_S", True)
    else:
        add("", False)


def node(name, pos, mirror=False):
    if mirror:
        NODES[name + "_N"] = pos
        NODES[name + "_S"] = mirror_z(pos)
    else:
        NODES[name] = pos


def edge(a, b, kind, mirror=False, requires=(), opens=(), **params):
    """kind: walk | ramp | drop | jump | mantle | jumpmantle | climb | wallrun | tunnel.
    requires: destructible ids that must survive; opens: ids whose destruction opens it."""
    def add(sa, sb, req, opn):
        EDGES.append({"a": sa, "b": sb, "kind": kind, "requires": list(req), "opens": list(opn), **params})
    if mirror:
        add(a.replace("@", "_N"), b.replace("@", "_N"), [r.replace("@", "_N") for r in requires],
            [o.replace("@", "_N") for o in opens])
        add(a.replace("@", "_S"), b.replace("@", "_S"), [r.replace("@", "_S") for r in requires],
            [o.replace("@", "_S") for o in opens])
    else:
        add(a, b, requires, opens)


# --------------------------------------------------------------------------- essential base
box("Bedrock", -130, 130, -16, -10, -110, 110, kind="bedrock", skin=False)
# Lower floors (top 0). The sunken collapse (pit) and the east gully sit at -6.
box("FloorWest", X0, -24, -10, LOWER, Z0, Z1, kind="floor", color="lower", visible=True)
box("FloorCentre", -24, 24, -10, LOWER, Z0, -24, kind="floor", color="lower", visible=True, mirror=True)
box("FloorEastLane", 24, 54, -10, LOWER, Z0, -13.5, kind="floor", color="lower", visible=True, mirror=True)
# Pit floor sits 3 below the collapse level; runtime Terrain fills the last 3 studs so
# craters and sinkholes can be dug without ever reaching a bottomless hole.
box("PitBed", -24, 24, -10, PIT - 3, -24, 24, kind="floor", color="lower", visible=True)
box("Gully", 54, X1, -10, GULLY, -21, 21, kind="floor", color="lower", visible=True)
box("PassageFloor", 24, 54, -10, PIT, -5.25, 5.25, kind="floor", color="lower", visible=True)

# --------------------------------------------------------------------------- spawns (middle)
box("SpawnAlcove", -18, 18, -10, MIDDLE, Z0, -66, kind="shelf", color="middle", visible=True, mirror=True)
box("SpawnLip", -9, 9, MIDDLE, MIDDLE + 4.5, -68.25, -66, kind="cover", color="mass", mirror=True)
box("SpawnHood", -21, 21, MIDDLE + 13, MIDDLE + 18, Z0, -70.5, kind="mass", mirror=True)
ramp("SpawnRampWest", (-13.5, MIDDLE, -66), (-13.5, LOWER, -46.5), 9, mirror=True)
ramp("SpawnRampEast", (13.5, MIDDLE, -66), (13.5, LOWER, -46.5), 9, mirror=True)
box("WalkNorthWest", -60, -18, -10, MIDDLE, Z0, -72, kind="shelf", color="middle", visible=True, mirror=True)
box("WalkNorthEast", 18, 54, -10, MIDDLE, Z0, -72, kind="shelf", color="middle", visible=True, mirror=True)

# --------------------------------------------------------------------------- west: cliff run
# The cliff face (x = -87) is one long flat collision plane for reliable wall-running.
box("Cliff", -130, -87, -10, 60, Z0, -9, kind="cliff", color="cliff", run_faces=("east",), mirror=True)
box("CliffBehindShaft", -130, -96, -10, 60, -9, 9, kind="cliff", color="cliff")
box("CliffOverShaft", -96, -87, 30, 60, -9, 9, kind="cliff", color="cliff")
box("ShaftFace", -90, -87, 8, HIGH + 1, -9, 9, kind="cliff", color="cliff", run_faces=("east",))
box("ShelfNorthWest", -87, -60, -10, MIDDLE, Z0, -57, kind="shelf", color="middle", visible=True, mirror=True)
ramp("ShelfRampWest", (-70.5, MIDDLE, -57), (-70.5, LOWER, -37.5), 9, mirror=True)
# The Eyrie: a high ledge jutting from the cliff, the natural end of the wall-run. Two side
# legs carry it so the sealed shaft entrance below stays clear.
box("Eyrie", -87, -72, HIGH - 4, HIGH + 1, -12, 12, kind="ledge", color="high", visible=True)
box("EyrieLeg", -87, -82, LOWER, HIGH - 4, -12, -8.25, kind="mass", color="cliff", mirror=True)
# West abutment: the rock stack anchoring the high span, a fixed 12-stud jump from the Eyrie.
box("WestAbutment", -60, -48, -10, HIGH, -6, 6, kind="mass", color="column")

# --------------------------------------------------------------------------- centre: the collapse
# Monumental floor-to-ceiling columns screen each spawn from the centre.
box("Column", -9, 9, -10, CEILING + 6, -48, -30, kind="column", color="column", mirror=True)
# The keystone: a fallen monolith standing in the pit, carrying the high span.
box("Keystone", -6.75, 6.75, PIT - 3, HIGH, -6.75, 6.75, kind="landmark", color="column")
# High span from the abutment to the keystone; an 8-stud section in the middle can fall.
SPAN_MID = (-48 + -6.75) / 2
box("SpanWestEnd", -48, SPAN_MID - 4, HIGH - 3, HIGH, -5.25, 5.25, kind="bridge", color="high", visible=True)
box("SpanWestInner", SPAN_MID + 4, -6.75, HIGH - 3, HIGH, -5.25, 5.25, kind="bridge", color="high", visible=True)
box("SpanEast", 6.75, 36, HIGH - 3, HIGH, -5.25, 5.25, kind="bridge", color="high", visible=True)
box("EastLandingLeg", 28.5, 34.5, 6, HIGH - 3, -12, -6, kind="mass", color="column", mirror=True)
ramp("FallenSlab", (36, HIGH, -4.5), (60, MIDDLE, -27), 9, thickness=3.0, color="high", mirror=True)
ramp("PitRamp", (0, LOWER, -24), (0, PIT, -13.5), 12, mirror=True)
# The Hump: a raised mass east of the pit with the lower passage running through it.
box("HumpWest", 24, 30, -10, 6, -13.5, -5.25, kind="mass", mirror=True)
box("HumpEast", 45, 54, -10, 6, -13.5, -5.25, kind="mass", mirror=True)
box("HumpCore", 30, 45, -10, PIT, -13.5, -5.25, kind="mass", skin=False, mirror=True)
box("PassageRoofWest", 24, 30, 1, 6, -5.25, 5.25, kind="mass")
box("PassageRoofEast", 42, 54, 1, 6, -5.25, 5.25, kind="mass")

# --------------------------------------------------------------------------- east: shelves, bridge, spire
box("ShelfNorthEast", 54, X1, -10, MIDDLE, Z0, -21, kind="shelf", color="middle", visible=True, mirror=True)
ramp("GullyRamp", (66, GULLY, -17.25), (54.75, LOWER, -17.25), 7.5, mirror=True)
# Bridge ends reach to a fixed 12-stud centre (a sprint jump once it falls).
box("BridgeEnd", 69, 81, MIDDLE, MIDDLE + 2, -27, -6, kind="bridge", color="high", visible=True, mirror=True)
box("Spire", 87, 102, -10, HIGH, -7.5, 7.5, kind="landmark", color="column")
box("SpireStep", 90, 96, -10, MIDDLE + 4, -19.5, -13.5, kind="mass", color="column", mirror=True)

# --------------------------------------------------------------------------- boundary and roof
box("BoundaryNorth", -130, 130, -10, 70, -110, Z0, kind="boundary", color="boundary")
box("BoundarySouth", -130, 130, -10, 70, Z1, 110, kind="boundary", color="boundary")
box("BoundaryEast", X1, 130, -10, 70, Z0, Z1, kind="boundary", color="boundary")
box("RoofBacking", -130, 130, 72, 78, -110, 110, kind="roof", skin=False)

# --------------------------------------------------------------------------- destructibles
B, S, H = PALETTE["breakable"], PALETTE["shell"], PALETTE["hanging"]


# B. Progressive cover pillars (3 stages: chips, top, base).
def pillar(x, z, h=13.0):
    return [chunk("Cap", (x, h - 1.5, z), (4.4, 3.0, 4.2), 1, "Small", yaw=12, color=B),
            chunk("Upper", (x + 0.2, h - 5.0, z), (4.0, 4.0, 4.0), 2, yaw=-8, color=B),
            chunk("Middle", (x - 0.1, 4.75, z + 0.1), (4.4, 3.5, 4.4), 3, yaw=5, color=B),
            chunk("Base", (x, 1.5, z), (5.2, 3.0, 5.0), 3, yaw=-14, color=B)]


structure("PillarWest", "Full", "Pillar", "Stone", 150, 3, pillar(-45, -36), mirror=True,
          note="Progressive cover in the west lane; breaking it opens the lane to the Eyrie.")
structure("PillarEast", "Full", "Pillar", "Stone", 150, 3, pillar(37.5, -45), mirror=True)
structure("PillarCentre", "Full", "Pillar", "Stone", 150, 3, pillar(-20, -36), mirror=True,
          note="Cover between the spawn ramps and the collapse.")

# A. Loose boulders: fully destructible, a single strong hit or a few weak ones.
structure("BoulderWest", "Full", "Boulder", "Loose", 60, 1,
          [chunk("Rock", (-58.5, 2.0, -15), (5.0, 4.0, 4.6), 1, "Small", yaw=27, pitch=6, color=B)], mirror=True)
structure("BoulderLane", "Full", "Boulder", "Loose", 60, 1,
          [chunk("Rock", (45, 1.8, -28.5), (4.4, 3.6, 5.0), 1, "Small", yaw=-18, roll=7, color=B)], mirror=True)
structure("BoulderPit", "Full", "Boulder", "Loose", 70, 2,
          [chunk("Top", (12, PIT + 4.6, -15), (3.6, 2.4, 3.4), 1, "Small", yaw=30, color=B),
           chunk("Bottom", (12, PIT + 1.7, -15), (4.6, 3.4, 4.4), 2, "Small", yaw=-10, color=B)], mirror=True)


# D. Suspended formations: telegraphed falls onto the high positions below them.
def hanging(x, z, bottom):
    return [chunk("Neck", (x, CEILING - 4, z), (5.0, 8.0, 5.0), 1, yaw=10, color=H),
            chunk("Body", (x + 0.3, bottom + 9.5, z - 0.2), (6.4, 9.0, 6.0), 1, yaw=-15, color=H),
            chunk("Tip", (x - 0.2, bottom + 2.5, z + 0.2), (4.0, 5.0, 3.8), 1, yaw=22, color=H)]


HAZARD = {"radius": 9.0, "damage": 45.0, "warning": 1.3}
structure("HangingEyrie", "Partial", "Hanging", "Stone", 100, 1, hanging(-79.5, 0, 34), hazard=HAZARD,
          note="Drops onto the Eyrie; lands as cover on the ledge.")
structure("HangingKeystone", "Partial", "Hanging", "Stone", 100, 1, hanging(0, 0, 36), hazard=HAZARD,
          note="Drops onto the keystone top in the middle of the high span.")
structure("HangingBridge", "Partial", "Hanging", "Stone", 100, 1, hanging(75, 0, 34), hazard=HAZARD,
          note="Drops onto the east bridge; if the bridge is gone it lands in the gully.")

# C. Natural bridges: sections that fall as rubble, never the only route.
structure("BridgeCentre", "Partial", "Bridge", "Stone", 140, 2,
          [chunk("SlabNorth", (75, MIDDLE + 1, -3), (12.0, 2.0, 6.0), 1, yaw=2, color=B),
           chunk("SlabMiddle", (75, MIDDLE + 1, 0.5), (12.0, 2.0, 1.4), 2, color=B),
           chunk("SlabSouth", (75, MIDDLE + 1, 3.6), (12.0, 2.0, 4.8), 2, yaw=-2, color=B)],
          note="12-stud centre of the east bridge; the gap left is a sprint jump, rubble lands in the gully.")
structure("SpanWest", "Partial", "Bridge", "Stone", 140, 2,
          [chunk("SlabWest", (SPAN_MID - 2, HIGH - 1.5, 0), (4.0, 3.0, 10.5), 1, color=B),
           chunk("SlabEast", (SPAN_MID + 2, HIGH - 1.5, 0), (4.0, 3.0, 10.5), 2, color=B)],
          note="8-stud section of the high span between the west abutment and the keystone.")
structure("PassageRoof", "Partial", "Roof", "Stone", 120, 2,
          [chunk("RoofWest", (33, 3.5, 0), (6.0, 5.0, 10.5), 1, "Small", color=B),
           chunk("RoofEast", (39, 3.5, 0), (6.0, 5.0, 10.5), 2, "Small", color=B)],
          note="Breaking it from above exposes anyone holding the lower passage.")

# E. Breakable seal: reveals the climbing shaft inside the cliff up to the Eyrie.
structure("ShaftSeal", "Partial", "Wall", "Slab", 160, 3,
          [chunk("Upper", (-88.5, 6.5, 0), (3.0, 3.0, 18.0), 1, "Small", color=PALETTE["seal"]),
           chunk("Left", (-88.5, 2.5, -5.25), (3.0, 5.0, 7.5), 2, "Small", color=PALETTE["seal"]),
           chunk("Right", (-88.5, 2.5, 5.25), (3.0, 5.0, 7.5), 3, "Small", color=PALETTE["seal"]),
           chunk("Plug", (-88.5, 2.5, 0), (3.0, 5.0, 3.0), 3, "Small", color=PALETTE["seal"])],
          note="Thin slab: penetrating impacts are strongest against it.")


# G. Protected landmarks: outer slabs break, structural cores (static boxes above) remain.
def column_shell(z):
    return [chunk("SlabNorthLow", (0, 6, z - 9.9), (12.0, 9.0, 1.8), 1, color=S),
            chunk("SlabEastHigh", (9.9, 18, z), (1.8, 10.0, 12.0), 2, color=S),
            chunk("SlabWestLow", (-9.9, 7, z), (1.8, 11.0, 10.5), 2, color=S),
            chunk("SlabSouthHigh", (0, 20, z + 9.9), (10.5, 8.0, 1.8), 3, color=S)]


structure("ColumnShell", "Landmark", "Shell", "Hardrock", 260, 3, column_shell(-39), mirror=True,
          note="Outer slabs only: falling slabs become cover around the column's base.")
structure("KeystoneShell", "Landmark", "Shell", "Hardrock", 260, 3,
          [chunk("SlabNorth", (0, PIT + 6, -7.65), (10.5, 10.0, 1.8), 1, color=S),
           chunk("SlabSouth", (0, PIT + 6, 7.65), (10.5, 10.0, 1.8), 1, color=S),
           chunk("SlabWest", (-7.65, 12, 0), (1.8, 9.0, 10.5), 2, color=S),
           chunk("SlabEast", (7.65, 12, 0), (1.8, 9.0, 10.5), 3, color=S)])
structure("EyrieLip", "Full", "Cover", "Stone", 90, 2,
          [chunk("LipNorth", (-72.8, HIGH + 2.4, -6.75), (1.6, 2.8, 7.5), 1, "Small", yaw=6, color=B),
           chunk("LipSouth", (-72.8, HIGH + 2.4, 6.75), (1.6, 2.8, 7.5), 2, "Small", yaw=-6, color=B)],
          note="Low cover on the Eyrie edge: breaking it exposes the high ground.")

# F. Terrain: excavatable earth over protected bedrock (filled at runtime by the server).
TERRAIN.extend([
    {"id": "PitFloor", "kind": "Crater", "min": (-24, PIT - 3, -24), "max": (24, PIT, 24),
     "note": "Craters and sinkholes in the collapse, never deeper than the bed 3 studs down."},
    {"id": "HumpWall_N", "kind": "Tunnel", "min": (30, PIT, -13.5), "max": (45, 6, -5.25),
     "note": "Dig from the lane or the passage to open a side window or a new exit."},
    {"id": "HumpWall_S", "kind": "Tunnel", "min": (30, PIT, 5.25), "max": (45, 6, 13.5)},
    {"id": "MoundNorth", "kind": "Mound", "min": (-49.5, LOWER, -54), "max": (-34.5, LOWER + 3.5, -45),
     "note": "Loose earth cover in the west lane that can be dug away."},
    {"id": "MoundSouth", "kind": "Mound", "min": (-49.5, LOWER, 45), "max": (-34.5, LOWER + 3.5, 54)},
])

# --------------------------------------------------------------------------- decor (skins only)
for i, (x, z, length, radius) in enumerate([(-36, -40, 9, 2.4), (32, -34, 11, 2.8), (-14, -36, 7, 2.0),
                                            (44, -30, 8, 2.2), (-44, 18, 10, 2.6), (16, 40, 9, 2.4),
                                            (-20, 44, 7, 2.0), (56, 36, 10, 2.6), (24, -8, 8, 2.2),
                                            (-60, -10, 9, 2.4), (62, 10, 8, 2.2)]):
    DECOR.append({"name": f"Stalactite{i}", "type": "stalactite", "pos": (x * K, CEILING, z * K),
                  "length": length, "radius": radius})
# Ceiling slabs leave holes for shafts of daylight (sun at ClockTime 14).
DECOR.append({"name": "Ceiling", "type": "ceiling", "y": CEILING,
              "holes": [(-51, -27, 10), (45, 33, 9), (9, -66, 8), (-12, 45, 8), (60, -45, 8)]})

# --------------------------------------------------------------------------- route graph
node("Spawn", (0, MIDDLE, -75), mirror=True)
node("CentreLower", (0, LOWER, -45), mirror=True)
node("WestLane", (-45, LOWER, -30), mirror=True)
node("Trench", (-76, LOWER, -36), mirror=True)
node("ShelfW", (-75, MIDDLE, -69), mirror=True)
node("ShelfE", (78, MIDDLE, -51), mirror=True)
node("EastLane", (36, LOWER, -45), mirror=True)
node("Pit", (0, PIT, 0))
node("Passage", (36, PIT, 0))
node("Gully", (69, GULLY, 0))
node("Hump", (36, 6, -9), mirror=True)
node("Eyrie", (-79.5, HIGH + 1, 0))
node("Shaft", (-93, LOWER, 0))
node("WestAbutment", (-54, HIGH, 0))
node("Keystone", (0, HIGH, 0))
node("SpanEast", (27, HIGH, 0))
node("Spire", (94.5, HIGH, 0))
node("BridgeTop", (75, MIDDLE + 2, 0))

edge("Spawn@", "CentreLower@", "ramp", mirror=True, slope=27.1)
edge("Spawn@", "ShelfW@", "walk", mirror=True)
edge("Spawn@", "ShelfE@", "walk", mirror=True)
edge("Spawn@", "CentreLower@", "drop", mirror=True, height=10)
edge("CentreLower@", "WestLane@", "walk", mirror=True)
edge("CentreLower@", "EastLane@", "walk", mirror=True)
edge("CentreLower@", "Pit", "ramp", mirror=True, slope=29.7)
edge("CentreLower@", "Pit", "jumpmantle", mirror=True, rise=6)
edge("WestLane@", "Trench@", "walk", mirror=True)
edge("WestLane@", "Pit", "jumpmantle", mirror=True, rise=6)
edge("ShelfW@", "Trench@", "ramp", mirror=True, slope=27.1)
edge("ShelfW@", "Eyrie", "wallrun", mirror=True, length=45, climb=11)
edge("Trench@", "Eyrie", "climb", mirror=True, rise=21)
edge("Trench@", "Shaft", "tunnel", opens=["ShaftSeal"], mirror=True)
edge("Shaft", "Eyrie", "climb", rise=21)
edge("Eyrie", "WestAbutment", "jump", gap=12, drop=1)
edge("WestAbutment", "Keystone", "walk", requires=["SpanWest"])
edge("WestAbutment", "Keystone", "jump", opens=["SpanWest"], gap=8)
edge("Keystone", "SpanEast", "walk")
edge("Keystone", "Pit", "drop", height=26)
edge("Pit", "Keystone", "climb", rise=26)
edge("SpanEast", "ShelfE@", "ramp", mirror=True, slope=16.9)
edge("Pit", "Passage", "walk")
edge("Passage", "Gully", "walk")
edge("Hump@", "Passage", "drop", opens=["PassageRoof"], mirror=True, height=7)
edge("EastLane@", "Passage", "tunnel", opens=["HumpWall@"], mirror=True)
edge("EastLane@", "Hump@", "jumpmantle", mirror=True, rise=6)
edge("EastLane@", "Gully", "ramp", mirror=True, slope=28.1)
edge("ShelfE@", "Gully", "drop", mirror=True, height=16)
edge("ShelfE@", "BridgeTop", "walk", mirror=True)
edge("ShelfE@", "Spire", "jumpmantle", mirror=True, rise=6, gap=6, via="SpireStep")
edge("Gully", "Spire", "climb", rise=26)
edge("BridgeTop", "Gully", "drop", height=18)
edge("WestLane@", "EastLane@", "walk", mirror=True, via="CentreLower")
# The bridge joins the two east shelves only while its centre stands; afterwards the gully,
# a 12-stud sprint jump across the gap, or the spire do.
edge("ShelfE_N", "ShelfE_S", "walk", requires=["BridgeCentre"], via="BridgeTop")
edge("ShelfE_N", "ShelfE_S", "jump", opens=["BridgeCentre"], gap=12, skill=True)
