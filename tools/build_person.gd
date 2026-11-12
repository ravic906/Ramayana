extends SceneTree
## Turns a person exported by tools/mpfb_export.py (MakeHuman / MPFB2, CC0)
## into a game-ready body scene with the same layout as rama_body.scn:
##
##   <Name>Body / Armature / Skeleton3D / Body, Eyes, Eyebrows, Eyelashes,
##                                         Teeth, Tongue, HeadAttachment
##             / AnimationPlayer  (the game's animation library)
##
##   godot --headless -s res://tools/build_person.gd -- <person.glb> <name>
##
## The MPFB "game_engine" skeleton has the same bones as the game's
## (UE-style names); its rest orientations are set to the game skeleton's,
## so every clip in the library plays unchanged. The pelvis height track is
## scaled to the person's height. Face units (ARKit names) stay as blend
## shapes on every face mesh; FaceController drives them. Textures are saved
## as PNG beside the scene; materials are the game's own (skin, eye, hair).

const REFERENCE := "res://characters/rama/model/rama_body.scn"
const OUT_DIR := "res://characters/people/"
const RENAME := {"Root": "root", "head": "Head"}
## Each bone's primary child: the direction the bone points.
const CHAIN := {
	"pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01",
	"neck_01": "Head",
	"clavicle_l": "upperarm_l", "upperarm_l": "lowerarm_l", "lowerarm_l": "hand_l", "hand_l": "middle_01_l",
	"clavicle_r": "upperarm_r", "upperarm_r": "lowerarm_r", "lowerarm_r": "hand_r", "hand_r": "middle_01_r",
	"thigh_l": "calf_l", "calf_l": "foot_l", "foot_l": "ball_l",
	"thigh_r": "calf_r", "calf_r": "foot_r", "foot_r": "ball_r",
	"index_01_l": "index_02_l", "index_02_l": "index_03_l", "middle_01_l": "middle_02_l", "middle_02_l": "middle_03_l",
	"ring_01_l": "ring_02_l", "ring_02_l": "ring_03_l", "pinky_01_l": "pinky_02_l", "pinky_02_l": "pinky_03_l",
	"thumb_01_l": "thumb_02_l", "thumb_02_l": "thumb_03_l",
	"index_01_r": "index_02_r", "index_02_r": "index_03_r", "middle_01_r": "middle_02_r", "middle_02_r": "middle_03_r",
	"ring_01_r": "ring_02_r", "ring_02_r": "ring_03_r", "pinky_01_r": "pinky_02_r", "pinky_02_r": "pinky_03_r",
	"thumb_01_r": "thumb_02_r", "thumb_02_r": "thumb_03_r",
}
## Per person: complexion, inner glow (Rama's luminous skin), eye colour.
## Rama: dusky blue-dark, "shyama", the colour of rain clouds.
const PEOPLE := {
	"rama": {"complexion": Color(0.25, 0.22, 0.27), "glow": 0.06, "eyes": "brown", "hair": Color(0.03, 0.025, 0.025)},
	"lakshmana": {"complexion": Color(0.44, 0.31, 0.23), "glow": 0.0, "eyes": "brown", "hair": Color(0.035, 0.026, 0.02)},
	"vishvamitra": {"complexion": Color(0.42, 0.29, 0.21), "glow": 0.0, "eyes": "brown", "hair": Color(0.72, 0.7, 0.66), "beard": 0.13},
	"vasishtha": {"complexion": Color(0.47, 0.33, 0.24), "glow": 0.0, "eyes": "brownlight", "hair": Color(0.86, 0.85, 0.82), "beard": 0.2},
	"dasharatha": {"complexion": Color(0.48, 0.34, 0.25), "glow": 0.0, "eyes": "brown", "hair": Color(0.55, 0.53, 0.5), "beard": 0.05},
}
const SKIN_SHADER := "res://assets/shaders/skin.gdshader"
const DETAIL_NORMAL := "res://characters/rama/model/textures/rama_skin_normal.png"
var person_name := ""
const PARTS := {"body": "Body", "high-poly": "Eyes", "low-poly": "Eyes", "eyebrow": "Eyebrows",
	"eyelashes": "Eyelashes", "teeth": "Teeth", "tongue": "Tongue", "long01": "Hair"}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <person.glb> <name>")
		quit(1)
		return
	var err := build(args[0], args[1])
	quit(0 if err == OK else 1)


