"""Build Inferno's two forms in Blender 1:1 from the approved concept (docs/slugs/catalog/evidence/inferno/inferno.html).

Ports the concept's shape and colour functions to NumPy, meshes them with surface nets, reduces to a game mesh with a
high-density face island, bakes colour, glow, normal and occlusion, rigs each form and exports for Roblox.

Face rig, as on Floppy: each eye is its own mesh set behind the skin, and the upper lid is the skin itself, skinned to a lid
bone that stretches it down over the eye. He never blinks; anger furrows the lids. The mouth is one skinned mesh whose lips
morph from the grin to the gritted shape, so nothing fades or is swapped. The outline is a Highlight in Roblox, not an inverted hull. Run with Blender 4.5:

`blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/slugs/build_inferno.py`

Writes assets/source/slugs/models/inferno/inferno-{base,dragon}.blend and ignored build/slugs/inferno/{base,dragon}/:
model.glb, textures/, review renders and export-report.json. Nothing is uploaded. Concept coordinates are y-up with the
face toward +z; Blender gets (x, -z, y). Motion is authored at runtime (experiments/creatures/inferno/client).
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_floppy as bf
import export_floppy_roblox as ef
from common import ROOT
from build_floppy import gradient, mix, sd_bezier, sd_ell, smax, smin, smoothstep, surface_nets, to_blender

SOURCE = ROOT/"assets/source/slugs/models/inferno"
BUILD = ROOT/"build/slugs/inferno"
TEXTURE = 1024
GAME_SCALE = 0.4218  # the base form matches Floppy's game size (owner, 2026-11-02): about 1.06 tall and 0.69 wide
FACE_DENSITY = 3.0  # face texels relative to the rest of the body, so the eyes and grin stay sharp
SKIN_ROUGHNESS = 0.2
MOUTH_BONES = 9  # across each lip
MOUTH_PROUD = 0.012
REST_ENCODE = 0.18  # rest positions are baked as p*REST_ENCODE + 0.5
EYE_RECESS = 0.075  # how far the socket goes in behind the skin
EYE_INSET = 0.035  # how far the eye sits behind the skin: in front of the socket floor, behind the lid
LID_REACH = 0.16  # how far up the skin stretches with the lid
FLAME_LENGTH, FLAME_BACK = 1.9, 0.45  # the concept's flame, a little bigger (owner), and how far up the tail it starts
FACE_KEEP = 0.0006  # decimate edge-length cost around the eyes and mouth; small, since quadric costs are tiny

ORANGE = np.array([0.800, 0.170, 0.022])
RED = np.array([0.420, 0.038, 0.016])
AMBER = np.array([0.930, 0.480, 0.060])
INK = np.array([0.060, 0.010, 0.008])
FACE_LINE = np.array([0.24, 0.035, 0.014])  # eye and smile lines: deep red, since black ones read as scratches
MOLTEN = np.array([1.000, 0.300, 0.040])
HOT = np.array([1.000, 0.680, 0.220])
DEEP = np.array([0.620, 0.075, 0.010])
TEETH = np.array([1.0, 0.94, 0.80])
TEETH_SHADE = np.array([0.34, 0.11, 0.06])
LID_SLOPE = 0.14
EYE_DIM = np.array([0.25, 0.150, 0.03])
REST_TIME = 2.0  # the concept's uT in its turntable frames


def fract(x):
    return x - np.floor(x)


def normalize(v):
    v = np.asarray(v, float)
    return v/np.linalg.norm(v)


def cap(p, a, b, ra, rb):
    a, b = np.asarray(a, float), np.asarray(b, float)
    pa, ba = p - a, b - a
    h = np.clip((pa @ ba)/np.dot(ba, ba), 0.0, 1.0)
    return np.linalg.norm(pa - ba*h[:, None], axis=1) - (ra + (rb - ra)*h)


def seg2(p, a, b, ra, rb):
    a, b = np.asarray(a, float), np.asarray(b, float)
    pa, ba = p - a, b - a
    h = np.clip((pa @ ba)/np.dot(ba, ba), 0.0, 1.0)
    return np.linalg.norm(pa - ba*h[:, None], axis=1) - (ra + (rb - ra)*h)


class Form:
    """The shared face maths; each form supplies its eye placement, grin and ear settings."""
    name = ""
    recess = EYE_RECESS
    inset = EYE_INSET
    lip_band = 0.73  # where the grey band under the top lip starts, up the mouth
    carve = 0.0  # no grin hollow in the surface: the body under the mouth patches is clean skin
    grin_on = False  # whether colours include the painted grin; the body never does, only its patch
    grin_tilt = 0.20
    grin = (0.0, 0.0)
    hook = (0.335, 0.085)
    corner_end = 0.29
    eye_centre_xyz = (0.0, 0.0, 0.0)
    eye_axis_xyz = (0.0, 0.0, 1.0)

    def roughness(self, p):
        return np.full(len(p), SKIN_ROUGHNESS)

    def eye_centre(self, s):
        x, y, z = self.eye_centre_xyz
        return np.array([s*x, y, z])

    def eye_axes(self, s):
        x, y, z = self.eye_axis_xyz
        ax = normalize([s*x, y, z])
        u = normalize(np.cross([0.0, 1.0, 0.0], ax))
        return u, np.cross(ax, u), ax

    def eye_local(self, p, s):
        u, w, ax = self.eye_axes(s)
        q = p - self.eye_centre(s)
        return np.stack([q @ u, q @ w, q @ ax], -1)

    def almond(self, p, s):
        l = self.eye_local(p, s)
        x = l[:, 0]/EYE_DIM[0]
        power = np.where(s*x > 0.0, 0.40, 0.38)
        a = np.maximum(1.0 - x*x, 0.0)**power
        y = l[:, 1] - LID_SLOPE*s*l[:, 0]
        top = 0.096 if s < 0 else 0.138
        return np.maximum(np.maximum(y - top*a, -0.126*a - y), (np.abs(x) - 1.0)*EYE_DIM[0])

    def eye_colour(self, p, s):
        l = self.eye_local(p, s)
        r = np.linalg.norm((l[:, :2] - [0.0, 0.004])/EYE_DIM[1], axis=1)
        c = mix(np.array([1.0, 0.80, 0.36])[None], HOT[None], smoothstep(0.0, 0.45, r))
        c = mix(c, MOLTEN[None], smoothstep(0.45, 1.1, r))
        rays = 1.0 - 0.14*(0.5 + 0.5*np.sin(np.arctan2(l[:, 1], l[:, 0])*13.0))*smoothstep(0.35, 0.8, r)
        return mix(c*rays[:, None], DEEP[None], smoothstep(1.1, 1.75, r))

    def grin_coord(self, q):
        x = q[:, 0] - self.grin[0]
        return np.stack([x, q[:, 1] - self.grin[1] - self.grin_tilt*x], -1)

    @staticmethod
    def grin_top(x):
        return 0.40*x*x

    @staticmethod
    def grin_bottom(x):
        return np.where(x < 0.0, -0.095 + 1.53*x*x, -0.095 + 18.2*x*x*x*x)

    def grin_dist(self, q):
        g = self.grin_coord(q)
        x, y = g[:, 0], g[:, 1]
        return np.maximum(np.maximum(y - self.grin_top(x), self.grin_bottom(x) - y), np.abs(x) - 0.29)

    def paint_grin(self, col, q, gate):
        if not self.grin_on:
            return col
        gd = self.grin_dist(q)
        g = self.grin_coord(q)
        x, y = g[:, 0], g[:, 1]
        inside = (1.0 - smoothstep(-0.003, 0.003, gd))*gate
        depth = self.grin_top(x) - y
        shade = 1.0 - smoothstep(0.008, 0.020, depth - 0.010*(x + 0.29))
        col = mix(col, RED[None], (1.0 - smoothstep(0.0, 0.016, gd))*(1.0 - inside)*0.6*gate)
        corner = smoothstep(0.13, self.corner_end, np.abs(x))
        teeth = mix(TEETH[None], TEETH_SHADE[None], np.maximum(shade, 0.85*corner))
        col = col*(1.0 - inside[:, None]) + teeth*inside[:, None]
        below = (1.0 - inside)*(1.0 - smoothstep(0.0, 0.05, gd))*(y <= 0.0)*gate
        col = col*(1.0 - (below*0.8)[:, None]) + col*np.array([0.72, 0.52, 0.45])*(below*0.8)[:, None]
        tap = 1.0 - smoothstep(-0.30, 0.36, np.abs(x))
        crease = np.abs(y - self.grin_top(x)) - 0.002 - 0.011*tap
        crease = np.maximum(crease, np.abs(x) - 0.30)
        crease = np.minimum(crease, seg2(g, (0.285, 0.033), self.hook, 0.007, 0.0015))
        crease = np.minimum(crease, seg2(g, (-0.285, 0.033), (-0.33, 0.047), 0.006, 0.0015))
        return mix(col, FACE_LINE[None], (1.0 - smoothstep(0.0, 0.005, crease))*gate)

    def eye_patch(self, s):
        """An eye: a sheet following the head just behind the skin. Returns its grid of points and local coordinates."""
        u, w, ax = self.eye_axes(s)
        centre = self.eye_centre(s)
        columns, rows = 32, 22
        lx, ly = np.meshgrid(np.linspace(-0.31, 0.31, columns + 1), np.linspace(-0.21, 0.21, rows + 1), indexing="ij")
        lx, ly = lx.ravel(), ly.ravel()
        q = centre + lx[:, None]*u + ly[:, None]*w + ax*0.25
        recess, self.recess = self.recess, 0.0
        for _ in range(60):
            q = q - ax*(np.clip(self.rest_skin(q), -0.05, 0.05)*0.7)[:, None]
        hit = np.abs(self.rest_skin(q)) < 0.02
        self.recess = recess
        # Beyond the opening the sheet dives into the head, so on a curved face it can never come out through the skin.
        beyond = np.maximum(self.almond(q, s), 0.0)
        q = q - ax*(self.inset + beyond*1.2)[:, None]
        # Rays that miss the head stay deep inside it.
        q = np.where(hit[:, None], q, centre + lx[:, None]*u + ly[:, None]*w - ax*0.2)
        return self.to_world(q), columns, rows, lx, ly

    def rest_skin(self, q):
        return self.skin(q)

    def to_world(self, q):
        return q

    def face_keep(self, p):
        """1 around the eyes, whose skin has to stay dense to stretch cleanly."""
        q = self.undeform(p)
        keep = np.zeros(len(q))
        for s in (-1.0, 1.0):
            keep = np.maximum(keep, 1.0 - smoothstep(0.0, LID_REACH + 0.04, self.almond(q, s)))
        return keep*self.face_gate(q)

    def undeform(self, p):
        return p

    def face_space(self, q):
        return q

    def lid_weights(self, w, q):
        """Skin above each eye follows its lid bone: fully at the rim, fading up the forehead, anchored at the corners."""
        gate = self.face_gate(q)
        for s, tag in ((-1.0, "L"), (1.0, "R")):
            l = self.eye_local(q, s)
            over = l[:, 1] - LID_SLOPE*s*l[:, 0]
            above = smoothstep(-0.02, 0.03, over)
            reach = 1.0 - smoothstep(0.0, LID_REACH, np.maximum(self.almond(q, s), 0.0))
            corners = 1.0 - smoothstep(EYE_DIM[0]*0.8, EYE_DIM[0]*1.3, np.abs(l[:, 0]))
            on = above*reach*corners*gate*(l[:, 2] > -0.2)
            for key in w:
                w[key] = w[key]*(1.0 - on)
            w["lid_" + tag] = on

    def mouth_outlines(self, t):
        """Lip positions at t in -1..1: (x, top y, bottom y) for the grin and for the gritted mouth."""
        offset = self.grit["centre"][1] - (self.grin[1] + 0.02) if self.name == "dragon" else 0.0
        gx, gy = self.grin
        x = 0.29*t
        smile = (gx + x, gy + offset + self.grin_tilt*x + self.grin_top(x), gy + offset + self.grin_tilt*x + self.grin_bottom(x))
        cx, cy = self.grit["centre"]
        half = self.grit["half"]
        r = half*t
        line = cy + 0.03 - 1.25*r*r
        h = 0.016 + 0.058*np.sqrt(np.maximum(1.0 - t*t, 0.0))
        return smile, (cx + r, line + h, line - h)

    def fit(self, x, y, proud):
        """Points on the face, a little in front of the skin."""
        x, y = np.asarray(x, float), np.asarray(y, float)
        points = np.stack([x, y, np.full(x.shape, self.grit["start"])], -1)
        for _ in range(90):
            points[:, 2] -= np.clip(self.rest_skin(points), -0.05, 0.05)*0.7
        hit = np.abs(self.rest_skin(points)) < 0.02
        points[:, 2] = np.where(hit, points[:, 2], np.median(points[hit, 2]))
        points[:, 2] += proud
        return self.to_world(points)

    def mouth_rig(self):
        """Each lip bone's rest position (the grin) and how far it moves to reach the gritted mouth."""
        if hasattr(self, "_mouth_rig"):
            return self._mouth_rig
        t = np.linspace(-1.0, 1.0, MOUTH_BONES)
        smile, frown = self.mouth_outlines(t)
        rig = {}
        for tag, index in (("t", 1), ("b", 2)):
            rest = self.fit(smile[0], smile[index], MOUTH_PROUD)
            target = self.fit(frown[0], frown[index], MOUTH_PROUD)
            for k in range(MOUTH_BONES):
                rig[f"mouth_{tag}{k}"] = (rest[k], target[k] - rest[k])
        # The ink's tails: up off the corners of the grin, down off the corners of the gritted mouth.
        for side, name, k in ((-1.0, "mouth_tail_L", 0), (1.0, "mouth_tail_R", MOUTH_BONES - 1)):
            rest = self.fit([smile[0][k] + side*0.05], [smile[1][k] + 0.055], MOUTH_PROUD)[0]
            target = self.fit([frown[0][k] + side*0.05], [frown[2][k] - 0.05], MOUTH_PROUD)[0]
            rig[name] = (rest, target - rest)
        self._mouth_rig = rig
        return rig

    def face_bones(self, parent="head"):
        out = []
        for s, tag in ((-1.0, "L"), (1.0, "R")):
            pivot = self.to_world(self.eye_centre(s)[None])[0]
            out.append(("lid_" + tag, tuple(to_blender(pivot)), tuple(to_blender(pivot + self.eye_axes(s)[2]*0.1)), parent))
        for name, (rest, _) in self.mouth_rig().items():
            out.append((name, tuple(to_blender(rest)), tuple(to_blender(rest + np.array([0.0, 0.05, 0.0]))), parent))
        return out

    @staticmethod
    def ember_mask(em):
        ember = (em[:, 0]/0.058)**1.25 + (np.abs(em[:, 1])/np.where(em[:, 1] > 0.0, 0.088, 0.066))**1.25
        spark = seg2(em, (0.098, -0.030), (0.128, 0.034), 0.017, 0.003)
        return np.maximum(1.0 - smoothstep(0.90, 1.0, ember), 1.0 - smoothstep(0.0, 0.004, spark))


