class_name Animal
extends CharacterBody3D
## A wild animal of the riverbank (deer, stag, wild bull). Never harmed: arrows
## pass through animals (they are on their own physics layer), and an arrow
## landing near one startles it into flight.
##
## Behaviour:
##   GRAZE   idles and grazes, drifting a little.
##   RUN     gallops along `route` (a stampede), then stops.
##   FLEE    bolts away from a fright for a few seconds, then resumes.
##   CHARGE  (bulls, in a panic) runs at `charge_target`; turned aside by a
##           guarding Lakshmana or an arrow, or it barrels through.

signal struck(target: Node3D)
signal turned(by: Node)

enum Mode { GRAZE, RUN, FLEE, CHARGE, DONE }

const SPECIES := {
	"deer": {"walk": 1.2, "run": 8.5, "radius": 0.35},
	"stag": {"walk": 1.3, "run": 8.0, "radius": 0.45},
	"bull": {"walk": 1.0, "run": 6.5, "radius": 0.6},
}
const LAYER := 32  # physics layer 6 "animals"
const STARTLE_RADIUS := 4.5
const GUARD_TURN_RADIUS := 2.6
const HIT_RADIUS := 1.3

@export_enum("deer", "stag", "bull") var species := "deer"

var state := Mode.GRAZE
## World points the stampede follows.
var route: PackedVector3Array = []
var charge_target: Node3D
var _route_i := 0
var _flee_dir := Vector3.ZERO
var _flee_left := 0.0
var _resume := Mode.GRAZE
var _graze_t := 0.0
var _model: Node3D
var _anim: AnimationPlayer
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


static func spawn(parent: Node, kind: String, pos: Vector3) -> Animal:
	var a := Animal.new()
	a.species = kind
	a.name = kind.capitalize()
	parent.add_child(a)
	a.global_position = pos
	return a


func _ready() -> void:
	add_to_group(&"animals")
	collision_layer = LAYER
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = SPECIES[species]["radius"]
	cap.height = maxf(cap.radius * 2.0, 1.0)
	shape.shape = cap
	shape.position.y = cap.height * 0.5
	add_child(shape)
	_model = (load("res://characters/animals/model/%s.scn" % species) as PackedScene).instantiate()
	add_child(_model)
	_anim = _model.get_node("AnimationPlayer")
	_anim.play(&"graze" if randf() < 0.5 else &"idle")
	_anim.seek(randf() * 2.0)
	_graze_t = randf_range(2.0, 6.0)


## Starts galloping along `points`.
func stampede(points: PackedVector3Array) -> void:
	route = points
	_route_i = 0
	_set_state(Mode.RUN)


## Panics toward `target` (bulls): turned by a guard or an arrow.
func charge(target: Node3D) -> void:
	charge_target = target
	add_to_group(&"charging_animals")
	_set_state(Mode.CHARGE)


## An arrow came down at `at`: bolt away if it was close.
func on_arrow_near(at: Vector3, _shooter: Node = null) -> void:
	var d := at - global_position
	d.y = 0.0
	if d.length() > STARTLE_RADIUS or state == Mode.DONE:
		return
	_frighten(-d if d.length() > 0.1 else -global_transform.basis.z)
	if state == Mode.FLEE and charge_target:
		turned.emit(null)
		charge_target = null
		remove_from_group(&"charging_animals")


func is_charging() -> bool:
	return state == Mode.CHARGE


func _frighten(away: Vector3) -> void:
	away.y = 0.0
	_flee_dir = away.normalized()
	_flee_left = randf_range(2.0, 3.0)
	if state != Mode.FLEE:
		_resume = Mode.RUN if state == Mode.RUN and _route_i < route.size() else Mode.GRAZE
	_set_state(Mode.FLEE)


func _set_state(s: Mode) -> void:
	state = s
	match s:
		Mode.GRAZE:
			_anim.play(&"graze", 0.3)
		Mode.RUN, Mode.FLEE, Mode.CHARGE:
			_anim.play(&"run", 0.15)
			_anim.speed_scale = randf_range(0.95, 1.1)
		Mode.DONE:
			_anim.play(&"idle", 0.4)


func _physics_process(delta: float) -> void:
	velocity.y = velocity.y - _gravity * delta if not is_on_floor() else 0.0
	var want := Vector3.ZERO
	var speed := 0.0
	var run: float = SPECIES[species]["run"]
	match state:
		Mode.GRAZE:
			_graze_t -= delta
			if _graze_t <= 0.0:
				_graze_t = randf_range(3.0, 7.0)
				_anim.play(&"graze" if randf() < 0.6 else &"idle", 0.4)
		Mode.RUN:
			if _route_i >= route.size():
				_set_state(Mode.DONE)
			else:
				var to := route[_route_i] - global_position
				to.y = 0.0
				if to.length() < 2.0:
					_route_i += 1
				want = to.normalized()
				speed = run
		Mode.FLEE:
			_flee_left -= delta
			want = _flee_dir
			speed = run * 1.1
			if _flee_left <= 0.0:
				_set_state(_resume)
		Mode.CHARGE:
			if not is_instance_valid(charge_target):
				_set_state(Mode.GRAZE)
			else:
				var to2 := charge_target.global_position - global_position
				to2.y = 0.0
				want = to2.normalized()
				speed = run
				var guard := _guard_near()
				if guard:
					# Lakshmana stands in its way: the bull swerves and runs on.
					_frighten(global_position - guard.global_position + want.cross(Vector3.UP) * 0.5)
					_resume = Mode.GRAZE
					charge_target = null
					remove_from_group(&"charging_animals")
					turned.emit(guard)
				elif to2.length() < HIT_RADIUS:
					struck.emit(charge_target)
					if charge_target.has_method("on_attacked"):
						charge_target.on_attacked(0.0, self)
					_frighten(want)
					_resume = Mode.GRAZE
					charge_target = null
					remove_from_group(&"charging_animals")
	if want != Vector3.ZERO:
		var yaw := atan2(want.x, want.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 6.0, 0.0, 1.0))
		var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
		velocity.x = fwd.x * speed
		velocity.z = fwd.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
	move_and_slide()


func _guard_near() -> Node3D:
	for c in get_tree().get_nodes_in_group(&"companions"):
		if c is Node3D and "command" in c and c.command == Lakshmana.Command.GUARD \
				and (c as Node3D).global_position.distance_to(global_position) < GUARD_TURN_RADIUS:
			return c
	return null
