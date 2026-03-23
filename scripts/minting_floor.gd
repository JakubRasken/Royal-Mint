# Coordinates the main gameplay screen so stage assignment, day flow, and the
# existing autoload systems are wired together without direct UI-to-UI coupling.
extends Control

const ROLE_BY_STAGE: Dictionary = {
    "smelting": "Smelter",
    "striking": "Pressman",
    "assay": "Assayer"
}
const GROSCHEN_VALUE_PER_MERCHANT_COIN: int = 1
const BASE_OUTPUT_PER_SKILL: float = 12.0
const OUTPUT_FATIGUE_PENALTY: float = 0.55
const FLOOR_HAND_OUTPUT: int = 10
const FLOOR_HAND_QUALITY: float = 50.0
const FLOOR_HAND_MERCHANT_FACTOR: float = 0.4
const QUALITY_BASE_SCORE: float = 40.0
const QUALITY_SKILL_WEIGHT: float = 15.0
const QUALITY_FATIGUE_PENALTY: float = 0.15
const DAY_COUNTER_SAFE_COLOR: Color = Color("8b6914")
const DAY_COUNTER_WARNING_COLOR: Color = Color("c17f24")
const DAY_COUNTER_DANGER_COLOR: Color = Color("8b1a1a")
const DAY_COUNTER_PULSE_MIN_ALPHA: float = 0.6
const DAY_COUNTER_PULSE_DURATION: float = 0.6
const SIGISMUND_SEAL_BASE_ALPHA: float = 0.2
const SIGISMUND_SEAL_MAX_ALPHA: float = 1.0
const SIGISMUND_SEAL_COLOR: Color = Color("8b1a1a")
const SHIFT_GRADE_TEXT_COLOR: Color = Color("fdf6e3")
const SHIFT_GRADE_BORDER_COLOR: Color = Color("5c4409")
const SHIFT_GRADE_ROYAL_COLOR: Color = Color("8b6914")
const SHIFT_GRADE_MERCHANT_COLOR: Color = Color("2a5a2a")
const SHIFT_GRADE_COMMON_COLOR: Color = Color("c17f24")
const SHIFT_GRADE_DEBASED_COLOR: Color = Color("8b1a1a")

@onready var _stage_nodes: Dictionary = {
    "smelting": $"ScreenLayout/MainContent/LeftPanel/StageContainer/PipelineStage_Smelting",
    "striking": $"ScreenLayout/MainContent/LeftPanel/StageContainer/PipelineStage_Striking",
    "assay": $"ScreenLayout/MainContent/LeftPanel/StageContainer/PipelineStage_Assay"
}
@onready var _worker_roster = $"ScreenLayout/MainContent/RightPanel/WorkerRoster"
@onready var _morning_brief = $MorningBrief
@onready var _auditor_screen = $AuditorScreen
@onready var _day_advance_button: Button = $"ScreenLayout/BottomSection/EndShiftButton"
@onready var _day_counter_label: Label = $ScreenLayout/HeaderBar/HeaderContent/DayCounterLabel
@onready var _sigismund_seal: TextureRect = $ScreenLayout/HeaderBar/HeaderContent/SigismundSeal
@onready var _shift_report_panel: PanelContainer = $"ScreenLayout/BottomSection/ShiftReport"
@onready var _shift_report_label: Label = $"ScreenLayout/BottomSection/ShiftReport/ReportContent/ShiftReportLabel"
@onready var _grade_stamp: PanelContainer = $"ScreenLayout/BottomSection/ShiftReport/ReportContent/GradeStamp"
@onready var _grade_stamp_label: Label = $"ScreenLayout/BottomSection/ShiftReport/ReportContent/GradeStamp/GradeStampLabel"
@onready var _shift_report_detail: Label = $"ScreenLayout/BottomSection/ShiftReport/ReportContent/ShiftReportDetail"

var _pending_stage_id: String = ""
var _day_counter_tween: Tween
 

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
        stage_node.worker_state_changed.connect(_on_stage_worker_state_changed)


func _on_stage_assignment_requested(stage_id: String) -> void:
    _pending_stage_id = stage_id
    _refresh_assignment_feedback()


func _on_stage_worker_removed(stage_id: String) -> void:
    GameManager.stage_assignments.erase(stage_id)
    _clear_pending_stage_assignment(stage_id)
    _refresh_stage_previews()


func _on_worker_selected(worker: Worker) -> void:
    if _pending_stage_id.is_empty() or worker.is_resting or worker.is_incapacitated():
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


func _on_stage_worker_state_changed(_stage_id: String, _worker: Worker) -> void:
    _worker_roster.refresh()


