# Implements the reusable pipeline stage panel so worker assignment UI can stay
# isolated from the global day-flow systems and be instanced by MintingFloor.
extends PanelContainer

signal assignment_requested(stage_id: String)
signal worker_assigned(stage_id: String, worker: Worker)
signal worker_removed(stage_id: String)

const EMPTY_WORKER_NAME: String = "Unassigned"
const EMPTY_OUTPUT_TEXT: String = "~0 coins / shift"
const REMOVE_BUTTON_TEXT: String = "Remove"
const ASSIGN_BUTTON_TEXT: String = "Assign"

@export var stage_id: String = "smelting"
@export var stage_name: String = "Smelting"

@onready var _stage_name_label: Label = %StageNameLabel
@onready var _worker_name_label: Label = %WorkerName
@onready var _assign_button: Button = %AssignButton
@onready var _output_label: Label = %OutputLabel
@onready var _fatigue_bar: ProgressBar = %FatigueBar

var _assigned_worker: Worker


func _ready() -> void:
    _assign_button.pressed.connect(_on_assign_button_pressed)
    _refresh_display()


func assign_worker(worker: Worker) -> void:
    if worker == null:
        return

    _assigned_worker = worker
    _refresh_display()
    worker_assigned.emit(stage_id, worker)


func remove_worker() -> void:
    if _assigned_worker == null:
        return

    _assigned_worker = null
    _refresh_display()
    worker_removed.emit(stage_id)


func set_output_preview(estimated_coins: int) -> void:
    _output_label.text = "~%d coins / shift" % maxi(estimated_coins, 0)


func get_assigned_worker() -> Worker:
    return _assigned_worker


func _refresh_display() -> void:
    _stage_name_label.text = stage_name

    if _assigned_worker == null:
        _worker_name_label.text = EMPTY_WORKER_NAME
        _assign_button.text = ASSIGN_BUTTON_TEXT
        _assign_button.disabled = false
        _output_label.text = EMPTY_OUTPUT_TEXT
        _fatigue_bar.value = 0
        return

    _worker_name_label.text = _assigned_worker.worker_name
    _assign_button.text = REMOVE_BUTTON_TEXT
    _assign_button.disabled = false
    _fatigue_bar.value = _assigned_worker.fatigue


func _on_assign_button_pressed() -> void:
    if _assigned_worker != null:
        remove_worker()
        return

    assignment_requested.emit(stage_id)
