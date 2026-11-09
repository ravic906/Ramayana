extends TestCase
## Episodic Parts: catalog, unlock rules, card states, saves and Part packs.

const StoreScript := preload("res://autoload/store.gd")
const GameStateScript := preload("res://autoload/game_state.gd")
const MenuScript := preload("res://ui/journey_menu.gd")


func _store() -> Node:
	var s: Node = StoreScript.new()
	add_child(s)
	s.debug_unlock_all = false
	s.revoke_all()
	return s


func test_catalog_has_eight_parts_in_order() -> void:
	var parts := PartCatalog.all()
	assert_eq(parts.size(), 8)
	var ids := {}
	for i in parts.size():
		assert_eq(parts[i].number, i + 1)
		ids[parts[i].id] = true
		if i > 0:
			assert_false(parts[i].free, "only Part 1 is free")
			assert_true(parts[i].product_id.begins_with("ramayana_part_"))
	assert_eq(ids.size(), 8, "unique ids")
	var first := parts[0]
	assert_true(first.free and first.released and first.is_built_in())
	assert_true(ResourceLoader.exists(first.scene_path), "Part 1 scene exists")
	assert_eq(parts[5].kanda, "Yuddha Kanda I")
	assert_eq(parts[6].kanda, "Yuddha Kanda II")


func test_unlock_rules() -> void:
	var store := _store()
	var gs: Node = GameStateScript.new()
	add_child(gs)
	var p1 := PartCatalog.by_number(1)
	var p3 := PartCatalog.by_number(3)
	var p4 := PartCatalog.by_number(4)
	assert_true(gs.is_part_unlocked(p1, store), "Part 1 free")
	assert_false(gs.is_part_unlocked(p3, store), "Part 3 locked")
	store.grant("ramayana_part_03")
	assert_true(gs.is_part_unlocked(p3, store), "Part 3 bought alone")
	assert_false(gs.is_part_unlocked(p4, store), "Part 4 still locked")
	store.grant(store.FULL_JOURNEY_PRODUCT_ID)
	for part in PartCatalog.all():
		assert_true(gs.is_part_unlocked(part, store), "Full Journey unlocks Part %d" % part.number)


func test_unknown_purchase_rejected() -> void:
	var store := _store()
	var failures := []
	store.purchase_failed.connect(func(id, _r): failures.append(id))
	store.purchase("not_a_product")
	store.purchase("ramayana_part_02")  # no billing backend in tests
	assert_eq(failures, ["not_a_product", "ramayana_part_02"])
	assert_false(store.owns_product("ramayana_part_02"))


func test_card_states() -> void:
	var p1 := PartCatalog.by_number(1)
	var p2 := PartCatalog.by_number(2)
	var released := p2.duplicate() as PartResource
	released.released = true
	assert_eq(MenuScript.card_state(p1, true, true, false), PartCard.State.PLAY)
	assert_eq(MenuScript.card_state(p1, true, true, true), PartCard.State.REPLAY)
	assert_eq(MenuScript.card_state(p2, false, false, false), PartCard.State.COMING_SOON)
	assert_eq(MenuScript.card_state(released, false, false, false), PartCard.State.BUY)
	assert_eq(MenuScript.card_state(released, true, false, false), PartCard.State.DOWNLOAD)
	assert_eq(MenuScript.card_state(released, true, true, false), PartCard.State.PLAY)


func test_v1_save_migrates_to_parts() -> void:
	var gs: Node = GameStateScript.new()
	add_child(gs)
	gs.from_dict({"version": 1, "current_kanda": 5, "punya": 40})
	assert_eq(gs.current_part, 6, "Yuddha -> Part 6")
	assert_eq(gs.punya, 40)
	gs.from_dict({"version": 1, "current_kanda": 6})
	assert_eq(gs.current_part, 8, "Uttara -> Part 8")


func test_part_progress_round_trip() -> void:
	var gs: Node = GameStateScript.new()
	add_child(gs)
	gs.set_part(2)
	gs.complete_part(&"part_01")
	var copy: Node = GameStateScript.new()
	add_child(copy)
	copy.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	assert_eq(copy.current_part, 2)
	assert_true(copy.is_part_completed(&"part_01"))
	assert_false(copy.is_part_completed(&"part_02"))


func test_final_trial_advances_to_the_sage() -> void:
	GameState.completed_parts.clear()
	GameState.current_mission = 1
	var level: Node = load("res://kandas/01_bala/training_grounds.tscn").instantiate()
	var spawner: WaveSpawner = level.get_node("WaveSpawner")
	spawner.auto_start = false
	spawner.waves.clear()
	spawner.waves.append(PackedStringArray(["grunt"]))
	add_child(level)
	spawner.spawn_wave(0)
	for r in spawner.alive.duplicate():
		r.health.take_damage(10000.0)
	await get_tree().physics_frame
	assert_eq(GameState.current_mission, 2, "on to The Sage at the Gate")
	assert_false(GameState.is_part_completed(&"part_01"), "Part 1 continues past the trials")
	level.queue_free()
	GameState.current_mission = 0
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)
	GameState.completed_parts.clear()


func test_part_pack_mounts() -> void:
	# Build a tiny content pack exactly like a downloadable Part would ship.
	DirAccess.make_dir_recursive_absolute(PartLoader.PARTS_DIR)
	var scene_src := "user://test_part_scene.tscn"
	var f := FileAccess.open(scene_src, FileAccess.WRITE)
	f.store_string('[gd_scene format=3]\n\n[node name="TestPart" type="Node3D"]\n')
	f.close()
	var part := PartResource.new()
	part.id = &"part_test"
	part.pack_file = "part_test.pck"
	part.scene_path = "res://test_parts/part_test.tscn"
	var packer := PCKPacker.new()
	assert_eq(packer.pck_start(PartLoader.pack_path(part)), OK)
	assert_eq(packer.add_file(part.scene_path, scene_src), OK)
	assert_eq(packer.flush(), OK)
	part.pack_size = FileAccess.open(PartLoader.pack_path(part), FileAccess.READ).get_length()
	part.pack_sha256 = FileAccess.get_sha256(PartLoader.pack_path(part))

	assert_true(PartLoader.is_installed(part))
	assert_true(PartLoader.verify(PartLoader.pack_path(part), part), "size + checksum")
	assert_true(PartLoader.mount(part), "pack mounted")
	var scene := load(part.scene_path) as PackedScene
	assert_true(scene != null and scene.instantiate().name == "TestPart")
	var bad := part.duplicate() as PartResource
	bad.pack_sha256 = "0".repeat(64)
	assert_false(PartLoader.verify(PartLoader.pack_path(part), bad), "bad checksum rejected")
	DirAccess.remove_absolute(PartLoader.pack_path(part))
	DirAccess.remove_absolute(scene_src)
