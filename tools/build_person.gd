extends SceneTree
## Turns a person exported by tools/mpfb_export.py (MakeHuman / MPFB2, CC0)
## into a game-ready body scene with the same layout as rama_body.scn:
##
##   <Name>Body / Armature / Skeleton3D / Body, Eyes, Eyebrows, Eyelashes,
##                                         Teeth, Tongue, HeadAttachment
##             / AnimationPlayer  (the game's animation library)
##
##   godot --headless -s res://tools/build_person.gd -- <person.glb> <name>
##
## The MPFB "game_engine" skeleton has the same bones as the game's
## (UE-style names); its rest orientations are set to the game skeleton's,
## so every clip in the library plays unchanged. The pelvis height track is
## scaled to the person's height. Face units (ARKit names) stay as blend
## shapes on every face mesh; FaceController drives them. Textures are saved
## as PNG beside the scene; materials are the game's own (skin, eye, hair).

const REFERENCE := "res://characters/rama/model/rama_body.scn"
const OUT_DIR := "res://characters/people/"
const RENAME := {"Root": "root", "head": "Head"}
const PARTS := {"body": "Body", "high-poly": "Eyes", "low-poly": "Eyes", "eyebrow": "Eyebrows",
	"eyelashes": "Eyelashes", "teeth": "Teeth", "tongue": "Tongue"}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <person.glb> <name>")
		quit(1)
		return
	var err := build(args[0], args[1])
	quit(0 if err == OK else 1)


func build(glb: String, person: String) -> Error:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(glb, state)
	if err != OK:
		printerr("Cannot read ", glb)
		return err
	var src := doc.generate_scene(state)
	var sk_src: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var ref_scene := (load(REFERENCE) as PackedScene).instantiate()
	var sk_ref: Skeleton3D = ref_scene.find_children("*", "Skeleton3D", true, false)[0]
	var ref_anim: AnimationPlayer = ref_scene.get_node("AnimationPlayer")

	var dir := OUT_DIR + person + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	# New tree, rama_body.scn's layout.
	var root := Node3D.new()
	root.name = person.to_pascal_case() + "Body"
	var armature := Node3D.new()
	armature.name = "Armature"
	root.add_child(armature)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	armature.add_child(sk)

	# Bones: MPFB positions, reference orientations.
	var old_global := {}
	for i in sk_src.get_bone_count():
		var bname: String = RENAME.get(sk_src.get_bone_name(i), sk_src.get_bone_name(i))
		sk.add_bone(bname)
		old_global[bname] = sk_src.get_bone_global_rest(i)
	for i in sk_src.get_bone_count():
		var p := sk_src.get_bone_parent(i)
		if p >= 0:
			sk.set_bone_parent(i, p)
	var new_global := {}
	for i in sk.get_bone_count():
		var bname := sk.get_bone_name(i)
		var g: Transform3D = old_global[bname]
		var r := sk_ref.find_bone(bname)
		var basis := sk_ref.get_bone_global_rest(r).basis.orthonormalized() if r >= 0 else g.basis
		new_global[bname] = Transform3D(basis, g.origin)
	for i in sk.get_bone_count():
		var bname := sk.get_bone_name(i)
		var p := sk.get_bone_parent(i)
		var local: Transform3D = new_global[bname]
		if p >= 0:
			local = (new_global[sk.get_bone_name(p)] as Transform3D).affine_inverse() * local
		sk.set_bone_rest(i, local)
	sk.reset_bone_poses()

	# Meshes: rebind to the new rests, own materials, saved textures.
	for mi_src: MeshInstance3D in sk_src.find_children("*", "MeshInstance3D", true, false):
		var part := _part_name(String(mi_src.name))
		if part == "":
			print("skipping ", mi_src.name)
			continue
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = mi_src.mesh
		var skin := mi_src.skin.duplicate() as Skin
		for b in skin.get_bind_count():
			var bname: String = String(skin.get_bind_name(b))
			if bname == "":
				bname = sk_src.get_bone_name(skin.get_bind_bone(b))
			bname = RENAME.get(bname, bname)
			var old_bind := skin.get_bind_pose(b)
			var g_old: Transform3D = old_global[bname]
			var g_new: Transform3D = new_global[bname]
			skin.set_bind_pose(b, g_new.affine_inverse() * g_old * old_bind)
			skin.set_bind_name(b, bname)
			skin.set_bind_bone(b, sk.find_bone(bname))
		mi.skin = skin
		sk.add_child(mi)
		mi.skeleton = NodePath("..")
		_save_textures(mi, dir, part)

	var att := BoneAttachment3D.new()
	att.name = "HeadAttachment"
	att.bone_name = "Head"
	sk.add_child(att)

	# The animation library, with the pelvis height scaled to this body.
	var ratio := (new_global["pelvis"] as Transform3D).origin.y / sk_ref.get_bone_global_rest(sk_ref.find_bone("pelvis")).origin.y
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	for lib_name in ref_anim.get_animation_library_list():
		var lib := AnimationLibrary.new()
		var src_lib := ref_anim.get_animation_library(lib_name)
		for a_name in src_lib.get_animation_list():
			var a := src_lib.get_animation(a_name).duplicate(true) as Animation
			for t in a.get_track_count():
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * ratio)
			lib.add_animation(a_name, a)
		anim.add_animation_library(lib_name, lib)

	_own(root, root)
	var packed := PackedScene.new()
	err = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, dir + person + "_body.scn", ResourceSaver.FLAG_COMPRESS)
	print("Saved %s%s_body.scn: %s (pelvis ratio %.3f)" % [dir, person, error_string(err), ratio])
	ref_scene.free()
	src.free()
	return err


func _part_name(src_name: String) -> String:
	for key: String in PARTS:
		if key in src_name:
			return PARTS[key]
	return ""


## Saves the glTF's embedded textures as PNGs and gives the mesh a material
## that loads them (the game's shaders replace these in the person scene).
func _save_textures(mi: MeshInstance3D, dir: String, part: String) -> void:
	var m := mi.mesh.surface_get_material(0) as StandardMaterial3D
	if m == null or m.albedo_texture == null:
		mi.mesh.surface_set_material(0, StandardMaterial3D.new())
		return
	var img := m.albedo_texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var max_size: int = {"Body": 2048, "Eyes": 512, "Eyebrows": 512, "Eyelashes": 512}.get(part, 256)
	if img.get_width() > max_size:
		img.resize(max_size, max_size * img.get_height() / img.get_width(), Image.INTERPOLATE_LANCZOS)
	var path := dir + part.to_lower() + "_albedo.png"
	img.save_png(path)
	# Reference the saved file once it has been imported (run the build,
	# then --import, then the build again); never embed the image.
	var mat := StandardMaterial3D.new()
	mat.resource_name = part
	if ResourceLoader.exists(path):
		mat.albedo_texture = load(path)
	if part in ["Eyebrows", "Eyelashes"]:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.mesh.surface_set_material(0, mat)
	print("  ", path, " ", img.get_size())


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)
