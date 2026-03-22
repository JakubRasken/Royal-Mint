# Coordinates the morning brief overlay so narrative text and event choices stay
# in the scene layer while gameplay state remains in the autoloads.
extends CanvasLayer

signal begin_shift_requested
signal event_choice_selected(choice_id: String)

@onready var _brief_title: Label = $"Overlay/BriefPanel/VBoxContainer/BriefTitle"
@onready var _narrative_label: Label = $"Overlay/BriefPanel/VBoxContainer/NarrativeLabel"
@onready var _choice_row: HBoxContainer = $"Overlay/BriefPanel/VBoxContainer/ChoiceRow"
@onready var _choice_a_button: Button = $"Overlay/BriefPanel/VBoxContainer/ChoiceRow/ChoiceAButton"
@onready var _choice_b_button: Button = $"Overlay/BriefPanel/VBoxContainer/ChoiceRow/ChoiceBButton"
@onready var _begin_shift_button: Button = $"Overlay/BriefPanel/VBoxContainer/BeginShiftButton"


func _ready() -> void:
    _choice_a_button.pressed.connect(_on_choice_button_pressed.bind("a"))
    _choice_b_button.pressed.connect(_on_choice_button_pressed.bind("b"))
    _begin_shift_button.pressed.connect(_on_begin_shift_button_pressed)


func show_brief(day_num: int, active_event: GameEvent) -> void:
    visible = true

    if active_event == null:
        _brief_title.text = "Morning brief - Day %d" % day_num
        _narrative_label.text = (
            "Day %d begins beneath soot and parchment. Keep the furnaces hot, "
            + "the dies true, and the ledger clean before the Crown looks closer."
        ) % day_num
        _choice_row.visible = false
        _begin_shift_button.disabled = false
        return

    _brief_title.text = active_event.title
    _narrative_label.text = active_event.narrative
    _choice_row.visible = true
    _choice_a_button.text = active_event.choice_a_label
    _choice_b_button.text = active_event.choice_b_label
    _choice_a_button.disabled = false
    _choice_b_button.disabled = false
    _begin_shift_button.disabled = true


func resolve_choice(choice_id: String, resolution_summary: String = "") -> void:
    if resolution_summary.is_empty():
        _narrative_label.text += "\n\nChoice recorded for this day: %s." % choice_id
    else:
        _narrative_label.text += "\n\n" + resolution_summary
    _choice_a_button.disabled = true
    _choice_b_button.disabled = true
    _begin_shift_button.disabled = false


func hide_brief() -> void:
    visible = false


func _on_choice_button_pressed(choice_id: String) -> void:
    event_choice_selected.emit(choice_id)


func _on_begin_shift_button_pressed() -> void:
    begin_shift_requested.emit()
