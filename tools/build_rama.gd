extends SceneTree
## Builds Rama's rigged body from the CC0 Quaternius source packs.
##
## Source packs (CC0, free "Standard" versions; see assets/CREDITS.md):
##   - Universal Base Characters [Standard]
##   - Universal Animation Library [Standard]
##
## Usage (from the project root):
##   godot --headless -s res://tools/build_rama.gd -- <UBC folder> <UAL1_Standard.glb> [female]
## With "female": the woman's body for NPCs (Ahalya, townswomen, later Sita),
## written to res://characters/npc/model/woman_body.scn with a sari painted in.
##
## Output: res://characters/rama/model/rama_body.scn, a Skeleton3D-rigged body with
## the outfit painted into vertex colours, long hair on the head bone, toon
## materials and an AnimationPlayer holding only the clips the game uses.

const OUT_SCENE := "res://characters/rama/model/rama_body.scn"
const OUT_FEMALE := "res://characters/npc/model/woman_body.scn"
## The pack's long hair was modelled on the man's head; this fits it to the woman's.
var FEMALE_HAIR_FIT := Transform3D(Basis().scaled(Vector3(0.95, 0.95, 0.95)), Vector3(0, 1.657, 0.025)) * Transform3D(Basis(), -Vector3(0, 1.70, 0.03))
var female := false

## Source clip name -> name used in game.
const CLIPS := {
	"Idle_Loop": "idle",
	"Walk_Loop": "walk",
	"Jog_Fwd_Loop": "run",
	"Roll": "roll",
	"Spell_Simple_Shoot": "shoot",
	"Hit_Chest": "hit",
	"Sword_Attack": "strike",
	"Death01": "death",
	# Story staging (cutscenes): sitting at the camp, kneeling at the water, talking.
	"Sitting_Enter": "sit_down",
	"Sitting_Idle_Loop": "sit",
	"Sitting_Talking_Loop": "sit_talk",
	"Sitting_Exit": "stand_up",
	"Fixing_Kneeling": "kneel",
	"Idle_Talking_Loop": "talk",
	"Walk_Formal_Loop": "walk_formal",
	"Interact": "interact",
}
const LOOPING := ["idle", "walk", "run", "sit", "sit_talk", "kneel", "talk", "walk_formal"]

## Outfit regions, painted as pure 0/1 channel masks. The actual colours live
## in assets/materials/rama_body.tres (region_* uniforms):
const SKIN := Color(0, 0, 0)         # region_base: Rama's cloud-blue skin
const PITAMBARA := Color(1, 0, 0)    # region_r: yellow silk dhoti
const GOLD_TRIM := Color(0, 1, 0)    # region_g: zari border and waistband
const UTTARIYA := Color(0, 0, 1)     # region_b: saffron sash

