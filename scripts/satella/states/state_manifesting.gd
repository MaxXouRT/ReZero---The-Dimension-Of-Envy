extends SatellaState
## MANIFESTING — the dramatic approach.
## Activation: OBSESSED+ stare, spontaneous (OBSESSED+), scripted.
## Behaviour: each time the player looks away or the flashlight stutters,
## she is suddenly closer. Lights surge violet, the flashlight dies in
## bursts. When she reaches Subaru: either a jumpscare (she vanishes in his
## face) or, at UNSTABLE+ in zones allowing it, a chase begins.
## Sound: whispers from her position, low stingers on each blink.

var blinks := 0
var _blink_t := 0.0
var _final := false


func enter(a: Dictionary) -> void:
	var pos: Vector3 = a.get("pos", ai.global_position)
	if a.has("spot") and int(a["spot"]) >= 0:
		pos = ai.spots[int(a["spot"])]["pos"]
	ai.show_body(pos)
	ai.set_mirror_only(false)
	ai.body.set_pose(SatellaBody.Pose.STILL)
	ai.body.tendril_amount = 0.6
	blinks = 0
	_blink_t = 1.4
	_final = false
	ai.say_random("witch_idle", 6, {"position": ai.head_pos()})
	EventBus.flashlight_flicker_requested.emit(1.0, 0.8)
	for l in ai.get_tree().get_nodes_in_group("flicker_lights"):
		if l is FlickerLight and l.global_position.distance_to(ai.global_position) < 12.0:
			l.surge(1.0)


func update(delta: float) -> void:
	if _final:
		return
	_blink_t -= delta
	var d := ai.distance_to_player()
	if (ai.unseen_time > 0.25 or _blink_t <= 0.0) and time > 0.6:
		_blink_t = randf_range(1.1, 1.8)
		blinks += 1
		var p := ai.player.global_position
		var new_pos := ai.global_position.lerp(p, 0.42 if d > 6.0 else 0.6)
		new_pos.y = ai.global_position.y
		ai.global_position = new_pos
		ai.face_toward(p)
		ai.player.flashlight.flicker(0.35, 1.0)
		AudioManager.play_3d("whoosh", ai.head_pos(), -8.0)
		ai.player.add_panic(0.15)
		if blinks % 2 == 0:
			AudioManager.play_2d("heartbeat", -2.0)
	if ai.distance_to_player() < 2.6 or time > 18.0:
		_finish()


func _finish() -> void:
	_final = true
	var rules := ai.zone_rules()
	var stage := EnvyAwareness.stage()
	if stage >= EnvyAwareness.Stage.UNSTABLE and rules.get("chase", false) and ai.autonomous and randf() < 0.55:
		DialogueManager.say("c4_she_wait", {"position": ai.head_pos()})
		ai.sm.change("CHASING", {"id": "spontaneous", "speed": 4.9, "max_time": 25.0, "escape_distance": 26.0})
		return
	# jumpscare: she is right in front of you, then gone
	var p := ai.player
	var front := p.global_position + p.forward() * 0.9
	ai.show_body(front)
	ai.face_toward(p.global_position)
	ai.body.set_pose(SatellaBody.Pose.REACH)
	ai.body.set_face_lit(1.0)
	JumpscareState.begin("manifest", 2.5)
	AudioManager.play_jumpscare("stinger_1", -1.0)
	EventBus.camera_shake.emit(0.7, 0.5)
	EventBus.screen_glitch.emit(0.5, 0.4)
	p.add_panic(0.8)
	EnvyAwareness.add(2.0, "manifest_scare")
	await ai.get_tree().create_timer(0.55).timeout
	ai.body.set_face_lit(0.0)
	if ai.sm.current == self:
		ai.sm.change("DISAPPEARING", {"instant": true})


func exit() -> void:
	ai.body.tendril_amount = 1.0
	ai.body.set_face_lit(0.0)
