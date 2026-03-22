# Coordinates the main gameplay screen so stage assignment, day flow, and the
# existing autoload systems are wired together without direct UI-to-UI coupling.
extends Control

const ROLE_BY_STAGE: Dictionary = {
    "smelting": "Smelter",
    "striking": "Pressman",
    "assay": "Assayer"
}
const GROSCHEN_VALUE_PER_MERCHANT_COIN: int = 1

@onready var _stage_nodes: Dictionary = {
    "smelting": $"HBoxContainer/LeftPanel/StageContainer/PipelineStage_Smelting",
    "striking": $"HBoxContainer/LeftPanel/StageContainer/PipelineStage_Striking",
    "assay": $"HBoxContainer/LeftPanel/StageContainer/PipelineStage_Assay"
}
@onready var _worker_roster = $"HBoxContainer/RightPanel/WorkerRoster"
@onready var _morning_brief = $MorningBrief
@onready var _auditor_screen = $AuditorScreen
@onready var _day_advance_button: Button = $DayAdvanceButton

var _workers: Array[Worker] = []
var _pending_stage_id: String = ""
var _stage_assignments: Dictionary = {}


func _ready() -> void:
    _load_workers()
    _connect_stage_signals()
    _worker_roster.worker_selected.connect(_on_worker_selected)
    _worker_roster.rest_toggled.connect(_on_worker_rest_toggled)
    _morning_brief.begin_shift_requested.connect(_on_begin_shift_requested)
    _morning_brief.event_choice_selected.connect(_on_event_choice_selected)
    _day_advance_button.pressed.connect(_on_day_advance_pressed)

    GameManager.day_started.connect(_on_day_started)
    GameManager.day_ended.connect(_on_day_ended)
    GameManager.game_over.connect(_on_game_over)

    _worker_roster.set_workers(_workers)
    GameManager.start_new_game()


func _load_workers() -> void:
    _workers.clear()
    var worker_paths: PackedStringArray = [
        "res://data/workers/radek.tres",
        "res://data/workers/bozena.tres",
        "res://data/workers/jiri.tres"
    ]

    for worker_path: String in worker_paths:
        var worker: Worker = load(worker_path) as Worker
        if worker != null:
            _workers.append(worker.duplicate(true) as Worker)


func _connect_stage_signals() -> void:
    for stage_id: String in _stage_nodes.keys():
        var stage_node = _stage_nodes[stage_id]
        stage_node.assignment_requested.connect(_on_stage_assignment_requested)
        stage_node.worker_removed.connect(_on_stage_worker_removed)


func _on_stage_assignment_requested(stage_id: String) -> void:
    _pending_stage_id = stage_id


func _on_stage_worker_removed(stage_id: String) -> void:
    _stage_assignments.erase(stage_id)
    _refresh_stage_previews()


func _on_worker_selected(worker: Worker) -> void:
    if _pending_stage_id.is_empty() or worker.is_resting:
        return

    var expected_role: String = ROLE_BY_STAGE.get(_pending_stage_id, "")
    if worker.role != expected_role:
        return

    var previous_stage_id: String = _find_stage_for_worker(worker)
    if not previous_stage_id.is_empty():
        var previous_stage = _stage_nodes[previous_stage_id]
        previous_stage.remove_worker()

    _stage_assignments[_pending_stage_id] = worker
    var stage_node = _stage_nodes[_pending_stage_id]
    stage_node.assign_worker(worker)
    _pending_stage_id = ""
    _refresh_stage_previews()


func _on_worker_rest_toggled(worker: Worker) -> void:
    if worker.is_resting:
        var assigned_stage_id: String = _find_stage_for_worker(worker)
        if not assigned_stage_id.is_empty():
            var stage_node = _stage_nodes[assigned_stage_id]
            stage_node.remove_worker()
            _stage_assignments.erase(assigned_stage_id)

    _refresh_stage_previews()
    _worker_roster.refresh()


func _on_begin_shift_requested() -> void:
    GameManager.begin_shift()
    _morning_brief.hide_brief()
    _update_day_button_for_phase()


