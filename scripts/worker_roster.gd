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
const READY_ROW_MODULATE: Color = Color(1, 1, 1, 1)
const RESTING_ROW_MODULATE: Color = Color(0.75, 0.75, 0.75, 1.0)
const HIGHLIGHT_ROW_MODULATE: Color = Color(1.0, 0.9686, 0.8431, 1.0)
const DIMMED_ROW_MODULATE: Color = Color(0.88, 0.88, 0.88, 1.0)
const INCAPACITATED_ROW_MODULATE: Color = Color(0.92, 0.84, 0.84, 1.0)

@onready var _worker_rows: Dictionary = {
    "Radek": $"VBoxContainer/WorkerList/WorkerRow_Radek",
    "Bozena": $"VBoxContainer/WorkerList/WorkerRow_Bozena",
    "Jiri": $"VBoxContainer/WorkerList/WorkerRow_Jiri"
}

var _workers_by_name: Dictionary = {}
var _assignments_by_worker_name: Dictionary = {}
var _pending_role: String = ""


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


func set_stage_assignments(assignments: Dictionary) -> void:
    _assignments_by_worker_name.clear()
    for stage_id: Variant in assignments.keys():
        var worker: Worker = assignments[stage_id] as Worker
        if worker != null:
            _assignments_by_worker_name[worker.worker_name] = _stage_label_from_id(String(stage_id))
    refresh()


func set_pending_role(role_name: String) -> void:
    _pending_role = role_name
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
        var status_label: Label = info_column.get_node("StatusLabel") as Label
        var skill_label: Label = stats_row.get_node("SkillLabel") as Label
        var fatigue_label: Label = stats_row.get_node("FatigueLabel") as Label
        var rest_button: Button = row.get_node("RestDayButton") as Button

        name_label.text = "%s - %s" % [worker.worker_name, worker.role]
        status_label.text = _build_status_text(worker)
        skill_label.text = "Skill %d" % worker.skill
        fatigue_label.text = "Fatigue %d" % worker.fatigue
        rest_button.text = "Cancel rest" if worker.is_resting else "Rest today"
        row.modulate = _row_modulate_for_worker(worker)


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


func _build_status_text(worker: Worker) -> String:
    if worker.is_incapacitated():
        return "Collapsed after the last shift"

    if worker.is_resting:
        return "Resting today"

    if _assignments_by_worker_name.has(worker.worker_name):
        var assignment_text: String = "Assigned to %s" % String(_assignments_by_worker_name[worker.worker_name])
        if worker.loyalty <= 40:
            return assignment_text + ", but openly discontented"
        return assignment_text

    if not _pending_role.is_empty() and worker.role == _pending_role:
        if worker.loyalty <= 40:
            return "Ready for assignment, but resentful"
        return "Ready for assignment"

    if worker.loyalty <= 40:
        return "Idle and muttering about the pay"

    return "Waiting in the roster"


func _row_modulate_for_worker(worker: Worker) -> Color:
    if worker.is_incapacitated():
        return INCAPACITATED_ROW_MODULATE

    if worker.is_resting:
        return RESTING_ROW_MODULATE

    if _pending_role.is_empty():
        return READY_ROW_MODULATE

    if worker.role == _pending_role:
        return HIGHLIGHT_ROW_MODULATE

    return DIMMED_ROW_MODULATE


func _stage_label_from_id(stage_id: String) -> String:
    match stage_id:
        "smelting":
            return "Smelting"
        "striking":
            return "Striking"
        "assay":
            return "Assay"
        _:
            return stage_id.capitalize()
