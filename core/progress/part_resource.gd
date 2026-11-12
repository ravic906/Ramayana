class_name PartResource
extends Resource
## One episodic Part of the journey (usually one kanda). See data/parts/*.tres.

@export var id := &"part_01"
@export var number := 1
@export var title := "The Prince of Ayodhya"
@export var kanda := "Bala Kanda"
@export_multiline var synopsis := ""
## Scene that starts this Part.
@export_file("*.tscn") var scene_path := ""
## Content pack for Parts shipped as downloads ("" = built into the app).
@export var pack_file := ""
@export var pack_size := 0
@export var pack_sha256 := ""
## Store product that unlocks this Part on its own ("" for free Parts).
@export var product_id := ""
@export var price_label := ""
@export var free := false
## False while the Part is still in development ("Coming soon").
@export var released := false
@export var cover_color := Color(0.85, 0.55, 0.2)


func is_shipped_in_app() -> bool:
	return pack_file.is_empty()
