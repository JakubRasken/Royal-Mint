# Implements the reusable pipeline stage panel so worker assignment UI can stay
# isolated from the global day-flow systems and be instanced by MintingFloor.
extends PanelContainer

signal assignment_requested(stage_id: String)
signal worker_assigned(stage_id: String, worker: Worker)
signal worker_removed(stage_id: String)
signal worker_state_changed(stage_id: String, worker: Worker)

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
const STRIKE_FATIGUE_COST: int = 3
const STRIKE_CURSOR_SPEED_FAST: float = 1.45
const STRIKE_CURSOR_SPEED_SLOW: float = 0.7
const STRIKE_ZONE_RATIO_NARROW: float = 0.16
const STRIKE_ZONE_RATIO_WIDE: float = 0.38
const STRIKE_CURSOR_WIDTH: float = 6.0
const STRIKE_QUALITY_HIT: float = 90.0
const STRIKE_QUALITY_NEAR_MISS: float = 52.0
const STRIKE_QUALITY_FAR_MISS: float = 18.0
const STRIKE_AUDIO_MIX_RATE: float = 44100.0
const STRIKE_AUDIO_BUFFER_LENGTH: float = 0.2
const STRIKE_AUDIO_HIT_FREQUENCY: float = 880.0
const STRIKE_AUDIO_MISS_FREQUENCY: float = 220.0
const STRIKE_AUDIO_DURATION: float = 0.08
const STRIKE_AUDIO_GAIN: float = 0.2
const STRIKE_HIT_FLASH_COLOR: Color = Color("8b6914")
const STRIKE_MISS_FLASH_COLOR: Color = Color("8b1a1a")

@export var stage_id: String = "smelting"
@export var stage_name: String = "Smelting"

@onready var _stage_name_label: Label = %StageNameLabel
@onready var _worker_portrait: TextureRect = %WorkerPortrait
@onready var _worker_name_label: Label = %WorkerName
@onready var _assign_button: Button = %AssignButton
@onready var _output_icon: TextureRect = %OutputIcon
@onready var _output_preview: HBoxContainer = %OutputPreview
@onready var _output_label: Label = %OutputLabel
@onready var _striking_minigame: VBoxContainer = %StrikingMinigame
@onready var _strike_instruction_label: Label = %StrikeInstructionLabel
@onready var _strike_bar: PanelContainer = %StrikeBar
@onready var _strike_track: Control = %StrikeTrack
@onready var _sweet_spot: ColorRect = %SweetSpot
@onready var _strike_cursor: ColorRect = %StrikeCursor
@onready var _strike_batch_label: Label = %StrikeBatchLabel
@onready var _strike_feedback_label: Label = %StrikeFeedbackLabel
@onready var _strike_audio_player: AudioStreamPlayer = %StrikeAudioPlayer
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
var _shift_active: bool = false
var _cursor_progress: float = 0.0
var _cursor_direction: float = 1.0
var _struck_coin_count: int = 0
var _struck_quality_scores: Array[float] = []
var _strike_audio_playback: AudioStreamGeneratorPlayback
var _output_icon_tween: Tween


func _ready() -> void:
	_setup_strike_audio()
	_assign_button.pressed.connect(_on_assign_button_pressed)
	_strike_bar.gui_input.connect(_on_strike_bar_gui_input)
	_strike_track.resized.connect(_update_striking_bar_visuals)
	_refresh_display()


func _process(delta: float) -> void:
	if not _is_striking_interactive():
		return

	var cursor_speed: float = _get_strike_cursor_speed()
	_cursor_progress += _cursor_direction * delta * cursor_speed
	if _cursor_progress >= 1.0:
		_cursor_progress = 1.0
		_cursor_direction = -1.0
	elif _cursor_progress <= 0.0:
		_cursor_progress = 0.0
		_cursor_direction = 1.0
	_update_striking_bar_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_striking_interactive():
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_attempt_strike()
		get_viewport().set_input_as_handled()


