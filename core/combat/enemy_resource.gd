class_name EnemyResource
extends Resource
## Tuning data for an enemy type (see data/enemies/*.tres).

enum AttackKind { MELEE, RANGED }

@export var display_name := "Rakshasa"
@export var attack_kind := AttackKind.MELEE
@export var max_health := 60.0
@export var move_speed := 3.6
@export var turn_speed := 8.0
@export var damage := 15.0
## Melee: reach of the swing. Ranged: preferred standoff distance.
@export var attack_range := 2.0
@export var keep_distance := 0.0
## Seconds of readable wind-up before the hit lands.
@export var telegraph_time := 0.75
@export var recover_time := 0.9
@export var attack_cooldown := 1.6
## A single hit at least this big staggers the enemy.
@export var stagger_threshold := 30.0
@export var punya_reward := 15
@export var model_scale := 1.12
