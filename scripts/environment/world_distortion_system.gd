class_name WorldDistortionSystem
extends Node
## WorldDistortionSystem — the mansion does not obey the laws of space.
##
## 1. DISTORTABLES: registered nodes owning several "variants" (child nodes).
##    A change is QUEUED and only applied when no variant is visible to the
##    player: a room changes when you look away, a painting is different when
##    you look back, a door that was there is gone.
##       distortion.register("west_painting", [variant_a, variant_b])
##       distortion.request("west_painting", 1)
##
## 2. UNSEEN MOVES: move_when_unseen(node, transform) for furniture that
##    "was always there".
##
## 3. GLOBAL BREATHING: drives the global shader uniform `distortion`
##    (walls breathe) from Envy Awareness + pulses from events, and forwards
##    screen-space distortion to the post-process.
##
## 4. LOOP VARIANTS: variant chosen from the loop count (pick_for_loop).

var player: PlayerController
var _items := {}          # id -> {variants: Array[Node3D], current: int}
var _pending := {}        # id -> variant index
var _moves: Array = []    # [{node, xf}]
var _pulse := 0.0
var _pulse_time := 0.0
var _base := 0.0
var _check_t := 0.0


func _ready() -> void:
	EventBus.world_distortion.connect(pulse)
	EventBus.player_spawned.connect(func(p): player = p)
	RenderingServer.global_shader_parameter_set("distortion", 0.0)


func register(id: String, variants: Array, initial := 0) -> void:
	var list: Array[Node3D] = []
	for v in variants:
		list.append(v)
	_items[id] = {"variants": list, "current": -1}
	_apply(id, initial)


func current(id: String) -> int:
	return int(_items.get(id, {}).get("current", -1))


## Queues a variant change that happens only when the player is not looking.
func request(id: String, variant: int) -> void:
	if not _items.has(id):
		return
	if current(id) == variant:
		_pending.erase(id)
		return
	_pending[id] = variant


## Immediate change (use for cutscenes / when hidden by a blackout).
func force(id: String, variant: int) -> void:
	_pending.erase(id)
	_apply(id, variant)


func pick_for_loop(id: String) -> void:
	if not _items.has(id):
		return
	var n: int = _items[id]["variants"].size()
	force(id, GameState.deaths() % n)


func move_when_unseen(n: Node3D, xf: Transform3D) -> void:
	_moves.append({"node": n, "xf": xf})


func _apply(id: String, variant: int) -> void:
	var it: Dictionary = _items[id]
	var vs: Array = it["variants"]
	for i in vs.size():
		var v: Node3D = vs[i]
		if is_instance_valid(v):
			v.visible = i == variant
			_set_collision(v, i == variant)
	it["current"] = variant


func _set_collision(n: Node, on: bool) -> void:
	if n is CollisionObject3D:
		var co := n as CollisionObject3D
		if not co.has_meta("orig_layer"):
			co.set_meta("orig_layer", co.collision_layer)
		co.collision_layer = int(co.get_meta("orig_layer")) if on else 0
	for c in n.get_children():
		_set_collision(c, on)


func _is_seen(n: Node3D) -> bool:
	if player == null or not is_instance_valid(n):
		return false
	var p := n.global_position + Vector3.UP * 1.0
	if p.distance_to(player.global_position) > 40.0:
		return false
	return player.is_in_frustum(p) and player.can_see_point(p, 0.0)


func pulse(intensity: float, duration: float) -> void:
	_pulse = maxf(_pulse, intensity)
	_pulse_time = maxf(_pulse_time, duration)


func _process(delta: float) -> void:
	# breathing
	var stage := EnvyAwareness.stage()
	_base = [0.0, 0.0, 0.08, 0.18, 0.3, 0.45][stage]
	if _pulse_time > 0.0:
		_pulse_time -= delta
	else:
		_pulse = move_toward(_pulse, 0.0, delta * 0.8)
	var total := _base + _pulse
	if Settings.reduce_camera_motion:
		total *= 0.4
	RenderingServer.global_shader_parameter_set("distortion", total)
	# unseen changes
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.25
	for id in _pending.keys():
		var it: Dictionary = _items[id]
		var any_seen := false
		for v in it["variants"]:
			if v.visible and _is_seen(v):
				any_seen = true
				break
		var target_v: Node3D = it["variants"][_pending[id]]
		if not any_seen and not _is_seen(target_v):
			_apply(id, _pending[id])
			_pending.erase(id)
			# a single creak, somewhere, when the house rearranges itself
			if player:
				AudioManager.play_3d("creak", player.global_position - player.forward() * 4.0, -10.0)
	var keep: Array = []
	for m in _moves:
		var n: Node3D = m["node"]
		if not is_instance_valid(n):
			continue
		if _is_seen(n):
			keep.append(m)
		else:
			n.global_transform = m["xf"]
	_moves = keep
