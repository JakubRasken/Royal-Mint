# Implements the day state machine autoload so the jam loop can advance days,
# coordinate autoload systems, and remain decoupled from scene/UI logic.
extends Node

signal day_started(day_num: int)
signal day_ended(results: Dictionary)
signal game_over(ending_id: String)

const FIRST_DAY: int = 1
const FINAL_DAY: int = 14
const ZERO_OUTPUT_FAILURE_THRESHOLD: int = 3

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
var last_ending_id: String = ""
var workers: Array[Worker] = []
var stage_assignments: Dictionary = {}
var resolved_event: GameEvent
var resolved_event_choice_id: String = ""
var resolved_event_summary: String = ""
var _consecutive_zero_output_days: int = 0
var _last_shift_results: Dictionary = {}


func start_new_game() -> void:
    current_day = FIRST_DAY - 1
    current_phase = GamePhase.NOT_STARTED
    active_event = null
    last_ending_id = ""
    resolved_event = null
    resolved_event_choice_id = ""
    resolved_event_summary = ""
    stage_assignments.clear()
    _load_workers()
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
    var total_output: int = int(results.get("total_output", 0))
    Ledger.set_daily_output(merchant_grade_output)

    if total_output <= 0:
        _consecutive_zero_output_days += 1
    else:
        _consecutive_zero_output_days = 0

    day_ended.emit(_last_shift_results.duplicate(true))

    if _consecutive_zero_output_days >= ZERO_OUTPUT_FAILURE_THRESHOLD:
        _trigger_immediate_failure("zero_output_collapse")


func advance_day() -> void:
    if current_phase != GamePhase.EVENING_REPORT:
        return

    if current_day >= FINAL_DAY:
        _run_audit()
        return

    _start_day(current_day + 1)


func resolve_active_event(choice_id: String) -> Dictionary:
    if active_event == null:
        return {}

    resolved_event = active_event
    resolved_event_choice_id = choice_id
    var effects: Dictionary = EventManager.resolve_active_event(choice_id)
    resolved_event_summary = _describe_event_resolution(resolved_event, choice_id, effects)
    active_event = null
    return effects


func get_last_shift_results() -> Dictionary:
    return _last_shift_results.duplicate(true)


func _start_day(day_num: int) -> void:
    current_day = day_num
    current_phase = GamePhase.MORNING_BRIEF
    resolved_event = null
    resolved_event_choice_id = ""
    resolved_event_summary = ""
    Ledger.start_day(current_day)
    active_event = EventManager.trigger_day_event(current_day)
    day_started.emit(current_day)


func _run_audit() -> void:
    current_phase = GamePhase.AUDIT

    var quota_passed: bool = Ledger.did_meet_cumulative_quota()
    var ledger_clean: bool = Ledger.has_clean_ledger()
    var ending_id: String = "audit_pass" if quota_passed and ledger_clean else "audit_fail"

    last_ending_id = ending_id
    current_phase = GamePhase.COMPLETE
    game_over.emit(ending_id)


func _trigger_immediate_failure(ending_id: String) -> void:
    last_ending_id = ending_id
    current_phase = GamePhase.COMPLETE
    game_over.emit(ending_id)


func _load_workers() -> void:
    workers.clear()
    var worker_paths: PackedStringArray = [
        "res://data/workers/radek.tres",
        "res://data/workers/bozena.tres",
        "res://data/workers/jiri.tres"
    ]

    for worker_path: String in worker_paths:
        var worker: Worker = load(worker_path) as Worker
        if worker != null:
            workers.append(worker.duplicate(true) as Worker)


func _describe_event_resolution(event_resource: GameEvent, choice_id: String, effects: Dictionary) -> String:
    if event_resource == null:
        return "The clerk records your order and sends the room back to work."

    if event_resource.event_id == "sigismund_bribe":
        if choice_id == "a":
            return (
                "Sigismund's silver changes hands. The men keep silent, the books do not."
            )
        return (
            "The envoy leaves affronted. Jiri mutters at the lost coin and the mood turns colder."
        )

    var consequence_parts: Array[String] = []
    if effects.has("balance_delta"):
        var balance_delta: int = int(effects["balance_delta"])
        if balance_delta > 0:
            consequence_parts.append("The ledger gains %d groschen." % balance_delta)
        elif balance_delta < 0:
            consequence_parts.append("The ledger loses %d groschen." % abs(balance_delta))

    if effects.has("ledger_flag"):
        consequence_parts.append("A questionable ledger mark remains behind.")

    if effects.has("worker_loyalty_delta"):
        var loyalty_delta: Dictionary = effects["worker_loyalty_delta"] as Dictionary
        for worker_name: Variant in loyalty_delta.keys():
            var amount: int = int(loyalty_delta[worker_name])
            if amount == 0:
                continue
            var direction: String = "rises" if amount > 0 else "falls"
            consequence_parts.append("%s's loyalty %s." % [String(worker_name), direction])

    if consequence_parts.is_empty():
        return "The clerk records your order and sends the room back to work."

    return " ".join(consequence_parts)
