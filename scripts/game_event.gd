# Implements the authored event resource used by EventManager so daily events
# stay hand-authored in data files instead of being hardcoded in scripts.
class_name GameEvent
extends Resource

@export var event_id: String = ""
@export var day_trigger: int = -1
@export var trigger_days: PackedInt32Array = PackedInt32Array()
@export var title: String = ""
@export_multiline var narrative: String = ""
@export var choice_a_label: String = ""
@export var choice_b_label: String = ""
@export var choice_a_effect: Dictionary = {}
@export var choice_b_effect: Dictionary = {}


func triggers_on_day(day_num: int) -> bool:
    if not trigger_days.is_empty():
        return trigger_days.has(day_num)
    if day_trigger < 0:
        return false
    return day_trigger == day_num


func get_effect_for_choice(choice_id: String) -> Dictionary:
    match choice_id:
        "a":
            return choice_a_effect.duplicate(true)
        "b":
            return choice_b_effect.duplicate(true)
        _:
            return {}