func assign_worker(worker: Worker) -> void:
	if worker == null:
		return

	_assigned_worker = worker
	_reset_striking_session()
	_refresh_display()
	worker_assigned.emit(stage_id, worker)


func remove_worker() -> void:
	if _assigned_worker == null:
		return

	_assigned_worker = null
	_reset_striking_session()
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


func set_shift_active(is_active: bool) -> void:
	_shift_active = is_active
	if is_active:
		_reset_striking_session()
	_refresh_display()


func get_shift_results() -> Dictionary:
	if not _is_striking_stage():
		return {}

	return {
		"coins_struck": _struck_coin_count,
		"average_quality": _get_average_strike_quality()
	}


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
		_update_striking_panel()
		self_modulate = ACTIVE_STAGE_MODULATE if _assignment_pending else Color(1, 1, 1, 1)
		return

	_worker_portrait.texture = _assigned_worker.portrait if _assigned_worker.portrait != null else EMPTY_PORTRAIT_TEXTURE
	_worker_name_label.text = _assigned_worker.worker_name
	_assign_button.text = REMOVE_BUTTON_TEXT
	_assign_button.disabled = false
	_update_fatigue_display(_assigned_worker.fatigue)
	_update_striking_panel()
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


func _update_striking_panel() -> void:
	var show_striking_minigame: bool = _should_show_striking_minigame()
	_output_preview.visible = not show_striking_minigame
	_striking_minigame.visible = show_striking_minigame
	if not show_striking_minigame:
		return

	if _shift_active:
		_strike_instruction_label.text = "Strike with Space or by clicking the bar. Every blow costs fatigue."
	else:
		_strike_instruction_label.text = "Begin the shift, then strike with Space or by clicking the bar."

	_strike_batch_label.text = "%d coins struck this shift." % _struck_coin_count
	if _struck_coin_count == 0 and not _shift_active:
		_strike_feedback_label.text = "The die waits."
	elif _struck_coin_count == 0 and _shift_active:
		_strike_feedback_label.text = "The hammer is raised. Strike true."
	elif _assigned_worker != null and _assigned_worker.is_incapacitated():
		_strike_feedback_label.text = "Hands spent. No more strikes today."

	_update_striking_bar_visuals()


func _update_striking_bar_visuals() -> void:
	if not _should_show_striking_minigame():
		return

	var track_size: Vector2 = _strike_track.size
	if track_size.x <= 0.0 or track_size.y <= 0.0:
		return

	var sweet_spot_width: float = track_size.x * _get_sweet_spot_ratio()
	var sweet_spot_left: float = (track_size.x - sweet_spot_width) * 0.5
	_sweet_spot.position = Vector2(sweet_spot_left, 0.0)
	_sweet_spot.size = Vector2(sweet_spot_width, track_size.y)

	var cursor_left: float = (track_size.x - STRIKE_CURSOR_WIDTH) * _cursor_progress
	_strike_cursor.position = Vector2(cursor_left, -4.0)
	_strike_cursor.size = Vector2(STRIKE_CURSOR_WIDTH, track_size.y + 8.0)


func _on_strike_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_attempt_strike()


