# Defines authored upgrade data for the clicker rebuild so upgrades stay
# resource-driven and can be loaded without hardcoded shop tables.
class_name UpgradeData
extends Resource

@export var upgrade_id: String = ""
@export var label: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var tier: int = 1
@export var effect_type: String = ""
@export var effect_value: float = 0.0
@export var is_one_time: bool = true
