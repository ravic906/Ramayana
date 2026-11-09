class_name PartCatalog
extends RefCounted
## Ordered list of all Parts. Paths are listed explicitly because exported
## builds rename resource files (directory scans are unreliable there).

const PATHS: Array[String] = [
	"res://data/parts/part_01_bala.tres",
	"res://data/parts/part_02_ayodhya.tres",
	"res://data/parts/part_03_aranya.tres",
	"res://data/parts/part_04_kishkindha.tres",
	"res://data/parts/part_05_sundara.tres",
	"res://data/parts/part_06_yuddha_bridge.tres",
	"res://data/parts/part_07_yuddha_war.tres",
	"res://data/parts/part_08_uttara.tres",
]

static var _cache: Array[PartResource] = []


static func all() -> Array[PartResource]:
	if _cache.is_empty():
		for path in PATHS:
			var part := load(path) as PartResource
			if part:
				_cache.append(part)
		_cache.sort_custom(func(a: PartResource, b: PartResource) -> bool: return a.number < b.number)
	return _cache


static func get_part(id: StringName) -> PartResource:
	for part in all():
		if part.id == id:
			return part
	return null


static func by_number(number: int) -> PartResource:
	for part in all():
		if part.number == number:
			return part
	return null


## Kanda index (0 = Bala ... 6 = Uttara) -> Part number. Yuddha Kanda is
## split across Parts 6 and 7, so it maps to its first Part.
static func part_number_for_kanda(kanda_index: int) -> int:
	const MAP := [1, 2, 3, 4, 5, 6, 8]
	return MAP[clampi(kanda_index, 0, MAP.size() - 1)]
