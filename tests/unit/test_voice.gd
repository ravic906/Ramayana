extends TestCase
## Spoken lines: every subtitle has a voice, cutscenes speak and move on.


func after_each() -> void:
	Voice.stop()
	Music.voice_duck(false)


func test_every_dialogue_line_is_voiced() -> void:
	var missing := []
	for f in DirAccess.get_files_at("res://data/dialogue/part01"):
		if not f.ends_with(".tres"):
			continue
		var d := load("res://data/dialogue/part01/" + f) as DialogueResource
		for i in d.line_count():
			var line := d.get_line(i)
			if line["speaker"] != "" and line["text"] != "" and not Voice.has_line(line["speaker"], line["text"]):
				missing.append("%s: %s" % [f, line["text"]])
	assert_eq(missing, [], "run tools/gen_voices.py after editing dialogue")


func test_call_outs_are_voiced() -> void:
	for pair in [["Lakshmana", "Rakshasas, brother! Real ones, this time."], ["Rama", "Go. Do not return."],
			["Lakshmana", "Mercy is also dharma, brother."]]:
		assert_true(Voice.has_line(pair[0], pair[1]), pair[1])


func test_key_matches_the_generator() -> void:
	# tools/gen_voices.py: md5("Speaker|text")
	assert_eq(Voice.key("Rama", "Go. Do not return."), "d3855805e100361dff7c18f7f975c710")


func test_say_plays_and_ducks_the_music() -> void:
	var seconds := Voice.say("Rama", "Go. Do not return.")
	assert_true(seconds > 0.5, "returns the line's length")
	assert_true(Voice.speaking)
	assert_true(Music.voice_ducked, "music dips under the voice")
	assert_eq(Voice.say("Lakshmana", "Mercy is also dharma, brother.", false), 0.0, "call-outs don't interrupt")
	Voice.stop()
	assert_false(Music.voice_ducked)
	assert_eq(Voice.say("Nobody", "Unknown line"), 0.0, "unvoiced lines are silent")


func test_cutscene_moves_on_when_the_voice_ends() -> void:
	var d := DialogueResource.new()
	d.lines = PackedStringArray(["Rama|||Go. Do not return.", "Lakshmana|||Mercy is also dharma, brother."])
	var c := Cutscene.play(self, d)
	await get_tree().process_frame
	assert_eq(c.index, 0)
	assert_true(Voice.speaking, "the line is spoken")
	var waited := 0.0
	while c.index == 0 and waited < 5.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	assert_eq(c.index, 1, "advanced by itself after the line")
	c.skip()
	await get_tree().process_frame
	assert_false(Voice.speaking, "skip silences the voice")
