# Implements the event autoload that loads authored GameEvent resources and
# resolves one active event at a time without any direct scene references.
extends Node

signal event_triggered(event_id: String)
signal event_resolved(event_id: String, choice: String)
signal shift_interruption_triggered(interruption: Dictionary)
signal shift_interruption_resolved(interruption_id: String, choice: String)

const EVENTS_DIRECTORY: String = "res://data/events"
const SHIFT_INTERRUPTION_MIN_SECONDS: float = 20.0
const SHIFT_INTERRUPTION_MAX_SECONDS: float = 60.0
const MAX_SHIFT_INTERRUPTIONS: int = 2
const SHIFT_INTERRUPTION_DEFINITIONS: Dictionary = {
    "furnace_spike": {
        "id": "furnace_spike",
        "title": "Furnace spike",
        "narrative": "The furnace is running hot. Push through or bank the coals?",
        "choice_a_label": "Push through",
        "choice_b_label": "Bank the coals",
        "choice_a_effect": {
            "output_multiplier": 1.15,
            "worker_fatigue_delta": {
                "Radek": 20
            }
        },
        "choice_b_effect": {}
    },
    "jiri_drops_die": {
        "id": "jiri_drops_die",
        "title": "Jiri drops a die",
        "narrative": "The die slipped from Jiri's hand. Three coins are ruined before the bench is reset.",
        "choice_a_label": "Carry on",
        "choice_b_label": "Swallow the loss",
        "choice_a_effect": {
            "flat_coin_loss": 3
        },
        "choice_b_effect": {
            "flat_coin_loss": 3
        }
    },
    "suspicious_visitor": {
        "id": "suspicious_visitor",
        "title": "Suspicious visitor",
        "narrative": "A hooded man watches from the doorway, hands tucked into noble cloth.",
        "choice_a_label": "Ignore him",
        "choice_b_label": "Confront him",
        "choice_a_effect": {
            "interruption_note": "The hooded watcher leaves on his own. The floor remembers the colours."
        },
        "choice_b_effect": {
            "interruption_note": "He gives no name and goes, but the men whisper of Sigismund all the same."
        }
    },
    "worker_slowing": {
        "id": "worker_slowing",
        "title": "Worker slowing",
        "narrative": "Radek is struggling. His hands are shaking over the coals.",
        "choice_a_label": "Rest him now",
        "choice_b_label": "Push him",
        "choice_a_effect": {
            "force_floor_hands_stage": "smelting",
            "interruption_note": "Radek is pulled from the heat. Floor hands take the bellows."
        },
        "choice_b_effect": {
            "quality_penalty": 18.0,
            "worker_fatigue_delta": {
                "Radek": 10
            },
            "interruption_note": "Radek keeps working, but the silver will remember the strain."
        }
    }
}

var _events: Dictionary = {}
var _active_event: GameEvent
var _shift_interruption_timer: Timer
var _shift_interruption_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shift_interruptions_triggered: int = 0
var _remaining_shift_interruptions: Array[String] = []
var _active_shift_interruption: Dictionary = {}
var _shift_interruption_candidates: Array[String] = []


func _ready() -> void:
    _setup_shift_interruption_timer()
    reload_events()


func reload_events() -> void:
    _events.clear()

    var directory: DirAccess = DirAccess.open(EVENTS_DIRECTORY)
    if directory == null:
        return

    directory.list_dir_begin()
    while true:
        var file_name: String = directory.get_next()
        if file_name.is_empty():
            break
        if directory.current_is_dir() or not file_name.ends_with(".tres"):
            continue

        var resource_path: String = "%s/%s" % [EVENTS_DIRECTORY, file_name]
        var event_resource: GameEvent = load(resource_path) as GameEvent
        if event_resource != null and not event_resource.event_id.is_empty():
            _events[event_resource.event_id] = event_resource

    directory.list_dir_end()


func get_event_for_day(day_num: int) -> GameEvent:
    for event_resource: GameEvent in _events.values():
        if event_resource.triggers_on_day(day_num):
            return event_resource
    return null


func trigger_day_event(day_num: int) -> GameEvent:
    _active_event = get_event_for_day(day_num)
    if _active_event != null:
        event_triggered.emit(_active_event.event_id)
    return _active_event


func get_active_event() -> GameEvent:
    return _active_event


func resolve_active_event(choice_id: String) -> Dictionary:
    if _active_event == null:
        return {}

    var resolved_event_id: String = _active_event.event_id
    var effects: Dictionary = _active_event.get_effect_for_choice(choice_id)
    _apply_effects(effects)
    _active_event = null
    event_resolved.emit(resolved_event_id, choice_id)
    return effects


func begin_shift_interruptions(interruption_candidates: Array[String] = []) -> void:
    _shift_interruptions_triggered = 0
    _active_shift_interruption.clear()
    _remaining_shift_interruptions = []
    _set_shift_interruption_candidates(interruption_candidates)
    for interruption_id: String in SHIFT_INTERRUPTION_DEFINITIONS.keys():
        _remaining_shift_interruptions.append(interruption_id)
    _shift_interruption_rng.randomize()
    _schedule_next_shift_interruption()


