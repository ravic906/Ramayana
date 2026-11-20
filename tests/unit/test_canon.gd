extends TestCase
## The game follows the Valmiki Ramayana (docs/canon): every mission, quest,
## lore leaf and dialogue says where it comes from (`canon`, citing Griffith's
## canto numbers) or is marked `invented`.

const DIRS := ["res://data/missions/part01", "res://data/lore", "res://data/quests", "res://data/dialogue/part01"]
## Book I of Griffith's translation has cantos I-LXXVII, without XXXVII and XXXVIII.
const MISSING := [37, 38]


static func _roman(s: String) -> int:
	var vals := {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}
	var total := 0
	for i in s.length():
		var v: int = vals[s[i]]
		var nxt: int = vals[s[i + 1]] if i + 1 < s.length() else 0
		total += -v if v < nxt else v
	return total


## Every canto number cited as "Griffith XX-XXIV, XLV" in `canon`.
static func cited_cantos(canon: String) -> Array[int]:
	var out: Array[int] = []
	var re := RegEx.create_from_string("Griffith ([IVXL]+(?:[-, ]+[IVXL]+)*)")
	for m in re.search_all(canon):
		var raw: String = m.get_string(1)
		var tokens := RegEx.create_from_string("[IVXL]+").search_all(raw)
		var nums: Array[int] = []
		for t in tokens:
			nums.append(_roman(t.get_string()))
		out.append_array(nums)
	return out


func _resources() -> Array:
	var list := []
	for d: String in DIRS:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".tres"):
				list.append(d + "/" + f)
	return list


func test_every_resource_is_canon_or_invented() -> void:
	var n := 0
	for path: String in _resources():
		var r := load(path)
		if r == null or not ("canon" in r):
			continue
		n += 1
		var has := String(r.canon).strip_edges() != ""
		assert_true(has or r.invented, "%s cites its canon or is marked invented" % path.get_file())
	assert_true(n >= 40, "the canon fields are checked on the missions, lore, quests and dialogues (%d)" % n)


func test_cited_cantos_exist() -> void:
	for path: String in _resources():
		var r := load(path)
		if r == null or not ("canon" in r):
			continue
		for c in cited_cantos(String(r.canon)):
			assert_true(c >= 1 and c <= 77 and not (c in MISSING), "%s cites canto %d, which exists in Book I" % [path.get_file(), c])


func test_the_roman_reader() -> void:
	assert_eq(_roman("XLVIII"), 48)
	assert_eq(_roman("LXVII"), 67)
	assert_eq(cited_cantos("Griffith XX-XXIII, XLV (x)"), [20, 23, 45] as Array[int])


func test_the_reference_exists() -> void:
	for f in ["README.md", "01_bala_kanda.md", "ADDITIONS.md"]:
		assert_true(FileAccess.file_exists("res://docs/canon/" + f), "docs/canon/%s exists" % f)