class Base(Form):
    name = "base"
    grit = dict(centre=(0.02, 1.2), half=0.27, rect=((-0.42, 0.46), (1.0, 1.38)), start=1.2)
    grin = (0.02, 1.18)
    grin_tilt = 0.20
    hook = (0.335, 0.085)
    corner_end = 0.29
    eye_centre_xyz = (0.36, 1.625, 0.57)
    eye_axis_xyz = (0.42, -0.04, 1.0)
    ear_flat = np.array([1.0, 1.0, 1.9])
    bounds = ((-1.1, 1.1), (-0.03, 2.9), (-1.2, 1.0))
    step = 0.008
    high_triangles = 240000
    body_triangles = 12000
    LEAN = 0.14

    def deform(self, p):
        p = p.copy()
        p[:, 2] -= self.LEAN*smoothstep(0.3, 1.9, p[:, 1])
        return p

    def antenna(self, s):
        t = REST_TIME*1.6 + s*1.3
        mid = math.sin(t - 0.6)*0.025
        end = math.sin(t - 1.4)*0.07 + 0.025*math.sin(t*2.3)
        return np.array([s*0.36, 1.90, 0.0]), np.array([s*0.50, 2.66 + mid, -0.12]), np.array([s*(0.80 + end*0.4), 2.32 + end, -0.68 + end*0.4])

    def ear_dist(self, p, s):
        A, B, C = self.antenna(s)
        return sd_bezier(p*self.ear_flat, A*self.ear_flat, B*self.ear_flat, C*self.ear_flat)

    @staticmethod
    def lobes(th, phase):
        return 1.0 + 0.06*np.sin(3.0*th + 0.7 + phase) + 0.04*np.sin(5.0*th - 1.3 + phase*0.6)

    def skin_rest(self, p):
        """skin() on the concept's un-leaned space."""
        x, y, z = p[:, 0], p[:, 1], p[:, 2]
        q = p - np.array([0.0, 0.0, -0.02])
        th = np.arctan2(q[:, 2], q[:, 0])
        k = self.lobes(th, 0.0)
        d = sd_ell(np.stack([q[:, 0]/k, q[:, 1] - 0.24, q[:, 2]/k], -1), np.array([0.56, 0.30, 0.58]))*np.minimum(k, 1.0)
        d = smin(d, sd_ell(p - [0.0, 0.80, 0.02], np.array([0.45, 0.70, 0.42])), 0.42)
        d = smin(d, sd_ell(p - [0.0, 1.20, 0.02], np.array([0.51, 0.52, 0.45])), 0.25)
        k2 = self.lobes(th, 1.4)
        d = smin(d, sd_ell(np.stack([q[:, 0]/k2, q[:, 1] - 0.02, q[:, 2]/k2], -1), np.array([0.67, 0.06, 0.69]))*np.minimum(k2, 1.0), 0.28)
        d = smin(d, sd_ell(p - [0.0, 1.70, 0.10], np.array([0.66, 0.36, 0.56])), 0.16)
        d = smin(d, sd_ell(p - [0.0, 1.38, 0.24], np.array([0.50, 0.32, 0.38])), 0.32)
        d = smin(d, sd_ell(p - [0.0, 1.80, 0.02], np.array([0.58, 0.40, 0.50])), 0.22)
        d = smin(d, cap(p, (0.0, 0.10, -0.50), (0.0, 0.05, -1.00), 0.20, 0.02), 0.18)
        pr = np.stack([x*2.4, y, z], -1)
        for a, b, ra in (((0.0, 1.72, -0.38), (0.0, 1.86, -0.70), 0.13), ((0.0, 1.30, -0.36), (0.0, 1.42, -0.68), 0.13),
                         ((0.0, 0.92, -0.38), (0.0, 1.00, -0.68), 0.12), ((0.0, 0.54, -0.45), (0.0, 0.60, -0.73), 0.11)):
            d = smin(d, cap(pr, a, b, ra, 0.015)/2.4, 0.07)
        front = z > 0.0
        for s in (-1.0, 1.0):
            ad = self.almond(p, s)
            le = self.eye_local(p, s)
            above = smoothstep(-0.03, 0.03, le[:, 1] - LID_SLOPE*s*le[:, 0])
            fade = smoothstep(-0.21, -0.08, s*le[:, 0])
            outer = 1.0 - smoothstep(0.08, 0.17, s*le[:, 0])
            roll = (ad - 0.040)/0.040
            under = (ad - 0.022)/0.022
            socket = (p[:, :2] - [s*0.36, 1.625])/np.array([0.32, 0.22])
            d = d + front*(-above*fade*outer*(0.030 if s < 0 else 0.022)*np.exp(-roll*roll)
                           - 0.006*(1.0 - above)*fade*outer*np.exp(-under*under)
                           + self.recess*(1.0 - smoothstep(-0.03, 0.006, ad))
                           + 0.012*np.exp(-np.sum(socket*socket, axis=1)))
            dist, t = self.ear_dist(p, s)
            d = smin(d, (dist - (0.19 + (0.022 - 0.19)*t**0.8))/1.9, 0.10)
            d = smin(d, np.linalg.norm(p - self.antenna(s)[2], axis=1) - 0.018, 0.02)
        hi, lo = p[:, :2] - [0.34, 1.28], p[:, :2] - [-0.29, 1.155]
        mid = (p[:, :2] - [0.0, 1.80])/np.array([0.05, 0.11])
        d = d + (z > 0.2)*self.carve*(0.030*(1.0 - smoothstep(-0.016, 0.010, self.grin_dist(p))) + 0.016*np.exp(-np.sum(hi*hi, axis=1)/0.0014)
                           + 0.009*np.exp(-np.sum(lo*lo, axis=1)/0.0012) + 0.008*np.exp(-np.sum(mid*mid, axis=1)))
        # The sole: soft rolls with narrow creases, like Floppy's, so a backflip shows something worth seeing.
        return smax(d, -y + 0.012*(1.0 - self.sole_fold(x, z)), 0.07)

    @staticmethod
    def sole_fold(x, z):
        wander = 0.05*np.sin(x*5.1 + 0.6) + 0.025*np.sin(x*11.3 + z*2.0)
        return np.abs(np.sin((z + wander)*np.pi/0.2))**0.6

    def skin(self, p):
        return self.skin_rest(self.deform(p))

    def rest_skin(self, q):
        return self.skin_rest(q)

    def undeform(self, p):
        return self.deform(p)

    def to_world(self, q):
        q = q.copy()
        q[:, 2] += self.LEAN*smoothstep(0.3, 1.9, q[:, 1])
        return q

    @staticmethod
    def face_gate(q):
        return (q[:, 2] > 0.2)*1.0

    @staticmethod
    def ink_free(q, facing):
        return (q[:, 1] > 0.98) & (facing > 0.2)

    def mouth_bone_at(self, xy):
        return self.to_world(np.array([[xy[0], xy[1], 0.56]]))[0]

    def albedo(self, p):
        dp = self.deform(p)
        x, y, z = dp[:, 0], dp[:, 1], dp[:, 2]
        ax = np.abs(x)
        n = len(dp)
        col = np.tile(ORANGE, (n, 1))
        glow = np.zeros((n, 3))
        pale = smoothstep(0.10, 0.40, z + 0.10*smoothstep(0.5, 0.0, ax))*smoothstep(1.02, 0.72, y)*smoothstep(0.42, 0.12, ax)
        col = mix(col, AMBER[None], pale*0.72)
        wob = 0.05*np.sin(y*7.0 + x*5.0)
        col = mix(col, RED[None], smoothstep(0.10, -0.35, z + wob)*0.35*smoothstep(1.56, 1.38, y))
        around = np.arctan2(ax, -z)
        sv = y*3.3 + around*0.42
        width = 0.33*(1.0 - smoothstep(0.1, 2.5, around))
        fs = np.abs(fract(sv) - 0.5)
        band = smoothstep(0.14, 0.26, y)*smoothstep(1.62, 1.46, y)
        stripe = (1.0 - smoothstep(width - 0.05, width + 0.02, fs))*band*(np.floor(sv) <= 4.5)
        col = mix(col, RED[None], stripe*(1.0 - pale)*smoothstep(2.3, 1.95, around))
        em = np.stack([ax, y - 1.93], -1)/1.3
        col = mix(col, RED[None]*0.8, self.ember_mask(em)*(z > 0.05))
        for s in (-1.0, 1.0):
            dist, t = self.ear_dist(dp, s)
            on_ear = (1.0 - smoothstep(0.26, 0.40, dist))*smoothstep(0.04, 0.16, t)
            col = mix(col, RED[None], on_ear*smoothstep(0.15, 0.55, t))
            tip = on_ear*smoothstep(0.55, 1.0, t)
            col = mix(col, AMBER[None], tip)
            glow += mix(MOLTEN[None], HOT[None], np.full(n, 0.5))*(tip*tip)[:, None]
            col, glow = paint_eye(self, col, glow, dp, s, z > 0.1, 0.006, 0.014, s < 0, (-0.03, 0.09), True)
        edge = smoothstep(width - 0.05, width, fs)*(1.0 - smoothstep(width, width + 0.03, fs))
        col = mix(col, RED[None]*0.6, edge*(fract(sv) <= 0.5)*band*(1.0 - pale)*0.7*smoothstep(2.0, 1.5, around))
        col = mix(col, AMBER[None], smoothstep(-0.52, -0.66, z)*smoothstep(0.42, 0.50, y)*0.85)
        col = mix(col, RED[None], smoothstep(-0.62, -0.92, z)*(1.0 - smoothstep(0.20, 0.30, y))*0.8)
        col = mix(col, RED[None], (1.0 - smoothstep(0.03, 0.12, y))*0.42)
        fu = np.stack([around*3.4, y*8.5], -1)
        fid = np.floor(fu)
        fh = fract(np.sin(fid @ np.array([127.1, 311.7]))*43758.5453)
        fleck = (fh >= 0.58)*(1.0 - smoothstep(0.09, 0.15, np.linalg.norm(fract(fu) - 0.5 - ((fh - 0.79)*0.6)[:, None], axis=1)))
        col = mix(col, RED[None], fleck*smoothstep(1.42, 1.56, y)*smoothstep(0.08, -0.08, z)*(1.0 - smoothstep(2.05, 2.25, y))*0.55)
        sk = (np.stack([ax, y], -1) - [0.36, 1.625])/np.array([0.34, 0.24])
        jaw = smoothstep(0.95, 1.05, y)*smoothstep(1.12, 1.06, y)*smoothstep(0.55, 0.20, ax)
        amount = np.maximum(0.42*np.exp(-np.sum(sk*sk, axis=1)*1.1), 0.45*jaw)*(z > 0.1)
        col = col*(1.0 - amount[:, None]) + col*np.array([0.74, 0.56, 0.50])*amount[:, None]
        col = self.paint_grin(col, dp, (z > 0.2)*1.0)
        nz = dp[:, :2] + [0.0, 0.05]
        fr = np.full(n, 9.0)
        for c in ((-0.135, 1.455), (-0.078, 1.505), (-0.055, 1.425), (0.012, 1.475), (0.068, 1.430), (0.092, 1.505), (0.148, 1.450)):
            fr = np.minimum(fr, np.linalg.norm(nz - c, axis=1))
        col = mix(col, RED[None], (1.0 - smoothstep(0.011, 0.017, fr))*0.62*(z > 0.3))
        sq = np.stack([ax, y], -1)
        dots = np.full(n, 9.0)
        for c in ((0.53, 1.40), (0.58, 1.34), (0.50, 1.32)):
            dots = np.minimum(dots, np.linalg.norm(sq - c, axis=1))
        col = mix(col, RED[None], (1.0 - smoothstep(0.012, 0.018, dots))*0.55*(z > 0.1))
        sole = smoothstep(0.03, 0.012, y)
        painted = mix(ORANGE[None], AMBER[None], np.full(n, 0.35))*(0.72 + 0.33*self.sole_fold(x, z))[:, None]
        col = col*(1.0 - sole[:, None]) + painted*sole[:, None]
        return col, glow

    def face_region(self, p, n):
        dp = self.deform(p)
        return (n[:, 2] > 0.3) & (dp[:, 2] > 0.2) & (dp[:, 1] > 1.02) & (dp[:, 1] < 2.1) & (np.abs(dp[:, 0]) < 0.66)

    def bones(self):
        def b(v):
            return tuple(to_blender(np.array(v, float)))
        out = [("root", b((0, 0, 0)), b((0, 0.3, 0)), None),
               ("body_lower", b((0, 0.05, 0)), b((0, 0.6, 0)), "root"),
               ("body_upper", b((0, 0.6, 0)), b((0, 1.05, 0.04)), "body_lower"),
               ("head", b((0, 1.05, 0.04)), b((0, 1.9, 0.10)), "body_upper")]
        for s, tag in ((-1.0, "L"), (1.0, "R")):
            A, B, C = self.antenna(s)
            A, B, C = A + [0, 0, self.lean_at(A[1])], B + [0, 0, self.lean_at(B[1])], C + [0, 0, self.lean_at(C[1])]
            mid = 0.25*A + 0.5*B + 0.25*C
            out.append(("antenna_" + tag, tuple(to_blender(A)), tuple(to_blender(mid)), "head"))
            out.append(("antenna_tip_" + tag, tuple(to_blender(mid)), tuple(to_blender(C)), "antenna_" + tag))
        return out + self.face_bones()

    def lean_at(self, y):
        t = float(np.clip((y - 0.3)/1.6, 0.0, 1.0))
        return self.LEAN*t*t*(3 - 2*t)

    def weights(self, p):
        dp = self.deform(p)
        y = dp[:, 1]
        head = smoothstep(0.76, 1.06, y)
        upper = smoothstep(0.30, 0.78, y)*(1.0 - head)
        w = {"body_lower": 1.0 - head - upper, "body_upper": upper, "head": head}
        for s, tag in ((-1.0, "L"), (1.0, "R")):
            dist, t = self.ear_dist(dp, s)
            on = (1.0 - smoothstep(0.20, 0.32, dist))*smoothstep(0.05, 0.28, t)*(y > 1.85)
            for key in w:
                w[key] = w[key]*(1.0 - on)
            tip = smoothstep(0.35, 0.65, t)
            w["antenna_" + tag] = on*(1.0 - tip)
            w["antenna_tip_" + tag] = on*tip
        self.lid_weights(w, dp)
        return w


