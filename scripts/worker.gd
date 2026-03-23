class_name Worker
extends Resource

@export var worker_name: String = ""
@export var role: String = ""
@export var cost: int = 0
@export var groschen_per_sec: float = 0.0
@export var portrait: Texture2D
@export var is_hired: bool = false
@export var has_goof: bool = false
@export var has_rest: bool = false
@export var has_skim: bool = false
@export var hire_journal: String = ""
