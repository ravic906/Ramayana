class_name RealisticBody
extends RefCounted
## The realistic people (characters/people/*, built by tools/build_person.gd)
## replace a character's stylised body when the Realistic look is on. The
## body scene keeps the stylised body's layout (Body/Armature/Skeleton3D,
## Body/AnimationPlayer), so the character's code runs unchanged; props
## authored for the stylised body are shifted by the skeleton's
## "ref_offsets" meta (see PropBatch).


## Swaps `model`'s "Body" child for the scene at `path` (call from _enter_tree,
## before @onready variables resolve). Returns true if swapped.
static func apply(model: Node3D, path: String) -> bool:
	if path == "" or Engine.is_editor_hint() or not ResourceLoader.exists(path):
		return false
	var settings := model.get_node_or_null("/root/Settings")
	if settings and not settings.is_realistic():
		return false
	var old := model.get_node_or_null("Body")
	if old == null or old.has_meta(&"realistic_swapped"):
		return false
	var body := (load(path) as PackedScene).instantiate() as Node3D
	body.name = "Body"
	body.transform = old.transform
	body.set_meta(&"realistic_swapped", true)
	var at := old.get_index()
	model.remove_child(old)
	old.free()
	model.add_child(body)
	model.move_child(body, at)
	return true


static func is_realistic(skeleton: Skeleton3D) -> bool:
	return skeleton != null and skeleton.has_meta(&"realistic")


## Where a prop authored for the stylised body belongs on this one.
static func adjust(skeleton: Skeleton3D, bone: String, rest_xf: Transform3D) -> Transform3D:
	if skeleton == null or not skeleton.has_meta(&"ref_offsets"):
		return rest_xf
	var off: Dictionary = skeleton.get_meta(&"ref_offsets")
	return Transform3D(rest_xf.basis, rest_xf.origin + off.get(bone, Vector3.ZERO))
