extends SatellaState
## DORMANT — she is nowhere (and everywhere). Invisible.
## Activation: default state, after DISAPPEARING, at load.
## Behaviour: counts down an awareness-scaled cooldown, then asks the AI's
## appearance director for a spontaneous appearance. At AWAKENED she may
## whisper, unseen, about how "Subaru" does not move like Subaru.
## Sound: none (silence is part of the design).

var cooldown := 60.0
var _whisper_t := 0.0
var _modify_t := 45.0


func enter(a: Dictionary) -> void:
	ai.hide_body()
	ai.body.set_pose(SatellaBody.Pose.IDLE)
	cooldown = float(a.get("cooldown", ai.next_cooldown()))
	_whisper_t = randf_range(60.0, 120.0)


func update(delta: float) -> void:
	if not ai.autonomous:
		return
	cooldown -= delta
	if cooldown <= 0.0:
		if not ai.try_spontaneous_appearance():
			cooldown = randf_range(6.0, 12.0)
		return
	# OBSESSED+: she modifies the mansion while nobody is looking
	_modify_t -= delta
	if _modify_t <= 0.0:
		_modify_t = randf_range(40.0, 80.0)
		if EnvyAwareness.stage() >= EnvyAwareness.Stage.OBSESSED:
			var g := ai.get_parent()
			if g and g.get("distortion"):
				g.distortion.random_change()
	_whisper_t -= delta
	if _whisper_t <= 0.0:
		_whisper_t = randf_range(70.0, 140.0)
		if EnvyAwareness.stage() >= EnvyAwareness.Stage.AWAKENED and ai.player:
			var dir := -ai.player.forward() + Vector3(randf_range(-0.6, 0.6), 0, 0)
			DialogueManager.say("awake_%d" % randi_range(1, 5), {"direction": dir})
