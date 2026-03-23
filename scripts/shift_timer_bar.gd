# Draws the active shift timer as a wax-like bar that burns down toward dusk.
extends Control

const SAFE_COLOR: Color = Color("8b6914")
const WARNING_COLOR: Color = Color("c17f24")
const DANGER_COLOR: Color = Color("8b1a1a")
const EMPTY_COLOR: Color = Color("2a1a02")
const BORDER_COLOR: Color = Color("5c4409")
const SEGMENT_COUNT: int = 18
const BAR_INSET: float = 2.0

enum ShiftTimerPhase {
	SAFE,
	WARNING,
	DANGER
}

var _remaining_ratio: float = 1.0
var _phase: ShiftTimerPhase = ShiftTimerPhase.SAFE
var _pulse_alpha: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_display(remaining_ratio: float, phase: ShiftTimerPhase, pulse_alpha: float = 1.0) -> void:
	_remaining_ratio = clampf(remaining_ratio, 0.0, 1.0)
	_phase = phase
	_pulse_alpha = clampf(pulse_alpha, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var draw_rect_area: Rect2 = Rect2(Vector2(BAR_INSET, BAR_INSET), size - Vector2(BAR_INSET * 2.0, BAR_INSET * 2.0))
	if draw_rect_area.size.x <= 0.0 or draw_rect_area.size.y <= 0.0:
		return

	draw_rect(draw_rect_area, EMPTY_COLOR)
	draw_rect(draw_rect_area, BORDER_COLOR, false, 2.0)

	var segment_gap: float = 2.0
	var segment_width: float = (draw_rect_area.size.x - segment_gap * float(SEGMENT_COUNT - 1)) / float(SEGMENT_COUNT)
	var filled_width: float = draw_rect_area.size.x * _remaining_ratio
	var fill_color: Color = _phase_color()
	fill_color.a *= _pulse_alpha

	for segment_index: int in SEGMENT_COUNT:
		var segment_left: float = draw_rect_area.position.x + float(segment_index) * (segment_width + segment_gap)
		var segment_rect: Rect2 = Rect2(
			Vector2(segment_left, draw_rect_area.position.y),
			Vector2(segment_width, draw_rect_area.size.y)
		)
		var filled_amount: float = clampf(filled_width - (segment_left - draw_rect_area.position.x), 0.0, segment_width)
		if filled_amount > 0.0:
			draw_rect(Rect2(segment_rect.position, Vector2(filled_amount, segment_rect.size.y)), fill_color)


func _phase_color() -> Color:
	match _phase:
		ShiftTimerPhase.WARNING:
			return WARNING_COLOR
		ShiftTimerPhase.DANGER:
			return DANGER_COLOR
		_:
			return SAFE_COLOR
