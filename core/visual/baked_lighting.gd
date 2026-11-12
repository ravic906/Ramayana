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


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var path := baked_data
	if path == "" and owner and owner.scene_file_path != "":
		path = owner.scene_file_path.get_basename() + ".lmbake"  # the baker's naming
	if light_data == null and path != "" and ResourceLoader.exists(path):
		light_data = load(path)
	var fill := environment_custom_color * environment_custom_energy * fill_strength
	if environment_mode != LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR:
		fill = Color(0.45, 0.45, 0.5)
	RenderingServer.global_shader_parameter_set(&"gi_fill", Color(fill.r, fill.g, fill.b, 1.0))


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		RenderingServer.global_shader_parameter_set(&"gi_fill", Color(0, 0, 0, 1))