func pause_shift_interruptions() -> void:
    if _shift_interruption_timer != null:
        _shift_interruption_timer.paused = true


func resume_shift_interruptions() -> void:
    if _shift_interruption_timer == null:
        return
    if _active_shift_interruption.is_empty():
        _shift_interruption_timer.paused = false


func end_shift_interruptions() -> void:
    _active_shift_interruption.clear()
    _remaining_shift_interruptions.clear()
    _shift_interruption_candidates.clear()
    _shift_interruptions_triggered = 0
    if _shift_interruption_timer != null:
        _shift_interruption_timer.stop()
        _shift_interruption_timer.paused = false


func resolve_shift_interruption(choice_id: String) -> Dictionary:
    if _active_shift_interruption.is_empty():
        return {}

    var interruption_id: String = String(_active_shift_interruption.get("id", ""))
    var choice_key: String = "choice_a_effect" if choice_id == "a" else "choice_b_effect"
    var effects: Dictionary = (_active_shift_interruption.get(choice_key, {}) as Dictionary).duplicate(true)
    _active_shift_interruption.clear()
    shift_interruption_resolved.emit(interruption_id, choice_id)
    _schedule_next_shift_interruption()
    return effects


func set_shift_interruption_candidates(interruption_candidates: Array[String]) -> void:
    _set_shift_interruption_candidates(interruption_candidates)


func _apply_effects(effects: Dictionary) -> void:
    if effects.has("balance_delta"):
        var balance_delta: int = int(effects["balance_delta"])
        if balance_delta >= 0:
            Ledger.add_income(balance_delta)
        else:
            Ledger.subtract_expense(abs(balance_delta))

    if effects.has("ledger_flag"):
        Ledger.record_integrity_issue(String(effects["ledger_flag"]))

    if effects.has("worker_loyalty_delta"):
        var loyalty_delta: Dictionary = effects["worker_loyalty_delta"] as Dictionary
        for worker_name: Variant in loyalty_delta.keys():
            var worker: Worker = _find_worker_by_name(String(worker_name))
            if worker != null:
                worker.apply_loyalty_delta(int(loyalty_delta[worker_name]))


func _find_worker_by_name(worker_name: String) -> Worker:
    for worker: Worker in GameManager.workers:
        if worker.worker_name == worker_name:
            return worker
    return null


func _setup_shift_interruption_timer() -> void:
    _shift_interruption_timer = Timer.new()
    _shift_interruption_timer.one_shot = true
    add_child(_shift_interruption_timer)
    _shift_interruption_timer.timeout.connect(_on_shift_interruption_timeout)


func _schedule_next_shift_interruption() -> void:
    if _shift_interruption_timer == null:
        return
    if _shift_interruptions_triggered >= MAX_SHIFT_INTERRUPTIONS:
        _shift_interruption_timer.stop()
        return
    if _remaining_shift_interruptions.is_empty():
        _shift_interruption_timer.stop()
        return

    var next_interval: float = _shift_interruption_rng.randf_range(
        SHIFT_INTERRUPTION_MIN_SECONDS,
        SHIFT_INTERRUPTION_MAX_SECONDS
    )
    _shift_interruption_timer.start(next_interval)
    _shift_interruption_timer.paused = false


func _on_shift_interruption_timeout() -> void:
    if _remaining_shift_interruptions.is_empty():
        return
    if _shift_interruptions_triggered >= MAX_SHIFT_INTERRUPTIONS:
        return

    var eligible_interruptions: Array[String] = _eligible_shift_interruptions()
    if eligible_interruptions.is_empty():
        _schedule_next_shift_interruption()
        return

    var pick_index: int = _shift_interruption_rng.randi_range(0, eligible_interruptions.size() - 1)
    var interruption_id: String = eligible_interruptions[pick_index]
    _remaining_shift_interruptions.erase(interruption_id)
    _active_shift_interruption = (SHIFT_INTERRUPTION_DEFINITIONS.get(interruption_id, {}) as Dictionary).duplicate(true)
    _shift_interruptions_triggered += 1
    shift_interruption_triggered.emit(_active_shift_interruption.duplicate(true))


func _eligible_shift_interruptions() -> Array[String]:
    var eligible_interruptions: Array[String] = []
    for interruption_id: String in _remaining_shift_interruptions:
        if _shift_interruption_candidates.has(interruption_id):
            eligible_interruptions.append(interruption_id)
    return eligible_interruptions


func _set_shift_interruption_candidates(interruption_candidates: Array[String]) -> void:
    _shift_interruption_candidates.clear()
    for interruption_id: String in interruption_candidates:
        if SHIFT_INTERRUPTION_DEFINITIONS.has(interruption_id) and not _shift_interruption_candidates.has(interruption_id):
            _shift_interruption_candidates.append(interruption_id)
