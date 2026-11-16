class_name PlayerController
extends CharacterBody3D
## Subaru — first-person controller.
##
## Movement: walk / run (stamina) / slow walk / crouch, smooth acceleration,
## head bob, landing dip, FOV kick, camera shake (trauma), footsteps that
## depend on the surface. Interaction ray, object inspection hand-off, and
## the flashlight live under the camera.
##
## Horror hooks:
##   lock(reason) / unlock(reason)    disable control for cutscenes
##   look_at_point(p, t)              scripted camera turn
##   scripted_walk(dir, speed, t)     forced movement (meta ending)
##   can_see_point(p)                 visibility test used by Satella AI
##   die(cause)                       triggers Return by Death
##
## Panic (0..1) rises when Satella is close/visible and drives the heartbeat,
## breathing, vignette and the flashlight's instability.

signal teleported(new_position: Vector3)

const WALK := 3.4
const RUN := 6.1
const SLOW := 1.5
const CROUCH := 1.7
const ACCEL := 11.0
const FRICTION := 13.0
const STAND_H := 1.75
const CROUCH_H := 1.05
const EYE := 1.6

@export var mouse_enabled := true

var head: Node3D
var cam_pivot: Node3D
var camera: Camera3D
var flashlight: FlashlightController
var interaction: InteractionSystem
var collision: CollisionShape3D
var capsule: CapsuleShape3D

var stamina := 1.0
var _stamina_lock := false
var panic := 0.0
var panic_floor := 0.0           ## minimum panic forced by chases
var crouching := false
var dead := false
var current_zone := ""
var _locks := {}
var _yaw := 0.0
var _pitch := 0.0
var _bob_t := 0.0
var _step_dist := 0.0
var _trauma := 0.0
var _trauma_t := 0.0
var _land_dip := 0.0
var _was_on_floor := true
var _scripted_look: Tween
var _scripted_move := Vector3.ZERO
var _scripted_move_time := 0.0
var _scripted_speed := 0.0
var movement_locked := false      ## look allowed, no walking (meta finale)
var touch_move := Vector2.ZERO    ## set by TouchControls
var touch_sprint := false
var _base_fov := 75.0
var _height := STAND_H


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	_build()
	_base_fov = Settings.fov
	camera.fov = _base_fov
	EventBus.camera_shake.connect(add_trauma)
	Settings.settings_changed.connect(func(): _base_fov = Settings.fov)
	AudioManager.set_listener(camera)
	EventBus.player_spawned.emit(self)


func _build() -> void:
	collision = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = STAND_H
	collision.shape = capsule
	collision.position = Vector3(0, STAND_H * 0.5, 0)
	add_child(collision)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, EYE, 0)
	add_child(head)
	cam_pivot = Node3D.new()
	cam_pivot.name = "CamPivot"
	head.add_child(cam_pivot)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.04
	camera.far = 220.0
	camera.current = true
	camera.cull_mask = 0xFFFFF & ~2   # layer 2 = mirror-only reflections
	cam_pivot.add_child(camera)
	flashlight = FlashlightController.new()
	flashlight.name = "Flashlight"
	camera.add_child(flashlight)
	interaction = InteractionSystem.new()
	interaction.name = "Interaction"
	interaction.player = self
	interaction.add_exception(self)
	camera.add_child(interaction)
	if GameState.has_item("flashlight"):
		flashlight.give()


# ------------------------------------------------------------------ input
func lock(reason: String) -> void:
	_locks[reason] = true


func unlock(reason: String) -> void:
	_locks.erase(reason)


func is_input_locked() -> bool:
	return not _locks.is_empty() or dead


