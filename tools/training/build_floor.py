"""Authored training floor: painted rock, stations, runestones and dummy, from experiments/training/shared/floor.json.

blender -b --factory-startup --python tools/training/build_floor.py [-- --preview]
Everything lands in ignored build/training/floor. Each mesh gets a matching inverted ink shell (<name>_Ink).
Layout is in Roblox studs relative to the arena origin; Blender has x'=x, y'=-z, z'=y.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"build/training/floor"
OUT.mkdir(parents=True, exist_ok=True)
FLOOR = json.loads((ROOT/"experiments/training/shared/floor.json").read_text())
RIM = json.loads((ROOT/"experiments/lobby/scale/shared/rim_shape.json").read_text())["rock"]
# The floor repeats a painted tile this many studs across. One image over the whole island came out near 3 pixels a stud
# once Roblox capped it at 1024 (owner, 2026-11-03: "the resolution's horrible"); a tile gives about 21.
FLOOR_TILE = 48
TILE = 16  # the stone texture repeats every this many studs
INK_RGB = (0.055, 0.055, 0.07)
MOSS = np.array((0.36, 0.47, 0.33))
rng = np.random.default_rng(90210)
PARTS = {}
COL = None


def smooth_noise(size, scale, seed):
    """Periodic soft noise in 0..1, so the stone tile repeats without a seam."""
    r = np.random.default_rng(seed)
    fx, fy = np.fft.fftfreq(size)[None, :], np.fft.fftfreq(size)[:, None]
    falloff = np.exp(-(fx**2+fy**2)*(size/scale)**2)
    field = np.fft.ifft2(np.fft.fft2(r.normal(size=(size, size)))*falloff).real
    return (field-field.min())/(field.max()-field.min())


def ink_lines(image, count, seed, width, reach, wander=0.5):
    """Hand-inked fractures: wandering tapered strokes."""
    r = np.random.default_rng(seed)
    size = image.shape[0]
    for _ in range(count):
        x, y = r.uniform(0, size, 2)
        angle = r.uniform(0, math.tau)
        steps = int(r.uniform(0.5, 1)*reach*2)
        for step in range(steps):
            angle += r.uniform(-wander, wander)*0.5
            x, y = x+math.cos(angle)*1.5, y+math.sin(angle)*1.5
            w = max(1, int(width*math.sin(math.pi*(step+1)/(steps+1))))
            xi, yi = np.ogrid[-w:w+1, -w:w+1]
            mask = xi*xi+yi*yi <= w*w
            rows = (np.arange(-w, w+1)+int(y)) % size
            cols = (np.arange(-w, w+1)+int(x)) % size
            area = np.ix_(rows, cols)
            image[area] = np.where(mask[..., None], INK_RGB, image[area])


# Matched to the spawn island's painted stone. The first paint was about 2.5 times as bright and crossed the lobby's bloom
# threshold, so the whole arena glowed (owner, 2026-11-03).
ROCK, SHADOW = (0.40, 0.40, 0.45), (0.32, 0.32, 0.37)


def base_rock(size, contrast, seed):
    big, mid = smooth_noise(size, 14, seed), smooth_noise(size, 60, seed+1)
    grain = smooth_noise(size, size/3, seed+2)
    shade = (0.55*big+0.3*mid+0.15*grain-0.5)*contrast
    rock, shadow = np.array(ROCK), np.array(SHADOW)
    mix = np.clip(big*1.6-0.3, 0, 1)[..., None]
    return np.clip(shadow*(1-mix)+rock*mix+shade[..., None]*0.2, 0, 1)


def save_png(pixels, name):
    size = pixels.shape[0]
    rgba = np.ones((size, size, 4), "f4")
    rgba[..., :3] = pixels[::-1]  # Blender's row 0 is the bottom
    image = bpy.data.images.new(name, size, size, alpha=False)
    image.colorspace_settings.name = "Non-Color"  # painted in display colour
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(OUT/f"{name}.png")
    image.file_format = "PNG"
    image.save()
    return image


def stone_tile():
    """Stone with a mossy top: V=0 is an object's top, and it runs down its sides."""
    size = 1024
    pix = base_rock(size, 1.0, 11)
    ink_lines(pix, 7, 12, 3, 60, 0.3)
    v = np.linspace(0, 1, size)[:, None]
    edge = 0.035+0.04*smooth_noise(size, 30, 13)
    moss = np.clip((edge-v)*30, 0, 1)[..., None]
    pix = pix*(1-moss)+(MOSS*(0.78+0.4*smooth_noise(size, 80, 14))[..., None])*moss
    lip = np.clip(1-np.abs(v-edge)*90, 0, 1)[..., None]*0.45
    return save_png(pix*(1-lip)+np.array((0.13, 0.17, 0.13))*lip, "training-stone")


