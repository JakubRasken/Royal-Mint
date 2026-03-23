# Draws the Sigismund threat bar so the header threat state stays readable
# without relying on default Godot progress styling.
extends Control

const BAR_BACKGROUND_COLOR: Color = Color("3a2a04")
const BAR_BORDER_COLOR: Color = Color("8b6914")
const THREAT_GOLD_COLOR: Color = Color("8b6914")
const THREAT_AMBER_COLOR: Color = Color("c17f24")
const THREAT_RED_COLOR: Color = Color("8b1a1a")

var _threat_level: float = 0.0


func _ready() -> void:
    GameManager.threat_updated.connect(_on_threat_updated)
    _on_threat_updated(GameManager.sigismund_threat)


func _draw() -> void:
    var bar_rect: Rect2 = Rect2(Vector2.ZERO, size)
    draw_rect(bar_rect, BAR_BACKGROUND_COLOR)

    var fill_ratio: float = clampf(_threat_level / 100.0, 0.0, 1.0)
    if fill_ratio > 0.0:
        var fill_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(size.x * fill_ratio, size.y))
        draw_rect(fill_rect, _bar_fill_color())

    draw_rect(bar_rect, BAR_BORDER_COLOR, false, 1.0)


func _on_threat_updated(level: float) -> void:
    _threat_level = clampf(level, 0.0, 100.0)
    queue_redraw()


func _bar_fill_color() -> Color:
    if _threat_level <= 50.0:
        return THREAT_GOLD_COLOR.lerp(THREAT_AMBER_COLOR, _threat_level / 50.0)
    return THREAT_AMBER_COLOR.lerp(THREAT_RED_COLOR, (_threat_level - 50.0) / 50.0)
