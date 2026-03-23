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
const SHIFT_TIMER_BELL_FREQUENCY: float = 523.25
const SHIFT_TIMER_BELL_DURATION: float = 0.18
const SHIFT_TIMER_BELL_GAIN: float = 0.18
const SHIFT_TIMER_BELL_BUFFER_LENGTH: float = 0.3
const SHIFT_TIMER_BELL_PULSE_MIN_ALPHA: float = 0.55
const SHIFT_TIMER_BELL_PULSE_SPEED: float = 4.0
const INTERRUPTION_OUTPUT_LABEL_FORMAT: String = "%d coins struck. %d counted toward quota."
const ASSAY_INSPECTION_DURATION: float = 8.0
const ASSAY_SAMPLE_COUNT: int = 5
const ASSAY_ROYAL_SCORE: float = 92.0
const ASSAY_MERCHANT_SCORE: float = 74.0
const ASSAY_COMMON_SCORE: float = 54.0
const ASSAY_DEBASED_SCORE: float = 18.0
const ASSAY_HINT_COLOR: Color = Color(0.5451, 0.1019, 0.1019, 0.45)
const ASSAY_NORMAL_COLOR: Color = Color(1, 1, 1, 1)

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
@onready var _shift_timer_section: VBoxContainer = $"ScreenLayout/MainContent/LeftPanel/ShiftTimerSection"
@onready var _shift_timer_bar = $"ScreenLayout/MainContent/LeftPanel/ShiftTimerSection/ShiftTimerBar"
@onready var _shift_timer_warning_label: Label = $"ScreenLayout/MainContent/LeftPanel/ShiftTimerSection/ShiftTimerWarningLabel"
@onready var _shift_timer_audio_player: AudioStreamPlayer = $"ScreenLayout/MainContent/LeftPanel/ShiftTimerSection/ShiftTimerAudioPlayer"
@onready var _interruption_overlay: Control = $InterruptionOverlay
@onready var _interruption_title: Label = $"InterruptionOverlay/InterruptionPanel/InterruptionContent/InterruptionTitle"
@onready var _interruption_narrative: Label = $"InterruptionOverlay/InterruptionPanel/InterruptionContent/InterruptionNarrative"
@onready var _interruption_choice_a_button: Button = $"InterruptionOverlay/InterruptionPanel/InterruptionContent/InterruptionChoiceRow/InterruptionChoiceAButton"
@onready var _interruption_choice_b_button: Button = $"InterruptionOverlay/InterruptionPanel/InterruptionContent/InterruptionChoiceRow/InterruptionChoiceBButton"
@onready var _assay_overlay: Control = $AssayOverlay
@onready var _assay_timer_label: Label = $"AssayOverlay/AssayPanel/AssayContent/AssayTimerLabel"
@onready var _assay_coin_buttons: Array[TextureButton] = [
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot1/CoinButton1",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot2/CoinButton2",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot3/CoinButton3",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot4/CoinButton4",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot5/CoinButton5"
]
@onready var _assay_reject_marks: Array[Label] = [
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot1/CoinButton1/RejectMark1",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot2/CoinButton2/RejectMark2",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot3/CoinButton3/RejectMark3",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot4/CoinButton4/RejectMark4",
    $"AssayOverlay/AssayPanel/AssayContent/AssayCoinRow/CoinSlot5/CoinButton5/RejectMark5"
]

var _pending_stage_id: String = ""
var _day_counter_tween: Tween
var _shift_time_remaining: float = 0.0
var _shift_timer_running: bool = false
var _shift_timer_warning_played: bool = false
var _shift_timer_audio_playback: AudioStreamGeneratorPlayback
var _shift_timer_elapsed: float = 0.0
var _shift_output_multiplier: float = 1.0
var _shift_flat_coin_loss: int = 0
var _shift_quality_penalty: float = 0.0
var _forced_floor_hands_stages: Dictionary = {}
var _active_interruption_note: String = ""
var _shift_interruption_active: bool = false
var _assay_inspection_active: bool = false
var _assay_time_remaining: float = 0.0
var _assay_samples: Array[Dictionary] = []
var _pending_shift_results: Dictionary = {}
var _assay_rng: RandomNumberGenerator = RandomNumberGenerator.new()
 