def rune_paint():
    """The cut stone of the grove's entrance runestones: dark blue-grey, faint grain and a few fine cracks, no moss."""
    size = 1024
    big, mid, grain = smooth_noise(size, 10, 41), smooth_noise(size, 48, 42), smooth_noise(size, size/3, 43)
    g = np.clip(0.6*big+0.3*mid+0.1*grain, 0, 1)[..., None]
    dark, light = np.array((0.25, 0.25, 0.31)), np.array((0.45, 0.46, 0.54))
    pix = dark*(1-g)+light*g
    ink_lines(pix, 5, 44, 2, 50, 0.35)
    return save_png(np.clip(pix, 0, 1), "training-rune")


def glyph_paint():
    """Near-white with a faint brush grain. The game tints it and uses it as its own glow mask, like the lobby's symbols."""
    size = 256
    pix = np.ones((size, size, 3))*(0.9+0.1*smooth_noise(size, 12, 51))[..., None]
    return save_png(pix, "training-glyph")


def floor_paint():
    """Plain rock with drifts of moss all over, as one seamless tile (owner: more moss on the floor, a bit more texture).
    No marks: the stations say what they are."""
    size = 1024
    pix = base_rock(size, 1.2, 21)*0.86
    ink_lines(pix, 4, 22, 2, 70, 0.4)
    patches, edge = smooth_noise(size, 5, 33), smooth_noise(size, 36, 34)
    moss = np.clip((0.78*patches+0.22*edge-0.5)*7, 0, 1)[..., None]
    speck = (0.8+0.4*smooth_noise(size, 140, 35))[..., None]
    pix = pix*(1-moss)+(MOSS*0.72*speck)*moss
    return save_png(np.clip(pix, 0, 1), "training-floor")


# ---- Meshes ----

BOX_FACES = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]


