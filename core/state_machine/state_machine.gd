class_name StateMachine
extends Node
## Generic node-based finite state machine. Child nodes extending State are
## registered by name; the first child (or initial_state) is entered on ready.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: State

var current: State
var states: Dictionary = {}


func _ready() -> void:
	var actor: Node = owner if owner != null else get_parent()
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.machine = self
			child.actor = actor
	if initial_state == null:
		for child in get_children():
			if child is State:
				initial_state = child
				break
	# Wait for the actor so states can safely use its @onready variables.
	if actor != null and not actor.is_node_ready():
		await actor.ready
	if initial_state != null:
		current = initial_state
		current.enter()


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_warning("StateMachine: unknown state '%s'" % state_name)
		return
	var previous: StringName = current.name if current != null else &""
	if current != null:
		current.exit()
	current = states[state_name]
	current.enter(msg)
	state_changed.emit(previous, state_name)


func is_in(state_name: StringName) -> bool:
	return current != null and current.name == state_name


func _process(delta: float) -> void:
	if current != null:
		current.update(delta)


func _physics_process(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current != null:
		current.handle_input(event)