class Dragon(Form):
    name = "dragon"
    # His eyes face further outward, so from the front the inner socket wall shows: keep it shallow.
    recess = 0.045
    inset = 0.02
    lip_band = 0.86
    grit = dict(centre=(0.02, 1.055), half=0.25, rect=((-0.34, 0.38), (0.86, 1.28)), start=2.3)
    grin = (0.02, -0.145)
    grin_tilt = 0.15
    hook = (0.315, 0.062)
    corner_end = 0.27
    eye_centre_xyz = (0.29, 1.32, 1.45)
    eye_axis_xyz = (0.59, 0.28, 0.76)
    bounds = ((-2.4, 2.4), (-0.3, 2.75), (-2.9, 1.85))
    step = 0.009
    high_triangles = 360000
    body_triangles = 20000
    SPAN = 2.35
    ROOT_W = np.array([0.36, 0.04, 0.62])
    S = np.array([0.782, 0.501, -0.371])
    C = np.array([-0.188, -0.377, -0.907])
    N = np.array([-0.593, 0.777, -0.200])
    TAIL_Z = -1.9

    @staticmethod
    def face_gate(q):
        return (q[:, 2] > 0.75)*1.0

    @staticmethod
    def ink_free(q, facing):
        return facing > 0.12

    @staticmethod
    def face_space(q):
        return q - np.array([0.0, 1.2, 0.0])

    def mouth_bone_at(self, xy):
        return np.array([xy[0], xy[1] + 1.2, 1.5])

    @staticmethod
    def spine_c(z):
        w = smoothstep(0.6, -0.8, z)
        return np.stack([0.40*np.sin(z*1.35 + 0.4)*w, 0.30*np.sin(z*1.05 + 1.2)*w - 0.42*smoothstep(0.7, -0.5, z)], -1)

    @staticmethod
    def body_r(z):
        return 0.09 + (0.50 - 0.09)*smoothstep(-1.9, -0.3, z)

    def antenna(self, s):
        end = math.sin(REST_TIME*2.4 + s*1.3 - 1.2)*0.05
        return np.array([s*0.30, 1.54, 0.74]), np.array([s*0.56, 2.20, 0.34]), np.array([s*(0.84 + end*0.5), 2.14 + end, -0.60])

    def ear_dist(self, p, s):
        k = np.array([1.0, 1.7, 1.0])
        A, B, C = self.antenna(s)
        return sd_bezier(p*k, A*k, B*k, C*k)

    @staticmethod
    def trail(t):
        return 1.50*np.maximum(1.0 - t, 0.0)**0.62 - 0.17*np.abs(np.sin(t*9.42478))*(1.0 - 0.3*t)

    def uvn(self, a):
        q = np.stack([np.abs(a[:, 0]), a[:, 1], a[:, 2]], -1) - self.ROOT_W
        u = q @ self.S
        t = np.clip(u/self.SPAN, 0.0, 1.0)
        return np.stack([u, q @ self.C, q @ self.N - 0.06*np.sin(t*3.14159)], -1)

    def wing_point(self, t, v):
        return self.ROOT_W + self.S*(t*self.SPAN) + self.C*v + self.N*(0.06*math.sin(t*3.14159))

    def outline(self, uvn):
        t = np.clip(uvn[:, 0]/self.SPAN, 0.0, 1.0)
        return np.maximum(np.maximum(-uvn[:, 1], uvn[:, 1] - self.trail(t)), np.maximum(-uvn[:, 0], uvn[:, 0] - self.SPAN))

    def belly(self, a):
        """Folds across the pale underside, like the base form's sole. Returns the mask and the fold, 1 on each roll."""
        z = a[:, 2]
        q = a[:, :2] - self.spine_c(z)
        around = np.arctan2(np.abs(q[:, 0]), q[:, 1])
        mask = smoothstep(2.0, 2.45, around)*smoothstep(0.72, 0.5, z)*smoothstep(-1.3, -1.0, z)
        wander = 0.035*np.sin(a[:, 0]*6.0 + 0.6) + 0.018*np.sin(a[:, 0]*13.0 + z*2.0)
        return mask, np.abs(np.sin((z + wander)*np.pi/0.15))**0.6

    # Behind the shoulders the body, and the tail most of all, are shorter than the concept (owner). The body's maths stays
    # in concept lengths; points are converted on the way in, and the head, wings and flame are left at full size.
    SHOULDER, TAIL_ROOT = 0.3, -0.5  # concept z
    BODY_LENGTH, TAIL_LENGTH = 0.8, 0.5
    TAIL_ROOT_NOW = SHOULDER + (TAIL_ROOT - SHOULDER)*BODY_LENGTH

    @staticmethod
    def shortened(z):
        """A concept z along the body, as it now stands."""
        d = Dragon
        return np.where(z >= d.SHOULDER, z, np.where(z >= d.TAIL_ROOT, d.SHOULDER + (z - d.SHOULDER)*d.BODY_LENGTH, d.TAIL_ROOT_NOW + (z - d.TAIL_ROOT)*d.TAIL_LENGTH))

    @staticmethod
    def concept_length(a):
        """Points as they now stand, in the concept's lengths."""
        d = Dragon
        z = a[:, 2]
        z = np.where(z >= d.SHOULDER, z, np.where(z >= d.TAIL_ROOT_NOW, d.SHOULDER + (z - d.SHOULDER)/d.BODY_LENGTH, d.TAIL_ROOT + (z - d.TAIL_ROOT_NOW)/d.TAIL_LENGTH))
        return np.stack([a[:, 0], a[:, 1], z], -1)

    @staticmethod
    def flame_frame():
        """The tail tip and the axes of the fire leaving it: along the tail, sideways and up."""
        c = Dragon.spine_c(np.array([-1.9]))[0]
        along = normalize([0.35, -0.25, -1.0])
        side = normalize(np.cross(along, [0.0, 1.0, 0.0]))
        return np.array([c[0], c[1], float(Dragon.shortened(np.array(-1.9)))]), along, side, np.cross(side, along)

    def flame(self, a):
        """The approved concept's flame as a surface: one teardrop with rolling lobes and a long point. Returns its signed
        distance, how far along it each point lies, the angle round it and the lobes, -1 in a groove and 1 on a ridge."""
        tip, along, side, up = self.flame_frame()
        q = a - tip
        l = q @ along
        at = np.clip((l + FLAME_BACK)/FLAME_LENGTH, 0.0, 1.0)
        # The sway grows towards the end of the flame.
        qs, qu = q @ side + 0.07*at*np.sin(at*5.0), q @ up + 0.05*at*np.sin(at*4.0 + 1.4)
        ang = np.arctan2(qu, qs)
        first, second = np.sin(ang*3.0 + at*4.0), np.sin(ang*5.0 - at*7.0 + 0.8)
        radius = 0.51*(at + 0.03)**0.42*(1.0 - at)**0.95
        radius = radius*(1.0 + (0.08 + 0.22*at)*first + (0.03 + 0.10*at)*second)
        # Long licks reach past the body of the flame on some sides.
        radius = radius*(1.0 - 0.7*smoothstep(0.45, 1.0, at)*(0.5 - 0.5*np.sin(ang*3.0 + 0.7 + at*2.0)))
        past = np.maximum(-(l + FLAME_BACK), l + FLAME_BACK - FLAME_LENGTH)
        return (np.sqrt(qs*qs + qu*qu) - radius)*0.7 + np.maximum(past, 0.0), at, ang, 0.7*first + 0.3*second

    def face_keep(self, p):
        # The flame bends along its length, so it needs the triangles to bend smoothly.
        return np.maximum(super().face_keep(p), 0.7*smoothstep(-0.6, -0.9, p[:, 2]))

    def skin(self, p):
        real = p - np.array([0.0, 1.2, 0.0])
        a = self.concept_length(real)
        z = a[:, 2]
        cb = self.spine_c(z)
        zc = np.clip(z, -1.9, 0.8)
        d = np.sqrt(np.sum((a[:, :2] - cb)**2, axis=1) + (z - zc)**2) - self.body_r(zc)
        d = d*0.82
        d = smin(d, sd_ell(a - [0.0, 0.10, 0.95], np.array([0.52, 0.38, 0.62])), 0.16)
        d = smin(d, sd_ell(a - [0.0, -0.02, 1.32], np.array([0.37, 0.23, 0.36])), 0.14)
        d = smin(d, sd_ell(a - [0.0, -0.22, 1.20], np.array([0.30, 0.11, 0.38])), 0.10)
        uvn = self.uvn(real)
        d = smin(d, np.maximum(np.abs(uvn[:, 2])*0.7 - 0.016, self.outline(uvn)*0.6), 0.10)
        wa = np.stack([np.abs(real[:, 0]), real[:, 1], real[:, 2]], -1)
        wroot, elbow, wtip = self.wing_point(0.0, 0.0), self.wing_point(0.5, 0.0), self.wing_point(1.0, 0.0)
        d = smin(d, np.minimum(cap(wa, wroot, elbow, 0.07, 0.04), cap(wa, elbow, wtip, 0.04, 0.012)), 0.04)
        d = smin(d, cap(wa, wroot, self.wing_point(0.3333, float(self.trail(0.3333))), 0.032, 0.008), 0.03)
        d = smin(d, cap(wa, elbow, self.wing_point(0.6667, float(self.trail(0.6667))), 0.024, 0.007), 0.03)
        d = smin(d, cap(wa, self.wing_point(0.0, 0.70), self.wing_point(0.1667, float(self.trail(0.1667))), 0.030, 0.007), 0.03)
        for i in range(4):
            zi = 0.35 - 0.46*i
            c = self.spine_c(np.array([zi]))[0]
            r = float(self.body_r(np.array([zi]))[0])
            pr = np.stack([(a[:, 0] - c[0])*2.4, a[:, 1] - c[1], z], -1)
            d = smin(d, cap(pr, (0.0, r*0.85, zi), (0.0, r + 0.30 - 0.025*i, zi - 0.34), 0.13, 0.012)/2.4, 0.06)
        for s in (-1.0, 1.0):
            dist, t = self.ear_dist(p, s)
            d = smin(d, (dist - (0.20 + (0.018 - 0.20)*t**0.8))/1.7, 0.10)
            d = d + self.recess*(1.0 - smoothstep(-0.03, 0.006, self.almond(p, s)))*(z >= 0.8)
        mask, fold = self.belly(a)
        d = d + mask*0.012*(1.0 - fold)
        near = (z < -1.2) & (np.abs(a[:, 0]) < 1.3) & (a[:, 1] < 0.2) & (a[:, 1] > -1.7)
        if near.any():
            d[near] = smin(d[near], self.flame(real[near])[0], 0.07)
        return d + (z > 0.9)*self.carve*0.026*(1.0 - smoothstep(-0.016, 0.010, self.grin_dist(a)))

    def albedo(self, p):
        real = p - np.array([0.0, 1.2, 0.0])
        a = self.concept_length(real)
        n = len(a)
        x, y, z = a[:, 0], a[:, 1], a[:, 2]
        qb = a[:, :2] - self.spine_c(z)
        r = self.body_r(np.clip(z, -1.9, 0.8))
        around = np.arctan2(np.abs(qb[:, 0]), qb[:, 1])
        col = np.tile(ORANGE, (n, 1))
        glow = np.zeros((n, 3))
        col = mix(col, AMBER[None], smoothstep(1.95, 2.55, around)*0.85*np.maximum(smoothstep(0.95, 0.70, z), smoothstep(-0.20, -0.27, y)))
        col = mix(col, RED[None], smoothstep(-0.7, -1.3, z)*0.65)
        heat = smoothstep(-1.15, -1.9, z)
        col = mix(col, MOLTEN[None]*0.6, heat)
        hot = mix(np.array([1.25, 0.32, 0.03])[None], np.array([1.55, 0.92, 0.28])[None], smoothstep(0.55, 1.0, heat))
        glow += mix(np.array([0.85, 0.08, 0.015])[None], hot, smoothstep(0.15, 0.7, heat))*(heat*0.45)[:, None]
        sv = z*1.9 + around*0.35
        width = 0.30*(1.0 - smoothstep(0.2, 2.1, around))
        stripe = (1.0 - smoothstep(width - 0.05, width + 0.02, np.abs(fract(sv) - 0.5)))*smoothstep(0.55, 0.30, z)
        col = mix(col, RED[None], stripe)
        uvn = self.uvn(real)
        wt = np.clip(uvn[:, 0]/self.SPAN, 0.0, 1.0)
        on_wing = (1.0 - smoothstep(0.04, 0.09, np.abs(uvn[:, 2])))*(1.0 - smoothstep(0.02, 0.06, self.outline(uvn)))
        wing = mix(RED[None], ORANGE[None], smoothstep(0.1, 0.85, wt))
        wp = uvn[:, :2]
        we = (0.5*self.SPAN, 0.0)
        rib = np.minimum(seg2(wp, (0.0, 0.0), (0.3333*self.SPAN, float(self.trail(0.3333))), 0.018, 0.006),
                         seg2(wp, we, (0.6667*self.SPAN, float(self.trail(0.6667))), 0.016, 0.005))
        rib = np.minimum(rib, seg2(wp, (0.0, 0.0), (self.SPAN, 0.0), 0.030, 0.008))
        rib = np.minimum(rib, seg2(wp, (0.0, 0.70), (0.1667*self.SPAN, float(self.trail(0.1667))), 0.016, 0.005))
        wing = mix(wing, RED[None]*0.7, 1.0 - smoothstep(0.0, 0.012, rib))
        wing = mix(wing, AMBER[None], np.maximum(smoothstep(0.94, 1.0, wt), (1.0 - smoothstep(0.0, 0.028, self.trail(wt) - uvn[:, 1]))*0.85))
        col = col*(1.0 - on_wing[:, None]) + wing*on_wing[:, None]
        mask, fold = self.belly(a)
        col = col*(1.0 - mask[:, None]) + col*(0.70 + 0.34*fold)[:, None]*mask[:, None]
        col = mix(col, AMBER[None], smoothstep(r + 0.10, r + 0.20, qb[:, 1])*smoothstep(0.75, 0.55, z)*(1.0 - smoothstep(0.05, 0.12, np.abs(qb[:, 0])))*0.9)
        for s in (-1.0, 1.0):
            dist, t = self.ear_dist(p, s)
            on_ear = (1.0 - smoothstep(0.24, 0.36, dist))*smoothstep(0.04, 0.16, t)
            col = mix(col, RED[None], on_ear*smoothstep(0.15, 0.55, t))
            tip = on_ear*smoothstep(0.55, 1.0, t)
            col = mix(col, AMBER[None], tip)
            glow += mix(MOLTEN[None], HOT[None], np.full(n, 0.5))*(tip*tip)[:, None]
            col, glow = paint_eye(self, col, glow, p, s, z > 0.9, 0.005, 0.012, False, (-0.02, 0.06), False)
        em = np.stack([np.abs(x), y - 0.385], -1)/1.05
        col = mix(col, RED[None]*0.8, self.ember_mask(em)*(y > 0.15)*(z > 0.95))
        nz = np.stack([x/0.55, z - 0.02], -1)
        fr = np.full(n, 9.0)
        for c in ((-0.135, 1.52), (-0.075, 1.60), (-0.03, 1.50), (0.04, 1.62), (0.085, 1.51), (0.14, 1.59)):
            fr = np.minimum(fr, np.linalg.norm(nz - c, axis=1))
        col = mix(col, RED[None], (1.0 - smoothstep(0.012, 0.018, fr))*0.62*(y > 0.0)*(z > 1.15))
        col = self.paint_grin(col, a, (z > 0.9)*1.0)
        return self.paint_flame(col, glow, real)

    def paint_flame(self, col, glow, a):
        """Skin runs into fire with no edge: the colour licks up the tail in tongues, hot at the root and red at the points."""
        tip, along, side, up = self.flame_frame()
        q = a - tip
        around = np.arctan2(q @ up, q @ side)
        # Yellow on the ridges and deeper in the grooves, so the lobes read as streaks running down the flame.
        _, at, _, lobes = self.flame(a)
        v = at + 0.13*lobes*smoothstep(0.1, 0.35, at)
        fire = mix(np.array([1.0, 0.52, 0.06])[None], MOLTEN[None], smoothstep(0.15, 0.48, v))
        fire = mix(fire, DEEP[None], smoothstep(0.52, 0.84, v))
        fire = mix(fire, RED[None], smoothstep(0.84, 1.0, v))
        amount = self.flame_amount(self.concept_length(a), around)
        col = mix(col, fire, amount)
        glow = mix(glow, fire*(0.32 - 0.1*np.clip(v, 0.0, 1.0))[:, None], amount)
        return col, glow

    @staticmethod
    def flame_amount(a, around):
        """How much of a point is fire: licking up the tail in tongues, then all of it."""
        return smoothstep(-1.22, -1.62, a[:, 2] + 0.10*np.sin(around*4.0 + a[:, 2]*3.0))

    def roughness(self, p):
        # Fire has no wet shine, so no white streaks along the tongues.
        a = p - np.array([0.0, 1.2, 0.0])
        tip, _, side, up = self.flame_frame()
        q = a - tip
        return mix(np.full((len(a), 1), SKIN_ROUGHNESS), np.full((len(a), 1), 0.85), self.flame_amount(self.concept_length(a), np.arctan2(q @ up, q @ side)))[:, 0]

    def face_region(self, p, n):
        a = p - np.array([0.0, 1.2, 0.0])
        return (n[:, 2] > 0.3) & (a[:, 2] > 0.85) & (a[:, 1] < 0.56) & (np.abs(a[:, 0]) < 0.62)

    def tail_points(self):
        out = []
        for z in (-0.3, -0.9, -1.4, -1.9):
            c = self.spine_c(np.array([z]))[0]
            out.append(np.array([c[0], 1.2 + c[1], float(self.shortened(np.array(z)))]))
        return out

    def bones(self):
        tail = self.tail_points()
        neck = np.array([0.0, 1.05, 0.55])
        out = [("root", tuple(to_blender(tail[0])), tuple(to_blender(tail[0] + [0, 0.3, 0])), None),
               ("head", tuple(to_blender(neck)), tuple(to_blender(neck + [0, 0.1, 0.9])), "root"),
               ("tail_1", tuple(to_blender(tail[0])), tuple(to_blender(tail[1])), "root"),
               ("tail_2", tuple(to_blender(tail[1])), tuple(to_blender(tail[2])), "tail_1"),
               ("tail_3", tuple(to_blender(tail[2])), tuple(to_blender(tail[3])), "tail_2")]
        tip, along, _, _ = self.flame_frame()
        lift = np.array([0.0, 1.2, 0.0])
        parent = "tail_3"
        for i in range(3):
            name = f"flame_{i + 1}"
            out.append((name, tuple(to_blender(tip + along*(0.6*i) + lift)), tuple(to_blender(tip + along*(0.6*i + 0.6) + lift)), parent))
            parent = name
        tip, along, side, up = self.flame_frame()
        for name, way in (("L", side), ("R", -side), ("up", up), ("down", -up)):
            root = tip + along*0.45 + way*0.12 + lift
            out.append(("flame_" + name, tuple(to_blender(root)), tuple(to_blender(root + along*0.3)), "flame_1"))
        for s, tag in ((-1.0, "L"), (1.0, "R")):
            sign = np.array([s, 1.0, 1.0])
            root, elbow, tip = (self.wing_point(t, 0.0) + [0, 1.2, 0] for t in (0.05, 0.5, 1.0))
            out.append(("wing_" + tag, tuple(to_blender(root*sign)), tuple(to_blender(elbow*sign)), "root"))
            out.append(("wing_tip_" + tag, tuple(to_blender(elbow*sign)), tuple(to_blender(tip*sign)), "wing_" + tag))
            A, B, C = self.antenna(s)
            mid = 0.25*A + 0.5*B + 0.25*C
            out.append(("antenna_" + tag, tuple(to_blender(A)), tuple(to_blender(mid)), "head"))
            out.append(("antenna_tip_" + tag, tuple(to_blender(mid)), tuple(to_blender(C)), "antenna_" + tag))
        return out + self.face_bones()

    def weights(self, p):
        real = p - np.array([0.0, 1.2, 0.0])
        a = self.concept_length(real)
        z = a[:, 2]
        head = smoothstep(0.30, 0.70, z)
        t1 = smoothstep(-0.05, -0.6, z)*(1.0 - smoothstep(-0.65, -1.15, z))
        t2 = smoothstep(-0.65, -1.15, z)*(1.0 - smoothstep(-1.2, -1.6, z))
        t3 = smoothstep(-1.2, -1.6, z)
        w = {"head": head, "tail_1": t1, "tail_2": t2, "tail_3": t3}
        w["root"] = np.maximum(1.0 - head - t1 - t2 - t3, 0.0)
        uvn = self.uvn(real)
        wing = (1.0 - smoothstep(0.03, 0.11, np.abs(uvn[:, 2])))*(1.0 - smoothstep(0.03, 0.10, self.outline(uvn)))*smoothstep(0.18, 0.55, uvn[:, 0])
        tip = smoothstep(0.9, 1.5, uvn[:, 0])
        for s, tag in ((-1.0, "L"), (1.0, "R")):
            on = wing*(s*a[:, 0] > 0.0)
            for key in w:
                w[key] = w[key]*(1.0 - on)
            w["wing_" + tag] = on*(1.0 - tip)
            w["wing_tip_" + tag] = on*tip
        self.flame_weights(w, real)
        for s, tag in ((-1.0, "L"), (1.0, "R")):
            dist, t = self.ear_dist(p, s)
            on = (1.0 - smoothstep(0.18, 0.30, dist))*smoothstep(0.05, 0.28, t)
            for key in w:
                w[key] = w[key]*(1.0 - on)
            ear_tip = smoothstep(0.35, 0.65, t)
            w["antenna_" + tag] = on*(1.0 - ear_tip)
            w["antenna_tip_" + tag] = on*ear_tip
        self.lid_weights(w, p)
        return w

    def flame_weights(self, w, a):
        """A chain of three bones lets a wave run down the flame; four more swell its sides, so the lobes can roll round it."""
        tip, along, _, _ = self.flame_frame()
        l = (a - tip) @ along
        dist, at, ang, _ = self.flame(a)
        on = 1.0 - smoothstep(0.02, 0.12, dist)
        chain = (smoothstep(-0.1, 0.35, l)*(1.0 - smoothstep(0.45, 0.85, l)), smoothstep(0.45, 0.85, l)*(1.0 - smoothstep(1.0, 1.4, l)), smoothstep(1.0, 1.4, l))
        share = on*sum(chain)
        for key in w:
            w[key] = w[key]*(1.0 - share)
        for i, amount in enumerate(chain):
            w[f"flame_{i + 1}"] = on*amount
        bump = on*smoothstep(0.1, 0.35, at)*(1.0 - smoothstep(0.55, 0.85, at))
        for name, centre in (("L", 0.0), ("R", math.pi), ("up", math.pi/2.0), ("down", -math.pi/2.0)):
            mine = 0.7*bump*np.maximum(np.cos(ang - centre), 0.0)**2
            for key in w:
                w[key] = w[key]*(1.0 - mine)
            w["flame_" + name] = mine