func _attempt_strike() -> void:
	if not _is_striking_interactive():
		return

	var sweet_spot_ratio: float = _get_sweet_spot_ratio()
	var sweet_spot_half: float = sweet_spot_ratio * 0.5
	var distance_from_center: float = abs(_cursor_progress - 0.5)
	var miss_span: float = maxf(0.5 - sweet_spot_half, 0.001)
	var quality_score: float = STRIKE_QUALITY_HIT
	var feedback_text: String = "Clean strike. The die lands true."
	var flash_color: Color = STRIKE_HIT_FLASH_COLOR
	var tone_frequency: float = STRIKE_AUDIO_HIT_FREQUENCY

	if distance_from_center > sweet_spot_half:
		var miss_ratio: float = (distance_from_center - sweet_spot_half) / miss_span
		if miss_ratio <= 0.45:
			quality_score = STRIKE_QUALITY_NEAR_MISS
			feedback_text = "Off the die. Common coin."
		else:
			quality_score = STRIKE_QUALITY_FAR_MISS
			feedback_text = "Bad blow. Debased coin."
		flash_color = STRIKE_MISS_FLASH_COLOR
		tone_frequency = STRIKE_AUDIO_MISS_FREQUENCY

	_struck_coin_count += 1
	_struck_quality_scores.append(quality_score)
	_assigned_worker.fatigue = clampi(_assigned_worker.fatigue + STRIKE_FATIGUE_COST, 0, Worker.MAX_FATIGUE)
	_strike_feedback_label.text = feedback_text
	_play_strike_tone(tone_frequency)
	_flash_output_icon(flash_color)
	_update_fatigue_display(_assigned_worker.fatigue)
	_update_striking_panel()
	worker_state_changed.emit(stage_id, _assigned_worker)


func _get_average_strike_quality() -> float:
	if _struck_quality_scores.is_empty():
		return 0.0

	var total_quality: float = 0.0
	for quality_score: float in _struck_quality_scores:
		total_quality += quality_score
	return total_quality / float(_struck_quality_scores.size())


func _should_show_striking_minigame() -> bool:
	return _is_striking_stage() and _assigned_worker != null


func _is_striking_stage() -> bool:
	return stage_id == "striking"


func _is_striking_interactive() -> bool:
	return _should_show_striking_minigame() and _shift_active and not _assigned_worker.is_incapacitated()


func _get_strike_cursor_speed() -> float:
	var skill_ratio: float = _get_worker_skill_ratio()
	return lerpf(STRIKE_CURSOR_SPEED_FAST, STRIKE_CURSOR_SPEED_SLOW, skill_ratio)


func _get_sweet_spot_ratio() -> float:
	var skill_ratio: float = _get_worker_skill_ratio()
	return lerpf(STRIKE_ZONE_RATIO_NARROW, STRIKE_ZONE_RATIO_WIDE, skill_ratio)


func _get_worker_skill_ratio() -> float:
	if _assigned_worker == null:
		return 0.0
	return clampf(float(_assigned_worker.skill - 1) / 4.0, 0.0, 1.0)


func _reset_striking_session() -> void:
	_cursor_progress = 0.5
	_cursor_direction = 1.0
	_struck_coin_count = 0
	_struck_quality_scores.clear()
	_strike_feedback_label.text = "The die waits."


func _setup_strike_audio() -> void:
	var strike_stream := AudioStreamGenerator.new()
	strike_stream.mix_rate = STRIKE_AUDIO_MIX_RATE
	strike_stream.buffer_length = STRIKE_AUDIO_BUFFER_LENGTH
	_strike_audio_player.stream = strike_stream
	_strike_audio_player.play()
	_strike_audio_playback = _strike_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _play_strike_tone(frequency: float) -> void:
	if _strike_audio_playback == null:
		return

	var total_frames: int = int(STRIKE_AUDIO_DURATION * STRIKE_AUDIO_MIX_RATE)
	for frame_index: int in total_frames:
		var envelope: float = 1.0 - float(frame_index) / float(maxi(total_frames, 1))
		var sample: float = sin(TAU * frequency * float(frame_index) / STRIKE_AUDIO_MIX_RATE) * STRIKE_AUDIO_GAIN * envelope
		_strike_audio_playback.push_frame(Vector2(sample, sample))


func _flash_output_icon(flash_color: Color) -> void:
	if _output_icon_tween != null:
		_output_icon_tween.kill()
	_output_icon.modulate = flash_color
	_output_icon_tween = create_tween()
	_output_icon_tween.tween_property(_output_icon, "modulate", Color(1, 1, 1, 1), 0.18)
