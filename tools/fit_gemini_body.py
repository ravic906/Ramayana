"""Binds a generated humanoid mesh (e.g. from an image-to-3D tool) to the game skeleton.

    blender -b --python tools/fit_gemini_body.py -- <mesh.glb> <skeleton.glb> <out.glb> [height_m]

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
for o in list(bpy.context.scene.objects):
    if o.type != "ARMATURE":
        bpy.data.objects.remove(o, do_unlink=True)

before = set(bpy.context.scene.objects)
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

# Skin to the armature.
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
try:
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
except RuntimeError as e:
    print("auto weights failed:", e)
if not body.vertex_groups:
    bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
print("SKIN groups", len(body.vertex_groups), "verts", len(body.data.vertices))
# Smooth a little so thin garment flaps do not tear when posed.
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=2)
bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_skins=True, export_apply=False, export_yup=True)
print("wrote", OUT)
