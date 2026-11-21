"""Turns a Mixamo-rigged character plus its Mixamo animations into one game-ready GLB.

    blender -b --python tools/mixamo_to_glb.py -- <character_rig.fbx> <anim_dir> <out.glb>

- Bones are renamed from Mixamo's ("mixamorig:LeftForeArm") to the game's UE-style names
  ("lowerarm_l"), so the game's code (props on bones, aiming IK, upper-body masks) works unchanged.
- Every <anim_dir>/<clip>.fbx (downloaded "Without Skin" on the same Mixamo skeleton) becomes an
  animation named <clip>. Clips that travel (walk, run, roll) are made "in place": the game moves
  the character, the clip keeps only the bob and sway.
"""
import sys
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
RIG, ANIM_DIR, OUT = argv[:3]
# "--grip-left": an archer's bow hand, the left fingers closed round the grip in every clip.
GRIP_LEFT = "--grip-left" in argv
IN_PLACE = {"walk", "run", "roll", "walk_formal"}
# Keep only part of a clip (fractions of its length): the roll without the sprint stride before it
# and the crouch after it, so a short dodge plays the roll itself.
TRIM = {"roll": (0.2, 0.86)}

SIDES = {"Left": "l", "Right": "r"}
BODY = {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03",
        "Neck": "neck_01", "Head": "Head", "HeadTop_End": "head_end"}
LIMB = {"Shoulder": "clavicle", "Arm": "upperarm", "ForeArm": "lowerarm", "Hand": "hand",
        "UpLeg": "thigh", "Leg": "calf", "Foot": "foot", "ToeBase": "ball", "Toe_End": "toe_end"}
FINGER = {"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Pinky": "pinky"}


def game_name(mixamo: str) -> str:
    n = mixamo.split(":")[-1]
    if n in BODY:
        return BODY[n]
    for side, s in SIDES.items():
        if n.startswith(side):
            rest = n[len(side):]
            if rest in LIMB:
                return f"{LIMB[rest]}_{s}"
            for f, g in FINGER.items():
                if rest.startswith("Hand" + f):
                    i = int(rest[-1])
                    return f"{g}_0{i}_leaf_{s}" if i == 4 else f"{g}_0{i}_{s}"
    return n


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=RIG)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
rig.name = "Armature"
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

# Retarget: Mixamo's animation files are on its T-pose skeleton, the rig may be in the model's own
# pose (A-pose). Copy every bone's world rotation (and the pelvis's position) from the animation's
# skeleton onto the rig, frame by frame, and bake that as the rig's own clip.
clips = {}
for f in sorted(Path(ANIM_DIR).glob("*.fbx")):
    before = set(bpy.data.objects)
    acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=str(f))
    src = next((o for o in set(bpy.data.objects) - before if o.type == "ARMATURE"), None)
    new_acts = [a for a in bpy.data.actions if a not in acts_before]
    if src is None or not new_acts:
        print("no animation in", f.name)
        continue
    f0, f1 = (int(x) for x in new_acts[0].frame_range)
    for pb in rig.pose.bones:
        if pb.name not in src.pose.bones:
            continue
        c = pb.constraints.new("COPY_ROTATION")
        c.target, c.subtarget = src, pb.name
        c.target_space = c.owner_space = "WORLD"
        if pb.parent is None:
            c2 = pb.constraints.new("COPY_LOCATION")
            c2.target, c2.subtarget = src, pb.name
            c2.target_space = c2.owner_space = "WORLD"
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    rig.animation_data_create()
    rig.animation_data.action = None
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, only_selected=True, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    act = rig.animation_data.action
    rig.animation_data.action = None
    act.name = f.stem
    act.use_fake_user = True
    clips[f.stem] = act
    for o in set(bpy.data.objects) - before:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in new_acts:
        bpy.data.actions.remove(a)
    for pb in rig.pose.bones:  # back to rest for the next clip
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    print("retargeted", f.stem, f0, f1)

if GRIP_LEFT:
    import math
    for act in clips.values():
        f0, f1 = act.frame_range
        for f in ("Index", "Middle", "Ring", "Pinky", "Thumb"):
            for j in (1, 2, 3):
                if f == "Thumb" and j == 1:
                    continue
                bone = f"mixamorig:LeftHand{f}{j}"
                path = f'pose.bones["{bone}"].rotation_quaternion'
                for fc in [fc for fc in act.fcurves if fc.data_path == path]:
                    act.fcurves.remove(fc)
                ang = math.radians(28 if f == "Thumb" else (62 if j == 1 else 70))
                q = (math.cos(ang / 2), math.sin(ang / 2), 0.0, 0.0)
                for i, v in enumerate(q):
                    fc = act.fcurves.new(path, index=i, action_group=bone)
                    fc.keyframe_points.insert(f0, v)
                    fc.keyframe_points.insert(f1, v)
    print("left hand closed round the bow grip")

# Rename bones, and every animation curve that points at them.
mapping = {b.name: game_name(b.name) for b in rig.data.bones}
for old, new in mapping.items():
    rig.data.bones[old].name = new
for act in clips.values():
    for fc in act.fcurves:
        p = fc.data_path
        if p.startswith('pose.bones["'):
            old = p.split('"')[1]
            if old in mapping:
                fc.data_path = p.replace(f'"{old}"', f'"{mapping[old]}"', 1)
    for g in act.groups:
        if g.name in mapping:
            g.name = mapping[g.name]

for name, (s0, s1) in TRIM.items():
    act = clips.get(name)
    if act is None:
        continue
    f0, f1 = act.frame_range
    a0, a1 = f0 + (f1 - f0) * s0, f0 + (f1 - f0) * s1
    for fc in act.fcurves:
        for k in reversed(list(fc.keyframe_points)):
            if k.co[0] < a0 - 0.01 or k.co[0] > a1 + 0.01:
                fc.keyframe_points.remove(k)
        for k in fc.keyframe_points:
            k.co[0] -= a0 - f0
            k.handle_left[0] -= a0 - f0
            k.handle_right[0] -= a0 - f0
        fc.update()
    act.frame_range = (f0, f0 + (a1 - a0))
    act.use_frame_range = True
    print("trimmed", name, "to frames", round(a0), "-", round(a1))

# In place: the pelvis keeps its bob and dip but not its travel. Its horizontal offsets (bone axes
# x and z; y is up along the spine) are brought to zero at both ends of the clip.
for name, act in clips.items():
    if name not in IN_PLACE:
        continue
    for fc in act.fcurves:
        if fc.data_path != 'pose.bones["pelvis"].location' or fc.array_index == 1:
            continue
        k = fc.keyframe_points
        if len(k) < 2:
            continue
        f0, f1 = k[0].co[0], k[-1].co[0]
        v0, v1 = k[0].co[1], k[-1].co[1]
        for p in k:
            d = v0 + (v1 - v0) * (p.co[0] - f0) / max(f1 - f0, 1e-6)
            p.co[1] -= d
            p.handle_left[1] -= d
            p.handle_right[1] -= d
        fc.update()
        print("in place:", name, "axis", fc.array_index, "travel %.2f" % (v1 - v0))

# One NLA track per clip, so the exporter writes each as its own animation.
ad = rig.animation_data or rig.animation_data_create()
ad.action = None
for name, act in clips.items():
    tr = ad.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, int(act.frame_range[0]), act)
    st.name = name
    tr.mute = False

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_skins=True, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_yup=True, export_apply=False,
                          export_image_format="JPEG", export_image_quality=90)
print("wrote", OUT, "clips:", sorted(clips))
