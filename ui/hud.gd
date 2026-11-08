extends CanvasLayer
## Grey-box HUD: health, punya counter and touch controls.

@export var player_path: NodePath
@export var spawner_path: NodePath

@onready var health_bar: ProgressBar = %HealthBar
@onready var punya_label: Label = %PunyaLabel
@onready var hint_label: Label = %HintLabel
@onready var reticle: Reticle = %Reticle
@onready var vignette: ColorRect = %Vignette
@onready var perfect_label: Label = %PerfectLabel
@onready var shoot_button: ActionButton = %ShootButton
@onready var agni_button: ActionButton = %AgniButton
@onready var banner: Label = %Banner

var _player: Node
var _draw := 0.0
var _perfect := false
var _aim_weight := 0.0
var _hurt := 0.0
var _fire := 0.0
var _pulse := 0.0


func _ready() -> void:
	var player := get_node_or_null(player_path)
	_player = player
	if player is Rama:
		player.draw_changed.connect(_on_draw_changed)
		player.released.connect(_on_released)
		player.hurt.connect(func(_a: float) -> void: _hurt = 1.0)
		player.astra_detonated.connect(func(_p: Vector3) -> void: _fire = 1.0)
		player.perfect_dodge.connect(func() -> void: show_banner("Perfect dodge!", Color(1, 0.85, 0.4), 0.8))
		player.rama_died.connect(func() -> void: show_banner("Rama has fallen...", Color(1, 0.4, 0.35), 2.5))
	var spawner := get_node_or_null(spawner_path) as WaveSpawner
	if spawner:
		spawner.wave_started.connect(func(i: int, n: int) -> void:
			show_banner("Wave %d of %d" % [i + 1, n], Color(1, 0.9, 0.7), 2.0))
		spawner.all_cleared.connect(func() -> void:
			show_banner("The rakshasas are vanquished!\nVishvamitra is pleased.", Color(1, 0.85, 0.35), 4.0))
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
	_hurt = move_toward(_hurt, 0.0, real_delta * 2.5)
	_fire = move_toward(_fire, 0.0, real_delta * 2.0)
	var mat := vignette.material as ShaderMaterial
	mat.set_shader_parameter(&"strength", _aim_weight * (0.45 + 0.35 * _draw))
	mat.set_shader_parameter(&"glow", 1.0 if _perfect else 0.0)
	mat.set_shader_parameter(&"hurt", _hurt)
	mat.set_shader_parameter(&"fire", _fire)
	_update_agni(real_delta)
	shoot_button.progress = _draw if aiming else 0.0
	shoot_button.progress_color = Color(1.0, 0.95, 0.6) if _perfect else Color(1.0, 0.82, 0.3)


func _update_agni(real_delta: float) -> void:
	if not (_player is Rama) or _player.astras.is_empty():
		agni_button.visible = false
		return
	var rama := _player as Rama
	var astra: AstraResource = rama.astras[0]
	_pulse += real_delta
	agni_button.visible = rama.is_astra_unlocked(astra)
	var left := rama.astra_cooldown_left(astra)
	if rama.armed_astra == astra:
		agni_button.color = Color(1.0, 0.45 + 0.15 * sin(_pulse * 10.0), 0.1, 0.95)
		agni_button.progress = 1.0
		agni_button.progress_color = Color(1.0, 0.85, 0.35)
	elif left > 0.0:
		agni_button.color = Color(0.35, 0.25, 0.2, 0.7)
		agni_button.progress = 1.0 - left / astra.cooldown
		agni_button.progress_color = Color(1.0, 0.5, 0.15, 0.8)
	else:
		agni_button.color = Color(0.85, 0.3, 0.08, 0.85)
		agni_button.progress = 0.0


func show_banner(text: String, color: Color = Color.WHITE, hold: float = 2.0) -> void:
	banner.text = text
	banner.add_theme_color_override(&"font_color", color)
	banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(hold)
	tween.tween_property(banner, "modulate:a", 0.0, 0.6)


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