func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mouse_enabled:
		var inv := -1.0 if Settings.invert_y else 1.0
		add_look(event.relative * Settings.mouse_sensitivity * Vector2(1.0, inv))
	elif event.is_action_pressed("interact"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Settings.is_mobile() and event is InputEventMouseButton:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		interaction.try_interact()
	elif event.is_action_pressed("flashlight"):
		flashlight.toggle()
	elif event.is_action_pressed("crouch") and Settings.toggle_crouch:
		crouching = not crouching


## Look delta in radians (x = yaw, y = pitch). Used by mouse, gamepad and touch.
func add_look(delta: Vector2) -> void:
	if is_input_locked():
		return
	if _scripted_look and _scripted_look.is_running():
		return
	_yaw -= delta.x
	_pitch = clampf(_pitch - delta.y, deg_to_rad(-86), deg_to_rad(86))
	_apply_look()


func _apply_look() -> void:
	rotation.y = _yaw
	head.rotation.x = _pitch


func set_look(yaw: float, pitch := 0.0) -> void:
	_yaw = yaw
	_pitch = pitch
	_apply_look()


func get_yaw() -> float:
	return _yaw


## Smoothly turns the camera toward a world point (cutscenes / scares).
func look_at_point(target: Vector3, duration := 1.0) -> void:
	var to := target - head.global_position
	var yaw := atan2(-to.x, -to.z)
	var flat := Vector2(to.x, to.z).length()
	var pitch := atan2(to.y, flat)
	# shortest path
	var dy := wrapf(yaw - _yaw, -PI, PI)
	if _scripted_look and _scripted_look.is_valid():
		_scripted_look.kill()
	_scripted_look = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scripted_look.tween_method(_tw_yaw, _yaw, _yaw + dy, duration)
	_scripted_look.tween_method(_tw_pitch, _pitch, clampf(pitch, -1.4, 1.4), duration)


func _tw_yaw(v: float) -> void:
	_yaw = v
	_apply_look()


func _tw_pitch(v: float) -> void:
	_pitch = v
	_apply_look()


func scripted_walk(direction: Vector3, speed: float, duration: float) -> void:
	_scripted_move = direction.normalized()
	_scripted_speed = speed
	_scripted_move_time = duration


func teleport_to(pos: Vector3, yaw: float = NAN) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if not is_nan(yaw):
		_yaw = yaw
		_apply_look()
	teleported.emit(pos)


# ------------------------------------------------------------------ physics
func _physics_process(delta: float) -> void:
	if dead:
		velocity = velocity.move_toward(Vector3.ZERO, FRICTION * delta)
		velocity.y -= 9.8 * delta
		move_and_slide()
		return
	_gamepad_look(delta)
	var input := Vector2.ZERO
	var want_sprint := false
	var want_slow := false
	var want_crouch := crouching
	if not is_input_locked():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch_move.length() > 0.05:
			input = touch_move
		want_sprint = Input.is_action_pressed("sprint") or touch_sprint
		want_slow = Input.is_action_pressed("slow_walk")
		if not Settings.toggle_crouch:
			want_crouch = Input.is_action_pressed("crouch") or crouching
		if movement_locked:
			input = Vector2.ZERO
			want_sprint = false
	# crouch height (cannot stand up under a low ceiling)
	if not want_crouch and _height < STAND_H - 0.01 and _blocked_above():
		want_crouch = true
	var target_h := CROUCH_H if want_crouch else STAND_H
	_height = move_toward(_height, target_h, delta * 4.0)
	capsule.height = _height
	collision.position.y = _height * 0.5
	head.position.y = _height - (STAND_H - EYE) + _land_dip
	var moving := input.length() > 0.1
	var speed := WALK
	if want_crouch:
		speed = CROUCH
	elif want_slow:
		speed = SLOW
	elif want_sprint and moving and not _stamina_lock and input.y < 0.3:
		speed = RUN
	var sprinting := speed == RUN
	# stamina
	if sprinting:
		stamina = maxf(0.0, stamina - delta * 0.11)
		if stamina <= 0.0:
			_stamina_lock = true
			AudioManager.play_2d("breath_out", -6.0)
	else:
		stamina = minf(1.0, stamina + delta * (0.16 if moving else 0.24))
		if stamina > 0.35:
			_stamina_lock = false
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	if _scripted_move_time > 0.0:
		_scripted_move_time -= delta
		dir = _scripted_move
		speed = _scripted_speed
		moving = true
	dir = dir.normalized() * minf(1.0, input.length() if _scripted_move_time <= 0.0 else 1.0)
	var target_v := dir * speed
	var accel := ACCEL if moving else FRICTION
	velocity.x = move_toward(velocity.x, target_v.x, accel * delta * speed)
	velocity.z = move_toward(velocity.z, target_v.z, accel * delta * speed)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = maxf(velocity.y, -0.1)
	move_and_slide()
	# landing
	if is_on_floor() and not _was_on_floor:
		_land_dip = -0.12
		_play_step(1.2)
	_was_on_floor = is_on_floor()
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.6)
	_update_camera_fx(delta, sprinting)
	_footsteps(delta)
	_update_panic(delta)
	if global_position.y < -60.0:
		die("void_fall")


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * _height, global_position + Vector3.UP * (STAND_H + 0.1), 1)
	return not space.intersect_ray(q).is_empty()


