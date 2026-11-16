extends SatellaState
## FOLLOWING — she walks behind Subaru, keeping her distance.
## Activation: spontaneous (AWARE+), scripted ("follow").
## Behaviour: stays 6-10 m behind the player, on his path. Her footsteps echo
## his own a beat later and stop when he stops. If he turns around, she is
## there for a split second... then gone.
## Sound: echoing footsteps (3D), a breath when very close.

var distance := 8.0
var duration := 25.0
var _step_acc := 0.0
var _last_player_pos := Vector3.ZERO
var _caught_looking := 0.0


func enter(a: Dictionary) -> void:
	distance = float(a.get("distance", randf_range(6.0, 9.5)))
	duration = float(a.get("duration", randf_range(18.0, 32.0)))
	ai.hide_body()
	ai.visible = false
	ai.body.set_pose(SatellaBody.Pose.WALK)
	_last_player_pos = ai.player_pos()
	_caught_looking = 0.0


func update(delta: float) -> void:
	var p := ai.player
	var behind := p.global_position - p.forward() * distance
	# keep her where the player could actually see her if he turned around
	var space := ai.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p.eye_position(), behind + Vector3.UP * 1.5, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		behind = p.global_position.lerp(Vector3(hit["position"].x, p.global_position.y, hit["position"].z), 0.8)
	var can_show := p.global_position.distance_to(behind) > 3.0
	if not ai.visible and can_show and not p.is_in_frustum(behind + Vector3.UP * 1.3):
		ai.show_body(behind)
	elif ai.visible:
		ai.glide_toward(behind, 4.5, delta)
		if not can_show and not ai.seen:
			ai.visible = false
	# echo footsteps
	var moved := p.global_position.distance_to(_last_player_pos)
	_last_player_pos = p.global_position
	_step_acc += moved
	if _step_acc > 0.75:
		_step_acc = 0.0
		AudioManager.play_3d("step_wood", ai.global_position + Vector3.UP * 0.1, -10.0, 5.0, randf_range(0.8, 0.9))
	if ai.seen:
		_caught_looking += delta
		if _caught_looking > 0.35:
			AudioManager.play_2d("stinger_2", -10.0)
			ai.player.add_panic(0.4)
			EnvyAwareness.add(1.0, "caught_following")
			ai.sm.change("DISAPPEARING", {"instant": true})
			return
	if time > duration:
		if ai.sees_player(10.0) and randf() < 0.4:
			DialogueManager.say("witch_behind", {"position": ai.head_pos()})
		ai.sm.change("DISAPPEARING", {"instant": true})
