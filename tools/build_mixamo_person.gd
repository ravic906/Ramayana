extends SceneTree
## Builds a game body scene from a GLB made by tools/mixamo_to_glb.py (a Mixamo-rigged character
## with its Mixamo animations, bones already renamed to the game's names):
##
##   <Name>Body / Armature / Skeleton3D / Body (mesh), HeadAttachment (EyeL, EyeR)
##             / AnimationPlayer  (the character's own Mixamo clips)
##
##   godot --headless -s res://tools/build_mixamo_person.gd -- <in.glb> <name> [texture_dir]
##
## texture_dir (res://) holds the model's full-detail maps: body_albedo.png, body_normal.png,
## body_rm.png (roughness in green). Marks the skeleton like tools/build_person.gd does
## ("realistic", "ref_offsets"), so props authored for the old body land in the same places.

const REFERENCE := "res://characters/rama/model/rama_body.scn"
const OUT_DIR := "res://characters/people/"
const LOOPS := ["idle", "walk", "walk_formal", "run", "aim_idle", "sit", "kneel", "sit_talk", "talk"]
## Game clip names the code asks for that Mixamo has no separate clip for.
const ALIASES := {"walk_formal": "walk", "interact": "strike"}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <in.glb> <name> [texture_dir]")
		quit(1)
		return
	quit(0 if build(args[0], args[1], args[2] if args.size() > 2 else "") == OK else 1)


func build(glb: String, person: String, tex_dir: String) -> Error:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(glb, state)
	if err != OK:
		printerr("Cannot read ", glb)
		return err
	var src := doc.generate_scene(state)
	var sk_src: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var mi_src: MeshInstance3D = sk_src.find_children("*", "MeshInstance3D", true, false)[0]
	var ap_src: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var dir := OUT_DIR + person + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var root := Node3D.new()
	root.name = person.to_pascal_case() + "Body"
	var armature := Node3D.new()
	armature.name = "Armature"
	root.add_child(armature)
	# Keep the skeleton's place in the model (glTF may put a rotation on the armature node).
	var xf := Transform3D()
	var n: Node = sk_src
	while n != src:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	# Bake that transform into the skeleton (root bones' rests), so the skeleton's space is the
	# model's space, as on every other body: props authored in model space then land right.
	armature.transform = Transform3D()
	var sk := sk_src.duplicate() as Skeleton3D
	var roots := []
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) < 0:
			sk.set_bone_rest(i, xf * sk.get_bone_rest(i))
			roots.append(sk.get_bone_name(i))
	sk.reset_bone_poses()
	for c in sk.get_children():
		sk.remove_child(c)
		c.free()
	sk.name = "Skeleton3D"
	sk.transform = Transform3D()
	armature.add_child(sk)

	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mi_src.mesh
	mi.skin = mi_src.skin
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	mi.mesh.surface_set_material(0, _material(mi_src, dir, tex_dir))

	# Animations: paths re-rooted to Armature/Skeleton3D, loops set, aliases added.
	var lib := AnimationLibrary.new()
	for lib_name in ap_src.get_animation_library_list():
		var src_lib := ap_src.get_animation_library(lib_name)
		for a_name in src_lib.get_animation_list():
			var a := src_lib.get_animation(a_name).duplicate(true) as Animation
			for t in a.get_track_count():
				var path := a.track_get_path(t)
				var bone := String(path.get_concatenated_subnames())
				if bone != "":
					a.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone))
				if bone in roots:  # root bone keys are in the old (rotated) frame
					for k in a.track_get_key_count(t):
						var v = a.track_get_key_value(t, k)
						if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
							a.track_set_key_value(t, k, xf * (v as Vector3))
						elif a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
							a.track_set_key_value(t, k, xf.basis.get_rotation_quaternion() * (v as Quaternion))
			if String(a_name) in LOOPS:
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(a_name, a)
	for alias: String in ALIASES:
		if not lib.has_animation(alias) and lib.has_animation(ALIASES[alias]):
			lib.add_animation(alias, lib.get_animation(ALIASES[alias]))
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	anim.add_animation_library("", lib)
	print("  clips: ", lib.get_animation_list())

	# Marks for the game, as tools/build_person.gd sets them: props authored for the reference
	# body are moved by each bone's offset from the reference skeleton.
	var ref_scene := (load(REFERENCE) as PackedScene).instantiate()
	var sk_ref: Skeleton3D = ref_scene.find_children("*", "Skeleton3D", true, false)[0]
	var offsets := {}
	for i in sk.get_bone_count():
		var bname := sk.get_bone_name(i)
		var r := sk_ref.find_bone(bname)
		if r >= 0:
			offsets[bname] = _model_rest(sk, i, armature) - sk_ref.get_bone_global_rest(r).origin
	sk.set_meta(&"realistic", true)
	sk.set_meta(&"ref_offsets", offsets)

	# Head attachment with eye markers (the cutscene framer aims close-ups at them): the
	# reference eyes, moved with the head.
	var head := sk.find_bone("Head")
	var att := BoneAttachment3D.new()
	att.name = "HeadAttachment"
	att.bone_name = "Head"
	sk.add_child(att)
	var ref_head := sk_ref.get_bone_global_rest(sk_ref.find_bone("Head"))
	var new_head := sk.get_bone_global_rest(head)
	for eye in ["EyeL", "EyeR"]:
		var ref_eye := ref_scene.find_child(eye, true, false) as Node3D
		var m := Node3D.new()
		m.name = eye
		att.add_child(m)
		if ref_eye:
			var ref_global := ref_head * ref_eye.transform
			var global := Transform3D(Basis(), offsets.get("Head", Vector3.ZERO)) * ref_global
			m.transform = new_head.affine_inverse() * Transform3D(new_head.basis, global.origin)

	_own(root, root)
	var packed := PackedScene.new()
	err = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, dir + person + "_body.scn", ResourceSaver.FLAG_COMPRESS)
	print("Saved %s%s_body.scn: %s" % [dir, person, error_string(err)])
	ref_scene.free()
	src.free()
	return err


## A bone's rest position in the model's space (what the props are authored in).
func _model_rest(sk: Skeleton3D, bone: int, armature: Node3D) -> Vector3:
	return sk.get_bone_global_rest(bone).origin


func _material(mi_src: MeshInstance3D, dir: String, tex_dir: String) -> Material:
	var gm := StandardMaterial3D.new()
	var src_m := mi_src.mesh.surface_get_material(0) as StandardMaterial3D
	for key in ["albedo", "normal", "rm"]:
		var path := dir + "body_%s.png" % key
		var from := tex_dir.path_join("body_%s.png" % key) if tex_dir != "" else ""
		if from != "" and FileAccess.file_exists(from) and from != path:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(path))
		elif not FileAccess.file_exists(path) and key == "albedo" and src_m and src_m.albedo_texture:
			src_m.albedo_texture.get_image().save_png(path)
		if not ResourceLoader.exists(path):
			continue  # run the build, then --import, then the build again
		match key:
			"albedo":
				gm.albedo_texture = load(path)
			"normal":
				gm.normal_enabled = true
				gm.normal_texture = load(path)
			"rm":
				gm.roughness_texture = load(path)
				gm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	gm.roughness = 1.0
	gm.metallic_specular = 0.3
	gm.rim_enabled = true
	gm.rim = 0.12
	gm.rim_tint = 0.6
	return gm


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)