func _on_begin_shift_requested() -> void:
    if GameManager.active_event != null:
        return

    _pending_stage_id = ""
    GameManager.begin_shift()
    _set_stage_shift_active(true)
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
    _set_stage_shift_active(false)
    _clear_incapacitated_assignments()
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
    _set_stage_shift_active(false)
    _day_advance_button.visible = false
    _morning_brief.hide_brief()
    _auditor_screen.show_result(ending_id, Ledger.get_audit_snapshot())


func _complete_current_shift() -> void:
    _pending_stage_id = ""
    var stage_outputs: Array[int] = []
    var quality_scores: Array[float] = []
    var floor_hands_used: int = 0

    for stage_id: String in ROLE_BY_STAGE.keys():
        var worker: Worker = GameManager.stage_assignments.get(stage_id) as Worker
        if worker == null:
            stage_outputs.append(FLOOR_HAND_OUTPUT)
            quality_scores.append(FLOOR_HAND_QUALITY)
            floor_hands_used += 1
            continue

        if stage_id == "striking":
            var striking_stage = _stage_nodes[stage_id]
            var striking_results: Dictionary = striking_stage.get_shift_results()
            stage_outputs.append(int(striking_results.get("coins_struck", 0)))
            quality_scores.append(float(striking_results.get("average_quality", 0.0)))
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
    var merchant_or_better: int = 0
    if average_quality >= 65.0:
        merchant_or_better = total_output if floor_hands_used == 0 else int(floor(float(total_output) * FLOOR_HAND_MERCHANT_FACTOR))

    var income_earned: int = merchant_or_better * GROSCHEN_VALUE_PER_MERCHANT_COIN
    Ledger.add_income(income_earned)
    var wages_paid: int = Ledger.apply_daily_wages(GameManager.workers)
    _set_stage_shift_active(false)
    GameManager.complete_shift({
        "total_output": total_output,
        "merchant_grade_or_better": merchant_or_better,
        "quality_grade": quality_grade,
        "floor_hands_used": floor_hands_used,
        "income_earned": income_earned,
        "wages_paid": wages_paid,
        "net_result": income_earned - wages_paid
    })

    if GameManager.current_phase == GameManager.GamePhase.COMPLETE:
        return

    GameManager.evaluate_balance_failure()
    if GameManager.current_phase == GameManager.GamePhase.COMPLETE:
        return

    _apply_end_of_day_worker_updates()
    GameManager.evaluate_worker_collapse()
    if GameManager.current_phase == GameManager.GamePhase.COMPLETE:
        return

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
            stage_node.set_support_preview(FLOOR_HAND_OUTPUT)
            if stage_node.get_assigned_worker() != null:
                stage_node.remove_worker()
            continue

        stage_node.set_support_preview(0)
        if stage_node.get_assigned_worker() != worker:
            stage_node.assign_worker(worker)
        else:
            stage_node.refresh_worker_state()
        stage_node.set_output_preview(0 if worker.is_incapacitated() else _calculate_worker_output(worker))

    _refresh_assignment_feedback()
    _worker_roster.set_stage_assignments(GameManager.stage_assignments)


func _find_stage_for_worker(worker: Worker) -> String:
    for stage_id: String in GameManager.stage_assignments.keys():
        if GameManager.stage_assignments[stage_id] == worker:
            return stage_id
    return ""


func _calculate_worker_output(worker: Worker) -> int:
    if worker.is_incapacitated():
        return 0

    var base_output: float = float(worker.skill) * BASE_OUTPUT_PER_SKILL
    var fatigue_penalty: float = float(worker.fatigue) / 100.0
    return maxi(int(round(base_output * (1.0 - fatigue_penalty * OUTPUT_FATIGUE_PENALTY))), 0)


func _calculate_worker_quality(worker: Worker) -> float:
    return clampf(
        QUALITY_BASE_SCORE + float(worker.skill) * QUALITY_SKILL_WEIGHT - float(worker.fatigue) * QUALITY_FATIGUE_PENALTY,
        0.0,
        100.0
    )


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
    _set_stage_shift_active(GameManager.current_phase == GameManager.GamePhase.SHIFT)
    _clear_incapacitated_assignments()
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
    _grade_stamp.visible = false
    _shift_report_label.text = "No shift completed yet for Day %d." % GameManager.current_day
    _shift_report_detail.text = "Assign the floor, mind the fatigue, and strike enough merchant-grade coin to satisfy the Crown."


