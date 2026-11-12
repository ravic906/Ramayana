extends TestCase
## Every skinned mesh of every character follows its skeleton (Godot 4.4+
## no longer defaults MeshInstance3D.skeleton to the parent; a mesh with no
## skeleton renders in its bind pose, arms out).

const SCENES := [
	"res://characters/rama/rama.tscn",
	"res://characters/npc/vishvamitra.tscn",
	"res://characters/npc/npc_woman.tscn",
	"res://characters/enemies/rakshasa/rakshasa_grunt.tscn",
	"res://characters/animals/model/deer.scn",
	"res://characters/animals/model/bull.scn",
]


func test_every_skinned_mesh_resolves_its_skeleton() -> void:
	for path: String in SCENES:
		if not ResourceLoader.exists(path):
			continue
		var n := (load(path) as PackedScene).instantiate()
		add_child(n)
		var count := 0
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.skin == null:
				continue
			count += 1
			assert_true(mi.get_node_or_null(mi.skeleton) is Skeleton3D, "%s: %s follows its skeleton" % [path.get_file(), mi.name])
		assert_true(count > 0, "%s has skinned meshes" % path.get_file())
		n.free()