func _ready() -> void:
    _setup_shift_timer_audio()
    _connect_stage_signals()
    _worker_roster.worker_selected.connect(_on_worker_selected)
    _worker_roster.rest_toggled.connect(_on_worker_rest_toggled)
    _morning_brief.begin_shift_requested.connect(_on_begin_shift_requested)
    _morning_brief.event_choice_selected.connect(_on_event_choice_selected)
    _day_advance_button.pressed.connect(_on_day_advance_pressed)
    _interruption_choice_a_button.pressed.connect(_on_interruption_choice_pressed.bind("a"))
    _interruption_choice_b_button.pressed.connect(_on_interruption_choice_pressed.bind("b"))
    for coin_index: int in _assay_coin_buttons.size():
        _assay_coin_buttons[coin_index].pressed.connect(_on_assay_coin_pressed.bind(coin_index))

    GameManager.day_started.connect(_on_day_started)
    GameManager.day_ended.connect(_on_day_ended)
    GameManager.game_over.connect(_on_game_over)
    EventManager.shift_interruption_triggered.connect(_on_shift_interruption_triggered)

    _worker_roster.set_workers(GameManager.workers)
    if GameManager.current_phase == GameManager.GamePhase.NOT_STARTED and GameManager.current_day == 0:
        GameManager.start_new_game()
        _worker_roster.set_workers(GameManager.workers)
    else:
        _resume_from_game_state()


func _process(delta: float) -> void:
    _update_shift_timer(delta)
    _update_assay_inspection(delta)


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
    _refresh_shift_interruption_candidates()


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
    _refresh_shift_interruption_candidates()


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
    _refresh_shift_interruption_candidates()


func _on_stage_worker_state_changed(_stage_id: String, _worker: Worker) -> void:
    _worker_roster.refresh()
    _refresh_shift_interruption_candidates()


func _on_begin_shift_requested() -> void:
    if GameManager.active_event != null:
        return

    _pending_stage_id = ""
    _reset_shift_modifiers()
    GameManager.begin_shift()
    _set_stage_shift_active(true)
    _start_shift_timer()
    EventManager.begin_shift_interruptions(_build_shift_interruption_candidates())
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
    _stop_shift_timer()
    EventManager.end_shift_interruptions()
    _hide_shift_interruption()
    _hide_assay_inspection()
    _clear_incapacitated_assignments()
    _update_header_day(day_num)
    _morning_brief.show_brief(day_num, GameManager.active_event)
    _refresh_stage_previews()
    _worker_roster.refresh()
    _show_waiting_shift_report()
    _update_day_button_for_phase()
    _refresh_shift_interruption_candidates()


func _on_day_ended(_results: Dictionary) -> void:
    _show_shift_report(GameManager.get_last_shift_results())
    _update_day_button_for_phase()


func _on_game_over(ending_id: String) -> void:
    _set_stage_shift_active(false)
    _stop_shift_timer()
    EventManager.end_shift_interruptions()
    _hide_shift_interruption()
    _hide_assay_inspection()
    _shift_timer_section.visible = false
    _day_advance_button.visible = false
    _morning_brief.hide_brief()
    _auditor_screen.show_result(ending_id, Ledger.get_audit_snapshot())


func _complete_current_shift() -> void:
    _stop_shift_timer()
    _set_stage_shift_active(false)
    EventManager.end_shift_interruptions()
    _hide_shift_interruption()
    _pending_stage_id = ""
    var pending_results: Dictionary = _build_pending_shift_results()
    if _should_run_assay_inspection(pending_results):
        _start_assay_inspection(pending_results)
        return
    _finalize_shift_results(pending_results)


func _build_pending_shift_results() -> Dictionary:
    var stage_outputs: Array[int] = []
    var quality_scores: Array[float] = []
    var floor_hands_used: int = 0

    for stage_id: String in ROLE_BY_STAGE.keys():
        var worker: Worker = GameManager.stage_assignments.get(stage_id) as Worker
        var forced_floor_hands: bool = _forced_floor_hands_stages.get(stage_id, false)
        if worker == null or forced_floor_hands:
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

    var raw_total_output: int = stage_outputs.min() if not stage_outputs.is_empty() else 0
    var average_quality: float = 0.0
    if not quality_scores.is_empty():
        for score: float in quality_scores:
            average_quality += score
        average_quality /= quality_scores.size()

    var total_output: int = maxi(int(round(float(raw_total_output) * _shift_output_multiplier)) - _shift_flat_coin_loss, 0)
    average_quality = clampf(average_quality - _shift_quality_penalty, 0.0, 100.0)

    return {
        "total_output": total_output,
        "average_quality": average_quality,
        "floor_hands_used": floor_hands_used
    }

 