def add(name, verts, faces, klass, uv=None, inward=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if inward:  # an ink shell shows only its far side
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    data.shade_smooth()
    layer = data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        for li in poly.loop_indices:
            co = data.vertices[data.loops[li].vertex_index].co
            layer.data[li].uv = uv(co, poly.normal) if uv else (0.5, 0.5)
    obj = bpy.data.objects.new(name, data)
    COL.objects.link(obj)
    points = [v.co for v in data.vertices]
    lo = [min(c[i] for c in points) for i in range(3)]
    hi = [max(c[i] for c in points) for i in range(3)]
    PARTS[name] = {"class": klass, "min": [lo[0], lo[2], -hi[1]], "max": [hi[0], hi[2], -lo[1]]}
    return obj


def stone_uv(top_z, height, cy, depth):
    # The tile holds one moss edge, so V must never wrap: a tall wall takes a larger tile rather than a second green band.
    tile = max(TILE, height*1.02)

    def uv(co, normal):
        # The moss comes out at V near 1 once in Roblox. Tops are bare rock, from the tile's moss-free middle.
        if abs(normal.z) > 0.7:
            return (co.x/tile, 0.2+0.6*((co.y-cy)/max(depth, 0.1)+0.5))
        along = co.x if abs(normal.y) > abs(normal.x) else co.y
        return (along/tile, 1-(top_z-co.z)/tile)
    return uv


def box_grid(counts):
    verts, faces, index = [], [], {}
    nx, ny, nz = counts

    def vid(i, j, k):
        key = (i, j, k)
        if key not in index:
            index[key] = len(verts)
            verts.append((2*i/nx-1, 2*j/ny-1, 2*k/nz-1))
        return index[key]
    for a in range(nx):
        for b in range(ny):
            faces.append((vid(a, b, 0), vid(a, b+1, 0), vid(a+1, b+1, 0), vid(a+1, b, 0)))
            faces.append((vid(a, b, nz), vid(a+1, b, nz), vid(a+1, b+1, nz), vid(a, b+1, nz)))
    for a in range(nx):
        for c in range(nz):
            faces.append((vid(a, 0, c), vid(a+1, 0, c), vid(a+1, 0, c+1), vid(a, 0, c+1)))
            faces.append((vid(a, ny, c), vid(a, ny, c+1), vid(a+1, ny, c+1), vid(a+1, ny, c)))
    for b in range(ny):
        for c in range(nz):
            faces.append((vid(0, b, c), vid(0, b, c+1), vid(0, b+1, c+1), vid(0, b+1, c)))
            faces.append((vid(nx, b, c), vid(nx, b+1, c), vid(nx, b+1, c+1), vid(nx, b, c+1)))
    return verts, faces


def rounded(name, center, size, klass, radius=0.5, wobble=0.14, taper=0.0, ink=0.13, stone=True):
    """A chunky rounded block on a grid. Its ink shell is the same shape, grown, so corners never gap."""
    cx, cy, cz = center
    half = Vector(size)/2
    counts = [max(2, min(22, int(s/1.1))) for s in size]
    grid, faces = box_grid(counts)
    r = min(radius, min(size)/2-0.02)
    inner = Vector((half.x-r, half.y-r, half.z-r))
    seed = float(rng.uniform(0, 100))

    def shape(grow):
        out = []
        for g in grid:
            p = Vector((g[0]*half.x, g[1]*half.y, g[2]*half.z))
            core = Vector((max(-inner.x, min(inner.x, p.x)), max(-inner.y, min(inner.y, p.y)), max(-inner.z, min(inner.z, p.z))))
            off = p-core
            n = off.normalized() if off.length > 1e-6 else Vector((0, 0, 1))
            q = core+n*(r+grow)
            # Sides wander; tops stay nearly flat, so feet match the collision box.
            amount = wobble*(0.25 if abs(n.z) > 0.7 else 1)
            wave = math.sin(p.x*0.9+seed)+math.sin(p.y*1.1+seed*1.7)+math.sin(p.z*0.8+seed*0.6)
            q += n*amount*wave/3
            if taper:
                shrink = 1-taper*(p.z/half.z+1)/2
                q.x, q.y = q.x*shrink, q.y*shrink
            out.append((cx+q.x, cy+q.y, cz+q.z))
        return out

    add(name, shape(0), faces, klass, stone_uv(cz+half.z, size[2], cy, size[1]) if stone else None)
    if ink:
        add(name+"_Ink", shape(ink), faces, "ink", inward=True)


def block(name, x, z, size, klass="stone", base=0.0, **kw):
    """Layout box: size is Roblox (x, height, z), standing on base."""
    rounded(name, (x, -z, base+size[1]/2), (size[0], size[2], size[1]), klass, **kw)


def floor_mesh():
    s = FLOOR["island"]["scale"]
    n = len(RIM)
    points = [(math.sin(i*math.tau/n)*r*s, math.cos(i*math.tau/n)*r*s) for i, r in enumerate(RIM)]
    verts = [(0.0, 0.0, 0.03)]+[(x, y, 0.03) for x, y in points]
    faces = [(0, 1+i, 1+(i+1) % n) for i in range(n)]
    add("Floor", verts, faces, "floor", lambda co, _n: (co.x/FLOOR_TILE, co.y/FLOOR_TILE))


def cut_stone(name, x, z, w, d, h, yaw=0.0, slant=0.12, klass="rune", ink=0.12):
    """A standing stone cut like the grove's entrance runes: wider at the shoulder than the foot, a slanted top and
    one back corner sliced off, so no two faces are square. Returns its frame for whatever is carved on it."""
    grid, faces = box_grid((6, 4, max(4, int(h/1.2))))
    c, s = math.cos(yaw), math.sin(yaw)
    seed = float(rng.uniform(0, 100))

    def side(height):
        return 1.0-0.16*(1.0-height/h)

    def local(lx, ly, lz):
        return (x+lx*c-ly*s, -z+lx*s+ly*c, lz)

    def shape(grow):
        out = []
        for g in grid:
            lz = (g[2]+1)/2*h
            k = side(lz)
            lx, ly = g[0]*(w/2)*k, g[1]*(d/2)*k
            # The back corner on the +x side is sliced at 45 degrees.
            over = lx/(w/2*k)+ly/(d/2*k)-1.25
            if over > 0:
                lx, ly = lx-over*w/4*k, ly-over*d/4*k
            # Sunk a little, with the top sloping across.
            lz = lz*(h+slant*lx)/h-0.4
            wobble = 0.05*math.sin(lx*1.3+seed)*math.sin(lz*0.9+seed*0.7)
            out.append(local(lx+(math.copysign(grow+wobble, g[0]) if abs(g[0]) == 1 else 0),
                             ly+(math.copysign(grow, g[1]) if abs(g[1]) == 1 else 0),  # broad faces stay flat for carving
                             lz+(grow if g[2] == 1 else 0)))
        return out

    add(name, shape(0), faces, klass, lambda co, n: ((co.x+co.y)/8, co.z/8))
    if ink:
        add(name+"_Ink", shape(ink), faces, "ink", inward=True)
    return {"local": local, "side": side, "d": d, "h": h}


GLYPH_W = 0.5  # stroke width in symbol units


# One wing, the right, in symbol units: a solid base with four rounded feathers fanning up and out, longest on top.
# The left is its mirror (owner: wings rather than a runner).
WING_ROOT = (0.26, 0.12)
FEATHERS = [(40, 2.2), (24, 1.92), (8, 1.6), (-9, 1.26)]  # degrees above level, length
WING_BASE = [(0.22, 0.42), (1.2, 1.12), (1.3, 0.02), (0.22, -0.14)]


def glyph_shapes(kind, grow):
    """Each symbol as filled shapes in symbol units: polygons, capsules, rings and discs. `grow` thickens them all,
    for the painted edge that sits under the glow."""
    w = GLYPH_W+grow
    if kind == "Move":
        shapes = [("disc", (0, 0.12), 0.36+grow/2)]
        for side in (1, -1):
            rx, ry = WING_ROOT
            for degrees, length in FEATHERS:
                a = math.radians(degrees)
                shapes.append(("cap", (side*rx, ry), (side*(rx+math.cos(a)*length), ry+math.sin(a)*length), w*0.92))
            base = [(side*(x+grow*0.3*(1 if x > 0.5 else 0)), y+grow*0.3*(1 if y > 0.2 else -1)) for x, y in WING_BASE]
            shapes.append(("poly", base if side > 0 else list(reversed(base))))
        return shapes
    ticks = [("cap", (math.cos(a)*1.62, math.sin(a)*1.62), (math.cos(a)*2.1, math.sin(a)*2.1), w*0.7) for a in (0, math.pi/2, math.pi, 1.5*math.pi)]
    return [("ring", (0, 0), 1.3-w*0.26-grow/2, 1.3+w*0.26+grow/2), ("disc", (0, 0), 0.48+grow/2)]+ticks


def outline(shape):
    if shape[0] == "poly":
        return [list(shape[1])]
    if shape[0] == "disc":
        (cx, cy), r = shape[1], shape[2]
        return [[(cx+math.cos(i*math.tau/28)*r, cy+math.sin(i*math.tau/28)*r) for i in range(28)]]
    if shape[0] == "cap":
        (ax, ay), (bx, by), w = shape[1], shape[2], shape[3]
        ang = math.atan2(by-ay, bx-ax)
        pts = [(bx+math.cos(ang-math.pi/2+i*math.pi/10)*w/2, by+math.sin(ang-math.pi/2+i*math.pi/10)*w/2) for i in range(11)]
        pts += [(ax+math.cos(ang+math.pi/2+i*math.pi/10)*w/2, ay+math.sin(ang+math.pi/2+i*math.pi/10)*w/2) for i in range(11)]
        return [pts]
    (cx, cy), r0, r1 = shape[1], shape[2], shape[3]
    return [[(cx+math.cos(i*math.tau/40)*r, cy+math.sin(i*math.tau/40)*r) for i in range(40)] for r in (r1, r0)]


def carve(name, kind, stone, height, scale, klass, face):
    """A flush, filled glowing symbol on one broad face (face -1 is toward Roblox +Z), with a fine painted edge just
    under it, as the lobby's gateway symbols are made. Mirrored on the far face, so the runner leads the same way."""
    for layer, grow, proud, cls in (("Edge", 0.2, 0.06, "edge"+kind), ("", 0.0, 0.11, klass)):
        verts, faces = [], []
        face_y = face*(stone["d"]/2*stone["side"](height))
        for shape in glyph_shapes(kind, grow):
            loops = outline(shape)
            base = len(verts)
            for depth in (face_y-face*0.02, face_y+face*proud):
                for loop in loops:
                    verts.extend(stone["local"](u*scale*face, depth, height+v*scale) for u, v in loop)
            n = len(loops[0])
            if len(loops) == 1:
                faces.append(tuple(base+i for i in range(n)))
                faces.append(tuple(base+n+i for i in reversed(range(n))))
                faces.extend((base+i, base+(i+1) % n, base+n+(i+1) % n, base+n+i) for i in range(n))
            else:
                outer0, inner0, outer1, inner1 = base, base+n, base+2*n, base+3*n
                for i in range(n):
                    j = (i+1) % n
                    faces += [(outer0+i, outer0+j, inner0+j, inner0+i), (outer1+i, inner1+i, inner1+j, outer1+j),
                              (outer0+i, outer1+i, outer1+j, outer0+j), (inner0+i, inner0+j, inner1+j, inner1+i)]
        add(f"{name}{layer}", verts, faces, cls)


def runestone(kind, spec):
    """A pair of standing stones either side of the way in, like the slug grove's entrance, the symbol on both faces."""
    for i, (x, z) in enumerate(spec["stones"]):
        h = 11.5 if i == 0 else 9.6
        turn = (0.12 if i == 0 else -0.1)*(1 if x > 0 else -1)
        stone = cut_stone(f"Rune{kind}{i}", x, z, 6.4, 3.4, h, yaw=turn, slant=0.14 if i == 0 else -0.14)
        for face, tag in ((-1, "A"), (1, "B")):
            # Small, as the grove's slug mark is: about a third of the stone's width (owner: they looked too big).
            carve(f"Rune{kind}{i}Glyph{tag}", kind, stone, h*0.64, 0.62 if kind == "Move" else 0.5, "glow"+kind, face)


def dummy():
    """One training dummy at the origin, feet on 0. The server clones it per lane."""
    block("DummyBase", 0, 0, (4.6, 0.7, 4.6), radius=0.3, wobble=0.05)
    rounded("DummyLeg", (0, 0, 1.9), (1.0, 0.9, 2.6), "wood", radius=0.25, wobble=0.04, stone=False)
    rounded("DummyTorso", (0, 0, 4.2), (2.6, 1.5, 2.4), "sack", radius=0.55, wobble=0.07, stone=False)
    rounded("DummyArms", (0, 0, 4.7), (5.6, 0.8, 0.8), "wood", radius=0.25, wobble=0.04, stone=False)
    rounded("DummyHead", (0, 0, 6.3), (1.7, 1.5, 1.6), "sack", radius=0.6, wobble=0.05, stone=False)
    count = 28
    for r, klass, tag in ((0.92, "ink", "A"), (0.66, "bone", "B"), (0.3, "ink", "C")):
        back, front = -0.8-(0.92-r)*0.08, -0.84-(0.92-r)*0.08  # Blender -Y is Roblox +Z, toward the firing line
        verts = [(math.cos(i*math.tau/count)*r, depth, 4.2+math.sin(i*math.tau/count)*r) for depth in (back, front) for i in range(count)]
        verts += [(0.0, back, 4.2), (0.0, front, 4.2)]
        faces = []
        for i in range(count):
            j = (i+1) % count
            faces += [(i, j, count+j, count+i), (count*2, j, i), (count*2+1, count+i, count+j)]
        add(f"DummyRing{tag}", verts, faces, klass)


def station():
    """The dummy settings: a low cut stone in the runes' style, the target mark glowing on the side you walk up to."""
    x, z = FLOOR["station"]["at"]
    stone = cut_stone("Station", x, z, 5.2, 3.0, 4.6, slant=-0.16)
    carve("StationGlyph", "Target", stone, 2.7, 0.36, "glowTarget", -1)


def stations():
    course, shooting = FLOOR["course"], FLOOR["range"]
    for group in ("vaults", "mantles", "jumps"):
        for i, item in enumerate(course[group]):
            block(f"Course_{group}{i}", item["x"], item["z"], item["size"], radius=0.42 if group == "vaults" else 0.55)
    for group in ("wallRun", "climb"):
        for i, item in enumerate(course[group]):
            block(f"Course_{group}{i}", item["x"], item["z"], item["size"], radius=0.6, wobble=0.1)
    # The slide lane: a long clear run between two low kerbs.
    lane = course["slideLane"]
    for i, side in enumerate((-1, 1)):
        block(f"Course_curb{i}", lane["x"], lane["z"]+side*lane["width"]/2, (lane["length"], 0.5, 1.2), radius=0.2, wobble=0.04)
    z0 = shooting["firingZ"]
    line = shooting["line"]
    block("Range_line", (line["from"]+line["to"])/2, line["z"], (line["to"]-line["from"], 0.3, 1.0), radius=0.14, wobble=0.03)
    for i, item in enumerate(shooting["cover"]):
        block(f"Range_cover{i}", item["x"], item["z"], item["size"], radius=0.5)
    for i, item in enumerate(shooting["raised"]):
        block(f"Range_raised{i}", item["x"], z0-item["distance"], (10, item["height"], 10), radius=0.6, wobble=0.15)
    station()


def preview():
    scene = bpy.context.scene
    scene.world = scene.world or bpy.data.worlds.new("w")
    scene.world.use_nodes = True
    next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.008, 0.009, 0.013, 1)
    colors = {"stone": None, "floor": None, "rune": None, "ink": (0.004, 0.004, 0.006), "iron": (0.09, 0.09, 0.1), "wood": (0.2, 0.1, 0.05), "sack": (0.45, 0.33, 0.16),
              "bone": (0.8, 0.77, 0.66), "glowMove": (0.42, 0.8, 0.7), "glowTarget": (0.9, 0.55, 0.25), "edgeMove": (0.02, 0.2, 0.17), "edgeTarget": (0.3, 0.09, 0.01)}
    mats = {}
    for klass, color in colors.items():
        m = bpy.data.materials.new(klass)
        m.use_nodes = True
        shader = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Roughness"].default_value = 0.9
        if color is None:
            tex = m.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images[{"stone": "training-stone", "rune": "training-rune"}.get(klass, "training-floor")]
            m.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        else:
            shader.inputs["Base Color"].default_value = (*color, 1)
            if klass.startswith("glow"):
                shader.inputs["Emission Color"].default_value = (*color, 1)
                shader.inputs["Emission Strength"].default_value = 3
        m.use_backface_culling = True
        mats[klass] = m
    for obj in list(COL.objects):
        obj.data.materials.append(mats[PARTS[obj.name]["class"]])
    # Show the dummy on each lane for judging size.
    z0 = FLOOR["range"]["firingZ"]
    originals = [o for o in COL.objects if o.name.startswith("Dummy")]
    for lane in FLOOR["range"]["still"]+FLOOR["range"]["moving"]+FLOOR["range"]["raised"]:
        for obj in originals:
            copy = obj.copy()
            copy.location = (lane["x"], -(z0-lane["distance"]), lane.get("height", 0))
            COL.objects.link(copy)
    for name, loc, energy in (("a", (-50, 30, 90), 110000), ("b", (50, -30, 90), 110000), ("c", (0, 70, 60), 50000), ("d", (0, -150, 50), 90000)):
        light = bpy.data.lights.new(name, "POINT")
        light.energy, light.color = energy, (0.92, 0.94, 1)
        lamp = bpy.data.objects.new(name, light)
        COL.objects.link(lamp)
        lamp.location = loc
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    COL.objects.link(cam)
    scene.camera, cam.data.clip_end = cam, 2000
    scene.render.resolution_x, scene.render.resolution_y = 1100, 800
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 16
    for view, loc, aim, lens in (("top", (0, 0, 250), (0, 0, 0), 38), ("three", (40, -150, 85), (0, 0, 0), 38), ("eye", (70, -84, 5.5), (80, 30, 3), 30), ("course", (-20, -100, 9), (-80, 20, 4), 30), ("runes", (0, -128, 6), (0, -88, 6), 32), ("rune-close", (-22, -106, 7), (-16, -92, 6.6), 50), ("station", (52, -92, 5), (60, -82, 3), 40)):
        cam.location, cam.data.lens = loc, lens
        cam.rotation_euler = (Vector(aim)-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT/f"preview-{view}.png")
        bpy.ops.render.render(write_still=True)


def main():
    global COL
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    COL = bpy.context.scene.collection
    stone_tile()
    rune_paint()
    glyph_paint()
    floor_paint()
    floor_mesh()
    stations()
    for kind, spec in FLOOR["runes"].items():
        runestone(kind, spec)
    dummy()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/"training-authored.glb"), export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_animations=False, export_cameras=False, export_lights=False, export_materials="NONE")
    (OUT/"floor-layout.json").write_text(json.dumps({"authored": PARTS}, indent=1))
    print("TRAINING_FLOOR", len(meshes), "meshes", sum(len(o.data.polygons) for o in meshes), "triangles", flush=True)
    if "--preview" in sys.argv:
        preview()


if __name__ == "__main__":
    main()
