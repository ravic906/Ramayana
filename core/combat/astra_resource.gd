class_name AstraResource
extends Resource
## A divine weapon Rama can invoke onto a drawn arrow (see data/astras/*.tres).

enum Effect { FIRE, WATER, WIND }

@export var id := &"agneyastra"
@export var effect := Effect.FIRE
## Short label for the HUD button.
@export var short_name := "Agni"
## The mantra shown when Vishvamitra teaches it.
@export var mantra := ""
@export var display_name := "Agneyastra"
@export var cooldown := 12.0
## Minimum draw (0..1) for the astra to be released; weaker shots keep it armed.
@export var min_draw := 0.6
@export var impact_damage := 35.0
@export var radius := 4.5
@export var knockback := 7.0
@export var burn_dps := 6.0
@export var burn_duration := 4.0
## Burning ground left behind.
@export var patch_duration := 3.0
@export var patch_dps := 8.0
@export var color := Color(1.0, 0.45, 0.1)
@export var glow_color := Color(1.0, 0.8, 0.3)
