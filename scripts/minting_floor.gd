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
@onready var _day_counter_label: Label = $HeaderBar/HeaderContent/DayCounterLabel
@onready var _shift_report_panel: PanelContainer = $"HBoxContainer/LeftPanel/ShiftReportPanel"
@onready var _shift_report_title: Label = $"HBoxContainer/LeftPanel/ShiftReportPanel/VBoxContainer/ShiftReportTitle"
@onready var _shift_report_summary: Label = $"HBoxContainer/LeftPanel/ShiftReportPanel/VBoxContainer/ShiftReportSummary"
@onready var _shift_report_detail: Label = $"HBoxContainer/LeftPanel/ShiftReportPanel/VBoxContainer/ShiftReportDetail"

var _pending_stage_id: String = ""
 

func _ready() -> void:
    _connect_stage_signals()
    _worker_roster.worker_selected.connect(_on_worker_selected)
    _worker_roster.rest_toggled.connect(_on_worker_rest_toggled)
    _morning_brief.begin_shift_requested.connect(_on_begin_shift_requested)
    _morning_brief.event_choice_selected.connect(_on_event_choice_selected)
    _day_advance_button.pressed.connect(_on_day_advance_pressed)

    GameManager.day_started.connect(_on_day_started)
    GameManager.day_ended.connect(_on_day_ended)
    GameManager.game_over.connect(_on_game_over)

    _worker_roster.set_workers(GameManager.workers)
    if GameManager.current_phase == GameManager.GamePhase.NOT_STARTED and GameManager.current_day == 0:
        GameManager.start_new_game()
        _worker_roster.set_workers(GameManager.workers)
    else:
        _resume_from_game_state()


func _connect_stage_signals() -> void:
    for stage_id: String in _stage_nodes.keys():
        var stage_node = _stage_nodes[stage_id]
        stage_node.assignment_requested.connect(_on_stage_assignment_requested)
        stage_node.worker_removed.connect(_on_stage_worker_removed)


func _on_stage_assignment_requested(stage_id: String) -> void:
    _pending_stage_id = stage_id
    _refresh_assignment_feedback()


func _on_stage_worker_removed(stage_id: String) -> void:
    GameManager.stage_assignments.erase(stage_id)
    _clear_pending_stage_assignment(stage_id)
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

    GameManager.stage_assignments[_pending_stage_id] = worker
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
            GameManager.stage_assignments.erase(assigned_stage_id)
            _clear_pending_stage_assignment(assigned_stage_id)

    _refresh_stage_previews()
    _worker_roster.refresh()


func _on_begin_shift_requested() -> void:
    if GameManager.active_event != null:
        return

    _pending_stage_id = ""
    GameManager.begin_shift()
    _morning_brief.hide_brief()
    _update_day_button_for_phase()


func _on_event_choice_selected(choice_id: String) -> void:
    GameManager.resolve_active_event(choice_id)
    _morning_brief.resolve_choice(choice_id, GameManager.resolved_event_summary)
    _worker_roster.refresh()


func _on_day_advance_pressed() -> void:
    match GameManager.current_phase:
        GameManager.GamePhase.SHIFT:
            _complete_current_shift()
        GameManager.GamePhase.EVENING_REPORT:
            GameManager.advance_day()
        _:
            pass


func _on_day_started(day_num: int) -> void:
    _pending_stage_id = ""
    _update_header_day(day_num)
    _morning_brief.show_brief(day_num, GameManager.active_event)
    _refresh_stage_previews()
    _worker_roster.refresh()
    _show_waiting_shift_report()
    _update_day_button_for_phase()


func _on_day_ended(_results: Dictionary) -> void:
    _show_shift_report(GameManager.get_last_shift_results())
    _update_day_button_for_phase()


func _on_game_over(ending_id: String) -> void:
    _day_advance_button.visible = false
    _morning_brief.hide_brief()
    _auditor_screen.show_result(ending_id, Ledger.get_audit_snapshot())


func _complete_current_shift() -> void:
    _pending_stage_id = ""
    var stage_outputs: Array[int] = []
    var quality_scores: Array[float] = []

    for stage_id: String in ROLE_BY_STAGE.keys():
        var worker: Worker = GameManager.stage_assignments.get(stage_id) as Worker
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
    for worker: Worker in GameManager.workers:
        if worker.is_resting:
            worker.reset_fatigue()
            worker.clear_rest_day()
            continue

        if not _find_stage_for_worker(worker).is_empty():
            worker.apply_shift_fatigue()


