extends SceneTree
## Headless test runner.
##   godot --headless --import
##   godot --headless -s res://tests/run_tests.gd
## Exits with code 1 if any test fails.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	# Run after the first frame so autoloads are ready.
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR.path_join(file))
		if script == null or not script.can_instantiate():
			failed += 1  # a test file that doesn't compile must not pass silently
			printerr("  FAIL  %s - does not compile" % file)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			root.add_child(test)
			test.before_each()
			await test.call(name)
			test.after_each()
			var failures := test.get_failures()
			if failures.is_empty():
				passed += 1
				print("  PASS  %s::%s" % [file, name])
			else:
				failed += 1
				for f in failures:
					printerr("  FAIL  %s::%s - %s" % [file, name, f])
			test.queue_free()
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
