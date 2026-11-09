extends SceneTree
## Builds Rama's rigged body from the CC0 Quaternius source packs.
##
## Source packs (CC0, free "Standard" versions; see assets/CREDITS.md):
##   - Universal Base Characters [Standard]
##   - Universal Animation Library [Standard]
##
## Usage (from the project root):
##   godot --headless -s res://tools/build_rama.gd -- <UBC folder> <UAL1_Standard.glb>
##
## Output: res://characters/rama/model/rama_body.scn, a Skeleton3D-rigged body with
## the outfit painted into vertex colours, long hair on the head bone, toon
## materials and an AnimationPlayer holding only the clips the game uses.

const OUT_SCENE := "res://characters/rama/model/rama_body.scn"

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
}
const LOOPING := ["idle", "walk", "run"]

## Outfit regions, painted as pure 0/1 channel masks. The actual colours live
## in assets/materials/rama_body.tres (region_* uniforms):
const SKIN := Color(0, 0, 0)         # region_base: Rama's cloud-blue skin
const PITAMBARA := Color(1, 0, 0)    # region_r: yellow silk dhoti
const GOLD_TRIM := Color(0, 1, 0)    # region_g: zari border and waistband
const UTTARIYA := Color(0, 0, 1)     # region_b: saffron sash

const MAT_DIR := "res://assets/materials/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <UBC folder> <UAL1_Standard.glb>")
		quit(2)
		return
	var ubc: String = args[0]
	var body := _load_gltf(ubc.path_join("Base Characters/Godot - UE/Superhero_Male_FullBody.gltf"))
	var hair_src := _load_gltf(ubc.path_join("Hairstyles/Origin at 0/glTF (Godot)/Hair_Long.gltf"))
	var anims_src := _load_gltf(args[1])
	if body == null or hair_src == null or anims_src == null:
		quit(1)
		return

	var root := Node3D.new()
	root.name = "RamaBody"
	var armature: Node3D = body.get_node("Armature")
	body.remove_child(armature)
	root.add_child(armature)
	var skeleton: Skeleton3D = armature.get_node("Skeleton3D")

	# --- Body: paint outfit + toon material ---------------------------------
	var body_mi: MeshInstance3D = skeleton.get_node("SuperHero_Male")
	body_mi.name = "Body"
	body_mi.mesh = _with_lods(_paint_outfit(body_mi.mesh as ArrayMesh, skeleton), load(MAT_DIR + "rama_body.tres"))

	var eyes: MeshInstance3D = skeleton.get_node("Eyes")
	eyes.mesh.surface_set_material(0, load(MAT_DIR + "rama_eyes.tres"))
	var brows: MeshInstance3D = skeleton.get_node("Eyebrows")
	brows.mesh.surface_set_material(0, load(MAT_DIR + "rama_hair.tres"))  # double-sided dark

	# --- Hair on the head bone ------------------------------------------------
	var head_att := BoneAttachment3D.new()
	head_att.name = "HeadAttachment"
	head_att.bone_name = "Head"
	skeleton.add_child(head_att)
	var hair_mi: MeshInstance3D = hair_src.find_children("*", "MeshInstance3D", true, false)[0]
	var hair := MeshInstance3D.new()
	hair.name = "Hair"
	hair.mesh = _with_lods(hair_mi.mesh as ArrayMesh, load(MAT_DIR + "rama_hair.tres"))
	# The hair is modelled in place (origin at 0), so undo the head's rest transform.
	hair.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()
	head_att.add_child(hair)
	# Beard (hidden; sages and kings in cutscenes show it via NpcModel).
	var beard_src := _load_gltf(ubc.path_join("Hairstyles/Origin at 0/glTF (Godot)/Hair_Beard.gltf"))
	if beard_src:
		var beard_mi: MeshInstance3D = beard_src.find_children("*", "MeshInstance3D", true, false)[0]
		var beard := MeshInstance3D.new()
		beard.name = "Beard"
		beard.mesh = _with_lods(beard_mi.mesh as ArrayMesh, load(MAT_DIR + "rama_hair.tres"))
		beard.transform = hair.transform
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
		err = ResourceSaver.save(packed, OUT_SCENE, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s: %s (body tris: %d, LOD levels: %d)" % [OUT_SCENE, error_string(err),
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
