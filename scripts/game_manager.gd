# Implements the day state machine autoload so the jam loop can advance days,
# coordinate autoload systems, and remain decoupled from scene/UI logic.
extends Node

signal day_started(day_num: int)
signal day_ended(results: Dictionary)
signal game_over(ending_id: String)

const FIRST_DAY: int = 1
const FINAL_DAY: int = 14

enum GamePhase {
    NOT_STARTED,
    MORNING_BRIEF,
    SHIFT,
    EVENING_REPORT,
    AUDIT,
    COMPLETE
}

var current_day: int = 0
var current_phase: GamePhase = GamePhase.NOT_STARTED
var active_event: GameEvent
var _consecutive_zero_output_days: int = 0
var _last_shift_results: Dictionary = {}


func start_new_game() -> void:
    current_day = FIRST_DAY - 1
    current_phase = GamePhase.NOT_STARTED
    active_event = null
    _consecutive_zero_output_days = 0
    _last_shift_results.clear()
    Ledger.reset()
    EventManager.reload_events()
    _start_day(FIRST_DAY)


func begin_shift() -> void:
    if current_phase != GamePhase.MORNING_BRIEF:
        return
    current_phase = GamePhase.SHIFT


func complete_shift(results: Dictionary) -> void:
    if current_phase != GamePhase.SHIFT:
        return

    _last_shift_results = results.duplicate(true)
    current_phase = GamePhase.EVENING_REPORT

    var merchant_grade_output: int = int(results.get("merchant_grade_or_better", 0))
    Ledger.set_daily_output(merchant_grade_output)

    if merchant_grade_output <= 0:
        _consecutive_zero_output_days += 1
    else:
        _consecutive_zero_output_days = 0

    day_ended.emit(_last_shift_results.duplicate(true))


func advance_day() -> void:
    if current_phase != GamePhase.EVENING_REPORT:
        return

    if current_day >= FINAL_DAY:
        _run_audit()
        return

    _start_day(current_day + 1)


func resolve_active_event(choice_id: String) -> Dictionary:
    return EventManager.resolve_active_event(choice_id)


func get_last_shift_results() -> Dictionary:
    return _last_shift_results.duplicate(true)


func _start_day(day_num: int) -> void:
    current_day = day_num
    current_phase = GamePhase.MORNING_BRIEF
    Ledger.start_day(current_day)
    active_event = EventManager.trigger_day_event(current_day)
    day_started.emit(current_day)


func _run_audit() -> void:
    current_phase = GamePhase.AUDIT

    var quota_passed: bool = Ledger.did_meet_cumulative_quota()
    var ledger_clean: bool = Ledger.has_clean_ledger()
    var ending_id: String = "audit_pass" if quota_passed and ledger_clean else "audit_fail"

    current_phase = GamePhase.COMPLETE
    game_over.emit(ending_id)