const MAT_DIR := "res://assets/materials/"
const FaceRig := preload("res://tools/face_rig_builder.gd")
const HairBuilder := preload("res://tools/hair_builder.gd")
const Garments := preload("res://tools/garment_builder.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <UBC folder> <UAL1_Standard.glb>")
		quit(2)
		return
	var ubc: String = args[0]
	female = args.size() > 2 and args[2] == "female"
	FaceRig.L = FaceRig.FEMALE if female else FaceRig.MALE
	var body := _load_gltf(ubc.path_join("Base Characters/Godot - UE/Superhero_%s_FullBody.gltf" % ("Female" if female else "Male")))
	var hair_src := _load_gltf(ubc.path_join("Hairstyles/Origin at 0/glTF (Godot)/Hair_Long.gltf"))
	var anims_src := _load_gltf(args[1])
	if body == null or hair_src == null or anims_src == null:
		quit(1)
		return

	var root := Node3D.new()
	root.name = "WomanBody" if female else "RamaBody"
	var armature: Node3D = body.get_node("Armature")
	body.remove_child(armature)
	root.add_child(armature)
	var skeleton: Skeleton3D = armature.get_node("Skeleton3D")

	# --- Body: paint outfit + toon material ---------------------------------
	var body_mi: MeshInstance3D = null
	for n in skeleton.get_children():
		if n is MeshInstance3D and String(n.name).to_lower().begins_with("superhero"):
			body_mi = n
	body_mi.name = "Body"
	var body_mat: Material = load(MAT_DIR + "rama_body.tres")
	var painted := (_paint_skin(body_mi.mesh as ArrayMesh) if female else _paint_outfit(body_mi.mesh as ArrayMesh, skeleton)).surface_get_arrays(0)
	# --- Face rig (see tools/face_rig_builder.gd) ---------------------------------
	var head_binds := []
	var skin := body_mi.skin
	var head_bone := skeleton.find_bone("Head")
	for b in skin.get_bind_count():
		if skin.get_bind_bone(b) == head_bone or String(skin.get_bind_name(b)) == "Head":
			head_binds.append(b)
	var parts: Array = FaceRig.split_head(painted, head_binds)
	var body_only := ArrayMesh.new()
	body_only.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, parts[0])
	body_mi.mesh = _with_lods(body_only, body_mat)
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = FaceRig.head_mesh(parts[1], body_mat)
	head.skin = skin
	skeleton.add_child(head)
	head.skeleton = NodePath("..")
	if female:
		_add_garments(skeleton, body_mi, parts[0], body_mat)
		var scalp_m := ArrayMesh.new()
		var eye_y: float = (FaceRig.L.corner as Vector3).y + 0.072
		scalp_m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Garments.scalp(parts[1], eye_y, float(FaceRig.L.front_z)))
		scalp_m.surface_set_material(0, load(MAT_DIR + "rama_hair.tres"))
		var scalp_mi := MeshInstance3D.new()
		scalp_mi.name = "Scalp"
		scalp_mi.mesh = scalp_m
		scalp_mi.skin = skin
		skeleton.add_child(scalp_mi)
		scalp_mi.skeleton = NodePath("..")

	var eyes: MeshInstance3D = skeleton.get_node("Eyes")
	var eye_arrays := (eyes.mesh as ArrayMesh).surface_get_arrays(0)
	skeleton.remove_child(eyes)
	eyes.free()
	var brows: MeshInstance3D = skeleton.get_node("Eyebrows")
	brows.mesh = FaceRig.brow_mesh((brows.mesh as ArrayMesh).surface_get_arrays(0), load(MAT_DIR + "rama_hair.tres"))

	# --- Head attachment: eyes, lids, mouth, hair ---------------------------------
	var head_att := BoneAttachment3D.new()
	head_att.name = "HeadAttachment"
	head_att.bone_name = "Head"
	skeleton.add_child(head_att)
	var head_rest_inv := skeleton.get_bone_global_rest(head_bone).affine_inverse()
	for pair in FaceRig.split_eyes(eye_arrays, load(MAT_DIR + "rama_eyes.tres")):
		var c: Vector3 = pair[0]
		var pivot := Node3D.new()
		pivot.name = "EyeL" if c.x > 0.0 else "EyeR"   # the character's own left is +X
		pivot.transform = head_rest_inv * Transform3D(Basis(), c)
		head_att.add_child(pivot)
		var ball := MeshInstance3D.new()
		ball.name = "Ball"
		ball.mesh = pair[1]
		pivot.add_child(ball)
		var lid := MeshInstance3D.new()
		lid.name = "UpperLid"
		lid.mesh = FaceRig.lid_mesh(body_mat)
		lid.rotation.x = deg_to_rad(FaceRig.LID_OPEN_DEG)
		pivot.add_child(lid)
	var mouth := FaceRig.mouth_interior()
	mouth.transform = head_rest_inv * Transform3D(Basis().scaled(mouth.scale), Vector3(0.0, float(FaceRig.L.lip_y) - 0.0049, float(FaceRig.L.front_z) - 0.0232))
	head_att.add_child(mouth)
	var hair_mi: MeshInstance3D = hair_src.find_children("*", "MeshInstance3D", true, false)[0]
	var hair_mat: Material = load(MAT_DIR + "rama_hair.tres")
	# The hair is modelled in place (origin at 0), so undo the head's rest transform.
	var hair_xf := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()
	var hair := MeshInstance3D.new()
	hair.name = "Hair"
	var long_mesh := hair_mi.mesh as ArrayMesh
	if female:
		# A bun, gathered at the nape; the long hair refitted for her head.
		long_mesh = _transformed(long_mesh, FEMALE_HAIR_FIT)
		var cap_f := _load_gltf(ubc.path_join("Hairstyles/Origin at 0/glTF (Godot)/Hair_SimpleParted.gltf"))
		var cap_fm := _transformed((cap_f.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh as ArrayMesh, FEMALE_HAIR_FIT)
		hair.mesh = _with_lods(Garments.gathered_hair(long_mesh, cap_fm, Vector3(0, 1.625, -0.085)), hair_mat)
	else:
		# Hair gathered into the crown, face open, curled locks (tools/hair_builder.gd).
		var cap_src := _load_gltf(ubc.path_join("Hairstyles/Origin at 0/glTF (Godot)/Hair_SimpleParted.gltf"))
		var cap_mi: MeshInstance3D = cap_src.find_children("*", "MeshInstance3D", true, false)[0]
		hair.mesh = _with_lods(HairBuilder.build(long_mesh, cap_mi.mesh as ArrayMesh, null), hair_mat)
	hair.transform = hair_xf
	head_att.add_child(hair)
	# The long loose hair: sages, the king, rakshasas (NpcModel.long_hair).
	var hair_long := MeshInstance3D.new()
	hair_long.name = "HairLong"
	hair_long.mesh = _with_lods(long_mesh, hair_mat)
	hair_long.transform = hair_xf
	hair_long.visible = false
	head_att.add_child(hair_long)
	# Beard (hidden; sages and kings in cutscenes show it via NpcModel).
	var beard_src := _load_gltf(ubc.path_join("Hairstyles/Origin at 0/glTF (Godot)/Hair_Beard.gltf")) if not female else null
	if beard_src:
		var beard_mi: MeshInstance3D = beard_src.find_children("*", "MeshInstance3D", true, false)[0]
		var beard := MeshInstance3D.new()
		beard.name = "Beard"
		beard.mesh = _with_lods(beard_mi.mesh as ArrayMesh, hair_mat)
		beard.transform = hair_xf
		beard.visible = false
		head_att.add_child(beard)

	# --- Animations -------------------------------------------------------------
	var src_player: AnimationPlayer = anims_src.get_node("AnimationPlayer")
	var lib := AnimationLibrary.new()
	for src_name: String in CLIPS:
		var anim := src_player.get_animation(src_name).duplicate(true) as Animation
		var game_name: String = CLIPS[src_name]
		anim.loop_mode = Animation.LOOP_LINEAR if game_name in LOOPING else Animation.LOOP_NONE
		lib.add_animation(game_name, anim)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", lib)
	root.add_child(player)

	# --- Save -------------------------------------------------------------------
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_FEMALE.get_base_dir()))
		err = ResourceSaver.save(packed, OUT_FEMALE if female else OUT_SCENE, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s: %s (body tris: %d, LOD levels: %d)" % [OUT_FEMALE if female else OUT_SCENE, error_string(err),
		_tri_count(body_mi.mesh), _lod_count(body_mi.mesh)])
	quit(0 if err == OK else 1)


