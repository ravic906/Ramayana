class_name BakedLighting
extends LightmapGI
## A level's baked lighting (LightmapGI: bounce light and occlusion baked by
## tools/bake_lightmaps.sh; the sun stays real time for shadows).
##
## Engine quirk (Godot 4.7, Mobile renderer): batched foliage (MultiMesh) gets
## no light from the lightmap's probes and would render black on its shaded
## side. Foliage shaders add the global `gi_fill` instead, which this node sets
## to the bake's ambient (the colour the bake used for the sky) while the level
## runs, and clears when it leaves.

## Share of the bake's ambient given to foliage.
@export var fill_strength := 0.85
## The baked data (.lmbake). Loaded here, on the main thread, rather than
## as part of the level's scene: loaded inside the scene's threaded load it
## can deadlock the renderer (seen on the Sarayu road with Godot 4.7).
@export_file("*.lmbake") var baked_data := ""

var _env: Node


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var path := baked_data
	if path == "" and owner and owner.scene_file_path != "":
		path = owner.scene_file_path.get_basename() + ".lmbake"  # the baker's naming
	if light_data == null and path != "" and ResourceLoader.exists(path):
		light_data = load(path)
	# Everything outside the level's environment (characters, props, arrows,
	# effects) is lit by the light probes: a geometry left "static" without a
	# lightmap slot would get no ambient light at all.
	_env = get_parent().get_node_or_null("Environment")
	for gi: GeometryInstance3D in get_parent().find_children("*", "GeometryInstance3D", true, false):
		_make_dynamic(gi)
	get_tree().node_added.connect(_on_node_added)
	var fill := environment_custom_color * environment_custom_energy * fill_strength
	if environment_mode != LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR:
		fill = Color(0.45, 0.45, 0.5)
	RenderingServer.global_shader_parameter_set(&"gi_fill", Color(fill.r, fill.g, fill.b, 1.0))


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		RenderingServer.global_shader_parameter_set(&"gi_fill", Color(0, 0, 0, 1))


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D and is_inside_tree() and get_parent().is_ancestor_of(node):
		_make_dynamic(node)


func _make_dynamic(gi: GeometryInstance3D) -> void:
	if _env and _env.is_ancestor_of(gi):
		return
	if gi.gi_mode == GeometryInstance3D.GI_MODE_STATIC:
		gi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
