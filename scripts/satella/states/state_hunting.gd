extends SatellaState
## HUNTING — she searches for him.
## Activation: UNSTABLE+ spontaneous in zones allowing it, scripted ("hunt").
## Behaviour: patrols the zone's hunt points at walking pace. Detection uses
## her own line of sight, modulated by the flashlight and crouching:
## light ON = seen from far; crouched in the dark = only very close.
## On detection -> CHASING. Times out -> DISAPPEARING.
## Sound: slow heavy footsteps, humming, whispers.

var points: Array = []
var target := Vector3.ZERO
var duration := 45.0
var _step_t := 0.0
var _hum_t := 4.0


func enter(a: Dictionary) -> void:
	points = a.get("points", [])
	if points.is_empty():
		for s in ai.spots:
			if s["zone"] == ai.player.current_zone:
				points.append(s["pos"])
	duration = float(a.get("duration", randf_range(40.0, 60.0)))
	if points.is_empty():
		ai.sm.change("DORMANT", {})
		return
	var start: Vector3 = points[0]
	for pt in points:
		if not ai.player.is_in_frustum(pt + Vector3.UP * 1.3) and pt.distance_to(ai.player_pos()) > 8.0:
			start = pt
			break
	ai.show_body(start, false)
	ai.body.set_pose(SatellaBody.Pose.WALK)
	_pick()
	if EnvyAwareness.stage() >= 3:
		ai.player.flashlight.flicker(0.6, 0.6)


func _pick() -> void:
	target = points[randi() % points.size()]


func update(delta: float) -> void:
	if ai.glide_toward(target, 1.6, delta) < 0.4:
		_pick()
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.62
		AudioManager.play_3d("step_wood", ai.global_position + Vector3.UP * 0.1, -4.0, 7.0, 0.8)
	_hum_t -= delta
	if _hum_t <= 0.0:
		_hum_t = randf_range(8.0, 14.0)
		ai.say_random("witch_idle", 6, {"position": ai.head_pos()})
	var p := ai.player
	var d := ai.distance_to_player()
	var detect := 6.0
	if p.flashlight.on:
		detect = 15.0
	elif p.crouching or p._height < 1.4:
		detect = 2.8
	if d < detect and ai.sees_player(detect):
		DialogueManager.say("c4_she_whisper", {"position": ai.head_pos()})
		ai.sm.change("CHASING", {"id": "hunt", "speed": 5.0, "max_time": 30.0, "escape_distance": 24.0})
		return
	if time > duration:
		ai.sm.change("DISAPPEARING", {"instant": not ai.seen})
