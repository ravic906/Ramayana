"""Builds the cast's bodies and heads with MPFB2 (MakeHuman for Blender, CC0
output) and exports each as glTF for Godot.

    blender -b --python tools/mpfb_export.py -- <name> [<name> ...] --out DIR

Needs Blender 4.5 LTS with the MPFB extension, the makehuman_system_assets
(CC0) and faceunits01 (CC0) packs installed. Each person gets: a body shaped
by MakeHuman's macro and face targets, the "game_engine" skeleton (same bone
names as the game's animation library), skin, eyes, brows, lashes, teeth,
tongue, and the 52 ARKit face units as shape keys (expressions, lip sync).
"""
import sys
from pathlib import Path

import bpy

from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.faceservice import FaceService
from bl_ext.blender_org.mpfb.services.targetservice import TargetService

## name -> phenotype, face targets, skin, hair, brows. Indian features: a
## mix weighted to MakeHuman's caucasian and african bases (its "asian" is
## East Asian), warm brown skins.
CAST = {
    "rama": {
        "phenotype": {"gender": 1.0, "age": 0.43, "muscle": 0.62, "weight": 0.45, "proportions": 0.75,
                      "height": 0.62, "race": {"caucasian": 0.6, "african": 0.3, "asian": 0.1}},
        "targets": {"head-oval": 0.5, "nose-greek-incr": 0.3, "r-eye-scale-incr": 0.2,
                    "l-eye-scale-incr": 0.2, "chin-height-incr": 0.15, "nose-point-width-decr": 0.3},
        "skin": "young_african_male/young_african_male.mhmat",
        "brows": "eyebrow010", "hair": "",
    },
}


def args():
    a = [x for x in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []) if x != "--preview"]
    out = "."
    if "--out" in a:
        out = a[a.index("--out") + 1]
        a = a[:a.index("--out")] + a[a.index("--out") + 2:]
    return a or list(CAST.keys()), Path(out)


def _delete_helpers(body) -> None:
    """MakeHuman's base mesh carries helper geometry (skirt, tights, hair and
    joint helpers) that Blender only hides with a mask modifier; it must not
    reach the game. Keeps the vertices of the "body" group."""
    import bmesh
    group = body.vertex_groups.get("body")
    if group is None:
        print("WARNING: no 'body' vertex group; helpers kept")
        return
    gi = group.index
    keep = set()
    for v in body.data.vertices:
        for g in v.groups:
            if g.group == gi and g.weight > 0.0:
                keep.add(v.index)
                break
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    doomed = [v for v in bm.verts if v.index not in keep]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    for m in list(body.modifiers):
        if m.type == "MASK":
            body.modifiers.remove(m)
    print("removed %d helper vertices" % len(doomed))


def build(name: str, spec: dict, out: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    info = HumanService._create_default_human_info_dict()
    info["name"] = name
    pheno = TargetService.get_default_macro_info_dict()
    for k, v in spec["phenotype"].items():
        pheno[k] = v
    info["phenotype"] = pheno
    info["rig"] = "game_engine"
    info["eyes"] = "high-poly/high-poly.mhclo"
    info["eyebrows"] = "%s/%s.mhclo" % (spec["brows"], spec["brows"])
    info["eyelashes"] = "eyelashes01/eyelashes01.mhclo"
    info["teeth"] = "teeth_base/teeth_base.mhclo"
    info["tongue"] = "tongue01/tongue01.mhclo"
    if spec.get("hair"):
        info["hair"] = "%s/%s.mhclo" % (spec["hair"], spec["hair"])
    info["skin_mhmat"] = spec["skin"]
    info["skin_material_type"] = "MAKESKIN"
    info["targets"] = [{"target": t, "value": v} for t, v in spec.get("targets", {}).items()]
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    settings["load_clothes"] = False
    body = HumanService.deserialize_from_dict(info, settings)
    # Bake the body shape (macro and face targets) into the mesh: only the
    # face units stay as shape keys.
    TargetService.bake_targets(body)
    _delete_helpers(body)
    if FaceService.is_faceunits01_installed(True):
        FaceService.load_targets(body, load_microsoft_visemes=False, load_arkit_faceunits=True)
        FaceService.interpolate_targets(body)
    else:
        print("WARNING: faceunits01 not installed; no face units")
    keys = body.data.shape_keys.key_blocks if body.data.shape_keys else []
    print("%s: %d verts, %d shape keys" % (name, len(body.data.vertices), len(keys)))
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_skins=True,
                              export_morph=True, export_morph_normal=False, export_animations=False,
                              export_apply=False, use_visible=False)
    print("Wrote", path)


def preview(name: str, out: Path) -> None:
    """A quick Cycles portrait (CPU) for review."""
    import math
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x, scene.render.resolution_y = 600, 800
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    hb = rig.pose.bones["head"]
    head_z = (rig.matrix_world @ hb.head).z + 0.2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.location = (0.25, -0.75, head_z - 0.12)
    cam.data.lens = 85
    target = (0.0, 0.0, head_z - 0.13)
    import mathutils
    d = mathutils.Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 120
    key.data.size = 1.0
    key.location = (0.9, -1.0, head_z + 0.3)
    key.rotation_euler = (mathutils.Vector(target) - key.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(key)
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.33, 0.3, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    scene.render.filepath = str(out / f"{name}_portrait.png")
    bpy.ops.render.render(write_still=True)


def main():
    names, out = args()
    for n in names:
        build(n, CAST[n], out)
        if "--preview" in sys.argv:
            preview(n, out)


main()
