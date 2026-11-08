extends CanvasLayer
## Grey-box HUD: health, punya counter and touch controls.

@export var player_path: NodePath

@onready var health_bar: ProgressBar = %HealthBar
@onready var punya_label: Label = %PunyaLabel
@onready var hint_label: Label = %HintLabel
@onready var reticle: Reticle = %Reticle
@onready var vignette: ColorRect = %Vignette
@onready var perfect_label: Label = %PerfectLabel
@onready var shoot_button: ActionButton = %ShootButton

var _player: Node
var _draw := 0.0
var _perfect := false
var _aim_weight := 0.0


func _ready() -> void:
	var player := get_node_or_null(player_path)
	_player = player
	if player is Rama:
		player.draw_changed.connect(_on_draw_changed)
		player.released.connect(_on_released)
	if player != null:
		var health := player.get_node_or_null("Health") as Health
		if health != null:
			health.changed.connect(_on_health_changed)
			health_bar.max_value = health.max_health
			health_bar.value = health.max_health
	GameState.punya_changed.connect(_on_punya_changed)
	_on_punya_changed(GameState.punya)
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	var cam := get_viewport().get_camera_3d()
	var aiming: bool = _player is Rama and _player.is_drawing and _player.hold_time > _player.snap_shot_time
	_aim_weight = move_toward(_aim_weight, 1.0 if aiming else 0.0, real_delta * 6.0)
	reticle.weight = _aim_weight
	reticle.draw_amount = _draw
	reticle.perfect = _perfect
	var target: Node3D = _player.aim_target if _player is Rama else null
	reticle.has_lock = false
	if target != null and is_instance_valid(target) and cam != null:
		var p := AutoAim.aim_point_of(target)
		if not cam.is_position_behind(p):
			reticle.has_lock = true
			reticle.lock_position = cam.unproject_position(p) - reticle.global_position
	var mat := vignette.material as ShaderMaterial
	mat.set_shader_parameter(&"strength", _aim_weight * (0.45 + 0.35 * _draw))
	mat.set_shader_parameter(&"glow", 1.0 if _perfect else 0.0)
	shoot_button.progress = _draw if aiming else 0.0
	shoot_button.progress_color = Color(1.0, 0.95, 0.6) if _perfect else Color(1.0, 0.82, 0.3)


func _on_draw_changed(amount: float, perfect: bool) -> void:
	_draw = amount
	_perfect = perfect


func _on_released(_arrow: Node, _power: float, perfect: bool) -> void:
	if not perfect:
		return
	perfect_label.modulate.a = 1.0
	perfect_label.scale = Vector2(1.4, 1.4)
	var tween := create_tween()
	tween.tween_property(perfect_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.6)
	tween.tween_property(perfect_label, "modulate:a", 0.0, 0.5)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_punya_changed(total: int) -> void:
	punya_label.text = "Punya: %d" % total
