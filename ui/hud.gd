extends CanvasLayer
## Grey-box HUD: health, punya counter and touch controls.

@export var player_path: NodePath

@onready var health_bar: ProgressBar = %HealthBar
@onready var punya_label: Label = %PunyaLabel
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	var player := get_node_or_null(player_path)
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


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_punya_changed(total: int) -> void:
	punya_label.text = "Punya: %d" % total