func build(glb: String, person: String) -> Error:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(glb, state)
	if err != OK:
		printerr("Cannot read ", glb)
		return err
	var src := doc.generate_scene(state)
	var sk_src: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var ref_scene := (load(REFERENCE) as PackedScene).instantiate()
	var sk_ref: Skeleton3D = ref_scene.find_children("*", "Skeleton3D", true, false)[0]
	var ref_anim: AnimationPlayer = ref_scene.get_node("AnimationPlayer")

	person_name = person
	var dir := OUT_DIR + person + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	# New tree, rama_body.scn's layout.
	var root := Node3D.new()
	root.name = person.to_pascal_case() + "Body"
	var armature := Node3D.new()
	armature.name = "Armature"
	root.add_child(armature)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	armature.add_child(sk)

	# Bones. MakeHuman rests its limbs at different angles from the game's
	# skeleton, and the animation library assumes the game's rest shape. So
	# the body is first posed into that shape (each bone turned to point the
	# way the reference bone points), the mesh and its face shapes are baked
	# in that pose, and the new rests take the reference orientations.
	var old_global := {}
	for i in sk_src.get_bone_count():
		var bname: String = RENAME.get(sk_src.get_bone_name(i), sk_src.get_bone_name(i))
		sk.add_bone(bname)
		old_global[bname] = sk_src.get_bone_global_rest(i)
	for i in sk_src.get_bone_count():
		var p := sk_src.get_bone_parent(i)
		if p >= 0:
			sk.set_bone_parent(i, p)
	var delta := {}   # bone -> rotation applied to it (world), in rest space
	var posed := {}   # bone -> posed origin
	for i in sk.get_bone_count():  # parents come first (glTF order)
		var bname := sk.get_bone_name(i)
		var p := sk.get_bone_parent(i)
		var parent_rot := Basis()
		var origin: Vector3 = (old_global[bname] as Transform3D).origin
		if p >= 0:
			var pname := sk.get_bone_name(p)
			parent_rot = delta[pname]
			origin = (posed[pname] as Vector3) + parent_rot * (origin - (old_global[pname] as Transform3D).origin)
		posed[bname] = origin
		var rot := parent_rot
		var child: String = CHAIN.get(bname, "")
		if child != "" and old_global.has(child) and sk_ref.find_bone(child) >= 0 and sk_ref.find_bone(bname) >= 0:
			var cur := parent_rot * ((old_global[child] as Transform3D).origin - (old_global[bname] as Transform3D).origin)
			var want := sk_ref.get_bone_global_rest(sk_ref.find_bone(child)).origin - sk_ref.get_bone_global_rest(sk_ref.find_bone(bname)).origin
			if cur.length() > 0.0001 and want.length() > 0.0001:
				rot = Basis(Quaternion(cur.normalized(), want.normalized())) * parent_rot
		delta[bname] = rot
	var new_global := {}
	var skin_xf := {}  # bone -> rest space -> posed space
	for i in sk.get_bone_count():
		var bname := sk.get_bone_name(i)
		var r := sk_ref.find_bone(bname)
		var g: Transform3D = old_global[bname]
		var basis := sk_ref.get_bone_global_rest(r).basis.orthonormalized() if r >= 0 else (delta[bname] as Basis) * g.basis
		new_global[bname] = Transform3D(basis, posed[bname])
		skin_xf[bname] = Transform3D(delta[bname], posed[bname]) * Transform3D(Basis(), -g.origin)
	for i in sk.get_bone_count():
		var bname := sk.get_bone_name(i)
		var p := sk.get_bone_parent(i)
		var local: Transform3D = new_global[bname]
		if p >= 0:
			local = (new_global[sk.get_bone_name(p)] as Transform3D).affine_inverse() * local
		sk.set_bone_rest(i, local)
	sk.reset_bone_poses()

	# Meshes: baked into the new rest shape, bound to the new rests.
	for mi_src: MeshInstance3D in sk_src.find_children("*", "MeshInstance3D", true, false):
		var part := _part_name(String(mi_src.name))
		if part == "":
			print("skipping ", mi_src.name)
			continue
		var src_skin := mi_src.skin
		var bind_bone := []  # bind index -> bone name
		var bind_xf := []    # bind index -> mesh space -> posed space
		for b in src_skin.get_bind_count():
			var bname: String = String(src_skin.get_bind_name(b))
			if bname == "":
				bname = sk_src.get_bone_name(src_skin.get_bind_bone(b))
			bname = RENAME.get(bname, bname)
			bind_bone.append(bname)
			# bind pose maps mesh space to the old bone space; old global brings
			# it back to rest (skeleton) space; then the repose.
			var to_rest := (old_global[bname] as Transform3D) * src_skin.get_bind_pose(b)
			bind_xf.append((skin_xf[bname] as Transform3D) * to_rest)
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = _repose_mesh(mi_src.mesh as ArrayMesh, bind_xf)
		var skin := Skin.new()
		for b in bind_bone.size():
			var bname: String = bind_bone[b]
			skin.add_named_bind(bname, (new_global[bname] as Transform3D).affine_inverse())
		mi.skin = skin
		sk.add_child(mi)
		mi.skeleton = NodePath("..")
		_save_textures(mi, dir, part)

	var spec: Dictionary = PEOPLE.get(person, {})
	if spec.get("beard", 0.0) > 0.0:
		var body_mi := sk.get_node("Body") as MeshInstance3D
		var beard := _make_beard(body_mi, spec["beard"], new_global["Head"], spec["hair"])
		sk.add_child(beard)
		beard.skeleton = NodePath("..")

	var att := BoneAttachment3D.new()
	att.name = "HeadAttachment"
	att.bone_name = "Head"
	sk.add_child(att)

	# The animation library, with the pelvis height scaled to this body.
	var ratio := (new_global["pelvis"] as Transform3D).origin.y / sk_ref.get_bone_global_rest(sk_ref.find_bone("pelvis")).origin.y
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	for lib_name in ref_anim.get_animation_library_list():
		var lib := AnimationLibrary.new()
		var src_lib := ref_anim.get_animation_library(lib_name)
		for a_name in src_lib.get_animation_list():
			var a := src_lib.get_animation(a_name).duplicate(true) as Animation
			# Only the pelvis (and root) move by position, scaled to this
			# body; every other bone keeps this body's own proportions.
			for t in range(a.get_track_count() - 1, -1, -1):
				if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
					continue
				var bone := String(a.track_get_path(t).get_concatenated_subnames())
				if bone in ["pelvis", "root"]:
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * ratio)
				else:
					a.remove_track(t)
			lib.add_animation(a_name, a)
		anim.add_animation_library(lib_name, lib)

	_own(root, root)
	var packed := PackedScene.new()
	err = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, dir + person + "_body.scn", ResourceSaver.FLAG_COMPRESS)
	print("Saved %s%s_body.scn: %s (pelvis ratio %.3f)" % [dir, person, error_string(err), ratio])
	ref_scene.free()
	src.free()
	return err