func _finalize_shift_results(pending_results: Dictionary) -> void:
    var total_output: int = int(pending_results.get("total_output", 0))
    var average_quality: float = float(pending_results.get("average_quality", 0.0))
    var floor_hands_used: int = int(pending_results.get("floor_hands_used", 0))
    var quality_grade: String = _quality_grade_from_score(average_quality)
    var merchant_or_better: int = 0
    if average_quality >= 65.0:
        merchant_or_better = total_output if floor_hands_used == 0 else int(floor(float(total_output) * FLOOR_HAND_MERCHANT_FACTOR))

    var income_earned: int = merchant_or_better * GROSCHEN_VALUE_PER_MERCHANT_COIN
    Ledger.add_income(income_earned)
    var wages_paid: int = Ledger.apply_daily_wages(GameManager.workers)
    GameManager.complete_shift({
        "total_output": total_output,
        "merchant_grade_or_better": merchant_or_better,
        "quality_grade": quality_grade,
        "floor_hands_used": floor_hands_used,
        "income_earned": income_earned,
        "wages_paid": wages_paid,
        "net_result": income_earned - wages_paid,
        "interruption_note": _active_interruption_note
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


func _should_run_assay_inspection(pending_results: Dictionary) -> bool:
    # Only open the assay pass when there is an actual batch to inspect.
    var assay_worker: Worker = GameManager.stage_assignments.get("assay") as Worker
    return (
        assay_worker != null
        and not assay_worker.is_incapacitated()
        and int(pending_results.get("total_output", 0)) > 0
    )


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
    _shift_timer_section.visible = GameManager.current_phase == GameManager.GamePhase.SHIFT


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

    if GameManager.current_phase == GameManager.GamePhase.SHIFT:
        _start_shift_timer()
    else:
        _stop_shift_timer()


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
    var interruption_note: String = String(results.get("interruption_note", ""))
    _shift_report_label.text = INTERRUPTION_OUTPUT_LABEL_FORMAT % [total_output, merchant_output]
    _grade_stamp.visible = true
    _grade_stamp_label.text = "%s grade" % quality_grade
    _grade_stamp.add_theme_stylebox_override("panel", _build_shift_grade_stamp(quality_grade))
    _shift_report_detail.text = _grade_flavour_comment(quality_grade)
    if not interruption_note.is_empty():
        _shift_report_detail.text += " " + interruption_note


func _start_assay_inspection(pending_results: Dictionary) -> void:
    _pending_shift_results = pending_results.duplicate(true)
    _assay_samples = _generate_assay_samples(float(pending_results.get("average_quality", 0.0)))
    _assay_time_remaining = ASSAY_INSPECTION_DURATION
    _assay_inspection_active = true
    _assay_overlay.visible = true
    _assay_rng.randomize()
    _refresh_assay_samples()


func _update_assay_inspection(delta: float) -> void:
    if not _assay_inspection_active:
        return

    _assay_time_remaining = maxf(_assay_time_remaining - delta, 0.0)
    _assay_timer_label.text = "Inspection window: %0.1fs" % _assay_time_remaining
    if _assay_time_remaining <= 0.0:
        _resolve_assay_inspection()


func _on_assay_coin_pressed(coin_index: int) -> void:
    if not _assay_inspection_active:
        return
    if coin_index < 0 or coin_index >= _assay_samples.size():
        return

    var sample: Dictionary = _assay_samples[coin_index]
    sample["rejected"] = not bool(sample.get("rejected", false))
    _assay_samples[coin_index] = sample
    _refresh_assay_samples()


func _refresh_assay_samples() -> void:
    var assay_worker: Worker = GameManager.stage_assignments.get("assay") as Worker
    var show_bad_hints: bool = assay_worker != null and assay_worker.skill >= 3
    for coin_index: int in _assay_coin_buttons.size():
        var button: TextureButton = _assay_coin_buttons[coin_index]
        var reject_mark: Label = _assay_reject_marks[coin_index]
        var sample: Dictionary = _assay_samples[coin_index] if coin_index < _assay_samples.size() else {}
        var sample_grade: String = String(sample.get("grade", "Merchant"))
        var rejected: bool = bool(sample.get("rejected", false))
        var show_hint: bool = show_bad_hints and sample_grade == "Debased"
        button.modulate = ASSAY_HINT_COLOR if show_hint else ASSAY_NORMAL_COLOR
        reject_mark.visible = rejected


func _resolve_assay_inspection() -> void:
    var accepted_samples: Array[Dictionary] = []
    for sample: Dictionary in _assay_samples:
        if not bool(sample.get("rejected", false)):
            accepted_samples.append(sample)

    var accepted_ratio: float = float(accepted_samples.size()) / float(maxi(ASSAY_SAMPLE_COUNT, 1))
    var adjusted_results: Dictionary = _pending_shift_results.duplicate(true)
    adjusted_results["total_output"] = int(floor(float(int(_pending_shift_results.get("total_output", 0))) * accepted_ratio))

    var accepted_quality_total: float = 0.0
    for sample: Dictionary in accepted_samples:
        accepted_quality_total += float(sample.get("score", 0.0))
    adjusted_results["average_quality"] = 0.0 if accepted_samples.is_empty() else accepted_quality_total / float(accepted_samples.size())

    _hide_assay_inspection()
    _finalize_shift_results(adjusted_results)


func _hide_assay_inspection() -> void:
    _assay_inspection_active = false
    _assay_overlay.visible = false
    _assay_time_remaining = 0.0
    _assay_samples.clear()
    _pending_shift_results.clear()


func _generate_assay_samples(average_quality: float) -> Array[Dictionary]:
    _assay_rng.randomize()
    var samples: Array[Dictionary] = []
    for _sample_index: int in ASSAY_SAMPLE_COUNT:
        var sample_score: float = clampf(average_quality + _assay_rng.randf_range(-28.0, 24.0), 0.0, 100.0)
        var sample_grade: String = _quality_grade_from_score(sample_score)
        samples.append({
            "score": _score_for_grade(sample_grade),
            "grade": sample_grade,
            "rejected": false
        })
    return samples


func _score_for_grade(quality_grade: String) -> float:
    match quality_grade:
        "Royal":
            return ASSAY_ROYAL_SCORE
        "Merchant":
            return ASSAY_MERCHANT_SCORE
        "Common":
            return ASSAY_COMMON_SCORE
        _:
            return ASSAY_DEBASED_SCORE


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


func _start_shift_timer() -> void:
    _shift_time_remaining = float(GameManager.SHIFT_DURATION_SECONDS)
    _shift_timer_elapsed = 0.0
    _shift_timer_running = true
    _shift_timer_warning_played = false
    _shift_timer_section.visible = true
    _update_shift_timer_display()


func _stop_shift_timer() -> void:
    _shift_timer_running = false
    _shift_time_remaining = 0.0
    _shift_timer_elapsed = 0.0
    _shift_timer_warning_played = false
    _shift_timer_section.visible = false
    _update_shift_timer_display()


func _update_shift_timer(delta: float) -> void:
    if not _shift_timer_running:
        return
    if GameManager.current_phase != GameManager.GamePhase.SHIFT:
        return
    if _morning_brief.visible:
        return
    if _shift_interruption_active:
        return

    _shift_time_remaining = maxf(_shift_time_remaining - delta, 0.0)
    _shift_timer_elapsed += delta

    if not _shift_timer_warning_played and _shift_time_remaining <= 60.0:
        _shift_timer_warning_played = true
        _play_shift_timer_bell()

    _update_shift_timer_display()

    if _shift_time_remaining <= 0.0:
        _complete_current_shift()


func _update_shift_timer_display() -> void:
    var remaining_ratio: float = 0.0
    if GameManager.SHIFT_DURATION_SECONDS > 0:
        remaining_ratio = clampf(_shift_time_remaining / float(GameManager.SHIFT_DURATION_SECONDS), 0.0, 1.0)

    var timer_phase: int = _shift_timer_phase()
    var pulse_alpha: float = 1.0
    if timer_phase == 2:
        pulse_alpha = lerpf(
            SHIFT_TIMER_BELL_PULSE_MIN_ALPHA,
            1.0,
            (sin(_shift_timer_elapsed * SHIFT_TIMER_BELL_PULSE_SPEED) + 1.0) * 0.5
        )

    _shift_timer_bar.set_display(remaining_ratio, timer_phase, pulse_alpha)
    _shift_timer_warning_label.visible = _shift_timer_running and _shift_time_remaining <= 30.0


func _shift_timer_phase() -> int:
    if _shift_time_remaining <= 30.0:
        return 2
    if _shift_time_remaining <= 60.0:
        return 1
    return 0


func _setup_shift_timer_audio() -> void:
    var timer_stream := AudioStreamGenerator.new()
    timer_stream.mix_rate = 44100.0
    timer_stream.buffer_length = SHIFT_TIMER_BELL_BUFFER_LENGTH
    _shift_timer_audio_player.stream = timer_stream
    _shift_timer_audio_player.play()
    _shift_timer_audio_playback = _shift_timer_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _play_shift_timer_bell() -> void:
    if _shift_timer_audio_playback == null:
        return

    var total_frames: int = int(SHIFT_TIMER_BELL_DURATION * 44100.0)
    for frame_index: int in total_frames:
        var envelope: float = 1.0 - float(frame_index) / float(maxi(total_frames, 1))
        var sample: float = sin(TAU * SHIFT_TIMER_BELL_FREQUENCY * float(frame_index) / 44100.0) * SHIFT_TIMER_BELL_GAIN * envelope
        _shift_timer_audio_playback.push_frame(Vector2(sample, sample))


func _on_shift_interruption_triggered(interruption: Dictionary) -> void:
    if GameManager.current_phase != GameManager.GamePhase.SHIFT:
        return

    _shift_interruption_active = true
    _set_stage_shift_active(false)
    EventManager.pause_shift_interruptions()
    _interruption_title.text = String(interruption.get("title", "Interruption"))
    _interruption_narrative.text = String(interruption.get("narrative", "The floor demands a decision."))
    _interruption_choice_a_button.text = String(interruption.get("choice_a_label", "Choice A"))
    _interruption_choice_b_button.text = String(interruption.get("choice_b_label", "Choice B"))
    _interruption_overlay.visible = true


func _on_interruption_choice_pressed(choice_id: String) -> void:
    var effects: Dictionary = EventManager.resolve_shift_interruption(choice_id)
    _apply_shift_interruption_effects(effects)
    _hide_shift_interruption()
    if GameManager.current_phase == GameManager.GamePhase.SHIFT:
        _set_stage_shift_active(true)
        EventManager.resume_shift_interruptions()
        _worker_roster.refresh()
        _refresh_stage_previews()
        _refresh_shift_interruption_candidates()


func _hide_shift_interruption() -> void:
    _shift_interruption_active = false
    _interruption_overlay.visible = false


func _apply_shift_interruption_effects(effects: Dictionary) -> void:
    if effects.has("output_multiplier"):
        _shift_output_multiplier *= float(effects["output_multiplier"])

    if effects.has("flat_coin_loss"):
        var available_struck_coins: int = maxi(_current_struck_coin_count() - _shift_flat_coin_loss, 0)
        _shift_flat_coin_loss += mini(int(effects["flat_coin_loss"]), available_struck_coins)

    if effects.has("quality_penalty"):
        _shift_quality_penalty += float(effects["quality_penalty"])

    if effects.has("force_floor_hands_stage"):
        _forced_floor_hands_stages[String(effects["force_floor_hands_stage"])] = true

    if effects.has("interruption_note"):
        _active_interruption_note = String(effects["interruption_note"])

    if effects.has("worker_fatigue_delta"):
        var fatigue_delta: Dictionary = effects["worker_fatigue_delta"] as Dictionary
        for worker_name: Variant in fatigue_delta.keys():
            var worker: Worker = _find_worker_by_name(String(worker_name))
            if worker != null:
                worker.fatigue = clampi(worker.fatigue + int(fatigue_delta[worker_name]), 0, Worker.MAX_FATIGUE)


func _reset_shift_modifiers() -> void:
    _shift_output_multiplier = 1.0
    _shift_flat_coin_loss = 0
    _shift_quality_penalty = 0.0
    _forced_floor_hands_stages.clear()
    _active_interruption_note = ""


func _find_worker_by_name(worker_name: String) -> Worker:
    for worker: Worker in GameManager.workers:
        if worker.worker_name == worker_name:
            return worker
    return null


func _refresh_shift_interruption_candidates() -> void:
    EventManager.set_shift_interruption_candidates(_build_shift_interruption_candidates())


func _build_shift_interruption_candidates() -> Array[String]:
    var interruption_candidates: Array[String] = ["suspicious_visitor"]
    var smelting_worker: Worker = GameManager.stage_assignments.get("smelting") as Worker
    if smelting_worker != null and not smelting_worker.is_resting and not smelting_worker.is_incapacitated():
        interruption_candidates.append("furnace_spike")
        if smelting_worker.worker_name == "Radek":
            interruption_candidates.append("worker_slowing")

    var striking_worker: Worker = GameManager.stage_assignments.get("striking") as Worker
    if (
        striking_worker != null
        and striking_worker.worker_name == "Jiri"
        and not striking_worker.is_resting
        and not striking_worker.is_incapacitated()
        and _current_struck_coin_count() > 0
    ):
        interruption_candidates.append("jiri_drops_die")

    return interruption_candidates


func _current_struck_coin_count() -> int:
    var striking_stage = _stage_nodes.get("striking")
    if striking_stage == null:
        return 0
    var striking_results: Dictionary = striking_stage.get_shift_results()
    return int(striking_results.get("coins_struck", 0))
