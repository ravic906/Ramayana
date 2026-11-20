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

PALETTE = {  # name: (base colour, emission colour or None, emission strength)
    "plaster": ((0.93, 0.70, 0.50, 1), None, 0),
    "red": ((0.72, 0.22, 0.16, 1), None, 0),
    "stone": ((0.62, 0.40, 0.30, 1), None, 0),
    "dark": ((0.20, 0.10, 0.10, 1), None, 0),
    "gold": ((1.0, 0.68, 0.16, 1), (1.0, 0.55, 0.08, 1), 0.55),
    "flame": ((1.0, 0.8, 0.3, 1), (1.0, 0.7, 0.2, 1), 3.0),
    "paving": ((0.86, 0.62, 0.42, 1), None, 0),
    "paving2": ((0.78, 0.52, 0.36, 1), None, 0),
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


# --- Pieces -----------------------------------------------------------------

def pillar(x, y, z0, h):
    box("stone", Vector((x, y, z0 + 0.15)), (0.62, 0.62, 0.3))          # plinth
    box("plaster", Vector((x, y, z0 + 0.34)), (0.5, 0.5, 0.08))
    cyl("red", Vector((x, y, z0 + h / 2)), 0.2, 0.17, h - 0.8, 12)       # shaft
    for k in range(3):                                                    # carved rings
        cyl("gold", Vector((x, y, z0 + 0.6 + k * 0.05)), 0.215 - k * 0.005, 0.215 - k * 0.005, 0.03, 12)
    cyl("gold", Vector((x, y, z0 + h - 0.62)), 0.23, 0.23, 0.05, 12)
    box("plaster", Vector((x, y, z0 + h - 0.45)), (0.52, 0.52, 0.12))    # capital
    box("stone", Vector((x, y, z0 + h - 0.32)), (0.68, 0.68, 0.14))
    box("plaster", Vector((x, y, z0 + h - 0.2)), (0.84, 0.84, 0.14))


def colonnade(x0, x1, y, n, h=3.2):
    xs = [x0 + (x1 - x0) * i / (n - 1) for i in range(n)]
    for x in xs:
        pillar(x, y, 0.0, h)
    mid = (x0 + x1) / 2
    w = abs(x1 - x0) + 1.0
    box("plaster", Vector((mid, y, h + 0.2)), (w, 0.8, 0.4))             # architrave
    box("red", Vector((mid, y - 0.05, h + 0.52)), (w + 0.2, 0.9, 0.24))
    box("gold", Vector((mid, y - 0.52, h + 0.52)), (w + 0.2, 0.04, 0.08))
    for i in range(len(xs) - 1):                                          # arch infill
        cx = (xs[i] + xs[i + 1]) / 2
        box("dark", Vector((cx, y - 0.2, h - 0.35)), (abs(xs[1] - xs[0]) - 0.8, 0.14, 0.1))


def wall(x0, x1, y):
    mid = (x0 + x1) / 2
    w = abs(x1 - x0)
    box("plaster", Vector((mid, y, 1.6)), (w, 1.0, 3.2))
    box("stone", Vector((mid, y - 0.05, 0.25)), (w, 1.1, 0.5))           # plinth
    box("plaster", Vector((mid, y - 0.05, 3.35)), (w, 1.3, 0.3))         # cornice
    box("red", Vector((mid, y - 0.1, 3.58)), (w, 1.4, 0.16))
    n = int(w / 0.9)
    for i in range(n):                                                    # merlon-like finials
        sphere("gold", Vector((x0 + (i + 0.5) * w / n, y - 0.1, 3.82)), 0.1, 8)
        cyl("gold", Vector((x0 + (i + 0.5) * w / n, y - 0.1, 3.72)), 0.06, 0.03, 0.14, 8)
    for i in range(int(w / 3.0)):                                         # blind niches
        cx = x0 + (i + 0.5) * w / int(w / 3.0)
        box("dark", Vector((cx, y - 0.52, 1.7)), (0.9, 0.08, 1.5))
        box("gold", Vector((cx, y - 0.54, 2.5)), (1.0, 0.06, 0.08))


def tower():
    # Base block with the arched gateway.
    box("stone", Vector((0, 0, 0.3)), (11.4, 5.4, 0.6))
    box("plaster", Vector((0, 0, 3.1)), (10.4, 4.6, 5.0))
    box("red", Vector((0, -2.31, 3.1)), (10.4, 0.1, 5.0))
    for sx in (-1, 1):  # flanking pilasters
        for k in range(3):
            box("plaster", Vector((sx * (3.0 + k * 0.001), -2.45, 3.1)), (0.7, 0.35, 4.8))
            box("gold", Vector((sx * 3.0, -2.62, 5.3)), (0.8, 0.05, 0.1))
    # Doorway: dark opening with a round arch and gold arch rings.
    box("dark", Vector((0, -2.32, 2.0)), (3.0, 0.12, 3.4))
    cyl("dark", Vector((0, -2.32, 3.7)), 1.5, 1.5, 0.12, 24, "Y")
    for r, th in ((1.6, 0.1), (1.82, 0.14)):  # moulded arch rims (rings of segments)
        n = 28
        for i in range(n):
            a = math.pi * (i + 0.5) / n
            box("gold", Vector((r * math.cos(a), -2.38, 3.7 + r * math.sin(a))),
                (2 * r * math.sin(math.pi / n) * 1.08, 0.08, th), rot_y=a - math.pi / 2)
    box("gold", Vector((0, -2.38, 2.0)), (3.4, 0.06, 0.1))
    box("gold", Vector((-1.7, -2.38, 1.8)), (0.1, 0.06, 3.4))
    box("gold", Vector((1.7, -2.38, 1.8)), (0.1, 0.06, 3.4))
    # Cornice over the gateway block.
    box("stone", Vector((0, -0.1, 5.75)), (11.2, 5.0, 0.3))
    box("gold", Vector((0, -2.6, 5.75)), (11.2, 0.05, 0.12))
    # Tiers.
    z = 5.9
    w, d = 9.2, 4.0
    for t in range(6):
        h = 1.55 - t * 0.05
        box("plaster", Vector((0, 0, z + h / 2)), (w, d, h))
        box("red", Vector((0, -d / 2 - 0.02, z + h / 2)), (w - 0.2, 0.08, h - 0.25))
        n = max(3, int(w / 1.5))
        for i in range(n):  # windows with gold lintels
            cx = -w / 2 + (i + 0.5) * w / n
            box("dark", Vector((cx, -d / 2 - 0.06, z + h * 0.5)), (0.5, 0.1, h * 0.55))
            box("gold", Vector((cx, -d / 2 - 0.08, z + h * 0.5 + h * 0.3)), (0.62, 0.06, 0.07))
        box("stone", Vector((0, 0, z + h + 0.08)), (w + 0.7, d + 0.7, 0.16))   # cornice
        box("gold", Vector((0, -(d + 0.7) / 2, z + h + 0.1)), (w + 0.7, 0.05, 0.08))
        for sx in (-1, 1):
            sphere("gold", Vector((sx * (w + 0.7) / 2, -(d + 0.7) / 2, z + h + 0.22)), 0.13, 8)
        z += h + 0.16
        w *= 0.8
        d *= 0.84
    # Crown: barrel vault and finials.
    cyl("plaster", Vector((0, 0, z + 0.4)), 1.0, 1.0, w + 0.4, 20, "X")
    for k in range(5):
        x = (k - 2) * (w * 0.4)
        cyl("gold", Vector((x, 0, z + 1.25)), 0.16, 0.16, 0.5, 10)
        sphere("gold", Vector((x, 0, z + 1.65)), 0.2, 12)
        cyl("gold", Vector((x, 0, z + 2.0)), 0.07, 0.0, 0.55, 8)
    return z


def steps():
    for k in range(4):
        box("stone", Vector((0, -3.6 - k * 0.45, 0.12 - k * 0.0 + 0.0)), (4.6 + (3 - k) * 0.0, 0.5, 0.24 * (4 - k)))
    # flanking guard plinths
    for sx in (-1, 1):
        box("stone", Vector((sx * 3.7, -3.7, 0.3)), (1.1, 1.1, 0.6))
        cyl("gold", Vector((sx * 3.7, -3.7, 0.9)), 0.12, 0.1, 0.6, 8)


def lamp(x, y):
    box("stone", Vector((x, y, 0.15)), (0.5, 0.5, 0.3))
    cyl("dark", Vector((x, y, 1.1)), 0.05, 0.07, 1.8, 8)
    cyl("gold", Vector((x, y, 2.05)), 0.2, 0.1, 0.12, 12)
    cyl("gold", Vector((x, y, 2.2)), 0.1, 0.22, 0.18, 12)
    sphere("flame", Vector((x, y, 2.4)), 0.12, 10)


def paving():
    # Slightly separated stone slabs with alternating warm tones.
    nx, ny, s = 22, 14, 1.4
    for i in range(nx):
        for j in range(ny):
            x = (i - nx / 2 + 0.5) * s
            y = -4.2 - j * s
            box("paving" if (i + j) % 2 == 0 else "paving2", Vector((x, y, -0.02)), (s - 0.05, s - 0.05, 0.08))
    box("stone", Vector((0, -12, -0.15)), (nx * s, ny * s + 8, 0.2))


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
            var = 1.0 + (0.0 if name in ("gold", "flame") else random.uniform(-0.05, 0.05))
            ground = 0.72 + 0.28 * min(1.0, max(0.0, c.z / 3.0))      # darker near the floor
            v = var * ground
            for li in poly.loop_indices:
                lay.data[li].color = (v, v, v, 1)
        mat = bpy.data.materials.new(name)
        base, em, strength = PALETTE[name]
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = base
        bsdf.inputs["Roughness"].default_value = 0.55 if name != "gold" else 0.35
        if name == "gold":
            bsdf.inputs["Metallic"].default_value = 0.6
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
    tower()
    wall(-19, -5.7, 0.0)
    wall(5.7, 19, 0.0)
    colonnade(-18.5, -6.5, -1.6, 7)
    colonnade(6.5, 18.5, -1.6, 7)
    steps()
    for sx in (-1, 1):
        lamp(sx * 5.4, -5.6)
    paving()
    finish()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_yup=True,
                              export_apply=True, export_materials="EXPORT", export_vertex_color="ACTIVE")
    print("wrote", OUT, OUT.stat().st_size // 1024, "KB")


main()