## A beard grown from the face's own lower jaw, chin, cheeks and upper lip
## (the skin the jaw and mouth face units move; the lips themselves left
## clear): layered strand shells pushed out along the normals, the lower part
## drawn down into a hanging beard of `length` metres. It keeps the body's
## skinning and the jaw and mouth shapes, so it opens with the jaw.
func _make_beard(body: MeshInstance3D, length: float, head: Transform3D, color: Color) -> MeshInstance3D:
	var mesh := body.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per := bones.size() / verts.size()
	var shape_arrays := mesh.surface_get_blend_shape_arrays(0)
	var shape_names := []
	for i in mesh.get_blend_shape_count():
		shape_names.append(String(mesh.get_blend_shape_name(i)))
	var moved := func(name: String, v: int) -> float:
		var i := shape_names.find(name)
		return 0.0 if i < 0 else ((shape_arrays[i][Mesh.ARRAY_VERTEX] as PackedVector3Array)[v] - verts[v]).length()
	# Landmarks in model space (Y up), measured on this face: the mouth
	# centre from the lips (the vertices mouthPucker moves most), the facing
	# direction from mouth vs head, the chin's lowest point.
	var mouth := Vector3.ZERO
	var lip_n := 0
	for v in verts.size():
		if moved.call("mouthPucker", v) > 0.006:
			mouth += verts[v]
			lip_n += 1
	mouth /= maxf(lip_n, 1)
	var fwd := signf(mouth.z - head.origin.z)
	var chin := mouth.y
	for v in verts.size():
		var r := verts[v] - mouth
		if absf(r.x) < 0.02 and r.z * fwd > -0.022 and r.y < 0.0 and r.y > -0.09 and moved.call("jawOpen", v) > 0.003:
			chin = minf(chin, verts[v].y)
	var mask := PackedByteArray()
	mask.resize(verts.size())
	var top := mouth.y + 0.018
	var bottom := chin
	for v in verts.size():
		var r := verts[v] - mouth
		var depth := r.z * fwd  # + in front of the mouth
		var e := Vector2(r.x / 0.03, r.y / 0.012)
		var on_lips := e.length() < 1.0 and depth > -0.02
		var take := r.y < 0.018 and r.y > (chin - mouth.y) - 0.06 and absf(r.x) < 0.075 and depth > -0.1 and not on_lips
		# the cheeks up to the cheekbones, at the sides only
		if not take and absf(r.x) > 0.04 and absf(r.x) < 0.075 and r.y < 0.04 and r.y >= 0.018 and depth > -0.07 and depth < -0.01:
			take = true
		mask[v] = 1 if take else 0
	var tris := []
	for t in range(0, index.size(), 3):
		if mask[index[t]] and mask[index[t + 1]] and mask[index[t + 2]]:
			tris.append(t)
	var layers := [0.003, 0.007, 0.012]
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	var out_i := PackedInt32Array()
	var keep_shapes := ["jawOpen", "jawLeft", "jawRight", "jawForward", "mouthSmileLeft", "mouthSmileRight",
		"mouthFrownLeft", "mouthFrownRight", "mouthStretchLeft", "mouthStretchRight", "mouthFunnel",
		"mouthPucker", "mouthPressLeft", "mouthPressRight", "mouthClose", "mouthUpperUpLeft", "mouthUpperUpRight"]
	var out_shapes := []
	for n in keep_shapes:
		out_shapes.append([])  # plain Arrays: packed arrays inside an Array copy on write
	var down := Vector3(0, -1, 0.0)
	for li in layers.size():
		var remap := {}
		for t: int in tris:
			for k in 3:
				var v := index[t + k]
				if not remap.has(v):
					remap[v] = out_v.size()
					var local := verts[v] - mouth
					var lowness := clampf((top - verts[v].y) / maxf(top - bottom, 0.001), 0.0, 1.0)
					# only what lies below the chin hangs; the chin keeps its cover
					var below := clampf((chin + 0.006 - verts[v].y) / 0.02, 0.0, 1.0)
					var hang := Vector3.ZERO  # the long part is made of cards (below)
					var disp: Vector3 = normals[v] * float(layers[li]) + hang
					out_v.append(verts[v] + disp)
					out_n.append(normals[v])
					out_uv.append(Vector2(local.x * 6.0 + li * 0.37, lowness * 0.9 + 0.05))
					# the hanging part comes slightly forward, off the chest
					for k2 in per:
						out_b.append(bones[v * per + k2])
						out_w.append(weights[v * per + k2])
					for si in keep_shapes.size():
						var idx := shape_names.find(keep_shapes[si])
						var p := verts[v] if idx < 0 else (shape_arrays[idx][Mesh.ARRAY_VERTEX] as PackedVector3Array)[v]
						(out_shapes[si] as Array).append(p + disp)
				out_i.append(remap[v])
	# The hanging beard: strand cards along the jaw line (the lowest beard
	# vertex in each slice across the face), longest at the chin, two layers.
	if length > 0.06:
		var bins := 16
		var lowest := []
		lowest.resize(bins)
		lowest.fill(-1)
		for v in verts.size():
			if not mask[v]:
				continue
			var r := verts[v] - mouth
			var bi := int((r.x + 0.075) / 0.15 * bins)
			if bi < 0 or bi >= bins:
				continue
			if r.y > -0.022:
				continue
			# the front edge of the chin and jaw in this slice
			if lowest[bi] < 0 or r.z * fwd > (verts[lowest[bi]] - mouth).z * fwd:
				lowest[bi] = v
		var line := []
		for bi in bins:
			if lowest[bi] >= 0:
				line.append(lowest[bi])
		for layer in 2:
			var base := out_v.size()
			for k in line.size():
				var v: int = line[k]
				var r := verts[v] - mouth
				var taper := 1.0 - pow(absf(r.x) / 0.08, 2.0)
				var len_k := length * clampf(taper, 0.15, 1.0) * (0.88 + 0.24 * fposmod(sin(k * 12.9898 + layer * 4.1) * 43758.5453, 1.0))
				var out := normals[v] * (0.006 + layer * 0.006)
				var top_p := verts[v] + out
				var tip_p := top_p + Vector3(0, -len_k, 0) + Vector3(0, 0, fwd) * len_k * (0.12 + layer * 0.05)
				for end in 2:
					var p := top_p if end == 0 else tip_p
					out_v.append(p)
					out_n.append((normals[v] + Vector3(0, 0, fwd)).normalized())
					out_uv.append(Vector2(r.x * 6.0 + layer * 0.5, 0.05 if end == 0 else 0.97))
					for k2 in per:
						out_b.append(bones[v * per + k2])
						out_w.append(weights[v * per + k2])
					for si in keep_shapes.size():
						var idx := shape_names.find(keep_shapes[si])
						var d := Vector3.ZERO if idx < 0 else (shape_arrays[idx][Mesh.ARRAY_VERTEX] as PackedVector3Array)[v] - verts[v]
						(out_shapes[si] as Array).append(p + d)
			for k in line.size() - 1:
				var i0 := base + k * 2
				out_i.append_array(PackedInt32Array([i0, i0 + 2, i0 + 1, i0 + 2, i0 + 3, i0 + 1]))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = out_v
	a[Mesh.ARRAY_NORMAL] = out_n
	a[Mesh.ARRAY_TEX_UV] = out_uv
	a[Mesh.ARRAY_BONES] = out_b
	a[Mesh.ARRAY_WEIGHTS] = out_w
	a[Mesh.ARRAY_INDEX] = out_i
	var shapes := []
	for si in keep_shapes.size():
		var sa := []
		sa.resize(Mesh.ARRAY_MAX)
		sa[Mesh.ARRAY_VERTEX] = PackedVector3Array(out_shapes[si])
		sa[Mesh.ARRAY_NORMAL] = out_n
		shapes.append(sa)
	var bm := ArrayMesh.new()
	bm.blend_shape_mode = mesh.blend_shape_mode
	for n in keep_shapes:
		bm.add_blend_shape(n)
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
	print("  beard arrays v=%d n=%d uv=%d b=%d w=%d per=%d s0=%d" % [out_v.size(), out_n.size(), out_uv.size(), out_b.size(), out_w.size(), per, (out_shapes[0] as Array).size()])
	bm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, shapes, {}, flags)
	var hm := ShaderMaterial.new()
	hm.shader = load("res://assets/shaders/hair_card.gdshader")
	hm.set_shader_parameter(&"strands_tex", load("res://assets/people/hair/beard_strands.png"))
	hm.set_shader_parameter(&"hair_color", color)
	hm.set_shader_parameter(&"alpha_cut", 0.4)
	bm.surface_set_material(0, hm)
	var mi := MeshInstance3D.new()
	mi.name = "Beard"
	mi.mesh = bm
	mi.skin = body.skin
	print("  beard: %d triangles x %d layers" % [tris.size(), layers.size()])
	return mi