func _refresh_stage_previews() -> void:
    for stage_id: String in _stage_nodes.keys():
        var stage_node = _stage_nodes[stage_id]
        var worker: Worker = GameManager.stage_assignments.get(stage_id) as Worker
        if worker == null:
            stage_node.set_output_preview(0)
            if stage_node.get_assigned_worker() != null:
                stage_node.remove_worker()
            continue

        if stage_node.get_assigned_worker() != worker:
            stage_node.assign_worker(worker)
        else:
            stage_node.refresh_worker_state()
        stage_node.set_output_preview(_calculate_worker_output(worker))

    _refresh_assignment_feedback()
    _worker_roster.set_stage_assignments(GameManager.stage_assignments)


func _find_stage_for_worker(worker: Worker) -> String:
    for stage_id: String in GameManager.stage_assignments.keys():
        if GameManager.stage_assignments[stage_id] == worker:
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


func _clear_pending_stage_assignment(stage_id: String = "") -> void:
    if stage_id.is_empty() or _pending_stage_id == stage_id:
        _pending_stage_id = ""


func _resume_from_game_state() -> void:
    _update_header_day(GameManager.current_day)
    _refresh_stage_previews()
    _worker_roster.refresh()
    _update_day_button_for_phase()

    if GameManager.current_phase == GameManager.GamePhase.MORNING_BRIEF:
        if GameManager.active_event != null:
            _morning_brief.show_brief(GameManager.current_day, GameManager.active_event)
        elif GameManager.resolved_event != null:
            _morning_brief.show_brief(GameManager.current_day, GameManager.resolved_event)
            _morning_brief.resolve_choice(
                GameManager.resolved_event_choice_id,
                GameManager.resolved_event_summary
            )
        else:
            _morning_brief.show_brief(GameManager.current_day, null)
        _show_waiting_shift_report()
    elif GameManager.current_phase == GameManager.GamePhase.EVENING_REPORT:
        _show_shift_report(GameManager.get_last_shift_results())
    elif GameManager.current_phase == GameManager.GamePhase.COMPLETE:
        _day_advance_button.visible = false
        _auditor_screen.show_result(GameManager.last_ending_id, Ledger.get_audit_snapshot())
        _show_shift_report(GameManager.get_last_shift_results())
    else:
        _show_waiting_shift_report()


func _refresh_assignment_feedback() -> void:
    var pending_role: String = ROLE_BY_STAGE.get(_pending_stage_id, "")
    for stage_id: String in _stage_nodes.keys():
        var stage_node = _stage_nodes[stage_id]
        stage_node.set_assignment_pending(stage_id == _pending_stage_id)
    _worker_roster.set_pending_role(pending_role)


func _show_waiting_shift_report() -> void:
    _shift_report_panel.visible = true
    _shift_report_title.text = "Shift report"
    _shift_report_summary.text = "No shift completed yet for Day %d." % GameManager.current_day
    _shift_report_detail.text = "Assign the floor, mind the fatigue, and strike enough merchant-grade coin to satisfy the Crown."


func _show_shift_report(results: Dictionary) -> void:
    _shift_report_panel.visible = true
    var total_output: int = int(results.get("total_output", 0))
    var merchant_output: int = int(results.get("merchant_grade_or_better", 0))
    var quality_grade: String = String(results.get("quality_grade", "Debased"))
    var quota_met: bool = Ledger.did_meet_daily_quota()

    _shift_report_title.text = "Evening report - Day %d" % GameManager.current_day
    _shift_report_summary.text = (
        "%d coins struck. %d counted toward quota at %s grade."
    ) % [total_output, merchant_output, quality_grade]
    _shift_report_detail.text = (
        "Quota %s. Balance stands at %d groschen."
    ) % ["met" if quota_met else "unmet", Ledger.get_balance()]


func _update_header_day(day_num: int) -> void:
    if day_num <= 0:
        _day_counter_label.text = "Day -"
        return
    _day_counter_label.text = "Day %s of XIV" % _to_roman(day_num)


func _to_roman(number: int) -> String:
    var remainder: int = maxi(number, 0)
    var roman_text: String = ""
    var numerals: Array[Array] = [
        [10, "X"],
        [9, "IX"],
        [5, "V"],
        [4, "IV"],
        [1, "I"]
    ]

    for numeral_data: Array in numerals:
        var numeral_value: int = int(numeral_data[0])
        var numeral_text: String = String(numeral_data[1])
        while remainder >= numeral_value:
            roman_text += numeral_text
            remainder -= numeral_value

    return roman_text if not roman_text.is_empty() else "I"