def paint_eye(form, col, glow, dp, s, gate, low_line, top_line, heavy, shadow_range, base_lid):
    ad = form.almond(dp, s)
    l = form.eye_local(dp, s)
    top = (l[:, 1] - LID_SLOPE*s*l[:, 0]) >= 0.0
    if base_lid:
        fade = smoothstep(-0.21, -0.08, s*l[:, 0])
        band = (1.0 - smoothstep(0.055, 0.085, ad))*fade*(1.0 - smoothstep(0.08, 0.17, s*l[:, 0]))
        col = mix(col, RED[None], band*top*(0.42 if heavy else 0.30)*gate)
    else:
        col = mix(col, RED[None], (1.0 - smoothstep(0.03, 0.06, ad))*top*0.35*gate)
    line = 1.0 - np.clip(ad/np.where(top, top_line, low_line), 0.0, 1.0)**2*(3 - 2*np.clip(ad/np.where(top, top_line, low_line), 0.0, 1.0))
    col = mix(col, FACE_LINE[None], line*gate)
    inside = (1.0 - smoothstep(-0.004, 0.002, ad))*gate
    col = col*(1.0 - inside[:, None]) + np.array([0.10, 0.018, 0.010])*inside[:, None]
    return col, glow


# ---------------------------------------------------------------- meshing

