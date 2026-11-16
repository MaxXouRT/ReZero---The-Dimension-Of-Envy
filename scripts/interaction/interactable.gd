class_name Interactable
extends Area3D
## Base class of everything the player can use (layer 4 = "interact").
##
## The InteractionSystem ray-casts from the camera; when it hits an
## Interactable that is enabled it shows `prompt` and calls interact().
##
## Gameplay code can either subclass it or simply plug a Callable:
##     var i := Builder.interactable(parent, pos, size, "Lire", func(p): ...)

signal interacted(player: Node)

const LAYER := 8   # physics layer 4

@export var prompt := "Interagir"
@export var enabled := true
@export var one_shot := false
@export var max_distance := 2.6

## Optional callable(player) used instead of overriding _on_interact.
var action: Callable
## Optional callable() -> String for dynamic prompts.
var prompt_func: Callable
var _used := false


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	if prompt_func.is_valid():
		return String(prompt_func.call())
	return prompt


func can_interact() -> bool:
	return enabled and not (one_shot and _used)


func interact(player: Node) -> void:
	if not can_interact():
		return
	_used = true
	interacted.emit(player)
	if action.is_valid():
		action.call(player)
	_on_interact(player)


## Override in subclasses.
func _on_interact(_player: Node) -> void:
	pass


## Adds a box-shaped hit zone.
func set_box(size: Vector3, offset := Vector3.ZERO) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	add_child(cs)
