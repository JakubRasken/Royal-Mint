# Implements the day state machine autoload so the jam loop can advance days,
# coordinate autoload systems, and remain decoupled from scene/UI logic.
extends Node

signal day_started(day_num: int)
signal day_ended(results: Dictionary)
signal game_over(ending_id: String)
signal sigismund_attention_changed(level: int)

const FIRST_DAY: int = 1
const FINAL_DAY: int = 14
const SHIFT_DURATION_SECONDS: int = 90
const ZERO_OUTPUT_FAILURE_THRESHOLD: int = 3
const SIGISMUND_ATTENTION_MAX: int = 5
const JOURNAL_ENTRY_BY_CONDITION: Dictionary = {
    "high_quality": "A good day's work. The groschen rang true against the stone.",
    "jiri_fatigued": "Jiri could barely lift the hammer by dusk. I should let him rest tomorrow.",
    "quota_missed": "The Crown's man will notice. I need to push harder.",
    "debased_sent": "God forgive me. Those coins will buy bread for someone.",
    "sigismund_complied": "I told myself it was just this once.",
    "default": "The books close for now, but tomorrow will ask the same of me again."
}
const DAILY_FLAVOUR_BY_WORKER: Dictionary = {
    "Radek": {
        "idle": [
            "Sharpening tools. Waiting.",
            "Arms crossed. Ready."
        ],
        "fatigued": [
            "Hands shaking. Needs rest.",
            "Soot in his lungs. Still glaring at the furnace."
        ],
        "rested": [
            "Back straight. Ready to work.",
            "Fresh from rest. The furnace has his attention."
        ]
    },
    "Bozena": {
        "idle": [
            "Eyeing the ledger suspiciously.",
            "Polishing the assay scales."
        ],
        "fatigued": [
            "Eyes bloodshot. Barely standing.",
            "Squinting at the silver. Her patience is spent."
        ],
        "rested": [
            "Back straight. Ready to work.",
            "Quill trimmed. Scales steady again."
        ]
    },
    "Jiri": {
        "idle": [
            "Idle and muttering about the pay.",
            "Picking at the die. Restless."
        ],
        "fatigued": [
            "Hands shaking. Needs rest.",
            "Eyes bloodshot. Barely standing."
        ],
        "rested": [
            "Back straight. Ready to work.",
            "Rested, but still watching the purse."
        ]
    }
}

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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sigismund_attention: int = 0


func start_new_game() -> void:
    _rng.randomize()
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
    _sigismund_attention = 0
    Ledger.reset()
    EventManager.reload_events()
    sigismund_attention_changed.emit(_sigismund_attention)
    _start_day(FIRST_DAY)


func begin_shift() -> void:
    if current_phase != GamePhase.MORNING_BRIEF:
        return
    current_phase = GamePhase.SHIFT


func complete_shift(results: Dictionary) -> void:
    if current_phase != GamePhase.SHIFT:
        return

    _last_shift_results = results.duplicate(true)
    if String(_last_shift_results.get("quality_grade", "")) == "Debased":
        _raise_sigismund_attention()
    current_phase = GamePhase.EVENING_REPORT

    var merchant_grade_output: int = int(_last_shift_results.get("merchant_grade_or_better", 0))
    var total_output: int = int(_last_shift_results.get("total_output", 0))
    Ledger.set_daily_output(merchant_grade_output)

    # Treat the collapse check as literal zero coins produced.
    # Low-quality output can fail the quota without meaning the mint stood still.
    if total_output <= 0:
        _consecutive_zero_output_days += 1
    else:
        _consecutive_zero_output_days = 0

    day_ended.emit(_last_shift_results.duplicate(true))

    if _consecutive_zero_output_days >= ZERO_OUTPUT_FAILURE_THRESHOLD:
        _trigger_immediate_failure("zero_output_collapse")
        return

    if Ledger.did_exhaust_quota_grace():
        _trigger_immediate_failure("quota_grace_exhausted")


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
    if bool(effects.get("accepts_sigismund_bribe", false)):
        _raise_sigismund_attention()
    resolved_event_summary = _describe_event_resolution(resolved_event, choice_id, effects)
    active_event = null
    return effects


