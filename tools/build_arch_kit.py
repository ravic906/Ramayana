"""Builds the Ayodhya gate slice (tiered gate tower, walls, colonnade, steps, lamps,
paving) in Blender and exports a small GLB.

    blender -b --python tools/build_arch_kit.py -- assets/arch/gate_slice.glb

Blender: +Y is the back, -Y the front (faces +Z in Godot). Units are metres.
Canon (docs/canon/01_bala_kanda.md, Bala V): Ayodhya has gates, a chessboard
grid of streets and tall many-storeyed buildings; sal trees line the roads.
This slice is the royal training-ground gate, an invented composition.
"""
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

random.seed(7)
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else Path("gate_slice.glb")

PALETTE = {  # name: (base colour, emission colour or None, emission strength); palette sampled from the reference clip
    "plaster": ((0.96, 0.94, 0.88, 1), None, 0),
    "red": ((0.74, 0.1, 0.14, 1), None, 0),
    "teal": ((0.04, 0.46, 0.52, 1), None, 0),
    "stone": ((0.92, 0.89, 0.82, 1), None, 0),
    "marble": ((0.98, 0.97, 0.93, 1), None, 0),
    "dark": ((0.24, 0.14, 0.10, 1), None, 0),
    "wood": ((0.22, 0.09, 0.08, 1), None, 0),
    "gold": ((1.0, 0.72, 0.18, 1), (1.0, 0.5, 0.08, 1), 0.35),
    "flame": ((1.0, 0.8, 0.3, 1), (1.0, 0.7, 0.2, 1), 3.5),
    "glow": ((1.0, 0.72, 0.3, 1), (1.0, 0.55, 0.15, 1), 2.0),
    "saffron": ((0.95, 0.4, 0.1, 1), None, 0),
    "carpet": ((0.92, 0.42, 0.08, 1), None, 0),
    "paving": ((0.90, 0.88, 0.82, 1), None, 0),
    "paving2": ((0.82, 0.80, 0.74, 1), None, 0),
    "mortar": ((0.55, 0.52, 0.48, 1), None, 0),
}
bms = {k: bmesh.new() for k in PALETTE}