func _gamepad_look(delta: float) -> void:
	if is_input_locked():
		return
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if v.length() > 0.0:
		var inv := -1.0 if Settings.invert_y else 1.0
		add_look(Vector2(v.x, v.y * inv) * Settings.gamepad_sensitivity * delta)


func _update_camera_fx(delta: float, sprinting: bool) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var reduce := Settings.reduce_camera_motion
	# head bob
	var bob := Vector3.ZERO
	if is_on_floor() and hspeed > 0.3 and not reduce:
		_bob_t += delta * hspeed * 1.9
		bob = Vector3(sin(_bob_t) * 0.025, abs(cos(_bob_t)) * 0.04, 0) * clampf(hspeed / WALK, 0.3, 1.5)
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 3.0)
	# trauma shake
	var shake := Vector3.ZERO
	var shake_rot := Vector3.ZERO
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.4)
		_trauma_t += delta * 30.0
		var amt := _trauma * _trauma * (0.35 if reduce else 1.0)
		shake = Vector3(sin(_trauma_t * 1.3), sin(_trauma_t * 1.7 + 2.0), 0) * 0.03 * amt
		shake_rot = Vector3(sin(_trauma_t * 1.1 + 4.0), sin(_trauma_t * 0.9 + 1.0), sin(_trauma_t * 1.5)) * 0.04 * amt
	# panic tremor
	if panic > 0.5 and not reduce:
		shake_rot.z += sin(Time.get_ticks_msec() * 0.013) * 0.004 * panic
	cam_pivot.position = bob + shake
	cam_pivot.rotation = shake_rot
	# FOV
	var target_fov := _base_fov + (6.0 if sprinting and not reduce else 0.0) - panic * 4.0
	camera.fov = lerpf(camera.fov, target_fov, delta * 4.0)


func _footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed < 0.4:
		return
	_step_dist += hspeed * delta
	var stride := 0.62 if hspeed < 4.0 else 0.85
	if _step_dist >= stride:
		_step_dist = 0.0
		_play_step(clampf(hspeed / WALK, 0.3, 1.4))


func _play_step(loudness: float) -> void:
	var surface := "wood"
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.4, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] is Node:
		var col: Node = hit["collider"]
		if col.has_meta("surface"):
			surface = String(col.get_meta("surface"))
	var vol := lerpf(-26.0, -10.0, clampf(loudness, 0.0, 1.0))
	if crouching or _height < STAND_H - 0.2:
		vol -= 6.0
	AudioManager.play_2d("step_" + surface, vol, randf_range(0.9, 1.08))


func add_trauma(amount: float, _duration: float = 0.0) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func add_panic(amount: float) -> void:
	panic = clampf(panic + amount, 0.0, 1.0)


func _update_panic(delta: float) -> void:
	panic = maxf(panic_floor, panic - delta * 0.08)
	AudioManager.set_panic(panic)
	EventBus.player_panic_changed.emit(panic)
	flashlight.instability = clampf((panic - 0.4) * 1.2, 0.0, 1.0)


# ------------------------------------------------------------------ visibility
## True when `p` is inside the view cone and not hidden behind walls.
func can_see_point(p: Vector3, min_dot := 0.55) -> bool:
	var from := camera.global_position
	var to := p - from
	var fwd := -camera.global_transform.basis.z
	if fwd.dot(to.normalized()) < min_dot:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, p, 1)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func is_in_frustum(p: Vector3) -> bool:
	return camera.is_position_in_frustum(p)


func look_dot(p: Vector3) -> float:
	var to := (p - camera.global_position).normalized()
	return (-camera.global_transform.basis.z).dot(to)


func eye_position() -> Vector3:
	return camera.global_position


func forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0
	return f.normalized()


# ------------------------------------------------------------------ death
func die(cause: String) -> void:
	if dead:
		return
	dead = true
	EventBus.player_died.emit(cause)
