# Coordinates the roster panel so it can expose worker selection and rest-day
# toggles without owning gameplay state beyond its local display.
extends PanelContainer

signal worker_selected(worker: Worker)
signal rest_toggled(worker: Worker)

const ROLE_BY_WORKER: Dictionary = {
    "Radek": "Smelter",
    "Bozena": "Assayer",
    "Jiri": "Pressman"
}

@onready var _worker_rows: Dictionary = {
    "Radek": $"VBoxContainer/WorkerList/WorkerRow_Radek",
    "Bozena": $"VBoxContainer/WorkerList/WorkerRow_Bozena",
    "Jiri": $"VBoxContainer/WorkerList/WorkerRow_Jiri"
}

var _workers_by_name: Dictionary = {}


func _ready() -> void:
    for worker_name: String in _worker_rows.keys():
        var row: HBoxContainer = _worker_rows[worker_name] as HBoxContainer
        row.gui_input.connect(_on_worker_row_gui_input.bind(worker_name))
        var rest_button: Button = row.get_node("RestDayButton") as Button
        rest_button.pressed.connect(_on_rest_button_pressed.bind(worker_name))


func set_workers(workers: Array[Worker]) -> void:
    _workers_by_name.clear()
    for worker: Worker in workers:
        _workers_by_name[worker.worker_name] = worker
    refresh()


func refresh() -> void:
    for worker_name: String in _worker_rows.keys():
        var worker: Worker = _workers_by_name.get(worker_name) as Worker
        if worker == null:
            continue

        var row: HBoxContainer = _worker_rows[worker_name] as HBoxContainer
        var info_column: VBoxContainer = row.get_node("InfoColumn") as VBoxContainer
        var stats_row: HBoxContainer = info_column.get_node("StatsRow") as HBoxContainer
        var name_label: Label = info_column.get_node("NameLabel") as Label
        var skill_label: Label = stats_row.get_node("SkillLabel") as Label
        var fatigue_label: Label = stats_row.get_node("FatigueLabel") as Label
        var rest_button: Button = row.get_node("RestDayButton") as Button

        name_label.text = "%s - %s" % [worker.worker_name, worker.role]
        skill_label.text = "Skill %d" % worker.skill
        fatigue_label.text = "Fatigue %d" % worker.fatigue
        rest_button.text = "Cancel rest" if worker.is_resting else "Rest today"
        row.modulate = Color(0.75, 0.75, 0.75, 1.0) if worker.is_resting else Color(1, 1, 1, 1)


func _on_worker_row_gui_input(event: InputEvent, worker_name: String) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var worker: Worker = _workers_by_name.get(worker_name) as Worker
        if worker != null:
            worker_selected.emit(worker)


func _on_rest_button_pressed(worker_name: String) -> void:
    var worker: Worker = _workers_by_name.get(worker_name) as Worker
    if worker == null:
        return

    if worker.is_resting:
        worker.clear_rest_day()
    else:
        worker.mark_rest_day()

    refresh()
    rest_toggled.emit(worker)
