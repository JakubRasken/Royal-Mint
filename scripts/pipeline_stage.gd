# Implements the reusable pipeline stage panel so worker assignment UI can stay
# isolated from the global day-flow systems and be instanced by MintingFloor.
extends PanelContainer

signal assignment_requested(stage_id: String)
signal worker_assigned(stage_id: String, worker: Worker)
signal worker_removed(stage_id: String)

const EMPTY_PORTRAIT_TEXTURE: Texture2D = preload("res://assets/sprites/portrait_empty_slot.png")
const STAGE_ICON_BY_ID: Dictionary = {
	"smelting": preload("res://assets/sprites/icon_stage_smelting.png"),
	"striking": preload("res://assets/sprites/icon_stage_striking.png"),
	"assay": preload("res://assets/sprites/icon_stage_assay.png")
}
const EMPTY_WORKER_NAME: String = "Unassigned"
const EMPTY_OUTPUT_TEXT: String = "~0 coins / shift"
const REMOVE_BUTTON_TEXT: String = "Remove"
const ASSIGN_BUTTON_TEXT: String = "Assign"
const PICK_WORKER_TEXT: String = "Pick worker"
const ACTIVE_STAGE_MODULATE: Color = Color(1.0, 0.9725, 0.8902, 1.0)
const FATIGUE_SEGMENT_STEP: int = 20
const FATIGUE_DEPLETED_COLOR: Color = Color(0.1647, 0.1020, 0.0078, 1.0)
const FATIGUE_ACTIVE_COLOR: Color = Color(0.5451, 0.4118, 0.0784, 1.0)

@export var stage_id: String = "smelting"
@export var stage_name: String = "Smelting"

@onready var _stage_name_label: Label = %StageNameLabel
@onready var _worker_portrait: TextureRect = %WorkerPortrait
@onready var _worker_name_label: Label = %WorkerName
@onready var _assign_button: Button = %AssignButton
@onready var _output_icon: TextureRect = %OutputIcon
@onready var _output_label: Label = %OutputLabel
@onready var _fatigue_segments: Array[ColorRect] = [
	%FatigueSegment1,
	%FatigueSegment2,
	%FatigueSegment3,
	%FatigueSegment4,
	%FatigueSegment5
]

var _assigned_worker: Worker
var _assignment_pending: bool = false
var _support_preview_output: int = 0


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


func set_support_preview(estimated_coins: int) -> void:
	_support_preview_output = maxi(estimated_coins, 0)
	if _assigned_worker == null:
		_refresh_display()


func set_assignment_pending(is_pending: bool) -> void:
	_assignment_pending = is_pending
	_refresh_display()


func refresh_worker_state() -> void:
	_refresh_display()


func get_assigned_worker() -> Worker:
	return _assigned_worker


func _refresh_display() -> void:
	_stage_name_label.text = stage_name
	_output_icon.texture = STAGE_ICON_BY_ID.get(stage_id) as Texture2D

	if _assigned_worker == null:
		_worker_portrait.texture = EMPTY_PORTRAIT_TEXTURE
		_worker_name_label.text = EMPTY_WORKER_NAME
		_assign_button.text = PICK_WORKER_TEXT if _assignment_pending else ASSIGN_BUTTON_TEXT
		_assign_button.disabled = false
		if _assignment_pending:
			_output_label.text = "Select a worker from the roster"
		elif _support_preview_output > 0:
			_output_label.text = "~%d coins / shift with floor hands" % _support_preview_output
		else:
			_output_label.text = EMPTY_OUTPUT_TEXT
		_update_fatigue_display(0)
		self_modulate = ACTIVE_STAGE_MODULATE if _assignment_pending else Color(1, 1, 1, 1)
		return

	_worker_portrait.texture = _assigned_worker.portrait if _assigned_worker.portrait != null else EMPTY_PORTRAIT_TEXTURE
	_worker_name_label.text = _assigned_worker.worker_name
	_assign_button.text = REMOVE_BUTTON_TEXT
	_assign_button.disabled = false
	_update_fatigue_display(_assigned_worker.fatigue)
	self_modulate = Color(1, 1, 1, 1)


func _on_assign_button_pressed() -> void:
	if _assigned_worker != null:
		remove_worker()
		return

	assignment_requested.emit(stage_id)


func _update_fatigue_display(fatigue_value: int) -> void:
	var depleted_segments: int = clampi(int(ceili(float(fatigue_value) / FATIGUE_SEGMENT_STEP)), 0, _fatigue_segments.size())
	var active_segments: int = _fatigue_segments.size() - depleted_segments

	for segment_index: int in _fatigue_segments.size():
		var segment: ColorRect = _fatigue_segments[segment_index]
		segment.color = FATIGUE_ACTIVE_COLOR if segment_index < active_segments else FATIGUE_DEPLETED_COLOR
