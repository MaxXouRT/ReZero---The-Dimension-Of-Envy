class_name InteractionSystem
extends RayCast3D
## Camera ray that finds Interactables (physics layer 4) while being blocked
## by world geometry (layer 1) — you cannot use what you cannot see.
## Emits EventBus.interaction_prompt_changed for the HUD crosshair/prompt.

var player: Node = null
var current: Interactable = null
var _last_prompt := "__none__"


func _ready() -> void:
	target_position = Vector3(0, 0, -2.8)
	collision_mask = 1 | Interactable.LAYER
	collide_with_areas = true
	collide_with_bodies = true
	enabled = true


func _physics_process(_delta: float) -> void:
	var found: Interactable = null
	if is_colliding():
		var c := get_collider()
		if c is Interactable and c.can_interact():
			var dist := global_position.distance_to(get_collision_point())
			if dist <= c.max_distance:
				found = c
	if player != null and player.has_method("is_input_locked") and player.is_input_locked():
		found = null
	current = found
	var prompt := found.get_prompt() if found else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		EventBus.interaction_prompt_changed.emit(prompt, found != null)


func try_interact() -> bool:
	if current and current.can_interact():
		current.interact(player)
		return true
	return false