## Linear-blend skins every vertex (and every blend shape's vertices) by
## `bind_xf` (bind index -> mesh space -> reposed space): the mesh in the new
## rest shape. Bones and weights are kept.
func _repose_mesh(src: ArrayMesh, bind_xf: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.blend_shape_mode = src.blend_shape_mode
	for i in src.get_blend_shape_count():
		out.add_blend_shape(src.get_blend_shape_name(i))
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var n := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bones.size() / n
		var xfs: Array[Transform3D] = []
		xfs.resize(n)
		for v in n:
			var m := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
			var total := 0.0
			for k in per:
				var w := weights[v * per + k]
				if w <= 0.0:
					continue
				var t: Transform3D = bind_xf[bones[v * per + k]]
				m.basis.x += t.basis.x * w
				m.basis.y += t.basis.y * w
				m.basis.z += t.basis.z * w
				m.origin += t.origin * w
				total += w
			xfs[v] = m if total > 0.0 else Transform3D()
		arrays = _skin_arrays(arrays, xfs)
		var shapes := []
		for b in src.surface_get_blend_shape_arrays(s):
			shapes.append(_skin_arrays(b, xfs))
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
		out.surface_set_material(s, src.surface_get_material(s))
	return out


func _skin_arrays(arrays: Array, xfs: Array[Transform3D]) -> Array:
	var a := arrays.duplicate()
	var verts := a[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if verts != null and verts.size() == xfs.size():
		verts = verts.duplicate()
		for v in verts.size():
			verts[v] = xfs[v] * verts[v]
		a[Mesh.ARRAY_VERTEX] = verts
	var normals = a[Mesh.ARRAY_NORMAL]
	if normals is PackedVector3Array and (normals as PackedVector3Array).size() == xfs.size():
		var nn := (normals as PackedVector3Array).duplicate()
		for v in nn.size():
			nn[v] = (xfs[v].basis * nn[v]).normalized()
		a[Mesh.ARRAY_NORMAL] = nn
	var tangents = a[Mesh.ARRAY_TANGENT]
	if tangents is PackedFloat32Array and (tangents as PackedFloat32Array).size() == xfs.size() * 4:
		var tt := (tangents as PackedFloat32Array).duplicate()
		for v in xfs.size():
			var t := (xfs[v].basis * Vector3(tt[v * 4], tt[v * 4 + 1], tt[v * 4 + 2])).normalized()
			tt[v * 4] = t.x
			tt[v * 4 + 1] = t.y
			tt[v * 4 + 2] = t.z
		a[Mesh.ARRAY_TANGENT] = tt
	return a


func _part_name(src_name: String) -> String:
	for key: String in PARTS:
		if key in src_name:
			return PARTS[key]
	return ""


## Saves the glTF's embedded textures as PNGs and gives the mesh a material
## that loads them (the game's shaders replace these in the person scene).
func _save_textures(mi: MeshInstance3D, dir: String, part: String) -> void:
	var m := mi.mesh.surface_get_material(0) as StandardMaterial3D
	if m == null or m.albedo_texture == null:
		mi.mesh.surface_set_material(0, StandardMaterial3D.new())
		return
	var img := m.albedo_texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var max_size: int = {"Body": 2048, "Hair": 1024, "Eyes": 512, "Eyebrows": 512, "Eyelashes": 512}.get(part, 256)
	if img.get_width() > max_size:
		img.resize(max_size, max_size * img.get_height() / img.get_width(), Image.INTERPOLATE_LANCZOS)
	var path := dir + part.to_lower() + "_albedo.png"
	img.save_png(path)
	# Reference the saved file once it has been imported (run the build,
	# then --import, then the build again); never embed the image.
	var spec: Dictionary = PEOPLE.get(person_name, PEOPLE["lakshmana"])
	var mat: Material
	if part == "Body":
		var sm := ShaderMaterial.new()
		sm.shader = load(SKIN_SHADER)
		if ResourceLoader.exists(path):
			sm.set_shader_parameter(&"albedo_tex", load(path))
		sm.set_shader_parameter(&"source_avg", _average(img))
		sm.set_shader_parameter(&"complexion", spec["complexion"])
		sm.set_shader_parameter(&"inner_glow", spec["glow"])
		sm.set_shader_parameter(&"detail_normal", load(DETAIL_NORMAL))
		mat = sm
	else:
		var st := StandardMaterial3D.new()
		st.resource_name = part
		var tex_path := path
		if part == "Eyes":
			var em := ShaderMaterial.new()
			em.shader = load("res://assets/shaders/eye.gdshader")
			em.set_shader_parameter(&"albedo_tex", load("res://assets/people/eyes/%s_eye.png" % spec["eyes"]))
			mi.mesh.surface_set_material(0, em)
			print("  eyes: ", spec["eyes"])
			return
		elif part in ["Teeth", "Tongue"]:
			st.roughness = 0.35
		elif part in ["Hair", "Eyebrows", "Eyelashes"]:
			var hm := ShaderMaterial.new()
			hm.shader = load("res://assets/shaders/hair_card.gdshader")
			if ResourceLoader.exists(path):
				hm.set_shader_parameter(&"strands_tex", load(path))
			var hc: Color = spec["hair"]
			if part == "Eyelashes":
				hc = Color(0.03, 0.025, 0.02)
			elif part == "Eyebrows":
				hc = hc.lerp(Color(0.05, 0.04, 0.035), 0.25 if hc.get_luminance() > 0.3 else 0.0)
			hm.set_shader_parameter(&"hair_color", hc)
			hm.set_shader_parameter(&"alpha_cut", 0.35 if part == "Hair" else 0.4)
			mi.mesh.surface_set_material(0, hm)
			return
		if ResourceLoader.exists(tex_path):
			st.albedo_texture = load(tex_path)
		mat = st
	mi.mesh.surface_set_material(0, mat)
	print("  ", path, " ", img.get_size())


## Mean colour of the skin texture (opaque, non-black texels): the skin
## shader divides by it to keep only the texture's detail.
func _average(img: Image) -> Color:
	var small := img.duplicate() as Image
	small.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var sum := Color(0, 0, 0)
	var n := 0
	for y in 64:
		for x in 64:
			var c := small.get_pixel(x, y)
			if c.a > 0.5 and c.get_luminance() > 0.04:
				sum += c
				n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n) if n > 0 else Color(0.5, 0.36, 0.28)


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)
