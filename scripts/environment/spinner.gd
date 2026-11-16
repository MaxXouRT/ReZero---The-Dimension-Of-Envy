class_name Spinner
extends Node3D
## Slowly rotates and bobs (seal fragments, floating objects).

@export var spin_speed := 0.8
@export var bob_height := 0.05
@export var bob_speed := 1.6
var _base_y := 0.0
var _t := 0.0


func _ready() -> void:
	_base_y = position.y
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	rotation.y += spin_speed * delta
	position.y = _base_y + sin(_t * bob_speed) * bob_height
