extends SceneTree
## One-off migration (Godot 4.3 -> 4.7): skinned meshes saved by 4.3 left
## MeshInstance3D.skeleton at its old default ("..") unsaved; newer Godot's
## default is empty, so the mesh stopped following its skeleton (T-pose).
## Sets the path explicitly and resaves each character scene.
##   godot --headless -s res://tools/fix_skeleton_paths.gd

const SCENES := [
	"res://characters/rama/model/rama_body.scn",
	"res://characters/npc/model/woman_body.scn",
	"res://characters/animals/model/deer.scn",
	"res://characters/animals/model/stag.scn",
	"res://characters/animals/model/bull.scn",
]


func _initialize() -> void:
	var failed := 0
	for path: String in SCENES:
		var root := (load(path) as PackedScene).instantiate()
		var fixed := 0
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if mi.skin and mi.get_parent() is Skeleton3D and mi.get_node_or_null(mi.skeleton) == null:
				mi.skeleton = NodePath("..")
				fixed += 1
		var packed := PackedScene.new()
		var err := packed.pack(root)
		if err == OK:
			err = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
		print("%s: %d meshes fixed, %s" % [path, fixed, error_string(err)])
		failed += int(err != OK)
		root.free()
	quit(failed)