def box(mat, c, size, rot_z=0.0, rot_y=0.0):
    bm = bms[mat]
    m = (Matrix.Translation(c) @ Matrix.Rotation(rot_y, 4, "Y") @ Matrix.Rotation(rot_z, 4, "Z")
         @ Matrix.Diagonal((size[0], size[1], size[2], 1)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def cyl(mat, c, r1, r2, h, seg=16, axis="Z"):
    bm = bms[mat]
    rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
    m = Matrix.Translation(c) @ rot
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h, matrix=m)


def sphere(mat, c, r, seg=14):
    bmesh.ops.create_uvsphere(bms[mat], u_segments=seg, v_segments=max(6, seg // 2), radius=r, matrix=Matrix.Translation(c))


# --- Pieces: a royal fort gate (Ayodhya: walls, gates, towers; Bala V) -----------

def pillar(x, y, z0, h):
    box("marble", Vector((x, y, z0 + 0.2)), (0.9, 0.9, 0.4))
    box("gold", Vector((x, y, z0 + 0.43)), (0.78, 0.78, 0.06))
    cyl("red", Vector((x, y, z0 + h / 2)), 0.27, 0.23, h - 1.1, 14)
    for k in range(3):
        cyl("gold", Vector((x, y, z0 + 0.75 + k * 0.07)), 0.29, 0.29, 0.035, 14)
    cyl("gold", Vector((x, y, z0 + h - 0.8)), 0.31, 0.31, 0.06, 14)
    box("marble", Vector((x, y, z0 + h - 0.6)), (0.7, 0.7, 0.16))
    box("gold", Vector((x, y, z0 + h - 0.46)), (0.9, 0.9, 0.08))
    box("marble", Vector((x, y, z0 + h - 0.3)), (1.1, 1.1, 0.2))


def colonnade(x0, x1, y, n, h=4.2):
    xs = [x0 + (x1 - x0) * i / (n - 1) for i in range(n)]
    for x in xs:
        pillar(x, y, 0.0, h)
    mid = (x0 + x1) / 2
    w = abs(x1 - x0) + 1.4
    box("marble", Vector((mid, y, h + 0.25)), (w, 1.1, 0.5))
    box("red", Vector((mid, y - 0.05, h + 0.65)), (w + 0.2, 1.2, 0.3))
    box("gold", Vector((mid, y - 0.64, h + 0.65)), (w + 0.2, 0.05, 0.1))
    # Scalloped arches between the pillars.
    for i in range(len(xs) - 1):
        cx = (xs[i] + xs[i + 1]) / 2
        gap = abs(xs[1] - xs[0]) - 1.1
        box("gold", Vector((cx, y - 0.5, h - 0.55)), (gap, 0.06, 0.1))
        for r in (0.0,):
            box("glow", Vector((cx, y - 0.1, h - 1.5)), (0.22, 0.05, 0.22))  # hanging lamp glow


def merlons(x0, x1, y, z, depth=1.2):
    n = int(abs(x1 - x0) / 1.3)
    for i in range(n):
        cx = x0 + (i + 0.5) * (x1 - x0) / n
        box("stone", Vector((cx, y, z + 0.45)), (0.8, depth, 0.9))
        box("gold", Vector((cx, y - depth / 2 - 0.01, z + 0.95)), (0.5, 0.04, 0.1))


def wall(x0, x1, y, h=6.2):
    mid = (x0 + x1) / 2
    w = abs(x1 - x0)
    box("stone", Vector((mid, y, h / 2)), (w, 1.6, h))
    box("marble", Vector((mid, y - 0.1, 0.45)), (w, 1.9, 0.9))                 # plinth
    box("red", Vector((mid, y - 0.1, h - 0.7)), (w, 1.9, 0.35))                 # frieze band
    box("gold", Vector((mid, y - 1.06, h - 0.7)), (w, 0.04, 0.1))
    box("marble", Vector((mid, y - 0.1, h + 0.1)), (w, 2.0, 0.3))               # cornice
    merlons(x0, x1, y - 0.1, h + 0.25)
    n = int(w / 3.2)
    for i in range(n):                                                          # arrow-slit niches
        cx = x0 + (i + 0.5) * w / n
        box("dark", Vector((cx, y - 0.82, h * 0.52)), (0.35, 0.06, 1.5))
        box("gold", Vector((cx, y - 0.85, h * 0.52 + 0.85)), (0.55, 0.05, 0.08))
        for sx_ in (-1, 1):
            box("gold", Vector((cx + sx_ * 1.1, y - 0.83, h * 0.5)), (0.95, 0.04, 1.65))
            box("teal", Vector((cx + sx_ * 1.1, y - 0.85, h * 0.5)), (0.8, 0.04, 1.5))
            box("marble", Vector((cx + sx_ * 1.1, y - 0.87, h * 0.5)), (0.3, 0.03, 0.9))
    for k in range(10):                                                         # fine stone courses
        box("mortar", Vector((mid, y - 0.81, 1.1 + k * 0.5)), (w, 0.02, 0.03))


def bastion(x, y, r, h):
    cyl("marble", Vector((x, y, 0.5)), r + 0.35, r + 0.45, 1.0, 20)
    cyl("stone", Vector((x, y, h / 2)), r, r + 0.1, h, 20)
    for k in range(3):
        cyl("gold", Vector((x, y, h * (0.35 + 0.22 * k))), r + 0.14, r + 0.14, 0.12, 20)
    cyl("red", Vector((x, y, h - 0.5)), r + 0.25, r + 0.25, 0.7, 20)
    cyl("marble", Vector((x, y, h + 0.1)), r + 0.55, r + 0.55, 0.3, 20)
    for i in range(10):                                                          # parapet round the top
        a = math.tau * i / 10
        box("stone", Vector((x + (r + 0.35) * math.cos(a), y + (r + 0.35) * math.sin(a), h + 0.6)), (0.7, 0.5, 0.8), rot_z=a)
    # chhatri: slim pillars under a golden dome
    for i in range(6):
        a = math.tau * i / 6
        cyl("red", Vector((x + r * 0.6 * math.cos(a), y + r * 0.6 * math.sin(a), h + 1.4)), 0.1, 0.1, 2.2, 8)
    cyl("marble", Vector((x, y, h + 2.55)), r * 0.85, r * 0.85, 0.2, 20)
    sphere("gold", Vector((x, y, h + 2.55)), r * 0.8, 18)
    cyl("gold", Vector((x, y, h + 2.55 + r * 0.8 + 0.2)), 0.1, 0.0, 0.8, 8)
    for i in range(4):                                                           # slit windows
        a = math.pi / 2 + i * 0.35 - 0.5
        box("dark", Vector((x + (r + 0.02) * math.cos(a), y + (r + 0.02) * math.sin(a), h * 0.55)), (0.3, 0.1, 1.2), rot_z=a)


def banner(x, y, z0, h, face=-1.0):
    cyl("gold", Vector((x, y, z0 + h / 2)), 0.06, 0.06, h, 8)
    sphere("gold", Vector((x, y, z0 + h + 0.06)), 0.12, 8)
    # Swallow-tailed saffron flag with a golden sun disc (the Ikshvaku solar line).
    box("saffron", Vector((x + 0.85, y, z0 + h - 0.8)), (1.7, 0.03, 1.1))
    box("saffron", Vector((x + 0.2, y, z0 + h - 0.8)), (0.3, 0.03, 1.1))
    cyl("gold", Vector((x + 0.6, y - 0.03, z0 + h - 0.8)), 0.28, 0.28, 0.03, 16, "Y")
    for k in range(10):
        a = math.tau * k / 10
        box("gold", Vector((x + 0.6 + 0.4 * math.cos(a), y - 0.03, z0 + h - 0.8 + 0.4 * math.sin(a))), (0.1, 0.02, 0.1))


def shikhara(cx, cy, z0, W, H, n=16, flag=False):
    """Curvilinear Nagara spire: stacked tapering layers, a rib on each face, urushringa
    (mini spires) clinging to the corners, amalaka, kalasha and optional flag."""
    lh = H / n
    for i in range(n):
        u = i / n
        w = W * (1.0 - u ** 1.35) * (1.0 - 0.1 * u) + 0.5
        box("stone", Vector((cx, cy, z0 + (i + 0.5) * lh)), (w, w, lh * 1.04))
        box("red" if i % 3 == 0 else "plaster", Vector((cx, cy, z0 + i * lh + 0.04)), (w + 0.2, w + 0.2, 0.12))   # ledge
        if i % 3 == 0:
            box("gold", Vector((cx, cy, z0 + i * lh + 0.12)), (w + 0.22, w + 0.22, 0.03))
        for sgn in (-1, 1):                                                              # central ribs (rathas)
            box("plaster", Vector((cx, cy + sgn * (w / 2 + 0.03), z0 + (i + 0.5) * lh)), (w * 0.34, 0.14, lh * 0.96))
            box("plaster", Vector((cx + sgn * (w / 2 + 0.03), cy, z0 + (i + 0.5) * lh)), (0.14, w * 0.34, lh * 0.96))
        if i % 3 == 1 and u < 0.8:                                                       # carved niche
            box("gold", Vector((cx, cy - w / 2 - 0.06, z0 + (i + 0.5) * lh)), (w * 0.2, 0.05, lh * 0.7))
            box("teal", Vector((cx, cy - w / 2 - 0.09, z0 + (i + 0.5) * lh)), (w * 0.15, 0.05, lh * 0.55))
    top = z0 + H
    cyl("stone", Vector((cx, cy, top + 0.25)), 0.9, 1.0, 0.5, 20)
    cyl("plaster", Vector((cx, cy, top + 0.62)), 1.25, 1.25, 0.26, 20)                  # amalaka
    for k in range(12):
        a = math.tau * k / 12
        sphere("plaster", Vector((cx + 1.25 * math.cos(a), cy + 1.25 * math.sin(a), top + 0.62)), 0.14, 6)
    cyl("gold", Vector((cx, cy, top + 1.1)), 0.32, 0.22, 0.5, 12)
    sphere("gold", Vector((cx, cy, top + 1.55)), 0.4, 14)
    cyl("gold", Vector((cx, cy, top + 2.1)), 0.12, 0.0, 0.8, 8)
    if flag:
        cyl("gold", Vector((cx, cy, top + 3.6)), 0.05, 0.05, 2.6, 6)
        box("saffron", Vector((cx + 0.9, cy, top + 4.4)), (1.7, 0.03, 0.95))
        box("saffron", Vector((cx + 0.2, cy, top + 4.4)), (0.3, 0.03, 0.95))


def mini_spires(cx, cy, z0, W, H):
    shikhara(cx - W * 0.9, cy, z0, W * 0.42, H * 0.5, 9)
    shikhara(cx + W * 0.9, cy, z0, W * 0.42, H * 0.5, 9)


def hall(cx, cy, w, d, h, spire_w, spire_h, flag=False, porch=True):
    box("stone", Vector((cx, cy, h / 2 + 1.0)), (w, d, h))
    for zb in (1.55, h + 0.35):                                                         # tiled bands, gold-edged
        box("gold", Vector((cx, cy - d / 2 - 0.04, zb)), (w - 0.2, 0.06, 0.62))
        box("teal", Vector((cx, cy - d / 2 - 0.07, zb)), (w - 0.4, 0.06, 0.48))
    box("marble", Vector((cx, cy, h + 1.2)), (w + 0.8, d + 0.8, 0.4))                   # eave
    box("gold", Vector((cx, cy - (d + 0.8) / 2, h + 1.25)), (w + 0.8, 0.05, 0.1))
    for k in range(int(w / 1.4)):                                                       # carved eave brackets
        box("red", Vector((cx - w / 2 + 0.7 + k * 1.4, cy - d / 2 - 0.3, h + 0.85)), (0.4, 0.5, 0.5))
    for k in range(int(w / 0.7)):                                                       # painted frieze under the eave
        box(("red", "teal", "gold")[k % 3], Vector((cx - w / 2 + 0.35 + k * 0.7, cy - d / 2 - 0.1, h + 0.62)), (0.5, 0.05, 0.36))
    if porch:                                                                           # jharokha balcony arches
        n = max(2, int(w / 3.0))
        for i in range(n):
            x = cx - w / 2 + (i + 0.5) * w / n
            box("dark", Vector((x, cy - d / 2 - 0.05, h * 0.55 + 1.0)), (1.0, 0.1, 2.0))
            box("glow", Vector((x, cy - d / 2 - 0.04, h * 0.55 + 1.0)), (0.6, 0.06, 1.5))
            box("gold", Vector((x, cy - d / 2 - 0.1, h * 0.55 + 2.1)), (1.2, 0.06, 0.1))
    shikhara(cx, cy, h + 1.4, spire_w, spire_h, 14, flag)


def sanctum():
    # Great plinth (jagati) in three broad courses, then the main hall, porch and cascading side halls.
    for k, (w, d) in enumerate(((48, 22), (46, 20), (44, 18))):
        box("marble", Vector((0, -1.0, 0.25 + k * 0.5)), (w, d, 0.5))
    hall(0, 0, 14, 12, 8.5, 11.0, 15.0, flag=True)
    hall(-10.5, -1.0, 7.5, 9, 6.0, 6.2, 7.5, porch=True)
    hall(10.5, -1.0, 7.5, 9, 6.0, 6.2, 7.5, porch=True)
    hall(-17.0, -1.5, 6.0, 8, 4.4, 4.6, 4.5, porch=False)
    hall(17.0, -1.5, 6.0, 8, 4.4, 4.6, 4.5, porch=False)
    # Pillared porch in front of the central hall: six carved pillars, stepped pyramidal roof.
    for i in range(6):
        pillar(-5.0 + i * 2.0, -8.3, 1.0, 5.4)
    box("marble", Vector((0, -8.3, 6.6)), (13.0, 2.2, 0.5))
    box("gold", Vector((0, -9.42, 6.6)), (13.0, 0.05, 0.12))
    for k in range(5):
        w = 12.0 - k * 2.2
        box("stone", Vector((0, -8.3, 7.15 + k * 0.5)), (w, 2.0 - k * 0.3, 0.5))
        box("plaster", Vector((0, -8.3 - (1.0 - k * 0.15), 7.15 + k * 0.5)), (w + 0.1, 0.1, 0.3))
    sphere("gold", Vector((0, -8.3, 9.9)), 0.3, 10)
    box("dark", Vector((0, -6.1, 4.0)), (3.4, 0.2, 5.4))                                # the great doorway
    box("glow", Vector((0, -6.05, 4.0)), (2.6, 0.12, 4.6))
    for r in (1.9, 2.2):
        for i in range(30):
            a = math.pi * (i + 0.5) / 30
            box("gold", Vector((r * math.cos(a), -6.2, 5.6 + r * math.sin(a))),
                (2 * r * math.sin(math.pi / 30) * 1.1, 0.1, 0.14), rot_y=a - math.pi / 2)


def elephant(x, y, face=-1.0):
    s = 1.0
    box("marble", Vector((x, y, 0.5)), (2.4, 4.0, 1.0))                                 # plinth
    cyl("stone", Vector((x, y, 2.3)), 1.0, 1.0, 2.8, 14, "Y")                           # barrel body
    sphere("stone", Vector((x, y + face * 1.9, 3.0)), 0.95, 12)                         # head
    for sx in (-1, 1):
        box("plaster", Vector((x + sx * 1.05, y + face * 1.5, 3.0)), (0.2, 1.1, 1.4))   # ear
        cyl("marble", Vector((x + sx * 0.5, y + face * 2.9, 2.5)), 0.07, 0.03, 1.0, 6)  # tusk
        for fz in (-1, 1):
            cyl("stone", Vector((x + sx * 0.6, y + fz * 1.3, 1.5)), 0.28, 0.3, 1.0, 8)  # legs
    for k in range(5):                                                                  # curled trunk
        sphere("stone", Vector((x, y + face * (2.6 + k * 0.08), 2.7 - k * 0.38)), 0.3 - k * 0.03, 8)
    box("red", Vector((x, y, 3.35)), (1.9, 2.2, 0.12))                                  # howdah cloth
    box("gold", Vector((x, y, 3.43)), (1.95, 2.25, 0.04))


def steps():
    for k in range(12):  # one broad ceremonial stair up to the porch
        box("marble", Vector((0, -10.2 - k * 0.55, 0.06 * (12 - k) + 0.04)), (9.0 + (11 - k) * 0.3, 0.55, 0.12 * (12 - k) + 0.08))
    for sx in (-1, 1):
        elephant(sx * 6.4, -13.0)
        for k in range(12):  # balustrade cheeks
            box("stone", Vector((sx * 4.7, -10.2 - k * 0.55, 0.12 * (12 - k) + 0.45)), (0.4, 0.55, 0.9))


def lamp(x, y):
    box("marble", Vector((x, y, 0.25)), (0.8, 0.8, 0.5))
    cyl("gold", Vector((x, y, 1.6)), 0.07, 0.1, 2.3, 8)
    cyl("gold", Vector((x, y, 2.85)), 0.28, 0.12, 0.16, 12)
    cyl("gold", Vector((x, y, 3.05)), 0.12, 0.28, 0.22, 12)
    sphere("flame", Vector((x, y, 3.3)), 0.17, 10)


def medallion(cx, cy):
    """Inlaid ceremonial medallion in the courtyard: concentric rings of crimson, teal and gold."""
    rings = [(9.0, "mortar"), (8.7, "red"), (8.1, "paving"), (7.3, "teal"), (6.7, "marble"), (5.6, "gold"), (5.3, "red"),
             (4.2, "marble"), (3.2, "teal"), (2.6, "gold"), (1.8, "red"), (1.0, "gold")]
    for i, (r, m) in enumerate(rings):
        cyl(m, Vector((cx, cy, 0.035 + i * 0.004)), r, r, 0.03, 56)
    for k in range(16):  # lotus petals
        a = math.tau * k / 16
        cyl("red" if k % 2 else "gold", Vector((cx + 6.1 * math.cos(a), cy + 6.1 * math.sin(a), 0.06)), 0.34, 0.34, 0.05, 10)
        box("gold", Vector((cx + 4.5 * math.cos(a), cy + 4.5 * math.sin(a), 0.1)), (0.9, 0.12, 0.03), rot_z=a)


def paving():
    nx, ny, s = 15, 12, 2.0
    for i in range(nx):
        for j in range(ny):
            x = (i - nx / 2 + 0.5) * s
            y = -17.2 - j * s
            box("paving" if (i + j) % 2 == 0 else "paving2", Vector((x, y, -0.02)), (s - 0.07, s - 0.07, 0.08))
    box("mortar", Vector((0, -28, -0.12)), (nx * s, ny * s + 6, 0.2))
    # Royal red runner with gold borders from the stair to the courtyard.
    medallion(0, -29.5)
    box("carpet", Vector((0, -22, 0.12)), (3.2, 12, 0.03))
    for sx in (-1, 1):
        box("gold", Vector((sx * 1.7, -22, 0.13)), (0.12, 12, 0.03))
    for k in range(9):
        box("gold", Vector((0, -17.6 - k * 1.3, 0.14)), (1.3, 0.4, 0.02))


def finish():
    # Bevel hard edges, add warm ground-darkening and slight per-face variation as vertex colour.
    objs = []
    for name, bm in bms.items():
        if not bm.verts:
            continue
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        bm.edges.ensure_lookup_table()
        hard = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6]
        if hard:
            bmesh.ops.bevel(bm, geom=hard, offset=0.035, segments=1, affect="EDGES")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        lay = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for poly in me.polygons:
            c = poly.center
            n = poly.normal
            vein = max(0.0, math.sin(c.x * 1.1 + c.y * 0.6 + math.sin(c.z * 0.9 + c.x * 0.3) * 3.0)) ** 10
            streak = 0.5 + 0.5 * math.sin(c.x * 2.3 + math.sin(c.z * 1.7) * 2.0)
            plain = name in ("gold", "flame", "glow", "teal", "red", "saffron", "carpet")
            var = 1.0 + random.uniform(-0.05, 0.04) - (0.03 * streak if plain else 0.06 * streak + 0.16 * vein)
            form = 0.88 + 0.12 * max(0.0, n.z) + 0.05 * (1.0 - abs(n.x))   # tops lit, sides and undersides darker
            ground = 0.82 + 0.18 * min(1.0, max(0.0, c.z / 3.0))            # grime near the floor
            v = max(0.0, min(1.0, var * form * ground))
            cool = 0.0 if plain else 0.05 * (vein + streak * 0.5)           # faint blue-grey in the veins
            for li in poly.loop_indices:
                lay.data[li].color = (v, v, min(1.0, v + cool), 1)
        mat = bpy.data.materials.new(name)
        base, em, strength = PALETTE[name]
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = base
        # Glossy finish: polished lacquer coat on everything, near-mirror metal for gold.
        bsdf.inputs["Roughness"].default_value = 0.5 if name != "gold" else 0.18
        bsdf.inputs["Coat Weight"].default_value = 0.0 if name in ("gold", "flame", "glow", "dark") else 0.3
        bsdf.inputs["Coat Roughness"].default_value = 0.08
        if name == "gold":
            bsdf.inputs["Metallic"].default_value = 0.95
        if em:
            bsdf.inputs["Emission Color"].default_value = em
            bsdf.inputs["Emission Strength"].default_value = strength
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    return objs


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sanctum()
    steps()
    wall(-46, -20.5, 0.0, 5.2)
    wall(20.5, 46, 0.0, 5.2)
    for sx in (-1, 1):
        bastion(sx * 47.5, -0.5, 3.2, 9.0)
        bastion(sx * 21.8, -2.0, 2.2, 7.0)
        banner(sx * 21.8, -2.0, 7.0 + 3.2, 5.5)
        banner(sx * 33.0, -0.8, 5.4, 4.6)
        banner(sx * 8.0, -9.2, 2.6, 6.0)
    colonnade(-43, -24.5, -3.4, 7, 3.8)
    colonnade(24.5, 43, -3.4, 7, 3.8)
    for sx in (-1, 1):
        for k in range(3):
            lamp(sx * 5.8, -18.0 - k * 5.0)
    paving()
    finish()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_yup=True,
                              export_apply=True, export_materials="EXPORT", export_vertex_color="ACTIVE")
    print("wrote", OUT, OUT.stat().st_size // 1024, "KB")


main()