func _load_gltf(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		printerr("Failed to load %s: %s" % [path, error_string(err)])
		return null
	return doc.generate_scene(state)


## Returns a copy of the mesh with the outfit painted into vertex colours,
## decided from each vertex's rest-pose position relative to the skeleton.
func _paint_outfit(src: ArrayMesh, skeleton: Skeleton3D) -> ArrayMesh:
	var y_of := func(bone: String) -> float:
		return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin.y
	var waist: float = y_of.call("spine_01") - 0.055   # dhoti tied just below the navel
	var ankle: float = y_of.call("foot_l") + 0.03
	var shoulder_l := Vector2(0.15, y_of.call("clavicle_l") - 0.01)
	var hip_r := Vector2(-0.17, waist + 0.02)

	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var c := SKIN
		if v.y < waist and v.y > ankle:
			c = PITAMBARA
			if v.y > waist - 0.035 or v.y < ankle + 0.035:
				c = GOLD_TRIM
		elif v.y >= waist and v.y < shoulder_l.y + 0.03 and absf(v.x) < 0.2:
			# Uttariya: a diagonal band from the left shoulder to the right hip.
			if _dist_to_segment(Vector2(v.x, v.y), shoulder_l, hip_r) < 0.06:
				c = UTTARIYA
		colors[i] = c
	arrays[Mesh.ARRAY_COLOR] = colors
	# Drop extra UV/colour channels the game never uses.
	for extra in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[extra] = null

	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_tangents()
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	return out


## The mesh of a loaded glTF scene with its node transforms baked in (some
## pack files are in centimetres under a rotated node).
func _baked(scene_root: Node) -> ArrayMesh:
	var mi: MeshInstance3D = scene_root.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != scene_root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return _transformed(mi.mesh as ArrayMesh, xf)


func _transformed(src: ArrayMesh, xf: Transform3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in src.get_surface_count():
		st.append_from(src, s, xf)
	return st.commit()


## The woman's skin everywhere: her clothes are geometry (_add_garments).
func _paint_skin(src: ArrayMesh) -> ArrayMesh:
	var arrays := src.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(SKIN)
	arrays[Mesh.ARRAY_COLOR] = colors
	for extra in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[extra] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_tangents()
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	return out


## A sari as geometry (tools/garment_builder.gd): the cloth over the torso and
## upper arms, and the draped skirt, both skinned like the body.
func _add_garments(skeleton: Skeleton3D, body_mi: MeshInstance3D, body_arrays: Array, material: Material) -> void:
	var y_of := func(bone: String) -> float:
		return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin.y
	var waist: float = y_of.call("spine_01") - 0.03
	var shoulder: float = y_of.call("clavicle_l")
	var elbow_x: float = absf(skeleton.get_bone_global_rest(skeleton.find_bone("lowerarm_l")).origin.x)
	var ankle: float = y_of.call("foot_l") + 0.04
	# The hips' half-widths, from the body at the top of the skirt.
	var v: PackedVector3Array = body_arrays[Mesh.ARRAY_VERTEX]
	var hx := 0.0
	var hz_front := 0.0
	var hz_back := 0.0
	for p in v:
		if absf(p.y - (waist - 0.08)) < 0.03:
			hx = maxf(hx, absf(p.x))
			hz_front = maxf(hz_front, p.z)
			hz_back = maxf(hz_back, -p.z)
	var skin := body_mi.skin
	var binds := {}
	for b in ["pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
		binds[b] = Garments.bind_of(skin, skeleton, b)
	var m := ArrayMesh.new()
	var shell := Garments.torso_shell(body_arrays, waist, shoulder, lerpf(0.18, elbow_x, 0.45))
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shell)
	var skirt := Garments.skirt(waist, ankle, Vector2(hx + 0.015, maxf(hz_front, hz_back) + 0.02), maxf(hx + 0.13, 0.3), binds)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, skirt)
	var garment := MeshInstance3D.new()
	garment.name = "Garment"
	garment.mesh = m
	for s in m.get_surface_count():
		m.surface_set_material(s, material)
	garment.skin = skin
	skeleton.add_child(garment)
	garment.skeleton = NodePath("..")


## The woman's outfit, a sari: R the lower drape (waist to ankle), G the zari
## border (hem, waist and the blouse's edge), B the blouse and the pallu over
## the left shoulder; the base (skin) elsewhere, with a little of the midriff.
func _paint_sari(src: ArrayMesh, skeleton: Skeleton3D) -> ArrayMesh:
	var y_of := func(bone: String) -> float:
		return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin.y
	var waist: float = y_of.call("spine_01") - 0.03
	var ankle: float = y_of.call("foot_l") + 0.03
	var blouse_low: float = y_of.call("spine_03") - 0.03
	var shoulder: float = y_of.call("clavicle_l") + 0.02
	var pallu_a := Vector2(0.14, shoulder)
	var pallu_b := Vector2(-0.16, waist + 0.02)
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var c := SKIN
		if v.y < waist and v.y > ankle:
			c = PITAMBARA
			if v.y < ankle + 0.05 or v.y > waist - 0.025:
				c = GOLD_TRIM
		elif v.y >= blouse_low and v.y < shoulder and absf(v.x) < 0.17:
			c = UTTARIYA  # the blouse
			if v.y < blouse_low + 0.015:
				c = GOLD_TRIM
		elif v.y >= waist and v.y < shoulder + 0.02 and absf(v.x) < 0.2 \
				and _dist_to_segment(Vector2(v.x, v.y), pallu_a, pallu_b) < 0.07:
			c = UTTARIYA  # the pallu across the body to the left shoulder
		colors[i] = c
	arrays[Mesh.ARRAY_COLOR] = colors
	for extra in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[extra] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_tangents()
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	return out


## Rebuilds `src` with automatically generated LODs so distant characters are
## cheap on phones. Every surface gets `material`.
func _with_lods(src: ArrayMesh, material: Material) -> ArrayMesh:
	var im := ImporterMesh.new()
	for s in src.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s), [], {}, material)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


func _lod_count(mesh: ArrayMesh) -> int:
	var rs := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	return (rs.get("lods", []) as Array).size()


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _tri_count(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		total += idx.size() / 3
	return total


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)
