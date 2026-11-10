class_name Health
extends Node
## Hit-point component. Attach as a child named "Health" to anything damageable.

signal changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died

@export var max_health := 100.0

var current := 0.0
## While true, take_damage() is ignored (e.g. during a dodge roll).
var invulnerable := false
## Optional (amount, source) -> amount: e.g. a shield that blocks frontal hits.
var damage_filter: Callable
## True while an astra's blast is being applied (shields don't stop astras).
static var from_astra := false


func _ready() -> void:
	current = max_health


func take_damage(amount: float, source: Node = null) -> void:
	if amount <= 0.0 or invulnerable or is_dead():
		return
	if damage_filter.is_valid():
		amount = damage_filter.call(amount, source)
		if amount <= 0.0:
			return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)


func revive() -> void:
	current = max_health
	changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0.0


func ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0
