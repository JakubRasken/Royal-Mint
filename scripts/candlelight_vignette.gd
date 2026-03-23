# Draws a layered edge vignette so the mint floor reads like parchment lit by
# candlelight rather than a flat UI sheet.
extends Control

const LAYER_COUNT: int = 6
const EDGE_COLOR: Color = Color(0.1647, 0.1020, 0.0078, 0.12)
const EDGE_THICKNESS_FACTOR: float = 0.09


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(_on_resized)
    queue_redraw()


func _draw() -> void:
    var edge_span: float = min(size.x, size.y) * EDGE_THICKNESS_FACTOR
    if edge_span <= 0.0:
        return

    for layer_index: int in LAYER_COUNT:
        var layer_progress: float = float(layer_index + 1) / float(LAYER_COUNT)
        var inset: float = edge_span * float(layer_index) / float(LAYER_COUNT)
        var thickness: float = edge_span * (1.0 - float(layer_index) / float(LAYER_COUNT))
        var layer_color: Color = EDGE_COLOR
        layer_color.a *= layer_progress

        draw_rect(Rect2(Vector2(inset, inset), Vector2(size.x - inset * 2.0, thickness)), layer_color)
        draw_rect(Rect2(Vector2(inset, size.y - inset - thickness), Vector2(size.x - inset * 2.0, thickness)), layer_color)
        draw_rect(Rect2(Vector2(inset, inset + thickness), Vector2(thickness, size.y - (inset + thickness) * 2.0)), layer_color)
        draw_rect(Rect2(Vector2(size.x - inset - thickness, inset + thickness), Vector2(thickness, size.y - (inset + thickness) * 2.0)), layer_color)


func _on_resized() -> void:
    queue_redraw()
