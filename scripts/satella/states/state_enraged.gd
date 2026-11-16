extends SatellaState
## ENRAGED — the Witch loses control.
## Activation: a door slammed in her face at UNSTABLE+, scripted (throne,
## chapter 4), too many escapes.
## Behaviour: chase at higher speed, shadow hands fully extended, lights
## along her path burst violet then die, the world breathes (distortion).
## Sound: scream, chase layer at full volume.

var _pulse_t := 0.0


func enter(a: Dictionary) -> void:
	ai.body.set_pose(SatellaBody.Pose.SCREAM)
	ai.body.tendril_amount = 1.0
	if not ai.visible:
		var p := ai.player
		ai.show_body(p.global_position - p.forward() * 10.0)
	DialogueManager.say("witch_enraged_%d" % randi_range(1, 2), {"position": ai.head_pos()})
	EventBus.world_distortion.emit(0.8, 3.0)
	EventBus.camera_shake.emit(0.4, 0.8)
	var cfg := a.duplicate()
	cfg["enraged"] = true
	cfg["speed"] = float(a.get("speed", 5.6))
	if ai.chase:
		if ai.chase.is_active():
			ai.chase.set_enraged(true)
		else:
			ai.chase.start(cfg)
	_pulse_t = 0.8


func update(delta: float) -> void:
	if time > 0.8:
		ai.body.set_pose(SatellaBody.Pose.RUN)
	if ai.chase == null or not ai.chase.is_active():
		ai.sm.change("DISAPPEARING", {"instant": false})
		return
	_pulse_t -= delta
	if _pulse_t <= 0.0:
		_pulse_t = 2.5
		for l in ai.get_tree().get_nodes_in_group("flicker_lights"):
			if l is FlickerLight and l.global_position.distance_to(ai.global_position) < 6.0:
				l.surge(1.0)
				l.blackout(3.0)


func interruptible() -> bool:
	return false
