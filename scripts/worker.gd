# Implements the Worker resource used for authored roster data and runtime
# fatigue/rest state so worker logic stays data-driven and UI-agnostic.
class_name Worker
extends Resource

const MAX_FATIGUE: int = 100
const SHIFT_FATIGUE_GAIN: int = 20

@export var worker_name: String = ""
@export var role: String = ""
@export_range(1, 5) var skill: int = 1
@export_range(0, 100) var fatigue: int = 0
@export_range(0, 100) var loyalty: int = 50
@export var portrait: Texture2D
@export var is_resting: bool = false


func apply_shift_fatigue() -> void:
    fatigue = clampi(fatigue + SHIFT_FATIGUE_GAIN, 0, MAX_FATIGUE)


func apply_loyalty_delta(amount: int) -> void:
    loyalty = clampi(loyalty + amount, 0, 100)


func mark_rest_day() -> void:
    is_resting = true


func clear_rest_day() -> void:
    is_resting = false


func reset_fatigue() -> void:
    fatigue = 0