func get_last_shift_results() -> Dictionary:
    return _last_shift_results.duplicate(true)


func refresh_journal_entry() -> void:
    if _last_shift_results.is_empty():
        return
    _last_shift_results["journal_entry"] = _build_journal_entry(_last_shift_results)


func get_sigismund_attention() -> int:
    return _sigismund_attention


func is_sigismund_attention_maxed() -> bool:
    return _sigismund_attention >= SIGISMUND_ATTENTION_MAX


func evaluate_worker_collapse() -> void:
    if workers.is_empty():
        return

    for worker: Worker in workers:
        if not worker.is_incapacitated():
            return

    _trigger_immediate_failure("workers_incapacitated")


func evaluate_balance_failure() -> void:
    if Ledger.is_bankrupt():
        _trigger_immediate_failure("ledger_bankrupt")


func _start_day(day_num: int) -> void:
    current_day = day_num
    current_phase = GamePhase.MORNING_BRIEF
    resolved_event = null
    resolved_event_choice_id = ""
    resolved_event_summary = ""
    Ledger.start_day(current_day)
    active_event = EventManager.trigger_day_event(current_day)
    _assign_daily_flavour()
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
    if current_phase == GamePhase.COMPLETE:
        return

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


func _assign_daily_flavour() -> void:
    for worker: Worker in workers:
        worker.daily_flavour = _pick_daily_flavour(worker)


func _pick_daily_flavour(worker: Worker) -> String:
    var flavour_sets: Dictionary = DAILY_FLAVOUR_BY_WORKER.get(worker.worker_name, {}) as Dictionary
    if flavour_sets.is_empty():
        return ""

    var flavour_key: String = "idle"
    if worker.fatigue >= 80:
        flavour_key = "fatigued"
    elif current_day > FIRST_DAY and worker.fatigue == 0:
        flavour_key = "rested"

    var flavour_options: Array = flavour_sets.get(flavour_key, [])
    if flavour_options.is_empty():
        flavour_options = flavour_sets.get("idle", [])
    if flavour_options.is_empty():
        return ""

    return String(flavour_options[_rng.randi_range(0, flavour_options.size() - 1)])


func _raise_sigismund_attention(amount: int = 1) -> void:
    var next_attention: int = clampi(_sigismund_attention + maxi(amount, 0), 0, SIGISMUND_ATTENTION_MAX)
    if next_attention == _sigismund_attention:
        return
    _sigismund_attention = next_attention
    sigismund_attention_changed.emit(_sigismund_attention)


func _build_journal_entry(results: Dictionary) -> String:
    var quality_grade: String = String(results.get("quality_grade", ""))
    if resolved_event != null and resolved_event.event_id == "sigismund_bribe" and resolved_event_choice_id == "a":
        return JOURNAL_ENTRY_BY_CONDITION["sigismund_complied"]
    if quality_grade == "Debased":
        return JOURNAL_ENTRY_BY_CONDITION["debased_sent"]
    if not Ledger.did_meet_daily_quota():
        return JOURNAL_ENTRY_BY_CONDITION["quota_missed"]

    var jiri: Worker = _find_worker_by_name("Jiri")
    if jiri != null and jiri.fatigue >= 80:
        return JOURNAL_ENTRY_BY_CONDITION["jiri_fatigued"]
    if quality_grade == "Royal":
        return JOURNAL_ENTRY_BY_CONDITION["high_quality"]
    return JOURNAL_ENTRY_BY_CONDITION["default"]


func _find_worker_by_name(worker_name: String) -> Worker:
    for worker: Worker in workers:
        if worker.worker_name == worker_name:
            return worker
    return null


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