func _show_shift_report(results: Dictionary) -> void:
    _shift_report_panel.visible = true
    var total_output: int = int(results.get("total_output", 0))
    var merchant_output: int = int(results.get("merchant_grade_or_better", 0))
    var quality_grade: String = String(results.get("quality_grade", "Debased"))
    _shift_report_label.text = "%d coins struck. %d counted toward quota." % [total_output, merchant_output]
    _grade_stamp.visible = true
    _grade_stamp_label.text = "%s grade" % quality_grade
    _grade_stamp.add_theme_stylebox_override("panel", _build_shift_grade_stamp(quality_grade))
    _shift_report_detail.text = _grade_flavour_comment(quality_grade)


func _update_header_day(day_num: int) -> void:
    _update_sigismund_seal(day_num)

    if _day_counter_tween != null:
        _day_counter_tween.kill()
        _day_counter_tween = null

    if day_num <= 0:
        _day_counter_label.text = "Day - / %d" % GameManager.FINAL_DAY
        _day_counter_label.add_theme_color_override("font_color", DAY_COUNTER_SAFE_COLOR)
        _day_counter_label.modulate = Color(1, 1, 1, 1)
        return

    _day_counter_label.text = "Day %d / %d" % [day_num, GameManager.FINAL_DAY]
    _day_counter_label.modulate = Color(1, 1, 1, 1)

    if day_num >= 13:
        _day_counter_label.add_theme_color_override("font_color", DAY_COUNTER_DANGER_COLOR)
        _day_counter_tween = create_tween()
        _day_counter_tween.set_loops()
        _day_counter_tween.tween_property(_day_counter_label, "modulate:a", DAY_COUNTER_PULSE_MIN_ALPHA, DAY_COUNTER_PULSE_DURATION)
        _day_counter_tween.tween_property(_day_counter_label, "modulate:a", 1.0, DAY_COUNTER_PULSE_DURATION)
        return

    if day_num >= 10:
        _day_counter_label.add_theme_color_override("font_color", DAY_COUNTER_WARNING_COLOR)
        return

    _day_counter_label.add_theme_color_override("font_color", DAY_COUNTER_SAFE_COLOR)


func _update_sigismund_seal(day_num: int) -> void:
    if day_num < 2:
        _sigismund_seal.visible = false
        return

    var seal_alpha: float = lerpf(
        SIGISMUND_SEAL_BASE_ALPHA,
        SIGISMUND_SEAL_MAX_ALPHA,
        clampf(float(day_num - 2) / float(GameManager.FINAL_DAY - 2), 0.0, 1.0)
    )
    _sigismund_seal.visible = true
    _sigismund_seal.modulate = Color(
        SIGISMUND_SEAL_COLOR.r,
        SIGISMUND_SEAL_COLOR.g,
        SIGISMUND_SEAL_COLOR.b,
        seal_alpha
    )


func _build_shift_grade_stamp(quality_grade: String) -> StyleBoxFlat:
    var stylebox := StyleBoxFlat.new()
    stylebox.bg_color = _grade_stamp_color(quality_grade)
    stylebox.border_color = SHIFT_GRADE_BORDER_COLOR
    stylebox.border_width_left = 2
    stylebox.border_width_top = 2
    stylebox.border_width_right = 2
    stylebox.border_width_bottom = 2
    stylebox.content_margin_left = 8.0
    stylebox.content_margin_top = 5.0
    stylebox.content_margin_right = 8.0
    stylebox.content_margin_bottom = 5.0
    stylebox.shadow_color = Color("2a1a02", 0.25)
    stylebox.shadow_size = 1
    _grade_stamp_label.add_theme_color_override("font_color", SHIFT_GRADE_TEXT_COLOR)
    return stylebox


func _grade_stamp_color(quality_grade: String) -> Color:
    match quality_grade:
        "Royal":
            return SHIFT_GRADE_ROYAL_COLOR
        "Merchant":
            return SHIFT_GRADE_MERCHANT_COLOR
        "Common":
            return SHIFT_GRADE_COMMON_COLOR
        _:
            return SHIFT_GRADE_DEBASED_COLOR


func _grade_flavour_comment(quality_grade: String) -> String:
    match quality_grade:
        "Royal":
            return "The groschen ring true."
        "Merchant":
            return "Passable work. The Crown expects more."
        "Common":
            return "Sloppy. The assayer is unhappy."
        _:
            return "These would shame a beggar. The auditor cannot see these."


func _clear_incapacitated_assignments() -> void:
    for stage_id: String in GameManager.stage_assignments.keys():
        var worker: Worker = GameManager.stage_assignments.get(stage_id) as Worker
        if worker != null and worker.is_incapacitated():
            GameManager.stage_assignments.erase(stage_id)


func _set_stage_shift_active(is_active: bool) -> void:
    for stage_id: String in _stage_nodes.keys():
        var stage_node = _stage_nodes[stage_id]
        stage_node.set_shift_active(is_active)
