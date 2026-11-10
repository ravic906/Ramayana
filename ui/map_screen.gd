class_name MapScreen
extends CanvasLayer
## The level map, drawn as aged parchment: the area from above, the story
## objective (gold), side quests (silver), pickups, the way onward, Rama's
## arrow and Lakshmana. Drag to pan, pinch or +/- to zoom, tap a quest marker
## to track it.

const PARCHMENT := """
shader_type canvas_item;
uniform float vignette = 0.55;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 sepia = mix(vec3(0.36, 0.25, 0.14), vec3(0.96, 0.88, 0.7), l);
	vec3 col = mix(sepia, c.rgb, 0.28);
	float n = hash(floor(UV * 420.0)) * 0.06;
	vec2 d = UV - 0.5;
	float v = 1.0 - vignette * smoothstep(0.25, 0.75, length(d) * 1.2);
	COLOR = vec4(col * v - n, 1.0);
}
"""

var map: MapResource
var zoom := 1.0
var pan := Vector2.ZERO
var _image: TextureRect
var _overlay: Control
var _frame: Control
var _touches := {}
var _pinch_start := 0.0
var _zoom_start := 1.0


static func open(host: Node, scene_path: String) -> MapScreen:
	var m := MapResource.for_level(scene_path)
	if m == null:
		return null
	var s := MapScreen.new()
	s.map = m
	host.add_child(s)
	return s


func _ready() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.045, 0.03, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = 60
	_frame.offset_right = -360
	_frame.offset_top = 110
	_frame.offset_bottom = -40
	_frame.clip_contents = true
	_frame.gui_input.connect(_on_input)
	add_child(_frame)
	_image = TextureRect.new()
	_image.texture = map.image
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PARCHMENT
	sm.shader = sh
	_image.material = sm
	_frame.add_child(_image)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_markers)
	_frame.add_child(_overlay)
	var title := PartCard._label(map.title, 44, Color(1, 0.85, 0.5), false)
	title.position = Vector2(60, 30)
	add_child(title)
	var side := VBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -330
	side.offset_right = -40
	side.offset_top = 30
	side.add_theme_constant_override(&"separation", 14)
	add_child(side)
	var close := _button("Close")
	close.pressed.connect(queue_free)
	side.add_child(close)
	var zrow := HBoxContainer.new()
	zrow.add_theme_constant_override(&"separation", 14)
	side.add_child(zrow)
	for spec in [["+", 1.3], ["-", 1.0 / 1.3]]:
		var b := _button(spec[0])
		b.custom_minimum_size = Vector2(130, 72)
		var f: float = spec[1]
		b.pressed.connect(func() -> void: set_zoom(zoom * f))
		zrow.add_child(b)
	for spec in [[Color(1.0, 0.78, 0.25), "Story objective"], [Color(0.6, 0.85, 1.0), "Tracked quest"],
			[Color(0.82, 0.86, 0.95), "Side quest"], [Color(0.85, 0.95, 0.75), "Something to find"],
			[Color(0.95, 0.65, 0.35), "The way onward"], [Color(0.45, 0.65, 1.0), "Rama"], [Color(0.95, 0.55, 0.3), "Lakshmana"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var swatch := ColorRect.new()
		swatch.color = spec[0]
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(PartCard._label(spec[1], 22, Color(0.92, 0.88, 0.8), false))
		side.add_child(row)
	_center_on_rama.call_deferred()


func _process(_delta: float) -> void:
	_layout()
	_overlay.queue_redraw()


func _layout() -> void:
	var fs := _frame.size
	var tex := map.image.get_size() if map.image else Vector2(1, 1)
	var fit := minf(fs.x / tex.x, fs.y / tex.y)
	_image.size = tex * fit * zoom
	_image.position = fs * 0.5 - _image.size * 0.5 + pan


func set_zoom(z: float) -> void:
	zoom = clampf(z, 1.0, 4.0)
	_clamp_offset()


func _center_on_rama() -> void:
	set_zoom(1.6)
	var r := get_tree().get_first_node_in_group(&"player") as Node3D
	if r:
		_layout()
		var p := to_screen(r.global_position)
		pan -= p - _frame.size * 0.5
		_clamp_offset()


func _clamp_offset() -> void:
	_layout()
	var limit := (_image.size - _frame.size).max(Vector2.ZERO) * 0.5
	pan = pan.clamp(-limit, limit)


## World point -> position inside the map frame.
func to_screen(p: Vector3) -> Vector2:
	return _image.position + map.to_uv(p) * _image.size


func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 2:
				_pinch_start = (_touches.values()[0] as Vector2).distance_to(_touches.values()[1])
				_zoom_start = zoom
		else:
			if _touches.size() == 1:
				_tap(t.position)
			_touches.erase(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() == 2 and _pinch_start > 1.0:
			var dist := (_touches.values()[0] as Vector2).distance_to(_touches.values()[1])
			set_zoom(_zoom_start * dist / _pinch_start)
		else:
			pan += d.relative
			_clamp_offset()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom * 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom / 1.15)
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom * (event as InputEventMagnifyGesture).factor)


## Tapping a side-quest marker tracks that quest.
func _tap(at: Vector2) -> void:
	for n in get_tree().get_nodes_in_group(&"nav_markers"):
		var m := n as NavMarker
		if m and m.quest_id != &"" and m.is_shown() and to_screen(m.global_position).distance_to(at) < 36.0:
			if Quests.is_active(m.quest_id):
				Quests.tracked = m.quest_id
			return


func _draw_markers() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var from := player.global_position if player else Vector3.INF
	var font := _overlay.get_theme_default_font()
	for n in get_tree().get_nodes_in_group(&"nav_markers"):
		var m := n as NavMarker
		if m == null or not m.is_shown(from):
			continue
		var p := to_screen(m.global_position)
		var r := 14.0 if m.is_tracked() else 10.0
		var c := m.color()
		var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		_overlay.draw_colored_polygon(pts, c)
		pts.append(pts[0])
		_overlay.draw_polyline(pts, Color(0.15, 0.08, 0.03), 2.5)
		if m.label != "" and (m.is_tracked() or m.kind != NavMarker.Kind.PICKUP):
			_overlay.draw_string(font, p + Vector2(r + 6, 7), m.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.15, 0.08, 0.03))
	var l := get_tree().get_first_node_in_group(&"companions") as Node3D
	if l:
		_overlay.draw_circle(to_screen(l.global_position), 8.0, Color(0.95, 0.55, 0.3))
	if player:
		var p := to_screen(player.global_position)
		var fwd := Vector3.FORWARD
		if player.has_method("get_facing"):
			fwd = player.get_facing()
		var dir := Vector2(fwd.x, fwd.z).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2(0, -1)
		var side := Vector2(-dir.y, dir.x)
		var arrow := PackedVector2Array([p + dir * 20.0, p - dir * 12.0 + side * 12.0, p - dir * 5.0, p - dir * 12.0 - side * 12.0])
		_overlay.draw_colored_polygon(arrow, Color(0.45, 0.65, 1.0))
		arrow.append(arrow[0])
		_overlay.draw_polyline(arrow, Color(0.05, 0.08, 0.2), 2.5)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(290, 72)
	b.add_theme_font_size_override(&"font_size", 28)
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(st, PartCard._style(Color(0.35, 0.22, 0.12), PartCard.GOLD, 3, 12))
	b.add_theme_color_override(&"font_color", Color(1, 0.96, 0.88))
	return b
