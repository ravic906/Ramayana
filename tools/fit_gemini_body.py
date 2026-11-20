"""Binds a generated humanoid mesh (e.g. from an image-to-3D tool) to the game skeleton.

    blender -b --python tools/fit_gemini_body.py -- <mesh.glb> <skeleton.glb> <out.glb> [height_m] [texture_px]

The skeleton file is a person exported by tools/mpfb_export.py (its armature has the game's bones,
in an A-pose). The mesh is stood on the floor, centred, scaled to `height_m`, and skinned to the
armature with automatic weights; the output keeps the armature and the single skinned mesh,
named "<person>.body" so tools/build_person.gd treats it like an MPFB body.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
MESH, SKEL, OUT = argv[:3]
HEIGHT = float(argv[3]) if len(argv) > 3 else 1.78
NAME = Path(OUT).stem

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SKEL)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
# The skeleton file's own body is already weighted to the game bones: keep it as the weight donor.
donor = next((o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.endswith(".body")), None)
for o in list(bpy.context.scene.objects):
    if o.type != "ARMATURE" and o is not donor:
        bpy.data.objects.remove(o, do_unlink=True)

before = set(bpy.context.scene.objects)  # includes the donor
bpy.ops.import_scene.gltf(filepath=MESH)
meshes = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
for o in bpy.context.scene.objects:
    if o not in before and o.type != "MESH":
        o.select_set(False)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Stand it on the floor, centred on x/y, scaled to the requested height.
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
mn = Vector((min(v[i] for v in bb) for i in range(3)))
mx = Vector((max(v[i] for v in bb) for i in range(3)))
scale = HEIGHT / (mx.z - mn.z)
body.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(scale=True)
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
mn = Vector((min(v[i] for v in bb) for i in range(3)))
mx = Vector((max(v[i] for v in bb) for i in range(3)))
body.location = Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))
bpy.ops.object.transform_apply(location=True)
body.name = f"{NAME}.body"
body.data.name = f"{NAME}.body"

# Keep only the base-colour picture (downscaled) so the character stays a few MB: generated models
# often carry 4096 px normal and metallic-roughness maps that a phone game does not need.
TEX = int(argv[4]) if len(argv) > 4 else 1024
for mat in body.data.materials:
    if mat and mat.use_nodes:
        nt = mat.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            for name in ("Metallic", "Roughness", "Normal"):
                for l in list(bsdf.inputs[name].links):
                    nt.links.remove(l)
            bsdf.inputs["Roughness"].default_value = 0.85
            bsdf.inputs["Metallic"].default_value = 0.0
        for n in list(nt.nodes):
            nm = (n.image.name.lower() if n.type == "TEX_IMAGE" and n.image else "")
            if n.type == "NORMAL_MAP" or n.type in ("SEPARATE_COLOR", "SEPARATE_RGB") or nm.endswith("_normal.png") or "_rm" in nm or "normal" in nm:
                nt.nodes.remove(n)
for img in list(bpy.data.images):
    if img.users and img.size[0] > TEX:
        img.scale(TEX, TEX)
    if img.users and not img.packed_file:
        img.pack()

# Skin: weights from distance to the bone segments (soft, no tearing). The donor body only
# supplies the list of deform bones (its vertex groups), then it is deleted.
from mathutils import Vector

body.parent = None
for g in list(body.vertex_groups):
    body.vertex_groups.remove(g)
# Generated hands are one solid mitt (fingers fused), so the game's finger-curl clips would fold it
# into flat blades: no finger bones, the whole hand follows the hand bone.
FINGERS = ("thumb_", "index_", "middle_", "ring_", "pinky_")
names = [vg.name for vg in donor.vertex_groups if vg.name in arm.data.bones and not vg.name.startswith(FINGERS)]
segs = []
for n in names:
    b = arm.data.bones[n]
    segs.append((n, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local))
for n in names:
    body.vertex_groups.new(name=n)


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (p - (a + ab * t)).length


for v in body.data.vertices:
    p = body.matrix_world @ v.co
    ds = sorted(((seg_dist(p, a, b), n) for n, a, b in segs))[:4]
    ws = [1.0 / (d + 0.03) ** 2 for d, _ in ds]
    s = sum(ws)
    for (d, n), w in zip(ds, ws):
        body.vertex_groups[n].add([v.index], w / s, "REPLACE")
bpy.data.objects.remove(donor, do_unlink=True)
body.parent = arm
body.matrix_parent_inverse = arm.matrix_world.inverted()
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm
body.parent = arm
body.matrix_parent_inverse = arm.matrix_world.inverted()
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm
unweighted = sum(1 for v in body.data.vertices if not any(g.weight > 0.001 for g in v.groups))
print("SKIN groups", len(body.vertex_groups), "verts", len(body.data.vertices), "unweighted", unweighted)
# Weights are a pure function of position, so vertices split at UV seams stay together (smoothing
# over mesh connectivity would pull them apart and tear the mesh when posed).
bpy.context.view_layer.objects.active = body
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_skins=True, export_apply=False, export_yup=True,
                          export_image_format="JPEG", export_image_quality=88)
print("wrote", OUT)
