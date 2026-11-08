class_name State
extends Node
## Base class for a state in a StateMachine. Override the hooks you need.

## Set by the owning StateMachine.
var machine: StateMachine
## The node this state controls (the StateMachine's owner, or its parent).
var actor: Node


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