func _on_event_choice_selected(choice_id: String) -> void:
    GameManager.resolve_active_event(choice_id)
    _morning_brief.resolve_choice(choice_id)


func _on_day_advance_pressed() -> void:
    match GameManager.current_phase:
        GameManager.GamePhase.SHIFT:
            _complete_current_shift()
        GameManager.GamePhase.EVENING_REPORT:
            GameManager.advance_day()
        _:
            pass


func _on_day_started(day_num: int) -> void:
    _morning_brief.show_brief(day_num, GameManager.active_event)
    _refresh_stage_previews()
    _worker_roster.refresh()
    _update_day_button_for_phase()


func _on_day_ended(_results: Dictionary) -> void:
    _update_day_button_for_phase()


func _on_game_over(ending_id: String) -> void:
    _day_advance_button.visible = false
    _morning_brief.hide_brief()
    _auditor_screen.show_result(ending_id, Ledger.get_audit_snapshot())


func _complete_current_shift() -> void:
    var stage_outputs: Array[int] = []
    var quality_scores: Array[float] = []

    for stage_id: String in ROLE_BY_STAGE.keys():
        var worker: Worker = _stage_assignments.get(stage_id) as Worker
        if worker == null:
            stage_outputs.append(0)
            quality_scores.append(0.0)
            continue

        var output: int = _calculate_worker_output(worker)
        stage_outputs.append(output)
        quality_scores.append(_calculate_worker_quality(worker))

    var total_output: int = stage_outputs.min() if not stage_outputs.is_empty() else 0
    var average_quality: float = 0.0
    if not quality_scores.is_empty():
        for score: float in quality_scores:
            average_quality += score
        average_quality /= quality_scores.size()

    var quality_grade: String = _quality_grade_from_score(average_quality)
    var merchant_or_better: int = total_output if average_quality >= 65.0 else 0

    Ledger.add_income(merchant_or_better * GROSCHEN_VALUE_PER_MERCHANT_COIN)
    GameManager.complete_shift({
        "total_output": total_output,
        "merchant_grade_or_better": merchant_or_better,
        "quality_grade": quality_grade
    })

    _apply_end_of_day_worker_updates()
    _refresh_stage_previews()
    _worker_roster.refresh()


func _apply_end_of_day_worker_updates() -> void:
    for worker: Worker in _workers:
        if worker.is_resting:
            worker.reset_fatigue()
            worker.clear_rest_day()
            continue

        if not _find_stage_for_worker(worker).is_empty():
            worker.apply_shift_fatigue()


func _refresh_stage_previews() -> void:
    for stage_id: String in _stage_nodes.keys():
        var stage_node = _stage_nodes[stage_id]
        var worker: Worker = _stage_assignments.get(stage_id) as Worker
        if worker == null:
            stage_node.set_output_preview(0)
            continue

        stage_node.set_output_preview(_calculate_worker_output(worker))


func _find_stage_for_worker(worker: Worker) -> String:
    for stage_id: String in _stage_assignments.keys():
        if _stage_assignments[stage_id] == worker:
            return stage_id
    return ""


func _calculate_worker_output(worker: Worker) -> int:
    var base_output: float = float(worker.skill * 10)
    var fatigue_penalty: float = float(worker.fatigue) / 100.0
    return maxi(int(round(base_output * (1.0 - fatigue_penalty * 0.7))), 0)


func _calculate_worker_quality(worker: Worker) -> float:
    return clampf(float(worker.skill * 20) - float(worker.fatigue) * 0.5, 0.0, 100.0)


func _quality_grade_from_score(score: float) -> String:
    if score >= 85.0:
        return "Royal"
    if score >= 65.0:
        return "Merchant"
    if score >= 40.0:
        return "Common"
    return "Debased"


func _update_day_button_for_phase() -> void:
    _day_advance_button.visible = GameManager.current_phase != GameManager.GamePhase.MORNING_BRIEF
    if GameManager.current_phase == GameManager.GamePhase.SHIFT:
        _day_advance_button.text = "End shift"
    elif GameManager.current_phase == GameManager.GamePhase.EVENING_REPORT:
        _day_advance_button.text = "Advance to next day"
