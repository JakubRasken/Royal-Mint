# Draws the header threat seal so Sigismund's attention can climb in visible
# steps without needing a texture set for each fill state.
extends Control

const OUTLINE_COLOR: Color = Color(0.545098, 0.101961, 0.101961, 0.38)
const FILL_COLOR: Color = Color(0.545098, 0.101961, 0.101961, 0.9)
const BASE_WAX_COLOR: Color = Color(0.545098, 0.101961, 0.101961, 0.14)
const SHADOW_COLOR: Color = Color(0.164706, 0.101961, 0.00784314, 0.18)
const SEGMENT_COUNT: int = 5
const ARC_POINTS: int = 12

var _attention_level: int = 0


func set_attention_level(level: int) -> void:
    var clamped_level: int = clampi(level, 0, SEGMENT_COUNT)
    if clamped_level == _attention_level:
        return
    _attention_level = clamped_level
    queue_redraw()


func _draw() -> void:
    var center: Vector2 = size * 0.5
    var outer_radius: float = min(size.x, size.y) * 0.45
    var inner_radius: float = outer_radius * 0.52
    var gap: float = deg_to_rad(8.0)
    var segment_arc: float = (TAU - gap * float(SEGMENT_COUNT)) / float(SEGMENT_COUNT)

    draw_circle(center + Vector2(1.5, 1.5), outer_radius, SHADOW_COLOR)
    draw_circle(center, outer_radius, BASE_WAX_COLOR)

    for segment_index: int in SEGMENT_COUNT:
        var start_angle: float = -PI * 0.5 + gap * 0.5 + float(segment_index) * (segment_arc + gap)
        var end_angle: float = start_angle + segment_arc
        var segment_color: Color = FILL_COLOR if segment_index < _attention_level else OUTLINE_COLOR
        draw_colored_polygon(_build_ring_segment(center, inner_radius, outer_radius, start_angle, end_angle), segment_color)
    draw_circle(center, inner_radius - 2.0, Color(0.992157, 0.964706, 0.890196, 0.08))


func _build_ring_segment(
    center: Vector2,
    inner_radius: float,
    outer_radius: float,
    start_angle: float,
    end_angle: float
) -> PackedVector2Array:
    var points := PackedVector2Array()
    for point_index: int in ARC_POINTS + 1:
        var t: float = float(point_index) / float(ARC_POINTS)
        var angle: float = lerpf(start_angle, end_angle, t)
        points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
    for point_index: int in ARC_POINTS + 1:
        var reverse_t: float = 1.0 - float(point_index) / float(ARC_POINTS)
        var reverse_angle: float = lerpf(start_angle, end_angle, reverse_t)
        points.append(center + Vector2(cos(reverse_angle), sin(reverse_angle)) * inner_radius)
    return points