def sample(form):
    (x0, x1), (y0, y1), (z0, z1) = form.bounds
    xs = np.arange(x0, x1 + 1e-9, form.step)
    ys = np.arange(y0, y1 + 1e-9, form.step)
    zs = np.arange(z0, z1 + 1e-9, form.step)
    vals = np.empty((len(xs), len(ys), len(zs)), np.float32)
    Y, Z = np.meshgrid(ys, zs, indexing="ij")
    for i, x in enumerate(xs):
        vals[i] = form.skin(np.stack([np.full(Y.size, x), Y.ravel(), Z.ravel()], -1)).reshape(Y.shape)
    return xs, ys, zs, vals


def project(form, p, iterations=3):
    for _ in range(iterations):
        d = form.skin(p)
        g = gradient(form.skin, p)
        step = d/np.maximum(np.sum(g*g, axis=1), 1e-6)
        p = p - g*np.clip(step, -0.006, 0.006)[:, None]
    return p


def concept_positions(mesh):
    co = np.empty(len(mesh.vertices)*3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return np.stack([co[:, 0], co[:, 2], -co[:, 1]], -1)


def keep_largest_part(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen, parts = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, part = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            part.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        parts.append(part)
    parts.sort(key=len, reverse=True)
    for part in parts[1:]:
        bmesh.ops.delete(bm, geom=part, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    print(form_label, "parts removed:", len(parts) - 1)


def repair(obj):
    """Patch surface-net and decimation junctions locally. Stops early rather than eating the shape; any leftovers are
    returned so the export report states them."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    start = len(bm.faces)
    for attempt in range(4):
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
        bad = [e for e in bm.edges if len(e.link_faces) != 2]
        if not bad:
            break
        faces = {f for e in bad for f in e.link_faces}
        for f in list(faces):
            for v in f.verts:
                faces.update(v.link_faces)
        bmesh.ops.delete(bm, geom=list(faces), context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=64)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    leftover = sum(1 for e in bm.edges if not (e.is_manifold and e.is_contiguous))
    print(form_label, "repair attempts", attempt, "leftover edges", leftover, "triangles", start, "->", len(bm.faces))
    assert len(bm.faces) > start*0.9, f"Repair removed too much of {obj.name}"
    for face in bm.faces:
        face.smooth = True
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return leftover


def decimate_keeping_face(form, obj, target):
    keep = form.face_keep(concept_positions(obj.data))
    group = obj.vertex_groups.new(name="keep")
    for value in np.unique(np.round(keep, 2)):
        group.add(np.nonzero(np.round(keep, 2) == value)[0].tolist(), float(value), "REPLACE")
    ef.select_only([obj])
    mod = obj.modifiers.new("Reduce", "DECIMATE")
    mod.ratio = min(1.0, target/ef.triangles(obj))
    mod.vertex_group = "keep"
    # Decimate preserves low weights, so "keep" goes in inverted.
    mod.invert_vertex_group = True
    mod.vertex_group_factor = FACE_KEEP
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if "keep" in obj.vertex_groups:
        obj.vertex_groups.remove(obj.vertex_groups["keep"])


def skinned_sheet(name, verts, tris, uv, weights, facing, rig, image=None):
    """An open mesh on the head: faces turned the way `facing` says, since Roblox culls back faces."""
    obj = bf.mesh_object(name, to_blender(np.asarray(verts)), np.asarray(tris))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    bmesh.ops.reverse_faces(bm, faces=[f for f in bm.faces if f.normal.dot(Vector(tuple(to_blender(facing(f.verts[0].index))))) < 0.0])
    if uv is not None:
        layer = bm.loops.layers.uv.verify()
        for f in bm.faces:
            for l in f.loops:
                l[layer].uv = tuple(uv[l.vert.index])
    bm.to_mesh(obj.data)
    bm.free()
    mat = bpy.data.materials.new(name + "Mat")
    mat.use_nodes = True
    if image is not None:
        shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    obj.data.materials.append(mat)
    for bone, values in weights.items():
        group = obj.vertex_groups.new(name=bone)
        for index, value in values:
            if value > 0.0:
                group.add([index], float(value), "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    ef.select_only([obj])
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    return obj


def grid_tris(columns, rows, offset=0):
    tris = []
    for c in range(columns):
        for r in range(rows):
            p, q = offset + c*(rows + 1) + r, offset + (c + 1)*(rows + 1) + r
            tris.append((p, q, q + 1))
            tris.append((p, q + 1, p + 1))
    return tris


def eye_mesh(form, rig, out):
    """Both eyes, one mesh and one atlas (left half, right half), so each keeps its own highlights."""
    stem = "inferno-base" if form.name == "base" else "inferno-dragon"
    name = ("Inferno" if form.name == "base" else "InfernoDragon") + "Eyes"
    size = 512
    rgb = np.zeros((size, size*2, 3))
    mask = np.zeros((size, size*2, 3))
    verts, tris, uvs, facing, offset = [], [], [], [], 0
    for side, s in enumerate((-1.0, 1.0)):
        q, columns, rows, lx, ly = form.eye_patch(s)
        verts.append(q)
        tris += grid_tris(columns, rows, offset)
        uvs.append(np.stack([((lx + 0.31)/0.62 + side)*0.5, (ly + 0.21)/0.42], -1))
        facing += [form.eye_axes(s)[2]]*len(q)
        offset += len(q)
        u, w, ax = form.eye_axes(s)
        X, Y = np.meshgrid(np.linspace(-0.31, 0.31, size), np.linspace(-0.21, 0.21, size), indexing="xy")
        p = form.eye_centre(s) + X.ravel()[:, None]*u + Y.ravel()[:, None]*w
        ec = form.eye_colour(p, s)
        l = np.stack([X.ravel(), Y.ravel()], -1)
        highlight = 1.0 - smoothstep(0.6, 1.0, np.linalg.norm((l - [-0.07, 0.035])/0.034, axis=1))
        if form.name == "base":
            highlight = np.maximum(highlight, 0.6*(1.0 - smoothstep(0.6, 1.0, np.linalg.norm((l - [0.065, -0.05])/0.016, axis=1))))
        shade = 0.30 + 0.40*(1.0 - smoothstep(-0.03, 0.09, l[:, 1]))
        glow = ec*shade[:, None] + np.array([1.0, 0.95, 0.85])*(highlight*0.9)[:, None]
        amount = np.clip(np.max(glow, axis=1), 0.0, 1.0)
        hue = glow/np.maximum(np.max(glow, axis=1, keepdims=True), 1e-6)
        col = ec*0.45*(1.0 - amount[:, None]) + hue*amount[:, None]
        rgb[:, side*size:(side + 1)*size] = col.reshape(size, size, 3)
        mask[:, side*size:(side + 1)*size] = amount.reshape(size, size, 1)
    colour = write_atlas(stem + "-eyes-color", rgb, out, "sRGB")
    write_atlas(stem + "-eyes-glow", mask, out, "Non-Color")
    per_side = len(verts[0])
    weights = {"head": [(i, 1.0) for i in range(per_side*2)]}
    return skinned_sheet(name, np.concatenate(verts), tris, np.concatenate(uvs), weights, lambda i: facing[i], rig, colour)


def write_atlas(name, rgb, out, colorspace):
    height, width = rgb.shape[:2]
    if colorspace == "sRGB":
        rgb = np.where(rgb <= 0.0031308, 12.92*rgb, 1.055*np.power(np.maximum(rgb, 0.0), 1/2.4) - 0.055)
    image = bpy.data.images.new(name, width, height, alpha=False)
    image.colorspace_settings.name = colorspace
    image.pixels.foreach_set(np.concatenate([np.clip(rgb, 0, 1), np.ones(rgb.shape[:-1] + (1,))], -1).astype(np.float32).ravel())
    path = out/"textures"/(name + ".png")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def lip_weights(tc, rv):
    """Bilinear between the lip bones: column from tc in -1..1, bottom lip at rv 0, top lip at rv 1."""
    position = (np.clip(tc, -1.0, 1.0) + 1.0)/2.0*(MOUTH_BONES - 1)
    k0 = np.minimum(position.astype(int), MOUTH_BONES - 2)
    f = position - k0
    return k0, f


def lip_points(form, tc, rv, top_grow, bottom_grow, proud):
    smile, _ = form.mouth_outlines(tc)
    y = smile[2] - bottom_grow + (smile[1] + top_grow - smile[2] + bottom_grow)*rv
    return form.fit(smile[0], y, proud)


def mouth_meshes(form, rig, out):
    """One mouth, three skinned layers on the same lip bones: ink behind, solid teeth, and the wavy line on top."""
    base = "Inferno" if form.name == "base" else "InfernoDragon"
    stem = "inferno-base" if form.name == "base" else "inferno-dragon"
    columns, rows = 48, 6
    forward = lambda i: np.array([0.0, 0.0, 1.0])

    def weights_for(tc, rv, tail=None):
        k0, f = lip_weights(tc, rv)
        weights = {}
        for i in range(len(tc)):
            scale = 1.0 - (tail[i] if tail is not None else 0.0)
            for tag, share in (("t", rv[i]), ("b", 1.0 - rv[i])):
                for k, amount in ((k0[i], 1.0 - f[i]), (k0[i] + 1, f[i])):
                    weights.setdefault(f"mouth_{tag}{k}", []).append((i, scale*share*amount))
            if tail is not None and tail[i] > 0.0:
                weights.setdefault("mouth_tail_L" if tc[i] < 0 else "mouth_tail_R", []).append((i, tail[i]))
        return weights

    # Teeth: solid white, a grey band under the top lip, the corners falling into shade.
    size = 256
    v, u = np.meshgrid(np.linspace(0.0, 1.0, size), np.linspace(0.0, 1.0, size), indexing="ij")
    t = np.abs(u*2.0 - 1.0)
    art = TEETH[None, None]*(1.0 - (0.3*smoothstep(0.6, 1.0, t))[..., None]) + TEETH_SHADE[None, None]*(0.3*smoothstep(0.6, 1.0, t))[..., None]
    band = smoothstep(form.lip_band, form.lip_band + 0.03, v)[..., None]
    art = art*(1.0 - band) + np.array([0.13, 0.11, 0.12])[None, None]*band
    image = write_atlas(stem + "-mouth", art, out, "sRGB")
    # The teeth glow gently so they stay white in any light; the band under the lip stays in shadow.
    write_atlas(stem + "-mouth-glow", (0.6 - 0.5*band)*np.ones_like(art), out, "Non-Color")
    tc, rv = np.meshgrid(np.linspace(-1.0, 1.0, columns + 1), np.linspace(0.0, 1.0, rows + 1), indexing="ij")
    tc, rv = tc.ravel(), rv.ravel()
    teeth = skinned_sheet(base + "Mouth", lip_points(form, tc, rv, 0.0, 0.0, MOUTH_PROUD), grid_tris(columns, rows),
                          np.stack([(tc + 1.0)/2.0, rv], -1), weights_for(tc, rv), forward, rig, image)

    # Ink: the whole outline, top and bottom, running on past the corners into tails.
    ink_columns = 60
    ic, jr = np.meshgrid(np.linspace(-1.2, 1.2, ink_columns + 1), np.linspace(0.0, 1.0, rows + 1), indexing="ij")
    ic, jr = ic.ravel(), jr.ravel()
    tail = np.clip((np.abs(ic) - 1.0)/0.2, 0.0, 1.0)
    points = lip_points(form, np.clip(ic, -1.0, 1.0), jr, 0.013, 0.008, MOUTH_PROUD - 0.004)
    rigged = form.mouth_rig()
    for i in np.nonzero(tail > 0.0)[0]:
        end = rigged["mouth_tail_L" if ic[i] < 0 else "mouth_tail_R"][0]
        points[i] = points[i] + (end - points[i])*tail[i]
    ink = skinned_sheet(base + "MouthInk", points, grid_tris(ink_columns, rows), None, weights_for(ic, jr, tail), forward, rig)

    # The wavy line where the teeth meet, which fades in as he clenches.
    line_columns = 70
    lc = np.repeat(np.linspace(-0.66, 0.66, line_columns + 1), 2)
    side = np.tile([0.0, 1.0], line_columns + 1)
    taper = 1.0 - smoothstep(0.42, 0.66, np.abs(lc))
    centre = 0.40 + 0.11*np.sin(lc*11.0 + 0.6) + 0.05*np.sin(lc*23.0)
    lr = centre + (side - 0.5)*0.11*taper
    line = skinned_sheet(base + "MouthLine", lip_points(form, lc, lr, 0.0, 0.0, MOUTH_PROUD + 0.003), grid_tris(line_columns, 1), None,
                         weights_for(lc, lr), forward, rig)
    return [teeth, ink, line]


def unwrap(form, low):
    """Planar high-density island for the face, smart project for the rest, then pack everything."""
    verts = concept_positions(low.data)
    normals = gradient(form.skin, verts)
    normals /= np.maximum(np.linalg.norm(normals, axis=1), 1e-9)[:, None]
    face_vert = form.face_region(verts, normals)
    ef.select_only([low])
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(low.data)
    bm.faces.ensure_lookup_table()
    uv = bm.loops.layers.uv.verify()
    in_face = [all(face_vert[v.index] for v in f.verts) for f in bm.faces]
    for f, is_face in zip(bm.faces, in_face):
        f.select = not is_face
    bmesh.update_edit_mesh(low.data)
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bm = bmesh.from_edit_mesh(low.data)
    bm.faces.ensure_lookup_table()
    uv = bm.loops.layers.uv.verify()
    uv_area, area = 0.0, 0.0
    for f, is_face in zip(bm.faces, in_face):
        if is_face:
            continue
        area += f.calc_area()
        pts = [l[uv].uv for l in f.loops]
        uv_area += abs(sum(pts[i].x*pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x*pts[i].y for i in range(len(pts))))/2
    scale = math.sqrt(uv_area/max(area, 1e-9))*FACE_DENSITY
    for f, is_face in zip(bm.faces, in_face):
        if is_face:
            for l in f.loops:
                l[uv].uv = (l.vert.co.x*scale + 0.5, l.vert.co.z*scale)
        f.select = True
    bmesh.update_edit_mesh(low.data)
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=False, scale=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    print(form_label, "face triangles", sum(in_face), "of", len(in_face))
    assert 0.1 < sum(in_face)/len(in_face) < 0.8, "face and body triangle balance is off"


def bake_attribute_positions(low, size):
    """Rest position of every texel, baked through emission and decoded."""
    mesh = low.data
    verts = concept_positions(mesh)
    attr = mesh.attributes.new("rest", "FLOAT_VECTOR", "POINT")
    attr.data.foreach_set("vector", (verts*REST_ENCODE + 0.5).astype(np.float32).ravel())
    image = bpy.data.images.new("bake_rest", size, size, alpha=True, float_buffer=True)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(np.zeros(size*size*4, np.float32))
    mat = bpy.data.materials.new("Bake_rest")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    a = nodes.new("ShaderNodeAttribute")
    a.attribute_name = "rest"
    e = nodes.new("ShaderNodeEmission")
    o = nodes.new("ShaderNodeOutputMaterial")
    links.new(a.outputs["Vector"], e.inputs["Color"])
    links.new(e.outputs["Emission"], o.inputs["Surface"])
    t = nodes.new("ShaderNodeTexImage")
    t.image = image
    nodes.active = t
    mesh.materials.clear()
    mesh.materials.append(mat)
    ef.select_only([low])
    bpy.ops.object.bake(type="EMIT", margin=6, use_clear=False)
    px = np.empty(size*size*4, np.float32)
    image.pixels.foreach_get(px)
    mesh.materials.clear()
    bpy.data.materials.remove(mat)
    bpy.data.images.remove(image)
    mesh.attributes.remove(mesh.attributes["rest"])
    return px.reshape(size, size, 4)


def occlusion(form, p):
    """The concept's ao(): how much of the space just off the surface is filled."""
    n = gradient(form.skin, p)
    n /= np.maximum(np.linalg.norm(n, axis=1), 1e-9)[:, None]
    o, weight = np.zeros(len(p)), 1.0
    for i in range(1, 6):
        h = 0.03*i
        o += (h - form.skin(p + n*h))*weight
        weight *= 0.75
    return np.clip(1.0 - 2.2*o, 0.0, 1.0)


def write_image(name, rgb, out, colorspace="sRGB"):
    """rgb is linear for sRGB images, raw for data images."""
    size = rgb.shape[0]
    if colorspace == "sRGB":
        rgb = np.where(rgb <= 0.0031308, 12.92*rgb, 1.055*np.power(np.maximum(rgb, 0.0), 1/2.4) - 0.055)
    image = bpy.data.images.new(name, size, size, alpha=False)
    image.colorspace_settings.name = colorspace
    image.pixels.foreach_set(np.concatenate([np.clip(rgb, 0, 1), np.ones(rgb.shape[:-1] + (1,))], -1).astype(np.float32).ravel())
    path = out/"textures"/(name + ".png")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def build_rig(form):
    arm = bpy.data.armatures.new(f"Inferno{form.name.title()}Rig")
    rig = bpy.data.objects.new(arm.name, arm)
    bpy.context.collection.objects.link(rig)
    ef.select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, head, tail, parent in form.bones():
        b = arm.edit_bones.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.roll = 0.0
        if parent:
            b.parent = made[parent]
        made[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def apply_weights(form, obj):
    weights = form.weights(concept_positions(obj.data))
    total = np.maximum(sum(weights.values()), 1e-6)
    for name, w in weights.items():
        group = obj.vertex_groups.new(name=name)
        q = np.round(w/total, 3)
        for value in np.unique(q):
            if value > 0:
                group.add(np.nonzero(q == value)[0].tolist(), float(value), "REPLACE")
    ef.select_only([obj])
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)


def game_material(form, colour, normal, rough, glow):
    mat = bpy.data.materials.new("InfernoSkin")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    c = nodes.new("ShaderNodeTexImage")
    c.image = colour
    links.new(c.outputs["Color"], shader.inputs["Base Color"])
    n = nodes.new("ShaderNodeTexImage")
    n.image = normal
    nm = nodes.new("ShaderNodeNormalMap")
    links.new(n.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], shader.inputs["Normal"])
    ef.add_gloss(mat, rough)
    g = nodes.new("ShaderNodeTexImage")
    g.image = glow
    links.new(c.outputs["Color"], shader.inputs["Emission Color"])
    mul = nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 2.5
    links.new(g.outputs["Color"], mul.inputs[0])
    links.new(mul.outputs["Value"], shader.inputs["Emission Strength"])
    return mat


def render_views(form, body, rig, out):
    """Fixed cameras and light for review, at source scale and with the model in its rest pose."""
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Review")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.42, 0.40, 0.46, 1)
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.view_settings.view_transform = "Standard"
    lows = [o for o in scene.objects if o.type == "MESH"]
    centre = Vector((0, -0.2, 1.2)) if form.name == "dragon" else Vector((0, 0, 1.25))
    distance = 8.5 if form.name == "dragon" else 5.6
    sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(-30), math.radians(-25))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 70
    scene.collection.objects.link(cam)
    scene.camera = cam
    paths = []
    for name, yaw, rise in (("front", 0.0, 0.16), ("three-quarter", 0.7, 0.16), ("side", 1.57, 0.16), ("back", 3.14, 0.16), ("under", 0.5, -0.9)):
        offset = Vector((math.sin(yaw), -math.cos(yaw), rise))*distance
        cam.location = centre + offset
        cam.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        path = out/"renders"/(name + ".png")
        path.parent.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(path.name)
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)
    return paths


