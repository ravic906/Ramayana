class_name Compass
extends Control
## A slim compass along the top of the screen. Cardinal points turn with the
## camera; NavMarkers slide along it with their distance in metres. Markers
## behind the view wait at the edge with an arrow.

const SPAN_DEG := 75.0   # half the angle the bar covers
const BAR_H := 46.0

var _font: Font
var _markers: Array[Node] = []
var _refresh := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_markers = get_tree().get_nodes_in_group(&"nav_markers")
	queue_redraw()


## Where on the bar (0..1, or <0 / >1 when outside the span) a world point is.
static func bar_position(cam_xform: Transform3D, point: Vector3) -> float:
	var fwd := -cam_xform.basis.z
	fwd.y = 0.0
	var to := point - cam_xform.origin
	to.y = 0.0
	if fwd.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return 0.5
	var ang := rad_to_deg(fwd.normalized().signed_angle_to(to.normalized(), Vector3.DOWN))
	return 0.5 + ang / (2.0 * SPAN_DEG)


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var w := size.x
	var y0 := 4.0
	draw_rect(Rect2(0, y0, w, BAR_H), Color(0.06, 0.04, 0.03, 0.45))
	draw_line(Vector2(0, y0 + BAR_H), Vector2(w, y0 + BAR_H), Color(0.83, 0.65, 0.23, 0.7), 2.0)
	var xf := cam.global_transform
	# Cardinal and intermediate ticks.
	for i in 8:
		var deg := i * 45.0
		var dir := Vector3(sin(deg_to_rad(deg)), 0, -cos(deg_to_rad(deg)))
		var t := bar_position(xf, xf.origin + dir * 100.0)
		if t < 0.0 or t > 1.0:
			continue
		var x := t * w
		var main := i % 2 == 0
		draw_line(Vector2(x, y0 + BAR_H - (14 if main else 8)), Vector2(x, y0 + BAR_H), Color(1, 0.92, 0.75, 0.9), 2.0)
		if main:
			var letter: String = ["N", "E", "S", "W"][i / 2]
			draw_string(_font, Vector2(x - 8, y0 + 24), letter, HORIZONTAL_ALIGNMENT_CENTER, 16, 22, Color(1, 0.93, 0.78))
	# Markers.
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var from := player.global_position if player else xf.origin
	# Distances only for the story objective and the nearest tracked marker.
	var nearest: NavMarker = null
	var nearest_d := INF
	for n in _markers:
		if is_instance_valid(n) and (n as NavMarker) and (n as NavMarker).kind != NavMarker.Kind.MAIN \
				and (n as NavMarker).is_tracked() and (n as NavMarker).is_shown(from):
			var d := from.distance_to((n as NavMarker).global_position)
			if d < nearest_d:
				nearest_d = d
				nearest = n
	for n in _markers:
		if not is_instance_valid(n):
			continue
		var m := n as NavMarker
		if m == null or not m.is_shown(from):
			continue
		var t := bar_position(xf, m.global_position)
		var edge := t < 0.0 or t > 1.0
		var x := clampf(t, 0.02, 0.98) * w
		var c := m.color()
		var big := m.is_tracked()
		var r := 11.0 if big else 7.0
		var cy := y0 + BAR_H * 0.55
		var diamond := PackedVector2Array([Vector2(x, cy - r), Vector2(x + r, cy), Vector2(x, cy + r), Vector2(x - r, cy)])
		draw_colored_polygon(diamond, c)
		diamond.append(diamond[0])
		draw_polyline(diamond, Color(0.1, 0.06, 0.03), 2.0)
		if edge:
			var s := -1.0 if t < 0.0 else 1.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + s * (r + 10), cy), Vector2(x + s * (r + 2), cy - 6), Vector2(x + s * (r + 2), cy + 6)]), c)
		if m.kind == NavMarker.Kind.MAIN or m == nearest:
			var dist := int(round(from.distance_to(m.global_position)))
			draw_string(_font, Vector2(x - 40, y0 + BAR_H + 22), "%d m" % dist, HORIZONTAL_ALIGNMENT_CENTER, 80, 20, c)
