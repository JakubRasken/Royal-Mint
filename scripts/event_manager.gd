# Implements the event autoload that loads authored GameEvent resources and
# resolves one active event at a time without any direct scene references.
extends Node

signal event_triggered(event_id: String)
signal event_resolved(event_id: String, choice: String)

const EVENTS_DIRECTORY: String = "res://data/events"

var _events: Dictionary = {}
var _active_event: GameEvent


func _ready() -> void:
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
