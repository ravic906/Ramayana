extends SceneTree
## Builds the wild animals from Quaternius' CC0 "Ultimate Animated Animals"
## (glTF; see assets/CREDITS.md).
##
## Usage (from the project root):
##   godot --headless -s res://tools/build_animals.gd -- <folder with Deer.gltf, Stag.gltf, Bull.gltf>
##
## Output: res://characters/animals/model/<name>.scn, each a rigged model with
## an AnimationPlayer holding the clips the game uses, PBR-style materials with
## the pack's colours (slightly muted) and generated LODs.

const OUT_DIR := "res://characters/animals/model/"
const ANIMALS := ["Deer", "Stag", "Bull"]
## Source clip -> game name.
const CLIPS := {
	"Idle": "idle", "Idle_Headlow": "graze", "Eating": "eat", "Walk": "walk",
	"Gallop": "run", "Idle_HitReact1": "startle", "Attack_Headbutt": "charge_hit",
}
const LOOPING := ["idle", "graze", "eat", "walk", "run"]
## Real-world size (the pack is about 3x): spotted deer ~1.5 m to the ear tip,
## a sambar stag ~1.9 m with antlers, a wild bull (gaur) ~1.75 m.
const SCALE := {"deer": 0.34, "stag": 0.42, "bull": 0.38}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <folder>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ok := true
	for animal: String in ANIMALS:
		ok = _build(args[0].path_join(animal + ".gltf"), animal.to_lower()) and ok
	quit(0 if ok else 1)


func _build(path: String, id: String) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		printerr("cannot load ", path)
		return false
	var src := doc.generate_scene(state)
	var root := Node3D.new()
	root.name = id.capitalize()
	for child in src.get_children():
		src.remove_child(child)
		root.add_child(child)
		if child is Node3D:
			(child as Node3D).scale *= SCALE[id]
			(child as Node3D).position *= SCALE[id]
	var tris := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var src_mesh := mi.mesh as ArrayMesh
		var im := ImporterMesh.new()
		for s in src_mesh.get_surface_count():
			var arrays := src_mesh.surface_get_arrays(s)
			for a in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arrays[a] = null
			arrays = _smooth(arrays)
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _material(src_mesh.surface_get_material(s)))
			tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		im.generate_lods(25.0, 60.0, [])
		mi.mesh = im.get_mesh()
	# Animations: keep only what the game uses, under game names.
	var src_player := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	for src_name: String in CLIPS:
		if not src_player.has_animation(src_name):
			continue
		var anim := src_player.get_animation(src_name).duplicate(true) as Animation
		var game_name: String = CLIPS[src_name]
		anim.loop_mode = Animation.LOOP_LINEAR if game_name in LOOPING else Animation.LOOP_NONE
		lib.add_animation(game_name, anim)
	src_player.get_parent().remove_child(src_player)
	src_player.free()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", lib)
	root.add_child(player)
	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_DIR + id + ".scn", ResourceSaver.FLAG_COMPRESS)
	print("Saved %s%s.scn: %s (tris %d, clips %s)" % [OUT_DIR, id, error_string(err), tris, lib.get_animation_list()])
	return err == OK


## Low-poly facets read as toys next to the realistic cast: weld the split
## vertices and recompute smooth normals.
func _smooth(arrays: Array) -> Array:
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.deindex()
	st.index()
	st.generate_normals()
	return st.commit_to_arrays()


## The pack's flat colours become a soft, matte fur material (muted a touch so
## they sit in the realistic look).
func _material(src: Material) -> Material:
	var m := StandardMaterial3D.new()
	var c := Color(0.5, 0.4, 0.3)
	if src is BaseMaterial3D:
		c = (src as BaseMaterial3D).albedo_color
	m.albedo_color = c.lerp(Color(c.get_luminance(), c.get_luminance(), c.get_luminance()), 0.15)
	m.roughness = 0.9
	m.metallic_specular = 0.2
	return m


func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)