def build(form):
    global form_label
    form_label = form.name
    out = BUILD/form.name
    out.mkdir(parents=True, exist_ok=True)
    ef.OUT = out
    ef.GAME_SCALE = GAME_SCALE
    bf.reset()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    print(form.name, "sampling")
    xs, ys, zs, vals = sample(form)
    verts, faces = surface_nets(xs, ys, zs, vals)
    del vals
    print(form.name, "surface nets", len(verts), "verts")
    high = bf.mesh_object("High", to_blender(project(form, verts, 2)), faces)
    keep_largest_part(high)
    # A voxel remesh gives a closed manifold surface, which the surface-net junctions are not.
    remesh = high.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = form.step
    remesh.use_smooth_shade = True
    ef.select_only([high])
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    keep_largest_part(high)
    ef.reduce(high, form.high_triangles)
    co = project(form, concept_positions(high.data))
    high.data.vertices.foreach_set("co", to_blender(co).astype(np.float32).ravel())
    high.data.update()
    low = high.copy()
    low.data = high.data.copy()
    low.name = low.data.name = "InfernoBody" if form.name == "base" else "InfernoDragonBody"
    bpy.context.collection.objects.link(low)
    decimate_keeping_face(form, low, form.body_triangles)
    leftover = repair(low)
    co = project(form, concept_positions(low.data), 2)
    low.data.vertices.foreach_set("co", to_blender(co).astype(np.float32).ravel())
    low.data.update()
    unwrap(form, low)

    print(form.name, "baking")
    px = bake_attribute_positions(low, TEXTURE)
    mask = px[..., 3] > 0.5
    pts = (px[..., :3][mask].astype(float) - 0.5)/REST_ENCODE
    col, glow = form.albedo(pts)
    ao = occlusion(form, pts)
    # Depth for Roblox's flatter lighting: baked contact shadow, kept out of the glowing parts.
    glow_amount = np.clip(np.max(glow, axis=1), 0.0, 1.0)
    col = col*(0.72 + 0.28*ao[:, None] + 0.28*(1.0 - ao[:, None])*glow_amount[:, None])
    # Roblox emission is surface colour x mask, so anything that glows must carry its glow colour.
    glow_hue = glow/np.maximum(np.max(glow, axis=1, keepdims=True), 1e-6)
    col = col*(1.0 - glow_amount[:, None]) + glow_hue*glow_amount[:, None]
    rgb = np.tile(ORANGE, (TEXTURE, TEXTURE, 1))
    rgb[mask] = np.clip(col, 0.0, 1.0)
    gl = np.zeros((TEXTURE, TEXTURE, 3))
    gl[mask] = glow_amount[:, None]
    name = low.name.lower().replace("infernodragonbody", "inferno-dragon").replace("infernobody", "inferno-base")
    colour = write_image(name + "-color", rgb, out)
    glow_image = write_image(name + "-glow", gl, out, "Non-Color")
    normal = ef.image(name + "-normal", "Non-Color")
    ef.bake_to(low, high, "NORMAL", normal)
    ef.save(normal, name + "-normal.png")
    normal.pack()
    # glTF metallic-roughness: roughness in G, metalness (0) in B.
    gloss = np.tile(np.array([1.0, SKIN_ROUGHNESS, 0.0]), (TEXTURE, TEXTURE, 1))
    gloss[mask, 1] = form.roughness(pts)
    rough = write_image(name + "-roughness", gloss, out, "Non-Color")
    low.data.materials.clear()
    low.data.materials.append(game_material(form, colour, normal, rough, glow_image))

    rig = build_rig(form)
    apply_weights(form, low)
    low.parent = rig
    low.modifiers.new("Armature", "ARMATURE").object = rig
    eyes = eye_mesh(form, rig, out)
    mouths = mouth_meshes(form, rig, out)
    bpy.data.objects.remove(high)
    review = render_views(form, low, rig, out)

    SOURCE.mkdir(parents=True, exist_ok=True)
    for b in rig.pose.bones:
        b.matrix_basis.identity()
    ef.select_only([low])
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.preferences.filepaths.save_version = 0
    for image in bpy.data.images:
        if image.source != "VIEWER" and not image.packed_file and image.has_data:
            image.pack()
    blend = SOURCE/f"inferno-{form.name}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True, copy=True)

    # Game version: facing +Y and at game scale, with the ink shell.
    meshes = [low, eyes] + mouths
    ef.face_plus_y(rig, meshes)
    ef.scale_to_blaster(rig, meshes)
    ef.select_only([rig] + meshes, active=rig)
    glb = out/"model.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_yup=True, export_image_format="AUTO")
    # Reimport and check what Roblox will receive.
    bone_names = sorted(b.name for b in rig.data.bones)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    rig2 = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    # The glTF importer adds an Icosphere as the bones' display shape.
    meshes2 = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("Inferno")]
    assert sorted(b.name for b in rig2.data.bones) == bone_names, "bones changed on reimport"
    frame = {"eyeAxis": list(form.eye_axis_xyz), "mouth": {name: [round(float(v), 4) for v in delta] for name, (_, delta) in form.mouth_rig().items()}}
    report = {"form": form.name, "faceRig": frame, "nonManifoldEdgesLeft": leftover, "tool": bpy.app.version_string, "gameScale": GAME_SCALE, "bones": bone_names, "meshes": {}, "reviewRenders": review,
              "studioImportVerified": False}
    points = []
    for m in meshes2:
        influences = max(len([g for g in v.groups if g.weight > 1e-5]) for v in m.data.vertices)
        assert influences <= 4, m.name
        m.data.calc_loop_triangles()
        own = [m.matrix_world @ v.co for v in m.data.vertices]
        report["meshes"][m.name] = {"triangles": len(m.data.loop_triangles), "maxInfluences": influences,
                                    "sizeStuds": [round(max(c[i] for c in own) - min(c[i] for c in own), 3) for i in range(3)]}
        points += own
    lo = [min(c[i] for c in points) for i in range(3)]
    hi = [max(c[i] for c in points) for i in range(3)]
    report["sizeStuds"] = [round(hi[i] - lo[i], 3) for i in range(3)]
    (out/"export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if form.name == "base":
        assert 1.0 <= report["sizeStuds"][2] <= 1.1, report["sizeStuds"]


form_label = ""


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["base", "dragon"]
    for name in argv:
        build({"base": Base, "dragon": Dragon}[name]())


if __name__ == "__main__":
    main()
