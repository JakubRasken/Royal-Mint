# Coordinates MintingFloor UI bindings so scene controls react to autoload
# signals without pushing any game logic into the scene tree.
extends Control

@onready var _groschen_rate_label: Label = $ScreenLayout/HeaderBar/HeaderContent/LeftRatePad/GroschenRateLabel


func _ready() -> void:
    GameManager.groschen_updated.connect(_on_groschen_updated)
    _on_groschen_updated(GameManager.groschen, GameManager.groschen_per_sec)


func _on_groschen_updated(_total: float, per_sec: float) -> void:
    _groschen_rate_label.text = "%0.1f / sec" % per_sec
