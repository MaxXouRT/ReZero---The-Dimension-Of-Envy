extends SatellaState
## CHASING — she runs after him.
## Activation: scripted chases (SHE IS COMING, forest...), HUNTING detection,
## MANIFESTING at UNSTABLE+.
## Behaviour: delegated to the ChaseController (breadcrumb pathing, doors,
## blinks, catch). This state owns the pose, sounds and dialogue.
## Sound: chase music layer, running steps, screams.

var _step_t := 0.0
var _scream_t := 0.0
var enraged := false


func enter(a: Dictionary) -> void:
	enraged = bool(a.get("enraged", false))
	ai.set_mirror_only(false)
	ai.body.set_pose(SatellaBody.Pose.RUN)
	ai.body.tendril_amount = 1.0
	if not ai.visible:
		var p := ai.player
		ai.show_body(p.global_position - p.forward() * 12.0)
	if ai.chase and not ai.chase.is_active():
		ai.chase.start(a)
	_scream_t = randf_range(6.0, 10.0)


func update(delta: float) -> void:
	if ai.chase == null or not ai.chase.is_active():
		ai.sm.change("DISAPPEARING", {"instant": not ai.seen})
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.3
		AudioManager.play_3d("step_wood", ai.global_position + Vector3.UP * 0.1, 0.0, 9.0, 0.75)
	_scream_t -= delta
	if _scream_t <= 0.0:
		_scream_t = randf_range(9.0, 15.0)
		if randf() < 0.5:
			AudioManager.play_3d("witch_giggle", ai.head_pos(), -2.0, 8.0, 1.0, "Voice")
		else:
			ai.say_random("witch_idle", 6, {"position": ai.head_pos()})


func exit() -> void:
	ai.body.speed_hint = 0.0


func interruptible() -> bool:
	return false
